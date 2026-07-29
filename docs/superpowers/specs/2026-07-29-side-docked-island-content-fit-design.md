# Side-Docked Dynamic Island Content-Fit Design

## Goal

Remove the large empty area below the content when the Dynamic Island is docked to the left or right edge, while keeping the current information, status dot, interaction model, and visual language.

## Confirmed product boundary

GodexU v2 keeps three complementary surfaces:

1. A ChatGPT-style project page that aggregates tasks from multiple agents.
2. An agent management page that lists node state, capability, usage/energy, and entry points, with status-bar hiding.
3. The current Dynamic Island and status surfaces.

Those v2 surfaces are product direction only. This change fixes the existing side-docked Dynamic Island and does not implement the v2 architecture.

## Root cause

The vertical compact and peek windows use `226` and `438` points of height, mirroring the horizontal widths rather than budgeting for the actual vertical content. Both vertical layouts also contain an unconstrained `Spacer`, so all surplus height becomes a visible empty block immediately above the status dot.

## Design

- Keep fixed window sizing to avoid AppKit/SwiftUI feedback loops and resize flicker.
- Use content-budgeted vertical sizes:
  - compact: `54 × 142`
  - peek: `92 × 270`
  - expanded: unchanged at `300 × 620`
- Remove the unconstrained spacer from vertical compact and peek content. The status dot remains the last item with the existing stack spacing and padding.
- Apply the same size rules to left and right docks.
- Preserve top-docked sizes, dock snapping, stored side position, hover transitions, click-to-expand, and dashboard opening.

## Error and safety handling

This change has no new data access, network access, persistence keys, or permissions. Existing screen-edge clamping continues to use the selected mode size.

## Verification

- Regression self-test fails against the oversized vertical compact/peek dimensions, then passes after the size change.
- Existing docking, interaction, quota-topology, display-surface, and status-item self-tests remain green.
- `make build` and `git diff --check` pass.
- Run the built app and visually inspect compact and hover/peek modes on both right and left edges.

## Rollback

Revert the two Swift-file changes. No stored user data migration is involved.
