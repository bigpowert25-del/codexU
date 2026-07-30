# GodexU Phase 2E NAS Delivery Research Run

Date: 2026-07-30 (Asia/Shanghai)

## Goal

Determine the smallest stable path from the Phase 2D local outbox to real NAS
OpenClaw/Hermes task acceptance without modifying the NAS.

## Evidence Coverage

| Check | Result |
| --- | --- |
| Configured SSH route | passed |
| Strict host-key connection | passed |
| OpenClaw process observation | passed |
| Hermes process observation | passed |
| Existing shared handoff layout | inspected |
| Existing task inbox contract | absent |
| OpenClaw task CLI available to configured account | failed: permission denied |
| Hermes task CLI visible | absent |
| Hermes Kanban schema | inspected read-only |
| Remote write performed | no |
| Credential/auth/message content read | no |

## Conclusion

The NAS is reachable, but there is no currently verified, supported ingestion
surface shared by both Agents. OpenClaw CLI execution is blocked for the
configured account. Hermes has a capable internal Kanban schema, including an
idempotency key, but direct database writes would be an unsupported coupling.

Therefore the stable design is a dedicated versioned inbox plus target-owned
adapters and checksum-bound receipts. SSH upload alone is transport evidence,
not Agent acceptance.

## Status

- local package preparation: `passed`
- NAS transport design: `passed`
- OpenClaw ingestion adapter: `blocked` by missing supported interface
- Hermes ingestion adapter: `blocked` by missing supported interface/entrypoint
- real delivery and receipt: `pending`
- NAS mutation: `not performed`
- one-click repair: `excluded`

## Next Verification

Identify or add target-owned OpenClaw and Hermes ingestion entrypoints in an
isolated NAS test namespace. Only then implement the Mac uploader and receipt
reader.
