# Side-Docked Dynamic Island Content-Fit Run

## Identity and boundary

- Run ID: `godexu-right-island-gap-20260729`
- Time: `2026-07-29 20:16 CST`
- Baseline SHA: `943dd7b925da0ca2a751de81755181650557e354`
- Project root: isolated local `codexU/dynamic-island-local-prototype` worktree
- Goal: remove the large empty area under side-docked compact and peek content.
- Excluded: GodexU v2 architecture, agent data sources, NAS, version bump, README/release assets, GitHub push/PR.
- Remote-write authorization: not granted for this diff.

## Root cause and implementation

The compact and peek vertical modes reused horizontal-width values as fixed heights (`226` and `438`). Each matching vertical SwiftUI stack also contained an unconstrained spacer, which expanded into the empty block shown by the user.

Implemented:

- Vertical compact size: `54 × 142`.
- Vertical peek size: `92 × 270`.
- Removed the flexible spacer before the status dot from vertical compact and peek content.
- Added regression assertions for compact/peek sizes and left/right symmetry.

## Allowed and changed paths

- `Sources/CodexUsageWidget/UI/DynamicIslandView.swift`
- `Sources/CodexUsageWidget/Domain/DynamicIslandPresentationSelfTest.swift`
- `docs/superpowers/specs/2026-07-29-side-docked-island-content-fit-design.md`
- `docs/superpowers/plans/2026-07-29-side-docked-island-content-fit.md`
- `docs/superpowers/runs/20260729-side-docked-island-content-fit.md`

No out-of-scope path was changed.

## TDD evidence

RED:

- Fresh optimized build and signing succeeded.
- `--self-test-dynamic-island` failed only with:
  - `side compact island should fit its content without surplus vertical space`
  - `side peek island should fit its content without surplus vertical space`

GREEN:

- Fresh optimized build, ad-hoc signing, and strict signature verification succeeded.
- `--self-test-dynamic-island` printed `dynamic island presentation self-test passed`.

## Verification

Automated checks: `13/13 passed`, `0 failed`.

1. Global shortcut self-test.
2. Status item self-test.
3. Particle animation self-test.
4. Display surface self-test.
5. Codex rate-limit normalization self-test.
6. Update self-test.
7. Statistics time-zone self-test.
8. Task navigation self-test.
9. Local system monitor self-test.
10. Agent selection self-test.
11. Codex token event normalization self-test.
12. Dynamic Island presentation/docking/layout self-test.
13. Codex, OpenClaw, Claude Code, and Hermes parser fixture checks.

Additional checks:

- `make build`: passed.
- `git diff --check`: passed.
- Built and installed executable hashes match:
  `dfb18f8835cead483b531faa41c6ffe94eab16524dece5e8d77fca1780a3d29f`.

## Real UI acceptance

Acceptance denominator: `5`.

- Covered: `4/5`.
- Unverified: `1/5`.
- Failed: `0/5`.

Passed:

1. Right compact mode: real installed window reported `54 × 142` at right edge and visual capture showed the status dot immediately below the token value.
2. Left compact mode: real installed window reported `54 × 142` at left edge and visual capture showed the same content fit.
3. Docking and stored side-center behavior: automated resolver/drag-gate checks passed; temporary left-side validation was restored to the original `right`, `626` setting.
4. Build, signature, install, launch, and installed-binary identity passed.

Unverified:

5. A human-visible hover/peek screenshot. The production path and regression test resolve peek to `92 × 270`, and the surplus spacer is removed, but the available accessibility control performs pointerless actions and cannot generate macOS `onHover`. This is recorded as unverified rather than inferred as visually passed.

## Status

- Overall: `acceptance_pending`
- Implementation: `complete`
- Local verification: `passed`
- E2E acceptance: `partial`
- Release: `not_authorized`
- GitHub: `not_pushed`
- Cross-device/NAS: `not_touched`

## Rollback

- Installed-app backup:
  `/Applications/codexU.app.backup-20260729-200912`
- Source rollback: revert the two Swift-file changes and rebuild.
- User placement after validation: restored to `right`, side center `626`.
