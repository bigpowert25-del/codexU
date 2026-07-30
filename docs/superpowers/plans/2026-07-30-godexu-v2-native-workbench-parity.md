# GodexU 2.0 Native Workbench Parity Implementation Plan

> **Execution:** implement inline with the `executing-plans` workflow. Keep the
> current worktree and preserve the untracked `.superpowers/` reference files.

**Goal:** Replace the fixed legacy main-window stack with the approved native
GodexU 2.0 wide workbench, with materially distinct stages and skins.

**Architecture:** Keep existing data stores/readers and expose them through a
new responsive shell. Add pure stage-layout and full-surface skin contracts,
then compose overview, projects, tasks, Agents, usage, and skills as native
destinations. Change main-window geometry independently from Dynamic Island and
status-bar geometry.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Foundation, existing stores and
executable self-test harness.

---

## Locked Scope

- Project root:
  `/Users/mac/.config/superpowers/worktrees/codexU/dynamic-island-local-prototype`
- Allowed production paths:
  `Sources/CodexUsageWidget/**`, `Makefile`, and this task's docs/run evidence.
- Visual reference:
  `.superpowers/brainstorm/63586-1785399492/content/godexu-v2-orbit-command-v3.html`
  plus the user-provided 2026-07-30 screenshot.
- Acceptance denominator:
  3 distinct stages, 5 distinct full-surface skins, 7 overview modules, 6
  existing regression surfaces, and one installed-app visual/interaction pass.
- Excluded:
  one-click repair, NAS mutation, Letta deployment, Windows implementation,
  token-accounting changes, release tags, and public GitHub Release.

## Task 1: Prove Stage And Skin Contracts Fail First

- [ ] Extend `GodexUWorkbenchPreferencesSelfTest` with unique layout-profile
  assertions for Light, Sync, and Command.
- [ ] Assert stage-specific section sets and inspector behavior.
- [ ] Assert every skin supplies a full surface palette and that palette
  identities are unique.
- [ ] Assert the built-in skins differ in canvas luminance, radius, or density,
  not only accent color.
- [ ] Run `make test-workbench-preferences` and capture the expected RED result.

## Task 2: Implement Pure Layout And Full-Surface Theme Models

- [ ] Add `GodexUWorkbenchLayoutProfile` and section contracts.
- [ ] Expand `GodexUSkinVisualTokens` to canvas, shell, panel, text, separator,
  radius, density, grid, and shadow responsibilities.
- [ ] Keep persisted skin/stage identifiers backward compatible.
- [ ] Re-run the focused self-test until GREEN.

## Task 3: Build The Native Shell

- [ ] Replace the root vertical stack with a responsive top bar, left rail, and
  stage-aware main canvas.
- [ ] Add overview hero and current-node relationship graph.
- [ ] Add the real-data KPI rail.
- [ ] Add recent-project continuation using
  `AgentProjectWorkspaceBuilder`.
- [ ] Add 2×2 CPU, memory, thermal, and index-availability cards.
- [ ] Add a truthful status ticker and local task-package composer.
- [ ] Add the Command inspector without repair mutation.
- [ ] Retain existing tasks, projects, usage, skills, Agent identity, and
  environment diagnostics as navigable destinations.

## Task 4: Make Main Window Responsive

- [ ] Change the default main-window content size to 1320 × 820.
- [ ] Permit horizontal and vertical resizing down to 1040 × 680.
- [ ] Clamp first launch to the current visible display.
- [ ] Keep Dynamic Island and status-bar sizes unchanged.
- [ ] Keep runtime selection accessible inside the Usage destination.

## Task 5: Automated And Visual Verification

- [ ] Run the focused workbench self-test.
- [ ] Run `make build`.
- [ ] Run all built-in executable self-tests and parser/MCP fixtures.
- [ ] Run `git diff --check` and privacy/source scans.
- [ ] Launch the development app with isolated preferences.
- [ ] Capture and inspect Light, Sync, and Command screenshots.
- [ ] Capture and inspect all five skin screenshots at Sync.
- [ ] Verify task detail, project selection, Agent identity sheet, settings,
  status bar, and Dynamic Island.
- [ ] Test the minimum and default window sizes for clipping.

## Task 6: Install And Continue Phase 2D

- [ ] Back up the currently installed `/Applications/codexU.app`.
- [ ] Install the verified build and repeat the installed-app smoke test.
- [ ] Record root cause, changed scope, verification totals, exclusions, and
  rollback.
- [ ] After UI parity passes, begin the independent human-confirmed
  Codex-to-OpenClaw/Hermes delivery slice.
- [ ] Keep one-click repair outside that delivery slice.

## Task 7: Publish The Verified Candidate

- [ ] Review the final diff against the locked scope.
- [ ] Commit the implementation and verification record.
- [ ] Push the existing branch and update the existing draft PR.
- [ ] Verify the remote commit and PR content.
- [ ] Do not create a tag or GitHub Release.
