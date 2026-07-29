# Side-Docked Dynamic Island Content-Fit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the oversized empty area in left/right compact and peek Dynamic Island modes without changing their content or interaction.

**Architecture:** Keep the existing fixed-size AppKit panel model. Tighten only the vertical compact and peek size budgets and make the SwiftUI vertical stacks hug their content by removing unconstrained spacers.

**Tech Stack:** Swift 6, SwiftUI, AppKit, existing command-line self-test harness.

---

### Task 1: Add the failing side-layout regression

**Files:**
- Modify: `Sources/CodexUsageWidget/Domain/DynamicIslandPresentationSelfTest.swift`

- [ ] **Step 1: Add exact vertical compact and peek size assertions**

Extend `runDockingTest()` to require right compact size `54 × 142`, right peek size `92 × 270`, and identical left/right sizes.

- [ ] **Step 2: Run the self-test to verify RED**

Run:

```sh
make build
build/codexU.app/Contents/MacOS/codexU --self-test-dynamic-island
```

Expected: the build succeeds and the self-test fails because the implementation still returns heights `226` and `438`.

### Task 2: Make side layouts hug their content

**Files:**
- Modify: `Sources/CodexUsageWidget/UI/DynamicIslandView.swift`

- [ ] **Step 1: Implement the minimal size correction**

Change only the vertical compact and peek sizes to `54 × 142` and `92 × 270`.

- [ ] **Step 2: Remove the two surplus-height spacers**

Remove `Spacer(minLength: 0)` immediately before `statusDot` in `verticalCompactContent` and `verticalPeekContent`.

- [ ] **Step 3: Run the self-test to verify GREEN**

Run:

```sh
make build
build/codexU.app/Contents/MacOS/codexU --self-test-dynamic-island
```

Expected: `dynamic island presentation self-test passed`.

### Task 3: Regression and real UI acceptance

**Files:**
- Create: `docs/superpowers/runs/20260729-side-docked-island-content-fit.md`

- [ ] **Step 1: Run the regression set**

```sh
build/codexU.app/Contents/MacOS/codexU --self-test-display-surface
build/codexU.app/Contents/MacOS/codexU --self-test-status-item
git diff --check
```

Expected: every command exits `0`.

- [ ] **Step 2: Run real UI acceptance**

Launch the built app, dock the island to the right and left, then inspect compact and hover/peek modes. Each capsule must end shortly below the status dot without the marked empty block.

- [ ] **Step 3: Record evidence and rollback**

Record the exact changed paths, verification results, visual evidence, unverified items, rollback target, and remote-write state in the run record.
