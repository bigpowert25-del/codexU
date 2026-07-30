# GodexU Phase 2D Human-Confirmed Outbox Run

Date: 2026-07-30 (Asia/Shanghai)

## Outcome

GodexU can now turn a locally-ready Agent handoff into one auditable local
delivery package. The package is checksum-protected and appears as `待人工发送`.
Nothing is sent to OpenClaw, Hermes, Codex, NAS, or Windows.

## Implemented

- Added the strict `godexu-task-delivery-package-v1` contract.
- Added a SHA-256 checksum over a deterministic package payload.
- Added a local atomic outbox with one package per envelope UUID.
- Enforced user-only permissions on the outbox directory and package files.
- Repeated preparation of the same envelope revision is idempotent.
- A newer envelope revision replaces the older pending package.
- Draft envelopes are rejected.
- Malformed, tampered, unknown-field, mismatched-filename, or invalid-envelope
  package files fail closed.
- Task detail now requires a separate explicit `生成本机投递包` action after
  `标记本机就绪`.
- Editing a prepared handoff invalidates its older local package.
- Task detail and the project hub use `待人工发送` and repeat `尚未发送`.
- Users can cancel a local package without deleting the underlying handoff.

## Verification

- RED proof: the new self-test failed to compile before the package and outbox
  types existed.
- Optimized arm64 build completed and strict deep code-sign verification passed.
- 17 executable regression flags passed after the build, including the new
  delivery-package test.
- Project index command tests passed.
- Codex, OpenClaw, Claude Code, and Hermes parser fixtures passed.
- MCP contract, protocol probe, and helper tests passed.
- `git diff --check` passed.
- The new package/outbox files contain no URL session, Network connection,
  process launch, credential field, password field, API key field, or sent-state
  implementation.
- Native app launch and the GodexU 2.0 overview were re-inspected after the
  integration; the main workbench remained intact.

One statistics-time-zone performance assertion failed once while the optimizer
had just saturated the CPU. It then passed twice consecutively in isolation.
This is recorded as an environment-sensitive performance fluctuation, not
silently counted as a first-run pass.

## Coverage Status

| Dimension | Status |
| --- | --- |
| Package model and checksum | passed |
| Strict local persistence | passed |
| Draft rejection and idempotency | passed |
| Existing envelope/project/MCP regressions | passed |
| Main native window smoke | passed |
| New task-detail control with a live user task | partial |
| Remote OpenClaw/Hermes delivery | excluded |
| Receipt/acknowledgement | excluded |
| One-click repair | excluded |

The task-detail control compiled and its state transitions are covered by the
package/store tests. A live task was not manufactured in the user's data just
to obtain a screenshot, so that visual interaction remains explicitly partial.

## Rollback

Revert the Phase 2D commit. Existing task envelopes remain readable because the
outbox uses a separate directory and does not change the envelope schema.
Deleting a pending package affects only the local outbox snapshot; it does not
delete the handoff draft or contact a remote Agent.
