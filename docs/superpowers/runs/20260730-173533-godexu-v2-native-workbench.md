# GodexU 2.0 Native Workbench Run

Date: 2026-07-30 (Asia/Shanghai)

## Scope

- Task ID: `godexu-v2-native-workbench`
- Branch: `codex/dynamic-island-local-prototype`
- Baseline commit: `d412b3b04ec55fd0b4d9a5ec4bf8358d67ebbc4e`
- Goal: implement the approved information-dense native workbench with
  Titanium Studio as the default skin.
- Execution approval: user said “好，默认皮肤钛金工作室，继续往下干吧”.
- Installation and GitHub synchronization approval: user said “继续做，我同意，
  我给你授权，你赶紧去改” after the local acceptance boundary and the
  separate installation/GitHub authorization requirement were reported.
- Allowed production paths: the preference domain/self-test, native workbench
  UI, local-system presentation, `main.swift`, `Makefile`, and this task's
  spec/plan/run documents.
- Excluded: `.superpowers/` prototype artifacts, NAS, Windows, task delivery,
  token accounting, installed app replacement, version bump, GitHub, and
  release.

## Baseline

Status: `passed`

- Optimized arm64 app/helper build: `1/1`.
- App self-test routes: `12/12`.
- Parser fixture suite: `1/1`.
- Project-index command suite: `1/1`.
- MCP helper/real protocol suite: `1/1`.
- Whitespace gate: `1/1`.
- Baseline failures: `0`.

## TDD Evidence

Status: `passed`

1. Preference contract RED: the optimized app build failed because
   `GodexUSkin` and `GodexUWorkbenchStage` did not exist. GREEN: the isolated
   `UserDefaults` self-test passed after implementing stable identifiers,
   Titanium Studio/Sync defaults, persistence, and fallback.
2. Overview model RED: the focused test failed because
   `GodexUWorkbenchOverview` did not exist. GREEN: task/node aggregation and
   `--` missing-state behavior passed after adding the pure model.
3. Official latest-day RED: a fixture with a nonzero prior day and structural
   zero current day failed against the first implementation. GREEN: the model
   now follows the existing official card's latest-nonzero rule and reports
   `501.9M` against the live official `5.0亿` card.
4. UI-gate RED: the focused build failed because
   `usesCompactSystemStatus` and `showsMetricSourceLabels` did not exist.
   GREEN: Light now compresses local-system presentation, and all three stages
   render source labels directly.

## Implementation

Status: `passed`

- Added five persisted skins with Titanium Studio as the default and kept
  macOS light/dark appearance independent.
- Added Light/Sync/Command stage controls with Sync as the default.
- Added a source-labeled core strip for official Codex activity, aggregate
  task counts, and locally observed Agent-node availability.
- Reused the existing official usage, local context, system monitor, Agent,
  task, project, Skill, and Dynamic Island data paths.
- Light uses a compact CPU/memory/thermal strip and hides Agent-node cards.
  Sync and Command retain the full local-system and Agent views.
- Missing values remain `--`; no new reader, polling loop, permission, network
  call, task mutation, or remote action was added.

## Verification

Status: `passed`

- Optimized arm64 app/helper build: `1/1`.
- App executable self-test routes: `19/19`.
- Parser fixture suites: `1/1`.
- Project-index command suites: `1/1`.
- MCP helper contract/protocol suites: `1/1`.
- `git diff --check`: `1/1`.
- Mach-O architecture: `arm64`.
- Deep code-sign verification: `1/1`.
- Failures: `0`.
- Main executable SHA-256:
  `ef505966bea04bea1fb96d1dc6674404d2d450396ed99acf5d8017fa997c2306`.
- MCP helper SHA-256:
  `e9363e70f3ca83b587d6293dae1d72f312379e56f8d4c011205240f7491278aa`.

## Real UI Acceptance

Status: `passed`

