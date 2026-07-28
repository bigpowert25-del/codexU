# Display Surface Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let codexU users choose whether to show the original app surface, the Dynamic Island surface, or both.

**Architecture:** Add one persisted display-surface preference to `AppSettings`, expose it in Settings, and let `AppDelegate` create/remove the main window/status item and Dynamic Island according to that preference. Keep data loading, token accounting, task behavior, NAS boundaries, and Dynamic Island placement unchanged.

**Tech Stack:** Swift/AppKit/SwiftUI, existing UserDefaults-backed settings, existing executable self-test pattern.

---

## Files

- Modify: `Sources/CodexUsageWidget/main.swift`
- Modify: `Makefile`
- Modify: `docs/superpowers/runs/20260727-0953-dynamic-island-local-prototype.md`

## Task 1: Add display-surface preference and self-test

- [x] Add `DisplaySurfaceMode` with cases `classicAndDynamicIsland`, `classicOnly`, and `dynamicIslandOnly`.
- [x] Persist it in `AppSettings` with default `classicAndDynamicIsland`.
- [x] Add `DisplaySurfaceModeSelfTest` covering default, persistence, invalid fallback, and mode capability booleans.
- [x] Add `--self-test-display-surface` and `make test-display-surface`.

## Task 2: Wire launch/runtime behavior

- [x] On launch, create the original surface only when the mode includes it.
- [x] On launch, create Dynamic Island only when the mode includes it.
- [x] When settings change, create or remove each surface without restarting the app.
- [x] In Dynamic-Island-only mode, keep the island click action able to open the main window temporarily.
- [x] Do not allow removing both surfaces through the settings UI.

## Task 3: Settings UI and docs

- [x] Add a “显示入口 / Display surface” segmented control in Settings.
- [x] Update the run notes with the new behavior and verification.
- [x] Verify build and relevant self-tests before reporting.
