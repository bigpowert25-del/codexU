# GodexU Phase 2E NAS Delivery Connector Design

Date: 2026-07-30 (Asia/Shanghai)

## Read-Only Findings

Current NAS inspection confirmed:

- the configured SSH route is reachable with strict host-key checking;
- one OpenClaw process and one Hermes process are observable;
- the OpenClaw executable resolves inside the packaged application area, but
  the configured SSH account cannot execute that CLI;
- Hermes runs from its own home and has a Kanban database;
- the Hermes `tasks` table includes an `idempotency_key`, status, assignee,
  project, retry, heartbeat, and run fields;
- no supported Hermes task-creation CLI was visible to the configured account;
- the existing shared `handoff` tree contains memory/daily-review acknowledgments
  and absorption packages, not a task-delivery inbox;
- the existing `pending` directory contained no task-delivery contract.

No credentials, task bodies, messages, auth files, environment files, or user
content were read during this inspection.

## Rejected Shortcuts

### Direct Hermes SQLite insert

Rejected. Although the table shape is visible, directly inserting rows would
bypass Hermes validation, migrations, event creation, dispatcher locking, and
future schema changes. A row in the database would also not prove that Hermes
accepted or ran the task.

### Reuse the current memory handoff directory

Rejected. Mixing task commands with identity, memory, and daily-review exchange
would weaken routing, retention, privacy, and acknowledgement semantics.

### Treat SSH copy as delivery

Rejected. A copied file proves only transport to storage. It does not prove
that OpenClaw or Hermes parsed, accepted, deduplicated, or scheduled the task.

## Stable Connector Architecture

Use one versioned transport-neutral inbox owned by the NAS adapter:

```text
GodexU local outbox
  -> explicit user confirmation
  -> SSH/SFTP temporary upload
  -> checksum verification
  -> atomic rename into target inbox
  -> target-owned OpenClaw/Hermes adapter
  -> target validates and deduplicates envelope UUID + revision
  -> target uses its supported internal task API
  -> signed/bounded receipt
  -> GodexU verifies receipt before showing accepted
```

The storage transport and Agent ingestion are separate proof layers.

## Remote Layout Contract

The final NAS path must be configured, not hard-coded. Its logical structure:

```text
task-delivery-v1/
  inbox/
    openclaw/
    hermes/
  processing/
  receipts/
    accepted/
    rejected/
  quarantine/
```

Uploads use `<package-id>.json.tmp`, verify size and SHA-256, then atomically
rename to `<package-id>.json`. The adapter moves invalid or unsupported
packages to quarantine without executing them.

## Receipt Contract

A receipt must contain only:

- schema and protocol version;
- package UUID;
- envelope UUID and revision;
- target Agent/node ID;
- original package SHA-256;
- `accepted` or `rejected`;
- bounded reason code;
- target-generated task ID only when accepted;
- observed timestamp;
- adapter identity/version.

GodexU may show `已接收` only after a receipt matches all identity and checksum
fields. Upload success remains `已到达 NAS，等待 Agent 回执`.

## Adapter Ownership

- OpenClaw adapter: validates the package, then calls an OpenClaw-owned task
  routing interface. It must not invoke an inaccessible package binary through
  permission workarounds.
- Hermes adapter: validates the package, then calls a Hermes-owned Kanban/task
  API. It must not write `kanban.db` directly.
- Both adapters use the envelope UUID and revision as the idempotency boundary.
- Both adapters run with least privilege and cannot read the GodexU local
  outbox or unrelated shared memory.

## Permission Gates

The app requires a final confirmation sheet showing:

- target Agent and device;
- project and task title;
- whether the handoff note is included;
- remote route label;
- exact claim: `发送到 NAS 收件箱，尚不代表 Agent 已接收`.

One-click repair remains outside this connector.

## Implementation Gate

Remote implementation can start only after all of these are identified:

1. a supported OpenClaw task-ingestion interface;
2. a supported Hermes task-ingestion interface or a target-owned adapter entry;
3. the configured inbox root and least-privilege account;
4. receipt writer ownership and permissions;
5. a test target that cannot affect production tasks.

Until then, Phase 2D local packages are the last trustworthy state.
