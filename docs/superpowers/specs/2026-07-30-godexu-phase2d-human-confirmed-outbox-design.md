# GodexU Phase 2D Human-Confirmed Outbox Design

Date: 2026-07-30 (Asia/Shanghai)

## Task Fence

```yaml
task_id: godexu-v2-phase2d-human-confirmed-outbox
goal: prepare one auditable local delivery package from a locally-ready Agent handoff
project_root: /Users/mac/.config/superpowers/worktrees/codexU/dynamic-island-local-prototype
allowed_paths:
  - Sources/CodexUsageWidget/Domain
  - Sources/CodexUsageWidget/Services
  - Sources/CodexUsageWidget/UI
  - Sources/CodexUsageWidget/main.swift
  - Makefile
  - docs/superpowers
acceptance_denominator:
  - ready envelope can create one checksum-protected local package
  - draft envelope cannot create a package
  - package creation is idempotent per envelope revision
  - editing an envelope invalidates its older pending package
  - task detail and project hub state the package is local and unsent
  - no network, NAS, process, credential, MCP-write, or Agent mutation occurs
excluded:
  - remote delivery
  - acknowledgement
  - automatic retries
  - one-click repair
  - NAS and Windows changes
  - release or version bump
```

## Decision

Phase 2D starts with a transport-neutral local outbox, not a hidden remote
write. A user must first mark a handoff locally ready, then explicitly generate
its delivery package. This creates an auditable seam for a later OpenClaw or
Hermes connector without claiming that any Agent received work.

## Model

`AgentTaskDeliveryPackage` is an immutable snapshot containing:

- fixed schema identifier;
- package/envelope UUID;
- full validated ready envelope;
- preparation time;
- SHA-256 checksum over a deterministic canonical payload.

One package file exists per envelope UUID. Repeating preparation for the same
revision is idempotent. Preparing a newer revision atomically replaces the
older package. Editing a prepared envelope cancels its old package before the
UI can claim the new revision is pending delivery.

## Storage And Privacy

Packages live under the existing macOS Application Support area in a dedicated
`delivery-outbox/pending` directory. The store:

- accepts a custom directory for isolated tests;
- writes atomically;
- enforces user-only directory and package permissions (`0700` / `0600`);
- fails closed on malformed schemas, unknown keys, invalid envelopes, bad
  checksums, duplicate IDs, or excessive file counts;
- never opens a socket, invokes a command, reads credentials, or writes outside
  its configured directory.

The package deliberately contains the user-approved title and handoff note.
Therefore the read-only MCP index must continue excluding both fields, and no
package content is exposed through the existing MCP tools.

## Native Interaction

In task detail:

1. save the draft;
2. mark it locally ready;
3. explicitly choose `生成本机投递包`;
4. see `已进入本机待投递箱，尚未发送`;
5. optionally cancel the local package.

The project hub distinguishes `本机就绪` from `待人工发送`. Neither state may
use `sent`, `queued`, `received`, `accepted`, or `running`.

## Next Independent Slice

The first actual connector must separately define authentication, target
address discovery, human confirmation, idempotency key, receipt verification,
timeout, retry, cancellation, and rollback. OpenClaw and Hermes transport
adapters remain unimplemented in this slice.
