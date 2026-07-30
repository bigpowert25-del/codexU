# GodexU Phase 2D Human-Confirmed Outbox Plan

## 1. Package Contract

- Add failing executable self-tests for ready-only preparation, checksum
  validation, deterministic persistence, idempotency, revision replacement,
  cancellation, and strict loading.
- Add `AgentTaskDeliveryPackage`.

## 2. Local Outbox

- Add `AgentTaskDeliveryOutbox`.
- Store one atomic package file per envelope UUID.
- Reject drafts and invalid/tampered documents.
- Expose only local prepare, lookup, and cancel operations.

## 3. Native Integration

- Inject one outbox store through the native view hierarchy.
- Add an explicit package-generation step after local readiness.
- Cancel stale packages when the source handoff changes.
- Show prepared/unsent state in task detail and project hub.

## 4. Verification

- Run the new RED/GREEN self-test.
- Run all envelope, project, MCP, display-surface, workbench, and Dynamic Island
  regressions.
- Build the optimized app.
- Inspect task detail and project hub in the native app.
- Run `git diff --check` and scan for network, credential, or remote-write
  expansion.

## 5. Delivery Boundary

- Do not connect to NAS, OpenClaw, Hermes, Codex, or Windows.
- Do not create a sent/received claim.
- Do not add one-click repair.
- Do not install, push, or publish until the slice passes review and acceptance.
