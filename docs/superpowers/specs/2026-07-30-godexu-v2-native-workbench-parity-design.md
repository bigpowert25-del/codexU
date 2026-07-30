# GodexU 2.0 Native Workbench Parity Rebuild

Date: 2026-07-30 (Asia/Shanghai)

## Decision

The previous native workbench slice is rejected as the final GodexU 2.0 main
window. It retained the legacy 820-point vertical dashboard and only added a
header and overview strip. That architecture cannot reproduce the approved
wide workbench reference or create meaningful differences between stages and
skins.

The main macOS window will be rebuilt as a native, wide, responsive workbench.
The approved `godexu-v2-orbit-command-v3.html` composition and the user's
2026-07-30 reference screenshot are the visual baseline. Existing readers,
stores, task details, project grouping, Agent identity sheets, menu-bar
surface, and Dynamic Island remain the data and interaction foundation.

This slice repairs the presentation architecture first. Human-confirmed remote
handoff is the next independent slice. One-click repair is explicitly excluded
from the first remote-handoff version.

## Root Cause

The observed mismatch is structural:

1. `UsageWidgetView` is fixed to 820 points and its window cannot resize
   horizontally.
2. All three stages render the same legacy vertical section stack. `light`
   suppresses one section, while `sync` and `command` are effectively
   identical.
3. Skin tokens only change accent colors and small chrome opacity values.
   Window canvas, sidebar, panels, text hierarchy, radii, density, and shadows
   continue to use the same global palette.
4. The approved sidebar, hero, relationship graph, project continuation panel,
   2×2 system telemetry, status ticker, and command composer were never
   implemented in the native view.

## Window And Navigation

- Default main-window content size: 1320 × 820 points, clamped to the current
  display's visible frame.
- Minimum content size: 1040 × 680 points.
- The main window is horizontally and vertically resizable.
- The classic 820-point dashboard is no longer the root composition. Its
  detailed usage, tasks, projects, skills, Agent identity, and environment
  diagnostics are retained as navigable workbench destinations.
- Dynamic Island, status-bar presentation, and display-surface choices keep
  their existing geometry and behavior.

The workbench uses a persistent left rail:

- Overview
- Projects
- Tasks
- Agents
- Usage
- Skills
- Settings

Navigation changes the main content; it does not merely scroll a long stack.

## Stage Contract

Stage controls layout and operational depth, not labels.

### Light

- Focused first-use/glance composition.
- Large goal-and-Agent hero plus compact real KPI rail.
- Relationship graph remains visible so node state is understandable.
- Project grid, telemetry grid, ticker, and advanced route inspector are
  removed from the first viewport.
- Compact task-package composer remains available.

### Sync (Default)

- Matches the approved target screenshot.
- Two-column hero: goal/entry on the left, live Agent relationship graph on the
  right.
- Five-part KPI rail using current real data.
- Lower split: recently active project continuation on the left and 2×2 local
  system/index status on the right.
- Status ticker and local task-package composer remain visible.

### Command

- High-density operations composition.
- Hero copy contracts and the relationship graph receives more width.
- A persistent right inspector shows selected Agent identity, device,
  capabilities, routing evidence, and read-only diagnostics.
- Project/status content becomes a single operational column to preserve
  readability beside the inspector.
- No repair mutation is exposed in this slice.

All three stages have unique, self-tested layout identities and section sets.

## Skin Contract

Skin owns the full visual surface contract:

- canvas and deep canvas;
- shell and sidebar;
- primary and elevated panel fills;
- primary, secondary, and dim text;
- accent, secondary accent, and attention accent;
- subtle and strong separators;
- control and panel radii;
- density;
- shell shadow and grid visibility.

Built-in skins:

1. Titanium Studio: pale silver/graphite shell, blue-violet navigation,
   restrained green health accents; the default.
2. Nebula Glass: deep navy/indigo glass with violet and cyan accents.
3. Tactical OLED: near-black, compact square geometry, acid-green/cyan
   telemetry.
4. Mineral Light: smoke-metal shell with black panels and mineral lime accent.
5. Orbit Command: near-black warm hardware surface with orange routes and
   green health.

Changing a skin cannot change data, routing, permissions, polling, identity, or
memory access. Semantic danger/warning/success meanings remain stable.

## Real Data Mapping

- Codex latest active-day and seven-day token values come from the existing
  official activity trend only.
- Task counts come from the existing combined task board.
- Projects come from `AgentProjectWorkspaceBuilder`, sorted by real recent
  activity; inactive projects naturally sink.
- Agent nodes come from current bounded local/SSH probes and cache. Missing
  nodes are not invented.
- CPU, memory, and thermal state come from `LocalSystemMonitor`.
- Memory/index health is labeled unavailable unless a real local index health
  signal exists; the UI never fabricates `4/4`.
- The relationship graph contains only observed nodes. Optional systems such as
  Letta are not displayed as connected until configured and observed.
- Missing values render `--` with a source or availability label, never fake
  zeroes or sample numbers.

## Interaction

- Clicking a relationship node opens the existing Agent identity detail sheet.
- Clicking a project switches to the existing project workspace.
- Clicking a task keeps the existing task-detail behavior.
- The bottom composer creates or opens a local, reviewable task package. It
  does not remotely deliver in this slice.
- Settings remains a native window action.
- Reduced motion removes decorative route-flow/ticker animation without hiding
  any information.

## UI Quality Gates

The native rebuild must pass:

1. Structural parity: top bar, rail, hero, relationship graph, KPI rail,
   project continuation, telemetry grid, ticker, and composer are visible in
   Sync.
2. Stage differentiation: screenshots and accessibility trees demonstrate
   materially different Light, Sync, and Command compositions.
3. Skin differentiation: screenshots demonstrate materially different canvas,
   shell, panel, text, accent, radius, and density treatment.
4. Truthfulness: no prototype sample values, fake nodes, or fake index counts.
5. Responsiveness: no clipping at 1040 × 680, default size, and the current
   display's practical maximum.
6. Accessibility: controls have labels/help, focus remains visible, and color
   is not the only status signal.
7. Regression: existing task detail, project grouping, Agent identity, usage,
   status bar, and Dynamic Island tests continue to pass.

## Excluded

- One-click repair or repair mutation;
- automatic remote delivery;
- NAS service installation or configuration;
- Letta deployment;
- Windows implementation;
- new token-accounting logic;
- background polling expansion;
- release tag or public GitHub Release.

## Rollback

The parity rebuild is isolated to the workbench preference/layout model, the
new native shell, and main-window geometry. Reverting the implementation commit
restores the previous fixed 820-point dashboard without changing saved task,
node, identity, handoff, usage, or Dynamic Island data.
