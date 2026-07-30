APP_NAME := codexU
DISPLAY_NAME := codexU
VERSION := $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist 2>/dev/null || echo 0.1.0)
BUILD_DIR := build
DIST_DIR := dist
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
MACOS_DIR := $(APP_DIR)/Contents/MacOS
RESOURCES_DIR := $(APP_DIR)/Contents/Resources
HELPERS_DIR := $(APP_DIR)/Contents/Helpers
MCP_HELPER_PACKAGE := MCPHelper
MCP_HELPER_PRODUCT := GodexUMCPServer
SOURCES := $(shell find Sources/CodexUsageWidget -name '*.swift' | sort)
APP_ICON := Resources/codexU.icns
DEPLOYMENT_TARGET ?= 14.0
HOST_ARCH := $(shell uname -m)
APPLE_SILICON_TARGET_TRIPLE ?= arm64-apple-macos$(DEPLOYMENT_TARGET)
INTEL_TARGET_TRIPLE ?= x86_64-apple-macos$(DEPLOYMENT_TARGET)
TARGET_TRIPLE ?= $(HOST_ARCH)-apple-macos$(DEPLOYMENT_TARGET)
ARCH_NAME := $(shell echo "$(TARGET_TRIPLE)" | sed -E 's/-apple-macos.*//')
DMG_NAME := $(APP_NAME)-$(VERSION)-mac-$(ARCH_NAME).dmg
DMG_PATH := $(DIST_DIR)/$(DMG_NAME)
SIGN_IDENTITY ?= -
CODESIGN_EXTRA_FLAGS ?=
SWIFTC_TARGET_FLAGS := -target $(TARGET_TRIPLE)
SWIFT_OPT_FLAGS ?= -O -whole-module-optimization

ifeq ($(SIGN_IDENTITY),-)
CODESIGN_FLAGS := --force --deep --sign -
else
CODESIGN_FLAGS := --force --deep --options runtime --timestamp --sign "$(SIGN_IDENTITY)" $(CODESIGN_EXTRA_FLAGS)
endif

.PHONY: build build-mcp-helper run probe test-rate-limits test-statistics-time-zone test-particle-animation test-display-surface test-task-navigation test-local-system test-agent-selection test-agent-nodes test-agent-identity test-task-envelopes test-task-envelope-store test-codex-token-events test-project-index test-mcp-helper test-dynamic-island test-parsers install dmg dmg-arm64 dmg-intel checksum checksum-arm64 checksum-intel release release-arm64 release-intel release-all release-package release-check notarize verify clean clean-dist

build-mcp-helper:
	swift build --package-path "$(MCP_HELPER_PACKAGE)" -c release --triple "$(TARGET_TRIPLE)" --product "$(MCP_HELPER_PRODUCT)"

