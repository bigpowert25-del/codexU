# Run: dynamic-island-local-prototype

- run_id: `20260727-0953-dynamic-island-local-prototype`
- branch: `codex/dynamic-island-local-prototype`
- worktree: `/Users/mac/.config/superpowers/worktrees/codexU/dynamic-island-local-prototype`
- baseline_sha: `5c47e67`
- target: local-only macOS codexU Dynamic Island plus Windows WPF prototype

## Authorization

- `execution_approval`: user said “能copy的直接copy，听我的，我们只是在本机上做着玩” on 2026-07-27.
- `remote_write_approval`: not granted.
- `release_approval`: not granted.

## Scope

Allowed writes:

- `Sources/CodexUsageWidget/Domain/DynamicIslandPresentation.swift`
- `Sources/CodexUsageWidget/Domain/DynamicIslandPresentationSelfTest.swift`
- `Sources/CodexUsageWidget/UI/DynamicIslandView.swift`
- `Sources/CodexUsageWidget/UI/DynamicIslandWindowController.swift`
- `Sources/CodexUsageWidget/main.swift`
- `Makefile`
- `THIRD_PARTY_NOTICES.md`
- `WindowsIsland/**`
- `docs/superpowers/**`

Excluded:

- no NAS service mutation;
- no `/Applications` install;
- no GitHub push/release;
- no GPL/eIsland, CC BY-NC/MioIsland, or no-license Python code copied into the publishable tree.

## Implementation summary

- Added `DynamicIslandPresentationBuilder` and self-test for Codex quota headline, CPU/memory/thermal formatting, runtime rows, and attention task extraction.
- Added a macOS top-center `DynamicIslandWindowController` and `DynamicIslandView` connected to existing codexU stores.
- Copied MIT Windows WPF base into `WindowsIsland/`, renamed it to `CodexUIsland`, and added local JSON snapshot loading.
- Added source attribution for CodexIsland, Ping Island, and the copied Windows base.

## Verification

Baseline:

- `make build`: passed before implementation.

Candidate:

- `make test-dynamic-island`: passed.
- `make test-local-system`: passed.
- `make build`: passed.
- `git diff --check`: passed.
- `python3 -m json.tool WindowsIsland/sample-status.json`: passed.
- `plutil -lint Resources/Info.plist`: passed.
- `codesign --verify --deep --strict build/codexU.app`: passed.
- `build/codexU.app/Contents/MacOS/codexU --self-test-task-navigation`: passed.
- `build/codexU.app/Contents/MacOS/codexU --self-test-agent-selection`: passed.
- `build/codexU.app/Contents/MacOS/codexU --self-test-codex-token-events`: passed.

Windows limitation:

- `dotnet` is not installed on this Mac, so `WindowsIsland/CodexUIsland.csproj` was not built locally.

## UI acceptance

- Launched `build/codexU.app`.
- Captured `/tmp/codexu-dynamic-island-final-top.png`.
- Captured `/tmp/codexu-dynamic-island-after-click.png` after clicking the island at Retina-corrected screen coordinates.
- Visual result: macOS Dynamic Island appears top-center, displays Codex quota/today-token state after refresh, and expands to the larger panel with Codex usage, local CPU/memory/thermal status, and the task board.

## Stability fix: hover flicker

- User feedback: “不太稳定，总闪”.
- Root cause: compact/peek mode changed directly inside SwiftUI `onHover`, while the AppKit panel was also animating its frame. Moving the mouse across a resizing non-activating panel could generate rapid hover enter/exit events and start overlapping window animations.
- Fix:
  - added `DynamicIslandInteractionState` with hover enter debounce and hover exit grace;
  - canceled stale hover transitions when the user pins expanded mode;
  - skipped duplicate window frame updates;
  - stopped using AppKit frame animation for the outer panel, leaving only the SwiftUI content animation.
- Added self-test coverage for quick hover enter/exit staying compact, stable hover entering peek mode, stale hover exit not collapsing pinned expanded mode, and close returning to compact.
- Verification after fix:
  - `make test-dynamic-island`: passed;
  - `git diff --check`: passed;
  - relaunched `build/codexU.app`;
  - captured `/tmp/codexu-dynamic-island-flicker-fix-final.png`;
  - posted a native click event and captured `/tmp/codexu-dynamic-island-swift-click.png`, confirming the expanded island layer opens above the dashboard.

## Docking update: vertical capsule islands

- User feedback: “左右两侧也是胶囊岛，只是变竖条” and “可以左右键同时按，拖动位置，就近吸附到边上”.
- Implemented three dock positions: top, left, and right.
- Top dock remains a horizontal capsule.
- Left and right docks render as vertical capsules, not square bars.
- Reposition gesture:
  - normal left click remains reserved for opening/expanding the island;
  - left and right mouse buttons held together enable reposition dragging;
  - releasing the buttons snaps to the nearest top/left/right edge.
