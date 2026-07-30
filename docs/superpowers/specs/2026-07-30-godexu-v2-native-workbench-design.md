# GodexU 2.0 Native Workbench Design

Date: 2026-07-30 (Asia/Shanghai)

## Decision

GodexU 2.0 keeps the existing native macOS dashboard, task board, project
workspace, Agent node cards, menu-bar surface, and Dynamic Island. It adds a
workbench presentation layer instead of replacing those proven surfaces.

The default skin is **Titanium Studio**. The previously approved dark
high-density Orbit Command composition remains an optional skin, not the
default. The native implementation preserves the information density of the
approved third visual prototype while following the existing macOS design
system.

## User-Facing Model

The main window has two independent preferences:

1. **Workbench stage**
   - `light`: fast glance; keeps the command summary and the selected task
     surface while suppressing secondary operational sections.
   - `sync`: default daily workspace; shows usage, local system state, Agent
     nodes, and the current task/project surface.
   - `command`: maximum operational context; keeps all `sync` information and
     expands the core summary for multi-Agent coordination.
2. **Skin**
   - `titaniumStudio` (default)
   - `nebulaGlass`
   - `tacticalOLED`
   - `mineralLight`
   - `orbitCommand`

Stage controls information density. Skin controls semantic visual tokens only.
Changing a skin must never change data, permissions, task routing, or polling.

## Native Visual Direction

Titanium Studio uses system typography, SF Symbols, one window-level glass
surface, restrained silver/chrome fills, and the existing blue-purple GodexU
brand colors. It must remain readable in both macOS light and dark appearance.

- Green is reserved for healthy/success state.
- Orange is reserved for warning, active output, or attention.
- Blue-purple is the default navigation and identity accent.
- Internal panels use static translucent fills; they do not stack additional
  material layers.
- No decorative glow field, large marketing gradient, emoji icon, or continuous
  animation is introduced.
- Reduced-transparency and increased-contrast system preferences remain valid.

Optional skins are expressed through one centralized token set. They may change
accent, chrome tint, and selected-control treatment, but not semantic status
colors.

## Information Architecture

The top of the main window gains a compact native workbench header and core
overview strip:

- Codex official latest active-day token activity, when available;
- Codex official seven-day token activity, when available;
- active task count;
- pending task count;
- available Agent node count over observed node count;
- explicit source labels and `--` for missing values.

Below it, the existing sections are composed by stage:

| Section | Light | Sync | Command |
| --- | --- | --- | --- |
| Core overview | compact | full | full |
| Usage overview | yes | yes | yes |
| Local CPU / memory / thermal | compact | yes | yes |
| Agent node status | no | yes | yes |
| Tasks / usage / projects / skills | yes | yes | yes |

The existing project workspace remains the ChatGPT-like aggregation surface.
The Agent node section remains the management surface. Dynamic Island remains a
separate display surface and is not redesigned in this slice.

## Data And Truthfulness

- Codex official activity uses only the existing official cloud trend fields.
  The latest-day metric follows the existing official card and skips structural
  zero buckets, so a not-yet-populated current day cannot replace the latest
  real activity day.
- Local context tokens stay explicitly labeled as local/non-official.
- Task counts come from the existing combined task board.
- Node availability comes from the existing bounded node probes/cache.
- Missing official or node data renders `--` or a stated unavailable condition,
  never a fabricated zero.
- Skin and stage settings are local `UserDefaults` preferences only.

## Architecture

- `GodexUWorkbenchPreferences` owns the pure, persistable skin/stage contract and
  centralized visual token values.
- `AppSettings` owns observable selection and persistence.
- `GodexUWorkbenchViews` renders the header, stage picker, skin picker, and
  metric strip from existing store snapshots.
- `UsageWidgetView` performs composition only. It does not add readers, network
  calls, timers, or task mutation.
- Existing `WidgetPalette` remains the semantic status authority. New theme
  tokens may tint workbench chrome but cannot redefine success/warning/danger.

## Failure And Empty States

- Unknown stored skin or stage values fall back to Titanium Studio and Sync.
- Missing official token values show `--` with an official-source label.
- Missing task board shows `--` counts rather than zero.
- No node observations show `--` rather than `0/0`.
- Existing environment diagnostics remain visible.

## Performance And Accessibility

- No new dependency or background worker.
- Skin changes are static value changes; no continuous animation.
- Stage changes only alter view composition.
- Controls have text labels, help text, and accessibility labels.
- Compact text uses the existing minimum size and scaling conventions.

## Excluded From This Slice

- NAS writes or remote Agent control;
- task delivery, one-click repair, or permission expansion;
- Windows implementation;
- Codex/OpenClaw/Hermes reader changes;
- token-accounting changes;
- Dynamic Island behavior changes;
- app rename, version bump, installation, GitHub push, or public release.

## Acceptance

1. Fresh settings default to Titanium Studio and Sync.
2. Valid stored selections round-trip; invalid values safely fall back.
3. The main window exposes stage and skin controls without changing existing
   task, project, Agent, usage, or Dynamic Island behavior.
4. Core metrics preserve source semantics and missing-data behavior.
5. Build, focused self-tests, existing regression tests, and a real macOS UI
   review pass.
6. The final diff contains no `.superpowers/` prototype artifact.

## Rollback

Remove the workbench preference domain/self-test and native workbench view,
remove the two `AppSettings` properties and settings rows, and restore
`UsageWidgetView` to the previous fixed section composition. No data migration,
remote state, or installed app rollback is required.
