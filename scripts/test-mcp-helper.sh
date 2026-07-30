#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PACKAGE="$ROOT/MCPHelper"

swift build --package-path "$PACKAGE" --product GodexUMCPServer
swift build --package-path "$PACKAGE" --product GodexUMCPProbe
swift run --package-path "$PACKAGE" GodexUMCPContractTests

BIN_DIR="$(swift build --package-path "$PACKAGE" --show-bin-path)"
"$BIN_DIR/GodexUMCPProbe" "$BIN_DIR/GodexUMCPServer"

APP="$ROOT/build/codexU.app"
HELPER="$APP/Contents/Helpers/GodexUMCPServer"
EXPECTED_ARCH="${EXPECTED_ARCH:-$(uname -m)}"

test -x "$HELPER"
file "$HELPER" | grep -q "$EXPECTED_ARCH"
codesign --verify --strict "$HELPER"
codesign --verify --deep --strict "$APP"

echo "MCP helper tests passed"