build: build-mcp-helper
	rm -rf "$(APP_DIR)"
	mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)" "$(HELPERS_DIR)"
	cp Resources/Info.plist "$(APP_DIR)/Contents/Info.plist"
	cp "$(APP_ICON)" "$(RESOURCES_DIR)/"
	cp Resources/*.png "$(RESOURCES_DIR)/"
	/usr/bin/xattr -dr com.apple.quarantine "$(APP_DIR)" 2>/dev/null || true
	MACOSX_DEPLOYMENT_TARGET="$(DEPLOYMENT_TARGET)" swiftc $(SWIFT_OPT_FLAGS) -parse-as-library $(SWIFTC_TARGET_FLAGS) $(SOURCES) \
		-o "$(MACOS_DIR)/$(APP_NAME)" \
		-framework Cocoa \
		-framework Carbon \
		-framework Network \
		-framework SwiftUI
	HELPER_BIN_DIR="$$(swift build --package-path "$(MCP_HELPER_PACKAGE)" -c release --triple "$(TARGET_TRIPLE)" --show-bin-path)"; \
		cp "$$HELPER_BIN_DIR/$(MCP_HELPER_PRODUCT)" "$(HELPERS_DIR)/$(MCP_HELPER_PRODUCT)"
	chmod 755 "$(HELPERS_DIR)/$(MCP_HELPER_PRODUCT)"
	codesign $(CODESIGN_FLAGS) "$(HELPERS_DIR)/$(MCP_HELPER_PRODUCT)"
	codesign $(CODESIGN_FLAGS) "$(APP_DIR)"
	codesign --verify --deep --strict "$(APP_DIR)"

run: build
	open "$(APP_DIR)"

probe: build
	"$(MACOS_DIR)/$(APP_NAME)" --dump-json

test-rate-limits:
	./scripts/test-rate-limits.sh

test-statistics-time-zone:
	./scripts/test-statistics-time-zone.sh

test-particle-animation:
	./scripts/test-particle-animation.sh

test-display-surface: build
	"$(MACOS_DIR)/$(APP_NAME)" --self-test-display-surface

test-task-navigation: build
	"$(MACOS_DIR)/$(APP_NAME)" --self-test-task-navigation

test-local-system: build
	"$(MACOS_DIR)/$(APP_NAME)" --self-test-local-system

test-agent-selection: build
	"$(MACOS_DIR)/$(APP_NAME)" --self-test-agent-selection

test-agent-nodes: build
	"$(MACOS_DIR)/$(APP_NAME)" --self-test-agent-nodes

test-agent-identity: build
	"$(MACOS_DIR)/$(APP_NAME)" --self-test-agent-identity

test-task-envelopes: build
	"$(MACOS_DIR)/$(APP_NAME)" --self-test-task-envelopes

test-task-envelope-store: build
	"$(MACOS_DIR)/$(APP_NAME)" --self-test-task-envelope-store

test-codex-token-events: build
	"$(MACOS_DIR)/$(APP_NAME)" --self-test-codex-token-events

test-project-index: build
	CODEXU_SKIP_BUILD=1 ./scripts/test-project-index.sh

test-mcp-helper: build
	./scripts/test-mcp-helper.sh

test-dynamic-island: build
	"$(MACOS_DIR)/$(APP_NAME)" --self-test-dynamic-island

test-parsers: build
	CODEXU_SKIP_BUILD=1 ./scripts/test-parsers.sh

install: build
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(APP_DIR)" "/Applications/$(APP_NAME).app"
	open "/Applications/$(APP_NAME).app"

dmg: build
	APP_NAME="$(APP_NAME)" \
	DISPLAY_NAME="$(DISPLAY_NAME)" \
	VERSION="$(VERSION)" \
	ARCH_NAME="$(ARCH_NAME)" \
	BUILD_DIR="$(BUILD_DIR)" \
	DIST_DIR="$(DIST_DIR)" \
	APP_DIR="$(APP_DIR)" \
	DMG_PATH="$(DMG_PATH)" \
	DMG_SIGN_IDENTITY="$(DMG_SIGN_IDENTITY)" \
	./scripts/package-dmg.sh

dmg-arm64:
	$(MAKE) dmg TARGET_TRIPLE="$(APPLE_SILICON_TARGET_TRIPLE)"

dmg-intel:
	$(MAKE) dmg TARGET_TRIPLE="$(INTEL_TARGET_TRIPLE)"

checksum: dmg
	shasum -a 256 "$(DMG_PATH)" > "$(DMG_PATH).sha256"
	@cat "$(DMG_PATH).sha256"

checksum-arm64:
	$(MAKE) checksum TARGET_TRIPLE="$(APPLE_SILICON_TARGET_TRIPLE)"

checksum-intel:
	$(MAKE) checksum TARGET_TRIPLE="$(INTEL_TARGET_TRIPLE)"

release: clean checksum
	@echo "Release artifact: $(DMG_PATH)"

release-arm64:
	$(MAKE) release TARGET_TRIPLE="$(APPLE_SILICON_TARGET_TRIPLE)"

release-intel:
	$(MAKE) release TARGET_TRIPLE="$(INTEL_TARGET_TRIPLE)"

release-all: clean-dist
	$(MAKE) release-arm64
	$(MAKE) release-intel

release-package:
	./scripts/build-release-artifacts.sh "$(VERSION)"

release-check:
	./scripts/check-release-ready.sh "$(VERSION)"

notarize: dmg
	APPLE_ID="$(APPLE_ID)" \
	TEAM_ID="$(TEAM_ID)" \
	NOTARY_PASSWORD="$(NOTARY_PASSWORD)" \
	DMG_PATH="$(DMG_PATH)" \
	./scripts/notarize-dmg.sh

verify: build
	file "$(MACOS_DIR)/$(APP_NAME)"
	codesign -dv --verbose=4 "$(APP_DIR)"

clean:
	rm -rf "$(BUILD_DIR)"

clean-dist:
	rm -rf "$(DIST_DIR)"
