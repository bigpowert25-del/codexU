# GodexU 2.0 Native Workbench Parity Run

Date: 2026-07-30 (Asia/Shanghai)

## Outcome

The native macOS main window was rebuilt from the fixed legacy dashboard into
the approved wide GodexU 2.0 workbench. This run covers the presentation
architecture only. Human-confirmed remote handoff remains the next independent
slice; one-click repair is not part of this candidate.

## Root Cause

The previous native slice could not match the approved browser reference
because it kept a fixed 820-point vertical stack. Its stage selector changed
labels and hid at most one legacy section, while its skin selector only changed
accent and chrome values. The native sidebar, goal hero, relationship graph,
project continuation, 2x2 telemetry, ticker, composer, and command inspector
did not exist.

## Changed Scope

- Added a resizable 1320 x 820 native workbench window with a 1040 x 680
  minimum.
- Added a persistent left rail for Overview, Projects, Tasks, Agents, Usage,
  Skills, and Settings.
- Added a real-data overview with goal hero, observed Agent relationship graph,
  KPI rail, recent projects, local telemetry, node ticker, and local-only task
  package composer.
- Added a read-only Command inspector with Agent identity, device, source,
  health, and capabilities.
- Made Light, Sync, and Command use different section and layout contracts.
- Made all five skins own the full shell, canvas, sidebar, panels, text,
  separators, geometry, density, grid, and shadow contract.
- Kept Titanium Studio as the default skin and Sync as the default stage.

## Truth And Permission Boundaries

- Token metrics use the existing official activity reader and retain their
  source labels.
- Task and project counts use the existing combined task/project builders.
- CPU, memory, and thermal state use `LocalSystemMonitor`.
- Index health remains `--` with an unavailable label because no verified
  health signal is connected.
- Only observed Agent nodes are rendered.
- The composer creates a real local-only `.draft` task envelope in the existing
  `godexu-inbox`; it never delivers remotely.
- The Command inspector is explicitly read-only.
- No one-click repair, NAS mutation, Letta deployment, Windows implementation,
  new token-accounting logic, tag, or GitHub Release is included.

## Automated Verification

- Build: `make build` completed and produced the native executable.
- Built-in regression commands: 17/17 passed, 0 failed.
  - display surface
  - workbench preferences
  - task navigation
  - local system monitor
  - Agent selection, node, identity, envelope, and envelope-store checks
  - Codex token event normalization
  - Dynamic Island presentation
  - project index and reader
  - Codex/OpenClaw/Claude Code/Hermes parser fixtures
  - MCP contract, protocol, and helper checks
  - rate-limit, statistics-time-zone, and particle-animation scripts
- Source hygiene: `git diff --check` passed.
- Privacy/source scan found no prototype node, fake index count, repair action,
  or remote-delivery write in the new workbench view.

## Review Closure

- First independent review: 0 critical, 7 important, 1 minor.
- Closed all eight findings:
  - composer now persists a true local draft instead of discarding input
  - relationship nodes open the saved Agent identity detail
  - project cards open the exact selected project
  - relationship edges only represent displayed nodes
  - Command inspector reads the saved Agent identity
  - skins now cover every rail destination
  - the minimum-size clamp remains valid on smaller visible screens
  - Reduce Motion disables stage-transition animation
- Second independent review: 0 critical, 0 important, 1 minor; the eight
  original findings were confirmed closed.
- The remaining minor was closed by making the relationship header report
  verified availability or local probe/cache instead of always claiming a
  green live relationship.

## Native Visual And Interaction Acceptance

- Stages: 3/3 inspected in the development app.
  - Light: hero, relationship graph, three KPIs, compact composer.
  - Sync: full target composition with five KPIs, projects, telemetry, ticker,
    and composer.
  - Command: wider graph plus persistent read-only Agent inspector.
- Skins: 5/5 inspected at Sync.
  - Titanium Studio
  - Nebula Glass
  - Tactical OLED
  - Mineral Light
  - Orbit Command
- Rail destinations: 6/6 opened with live content.
  - Overview
  - Projects
  - Tasks
  - Agents
  - Usage
  - Skills
- Existing task detail opened with summary, extraction-progress treatment,
  recent reply, local handoff draft, and valid Codex deep-link action.
- Relationship-node selection opened the stored Agent identity sheet, and the
  second project card opened that exact project rather than a default project.
- The local composer exposed a real target selector and enabled package
  creation only after text entry; persistence is covered by the executable
  envelope-store self-test without adding acceptance-test data to the user's
  inbox.
- Settings opened and retained stage, skin, runtime, status-bar, display-surface,
  update-policy, and shortcut controls.
- Minimum-size pass retained all horizontal content without clipping; the
  lower modules remain reachable by vertical scrolling.
- Status-bar and Dynamic Island regression contracts passed their executable
  self-tests; their geometry was not changed by this slice.

## Visual Evidence

- `2026-07-30-godexu-v2-native-workbench-titanium-sync.png`
- `2026-07-30-godexu-v2-native-workbench-nebula-sync.png`
- `2026-07-30-godexu-v2-native-workbench-tactical-sync.png`
- `2026-07-30-godexu-v2-native-workbench-mineral-sync.png`
- `2026-07-30-godexu-v2-native-workbench-orbit-sync.png`
- `2026-07-30-godexu-v2-native-workbench-light.png`
- `2026-07-30-godexu-v2-native-workbench-command.png`
- `2026-07-30-godexu-v2-native-workbench-min-window.png`

## Rollback

Restore the timestamped `/Applications/codexU-backup-*.app` created before
installation, or revert the native parity implementation commit. Saved tasks,
projects, Agent identities, usage caches, task envelopes, status-bar settings,
and Dynamic Island settings are not migrated or rewritten by this change.