- Dock placement is persisted in `UserDefaults` under `dynamicIslandDock`; side Y position is persisted under `dynamicIslandSideCenterY`.
- Added self-test coverage for:
  - top compact size staying horizontal;
  - left compact size becoming vertical;
  - left/right/top nearest-edge snapping;
  - left/right edge frame attachment and side-position clamping;
  - left+right button gate enabling drag only when both buttons are down.
- UI smoke:
  - reset dock to top, relaunched `build/codexU.app`, then posted native left+right drag events;
  - left snap confirmed by `defaults read com.guomeiqing.codexu dynamicIslandDock` returning `left` and screenshot `/tmp/codexu-dynamic-island-combo-left-current-screen.png`;
  - right snap confirmed by `defaults read com.guomeiqing.codexu dynamicIslandDock` returning `right` and screenshot `/tmp/codexu-dynamic-island-combo-right-current-screen.png`;
  - final build relaunched with right dock active and screenshot `/tmp/codexu-dynamic-island-final-right-dock.png`;
  - precise side click at the right capsule center opened the vertical expanded capsule panel, captured in `/tmp/codexu-dynamic-island-right-expanded-confirmed.png`.

## Quota topology update: no fake 5h placeholder

- User feedback: “现在没有5h额度重置了，你要会自动检测”.
- Existing main status item already had quota topology folding for 7d-only responses.
- Dynamic Island now uses the same idea:
  - if Codex has both 5h and 7d windows, show both;
  - if 5h is absent and 7d is present, show only `7d`;
  - if no quota window is present but the quota read succeeded, show “当前无额度限制” / “No active quota limits”;
  - do not render `-- 5h` for an absent 5h window.
- Added self-test coverage for weekly-only Codex quota: headline is labeled as `7d`, quota line omits missing 5h, and no fake 5h placeholder appears.
- Verification:
  - `make test-dynamic-island`: passed;
  - `make test-rate-limits`: passed;
  - `make test-local-system`: passed;
  - `git diff --check`: passed;
  - `make build`: passed.

## Rollback

- Work is isolated in a git worktree. Main checkout remains untouched except for its pre-existing untracked `HANDOFF.md`.
- No app installation or external publication was performed.

## Status

overall_status: passed_local_acceptance
implementation_status: complete
local_verification: passed
e2e_acceptance: passed
release_status: not_authorized
rollback_status: ready

## Final upload gate

- User approval: “测试一遍，没问题就上传”.
- Target remote: `fork` (`https://github.com/bigpowert25-del/codexU.git`).
- Target branch: `codex/dynamic-island-local-prototype`.
- Final checks before upload:
  - `make build`: passed;
  - `--self-test-statistics-time-zone`: passed;
  - `--self-test-status-item`: passed;
  - `--self-test-rate-limits`: passed;
  - `--self-test-particle-animation`: passed;
  - `--self-test-updates`: passed;
  - `--self-test-task-navigation`: passed;
  - `--self-test-local-system`: passed;
  - `--self-test-agent-selection`: passed;
  - `--self-test-codex-token-events`: passed;
  - `--self-test-dynamic-island`: passed;
  - `CODEXU_SKIP_BUILD=1 ./scripts/test-parsers.sh`: passed;
  - `python3 -m json.tool WindowsIsland/sample-status.json`: passed;
  - `plutil -lint Resources/Info.plist`: passed;
  - `git diff --check`: passed.
- Windows WPF limitation: `dotnet` is not installed on this Mac, so `WindowsIsland/CodexUIsland.csproj` was not compiled locally before upload.

## Version marking update

- User confirmed this feature set should be versioned as `1.2.0`.
- Updated app version metadata from `1.1.4 (23)` to `1.2.0 (24)`.
- Added v1.2.0 release notes and a cropped public README screenshot showing the right-side vertical Dynamic Island, avoiding the full desktop capture.

## Display surface mode update

- User requirement: “灵动岛和原有的版本可以同时选，也可以二选一”.
- Added a persisted display-surface setting with three choices:
  - original app + Dynamic Island;
  - original app only;
  - Dynamic Island only.
- Default remains original app + Dynamic Island, preserving the previous v1.2.0 prototype behavior.
- Dynamic-Island-only mode does not create the menu bar item or auto-show the main dashboard on launch; expanding the island can still open the dashboard temporarily.
- Added `--self-test-display-surface` and `make test-display-surface` coverage for default, persistence, invalid fallback, and per-mode surface capability flags.