- Launched the rebuilt development app without replacing `/Applications`.
- Verified the default visible state is Titanium Studio + Sync.
- Verified the five-skin menu and three-stage controls.
- Verified Sync shows direct source labels:
  `官方活动`, `聚合任务`, and `本机探测 / 缓存`.
- Verified Light reduces the core strip to three metrics, removes Agent-node
  cards, and compresses local CPU/memory/thermal to one line.
- Verified returning to Sync restores full system details and Agent-node cards.
- Verified the live loaded overview aligns with existing surfaces:
  latest active day `501.9M`, seven-day `3.2B`, active `5`, pending `9`,
  available nodes `1/3`.
- Verified loading/missing states show `--` before data arrives.
- Evidence:
  `docs/superpowers/runs/godexu-v2-native-workbench-titanium.png`
  (`820 × 720`).
- Native accessibility tree confirmed stage selection, skin value, visible
  source labels, task/project controls, and system metrics.
- Independent read-only code review: initial `Critical 0 / Important 2 /
  Minor 0`; both Important findings were fixed and re-reviewed as
  `Critical 0 / Important 0 / Minor 0`.
- The re-review independently rebuilt the app and passed eight focused
  no-interface self-tests plus `git diff --check`.

## Separate Status Dimensions

| Dimension | Status | Evidence or boundary |
| --- | --- | --- |
| Implementation | `passed` | Native workbench, preferences, and compact Light layout built |
| Local regression | `passed` | 19/19 routes plus parser, project, MCP, diff, architecture, and signing gates |
| Real UI | `passed` | Latest development build accepted in Titanium/Sync and Light |
| Installed app | `passed` | Backup, hash-matched install, and real UI/data smoke passed |
| NAS / remote Agents | `not_applicable` | No remote access or writes |
| Windows | `not_applicable` | No Windows work in this slice |
| GitHub / release | `platform_verified_published` | Draft PR #1 updated and remote SHA matched |

## Authorized Finish Run

- Target: local `/Applications/codexU.app` plus the existing public fork draft
  PR `bigpowert25-del/codexU#1`.
- GitHub scope: update only
  `fork/codex/dynamic-island-local-prototype`; no upstream push, default-branch
  push, tag, GitHub Release, DMG upload, or visibility change.
- Candidate allowlist: 11 paths; observed set difference: empty.
- Privacy scan: no user-home path, LAN address, GitHub token, API-key
  assignment, or private-key material in the candidate text files.
- Fresh release-candidate verification repeated the optimized build, 19/19
  executable self-tests, parser fixtures, project-index commands, MCP
  contract/protocol checks, strict signing, architecture, hash, and diff gates.
- Implementation commit:
  `66a9394762d83921745a6eb1d2d8ced2775342a6`.
- Existing app backup:
  `/Applications/codexU-backup-v1.2.0-20260730-212710.app`.
- Installed app and candidate executable SHA-256:
  `ef505966bea04bea1fb96d1dc6674404d2d450396ed99acf5d8017fa997c2306`.
- Installed-app read-back passed with Titanium Studio, Sync, visible metric
  source labels, loaded official activity, task counts, node status, CPU,
  memory, and thermal state.
- Fork branch remote SHA matched the implementation commit before the
  publication-record update.
- GitHub read-back confirmed draft PR #1 is open with the title
  `GodexU 2.0 native multi-Agent workbench`:
  `https://github.com/bigpowert25-del/codexU/pull/1`.

The seven `.superpowers/` prototype artifacts remain untracked design evidence
and are not part of the production file map. The installed app still has its
2026-07-29 22:27:42 +0800 modification time and a different executable hash,
confirming it was not replaced.

## Rollback

Source-only rollback: remove the three new workbench files, revert the
`main.swift`, `RuntimeViews.swift`, and `Makefile` integrations, and discard
this task's documentation/screenshot. There is no data migration, installed-app
replacement, NAS change, Windows change, or remote state to restore.
