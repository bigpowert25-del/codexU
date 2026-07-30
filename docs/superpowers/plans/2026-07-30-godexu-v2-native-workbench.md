# GodexU 2.0 Native Workbench Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the approved high-information-density GodexU 2.0 workbench to the macOS app, with Titanium Studio as the safe default skin.

**Architecture:** Add a pure local preference contract for skin and workbench stage, persist it through the existing `AppSettings`, and compose a new native header/core-overview layer over the current usage, system, Agent, task, project, and Dynamic Island surfaces. Reuse all existing readers and stores; do not add networking, polling, task mutation, or dependencies.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Foundation, UserDefaults, Make, existing executable self-test harness.

---

## Locked Scope And File Map

The implementation stays in the isolated worktree. It does not access NAS,
change task delivery, alter token accounting, implement Windows, replace
`/Applications/codexU.app`, bump the version, push GitHub, or publish a release.
The `.superpowers/` prototype directory is design evidence only and is excluded
from the production diff.

- Create `Sources/CodexUsageWidget/Domain/GodexUWorkbenchPreferences.swift`
- Create `Sources/CodexUsageWidget/Domain/GodexUWorkbenchPreferencesSelfTest.swift`
- Create `Sources/CodexUsageWidget/UI/GodexUWorkbenchViews.swift`
- Modify `Sources/CodexUsageWidget/UI/RuntimeViews.swift`
- Modify `Sources/CodexUsageWidget/main.swift`
- Modify `Makefile`
- Create/update this plan, the approved design spec, and the run record

### Task 1: Define The Skin And Stage Contract

- [x] Create `GodexUWorkbenchPreferencesSelfTest` first.
- [x] Route `--self-test-workbench-preferences` in `main.swift` and add
  `make test-workbench-preferences`.
- [x] Run `make build` and record the expected RED result for missing
  `GodexUSkin` and `GodexUWorkbenchStage`.
- [x] Implement five stable skin identifiers, three stage identifiers,
  Titanium Studio/Sync defaults, localized names, centralized non-semantic
  visual tokens, persistence helpers, and invalid-value fallback.
- [x] Run the focused self-test and record GREEN.

### Task 2: Persist Preferences Through AppSettings

- [x] Extend the failing self-test to construct isolated `UserDefaults` suites.
- [x] Prove fresh settings use Titanium Studio and Sync, valid mutations
  round-trip, and unknown raw values fall back.
- [x] Add published `workbenchSkin` and `workbenchStage` values to `AppSettings`
  with local persistence only.
- [x] Re-run the focused self-test.

### Task 3: Add The Native Workbench Presentation

- [x] Create `GodexUWorkbenchViews.swift` with:
  - a native workbench identity header;
  - a three-stage picker;
  - an accessible five-skin menu;
  - a source-labeled core overview strip.
- [x] Compute official latest active-day/seven-day tokens from existing official
  trend data,
  task counts from the combined task board, and node availability from current
  node snapshots.
- [x] Render missing data as `--`, not fabricated zero.
- [x] Inject centralized workbench chrome tokens and keep semantic status colors
  under `WidgetPalette`.
- [x] Compose sections in `UsageWidgetView` according to Light/Sync/Command,
  with Sync as the information-dense default.
- [x] Add settings rows for default stage and skin without changing the existing
  light/dark appearance selector.

### Task 4: Regression And Real UI Acceptance

- [x] Run the focused preference test.
- [x] Run `make build`.
- [x] Run display-surface, Dynamic Island, task navigation, project-index,
  Agent selection/node/identity, handoff, local-system, token-normalizer,
  parser, and MCP helper tests.
- [x] Run `git diff --check`.
- [x] Launch the built development app without replacing the installed app.
- [x] Verify Titanium Studio is the fresh default in an isolated preferences
  domain, controls work, information density is preserved, there is no clipped
  content/horizontal overflow, and existing task/project/Agent surfaces remain
  usable.
- [x] Capture a local screenshot as acceptance evidence.
- [x] Record totals, failures, gaps, build identity, and rollback in the run
  record.

### Task 5: Completion Boundary

- [x] Confirm `.superpowers/` is absent from the production file map.
- [x] Confirm NAS, Windows, installed app, version, GitHub, and release state are
  unchanged.
- [x] Stop at the local acceptance gate and request separate authorization
  before installation or remote publication.
