# Dynamic Island Local Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a local-only macOS Dynamic Island mode to codexU and a lightweight Windows Dynamic Island prototype that can display Codex / OpenClaw / Hermes status from a local snapshot.

**Architecture:** macOS stays inside codexU and reuses the existing `UsageStore`, `RuntimeScope`, `TaskBoard`, and `LocalSystemMonitor` data instead of creating a second statistics pipeline. Windows is a separate WPF/.NET 8 prototype copied from a MIT Dynamic Island base, with codexU-specific local JSON snapshot models added on top.

**Tech Stack:** Swift/AppKit/SwiftUI for macOS codexU; WPF/.NET 8 for Windows; local JSON only for cross-machine agent snapshots.

---

## Boundary and approvals

- `execution_approval`: user said “能copy的直接copy，听我的，我们只是在本机上做着玩” on 2026-07-27.
- Allowed writes:
  - `Sources/CodexUsageWidget/Domain/DynamicIslandPresentation.swift`
  - `Sources/CodexUsageWidget/Domain/DynamicIslandPresentationSelfTest.swift`
  - `Sources/CodexUsageWidget/UI/DynamicIslandView.swift`
  - `Sources/CodexUsageWidget/UI/DynamicIslandWindowController.swift`
  - `Sources/CodexUsageWidget/main.swift`
  - `Makefile`
  - `THIRD_PARTY_NOTICES.md`
  - `docs/superpowers/plans/2026-07-27-dynamic-island-local-prototype.md`
  - `WindowsIsland/**`
- Explicitly excluded:
  - no NAS writes or service changes;
  - no dependency installation in this turn;
  - no GitHub push or public release;
  - no GPL/eIsland, CC BY-NC/MioIsland, or no-license Python code copied into the publishable tree.

## Reuse decision

```text
reuse_decision: adapt
reason: CodexIsland is MIT and Ping Island is Apache 2.0, so macOS ideas can be reused with attribution. dynamic-island-on-windows is MIT and can be copied as the Windows base. eIsland, MioIsland, PyIsland, and rajsriv/dynamic-island-for-windows remain reference-only for public-safe code.
checked_at: 2026-07-27
sources: ericjypark/codex-island, erha19/ping-island, sadeeshasathsara/dynamic-island-on-windows, JNTMTMTM/eIsland, Python-island/Python-island, rajsriv/dynamic-island-for-windows
```

## Task 1: macOS presentation model self-test

**Files:**
- Create: `Sources/CodexUsageWidget/Domain/DynamicIslandPresentation.swift`
- Create: `Sources/CodexUsageWidget/Domain/DynamicIslandPresentationSelfTest.swift`
- Modify: `Sources/CodexUsageWidget/main.swift`
- Modify: `Makefile`

- [x] **Step 1: Write the failing self-test**

Create a self-test that expects:

- Codex quota and token metrics appear when a Codex runtime summary is available.
- OpenClaw/Hermes companion status is read from runtime summaries.
- Attention tasks sort ahead of active tasks, and stale inactive tasks are ignored.
- System CPU, memory, and thermal state are formatted without exposing private data.

- [x] **Step 2: Run the self-test and verify RED**

Run: `make test-dynamic-island`

Expected: build fails because `DynamicIslandPresentationSelfTest` is not implemented yet.

- [x] **Step 3: Implement the minimal model**

Add `DynamicIslandPresentationBuilder` that takes:

```swift
struct DynamicIslandPresentationInput {
    let runtimes: [RuntimeUsageSnapshot]
    let visibleScopes: [RuntimeScope]
    let aggregateTaskBoard: TaskBoard?
    let system: LocalSystemSnapshot
    let language: WidgetLanguage
    let now: Date
}
```

and returns a presentation with compact headline, quota text, system metrics, companion runtime rows, and up to three attention tasks.

- [x] **Step 4: Verify GREEN**

Run:

```sh
make test-dynamic-island
make build
```

Expected: self-test passes and codexU builds.

## Task 2: macOS island window

**Files:**
- Create: `Sources/CodexUsageWidget/UI/DynamicIslandView.swift`
- Create: `Sources/CodexUsageWidget/UI/DynamicIslandWindowController.swift`
- Modify: `Sources/CodexUsageWidget/main.swift`

- [x] **Step 1: Add a floating AppKit controller**

Implement an `NSWindowController` with:

- borderless transparent window;
- `.statusBar` level;
- `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.transient`, `.ignoresCycle`;
- top-center placement on the selected screen;
- compact / peek / expanded modes inspired by MIT/Apache projects.

- [x] **Step 2: Add SwiftUI island surface**

Implement a small Liquid Glass-compatible SwiftUI view:

- compact: Codex quota and today token headline;
- peek: CPU, memory, thermal/temp, active/attention task counts;
- expanded: runtime rows and top attention tasks;
- no prompt, reply body, tool arguments, auth, raw logs, or full paths.

- [x] **Step 3: Wire into AppDelegate**

Create the island controller at app launch, feed it `UsageStore`, `AppSettings`, and `LocalSystemMonitor`, and stop the monitor on termination.

- [x] **Step 4: Verify**

Run:

```sh
make test-dynamic-island
make test-local-system
make build
open build/codexU.app
```

Expected: codexU launches, island appears top-center, main window/status popover still work.

## Task 3: Windows WPF prototype

**Files:**
- Create: `WindowsIsland/**`
- Modify: `THIRD_PARTY_NOTICES.md`

- [x] **Step 1: Copy MIT Windows base**

Copy the MIT WPF Dynamic Island base from the isolated clone:

`/Users/mac/.openclaw/workspace/scratch/codexu-dynamic-island-research-20260727/repos/dynamic-island-on-windows`

into:

`WindowsIsland/`

Keep the original MIT `LICENSE` in `WindowsIsland/LICENSE`.

- [x] **Step 2: Rename and add codexU snapshot models**

Rename namespace/assembly to `CodexUIsland`, add:

- `Core/CodexUSnapshot.cs`
- `Services/CodexUSnapshotReader.cs`
- `sample-status.json`

The reader loads `CODEXU_ISLAND_SNAPSHOT` when set, otherwise `sample-status.json`.

- [x] **Step 3: Add a local status display path**

Make the WPF island show Codex/OpenClaw/Hermes status from the snapshot on launch. Keep notification listener code but do not require notification permission for the local status path.

- [x] **Step 4: Verify structure on macOS without installing .NET**

Run:

```sh
find WindowsIsland -maxdepth 3 -type f | sort
git diff --check
```

Expected: project files are present and whitespace checks pass. Full Windows build remains pending for a Windows machine.

## Task 4: final validation

**Files:**
- All allowed files.

- [x] **Step 1: Run local checks**

Run:

```sh
git status --short
git diff --check
make test-dynamic-island
make test-local-system
make build
```

- [x] **Step 2: Run app smoke**

Run:

```sh
osascript -e 'quit app "codexU"' >/dev/null 2>&1 || true
open build/codexU.app
```

Expected: codexU launches with the island visible and the main dashboard still accessible.

- [x] **Step 3: Stop before external writes**

Do not push, create a release, install into `/Applications`, or touch NAS without fresh user approval after validation.
