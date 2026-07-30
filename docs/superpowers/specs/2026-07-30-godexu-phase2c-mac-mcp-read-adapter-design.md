# GodexU v2 Phase 2C-Mac MCP Read Adapter Design

## 1. Project Promise

- Source request: continue GodexU v2, but research and stabilize the Mac side
  before Windows, NAS transport, task delivery, or repair.
- User-visible outcome: local Codex clients can read GodexU's project and
  handoff index through MCP without opening the GodexU window, starting a
  network service, scanning full conversations, or depending on Python/Node.
- Why now: Phase 2A established Agent identities and Phase 2B established the
  local project/handoff control plane. A read-only Mac adapter is the smallest
  safe proof that another Agent can consume that control plane.
- Project type: local-first Agent integration foundation.

## 2. Boundary Card

```yaml
status: bounded
task_id: "godexu-v2-phase2c-mac-mcp-read-adapter"
task_goal: "Expose a fast, privacy-bounded local project and handoff index to Mac Codex clients through a read-only stdio MCP helper."
in_scope:
  - a metadata-only GodexU project-index schema and serializer
  - a no-window `--dump-project-index` main-app command
  - an independently built Swift MCP helper using the official SDK
  - read-only project and handoff tools/resources
  - in-memory freshness cache and explicit stale/error semantics
  - Apple Silicon and Intel builds, signing, protocol, privacy, and latency checks
  - local connection documentation and a non-persistent Codex acceptance path
out_of_scope:
  - MCP mutation, task dispatch, acknowledgement, retry, repair, cancellation, or execution
  - NAS OpenClaw/Hermes reads or writes, SSH, remote polling, HTTP, OAuth, or listening ports
  - full prompt, reply, transcript, handoff-note, raw thread-ID, path, log, auth, or credential exposure
  - automatic or silent edits to `~/.codex/config.toml`
  - a Connect button, plugin submission, ChatGPT web integration, or public MCP endpoint
  - Windows, app rename, version bump, installed-app replacement, GitHub push, tag, or release
allowed_reads:
  - current isolated codexU worktree
  - local Codex thread metadata database
  - local OpenClaw canonical task and session-index metadata
  - Phase 2B local task-envelope store
  - official MCP and Codex documentation
allowed_writes:
  - allowlisted source, tests, Makefile, notices, and docs inside this worktree
  - generated build output and isolated test fixtures
external_actions: "none; persistent Codex registration, installation, NAS access, push, and release require later authorization"
success_evidence:
  - official MCP initialize, tools, resources, valid calls, invalid calls, and shutdown pass
  - the helper starts quickly and returns a fresh or explicitly stale bounded snapshot
  - Apple Silicon and Intel helper binaries build and pass architecture/signature checks
  - no prohibited content appears in MCP output, stdout diagnostics, public dumps, or logs
  - existing Phase 2A/2B behavior, app build, task details, status bar, and Dynamic Island remain green
stop_conditions:
  - implementation requires a listening port, credential, remote write, or persistent host-config mutation
  - the helper must read transcript bodies or invoke the full usage snapshot
  - a read tool mutates local or external state
  - the main app build/runtime regresses or the helper cannot be independently removed
next_action: "After spec approval, write the TDD implementation plan for this Mac-only read adapter."
```

The user's “继续” approves writing and reviewing this Mac design. It does not
authorize implementation, model/API use, persistent MCP registration,
installation, NAS access, GitHub push, or release.

## 3. Requirement Status

- Gate status: clear.
- Confidence basis:
  - the Phase 2B project/handoff models are committed and accepted locally;
  - the existing app already supports no-window command branches;
  - the official Swift SDK was compiled and exercised in an isolated Mac spike;
  - current Codex documentation confirms local stdio MCP support.
- Conservative assumptions:
  - the first adapter proves read interoperability, not cross-device delivery;
  - Mac-local data stays authoritative when NAS nodes are absent;
  - unavailable local runtimes are represented as unavailable, not as empty or
    remotely queried.
- Material unknown parked: persistent Codex registration UX and the final
  `GodexU.app` bundle name. Both can invalidate a stored executable path and
  therefore belong to a later connection phase.

## 4. Operator And First-Use Loop

- Primary operator: a Mac user who already uses Codex and GodexU.
- Trigger: the user asks Codex to review local projects or prepared handoffs.
- Existing workaround: open GodexU, inspect the project page, and manually copy
  status between Agent conversations.
- First 30 seconds after explicit connection: ask Codex to list GodexU
  projects; Codex calls `godexu_project_list` and receives project names,
  source labels, task-state counts, handoff counts, freshness, and stable IDs.
- Return reason: Codex can obtain the same bounded index on demand without
  opening the dashboard or asking the user to restate task status.

```text
user request -> Codex MCP call -> helper requests lightweight index
-> GodexU reads local metadata -> helper validates/caches result
-> Codex receives structured status -> user chooses the next authorized action
```

## 5. Alternatives And Decision

### A. Independent official-SDK helper plus lightweight main-app index — selected

Bundle a small `GodexUMCPServer` executable separately from the UI binary. The
helper owns protocol handling; the existing GodexU executable owns data
normalization and exposes a dedicated `--dump-project-index` command. The
helper derives the main executable path from its bundle location and invokes
only that bounded command.

Benefits:

- official MCP protocol implementation instead of a hand-written server;
- no SDK code, HTTP stack, or dependency initialization in the UI process;
- current direct-`swiftc` app build and startup path remain intact;
- one owner for project-index semantics;
- helper failure cannot prevent the menu-bar app from launching.

Cost:

- one extra signed executable per architecture;
- a SwiftPM dependency build for the helper;
- one local subprocess for snapshot refresh.

### B. Link the MCP SDK directly into the GodexU UI executable

This shares models without a subprocess, but changes the main build from the
current lightweight `swiftc` path, adds SDK dependencies to every app launch
and release build, and enlarges the UI-process blast radius. It is not selected.

### C. Hand-write a minimal JSON-RPC/MCP loop in the existing app

This avoids SwiftPM and initially produces a smaller binary, but makes GodexU
responsible for protocol negotiation, cancellation, batch behavior, schema
evolution, and future compatibility. It duplicates an official implementation
and is not selected.

Decision: use A. Keep the helper replaceable so a future SDK or transport
change does not alter the project-index contract.

## 6. Reuse Scan And Research Evidence

```text
reuse_decision: adapt
reason: reuse the official Swift MCP SDK for protocol/stdio behavior and reuse GodexU's existing task/project/handoff models for the local index; do not import a web service or create a second project database.
checked_at: 2026-07-30
sources:
  - local Sources/CodexUsageWidget/main.swift
  - local Sources/CodexUsageWidget/Domain/AgentProjectWorkspace.swift
  - local Sources/CodexUsageWidget/Services/AgentTaskEnvelopeStore.swift
  - https://github.com/modelcontextprotocol/swift-sdk
  - https://github.com/modelcontextprotocol/swift-sdk/releases/tag/0.12.1
  - https://modelcontextprotocol.io/specification/2025-11-25/basic/transports
  - https://learn.chatgpt.com/docs/extend/mcp
```

Verified Mac research:

- local environment: Apple Silicon, Swift 6.3.3, app target macOS 14;
- official SDK `0.12.1`: Swift 6.1 package, macOS 13 minimum, mixed
  Apache-2.0/MIT transition license;
- arm64 consumer build: passed;
- x86_64 cross-build from the same Mac: passed;
- real stdio initialize/tool/resource handshake: 5/5 passed;
- initialization: 19.32 ms in the isolated spike;
- four representative list/call/read operations: 10.65–12.18 ms each;
- resident memory: 8.64 MB;
- release helper size: 8.2 MB arm64 and 8.3 MB x86_64;
- ad-hoc signing and strict signature verification: passed;
- clean helper build: 275.48 seconds; incremental build: 0.82 seconds;
- current clean app build: 171.02 seconds;
- current complete `--dump-json`: did not return within 30 seconds and is
  rejected as an MCP data source;
- direct metadata timing on this Mac: Codex 212 rows in 2.83 ms and OpenClaw
  55 session-index rows in 30.66 ms;
- no local `~/.hermes/state.db` was present, so no Hermes-local acceptance was
  claimed.

The official SDK repository's own selected tests reached compiled MCP sources
but could not compile their `Testing`-based test target under the installed
Command Line Tools. This is an environment gap, not a passing upstream-suite
claim. GodexU therefore needs its own executable protocol probe and a full-Xcode
or CI check before release.

Dependency policy:

- pin the SDK to exact `0.12.1`;
- commit the helper's `Package.resolved`;
- record the SDK and transitive licenses in third-party notices;
- never follow a floating branch in the GodexU root package;
- upgrade only through a separately tested dependency change.

## 7. Architecture And Data Flow

### 7.1 Main app: metadata authority

Add a no-window command:

```text
codexU --dump-project-index
```

It emits exactly one JSON document with schema
`godexu-project-index-v1` and exits. It must not initialize `NSApplication`,
read official quota/app-server data, sample CPU/temperature, probe Agent
nodes, use SSH, access the network, or write caches.

The command uses dedicated metadata projections:

- Codex: read thread ID, visible title, state, timestamps, and safe project
  label from the local SQLite database. Do not open rollout JSONL files or read
  preview, first-user-message, or recent-reply content for MCP.
- OpenClaw: read canonical task metadata and `sessions.json` metadata. Do not
  open transcript JSONL files. A session without a safe stored title uses a
  neutral generated label.
- Handoffs: read the existing strict Phase 2B envelope store, but exclude
  `handoffNote`.
- Claude Code and Hermes: the schema supports availability records, but this
  checkpoint exposes no task data unless a separately audited metadata-only
  adapter and local fixture are present. It never falls back to NAS.

Every task keeps an explicit `sourceRuntime`. A Codex-backed execution remains
attributed to Codex by existing token rules; the project index does not invent
or reassign token ownership.

### 7.2 Index schema

Top-level fields:

- `schema`: `godexu-project-index-v1`;
- `generatedAt`;
- `deviceScope`: `local-mac`;
- `freshness`: `fresh` or `stale`;
- `runtimeAvailability[]`;
- `projects[]`;
- `handoffs[]`;
- `warnings[]` using bounded public error codes only.

Project fields:

- `id`, derived `name`, `isDerived`;
- `sourceRuntimes[]`;
- active, pending, scheduled, done, total, and handoff counts;
- `lastActiveAt`;
- bounded task summaries containing normalized task ID, visible title, source,
  state, updated time, and optional progress percentage.

Handoff fields:

- envelope UUID, project ID, source/target runtime, local state, revision,
  created/updated time;
- visible bounded title;
- no handoff note, node address, path, prompt, or reply.

Raw native thread/session IDs remain inside the app. The MCP surface exposes
only normalized GodexU task IDs. Unknown keys or schemas fail closed.

### 7.3 MCP helper

Bundle location:

```text
codexU.app/Contents/Helpers/GodexUMCPServer
```

The helper:

- uses official Swift MCP SDK `0.12.1`;
- supports stable protocol `2025-11-25` through stdio;
- advertises resources and tools only;
- never initializes AppKit or opens a window;
- writes valid MCP JSON-RPC only to stdout;
- sends bounded diagnostics to stderr only;
- derives the sibling main executable path; no caller-provided executable,
  command, shell fragment, or path is accepted;
- resolves and validates the fixed bundle-relative main-executable path before
  launch; it does not follow a caller-selected symlink or search `PATH`;
- refreshes the index through a child process with a three-second timeout;
- caches a valid snapshot in memory for three seconds;
- may serve the last valid snapshot for up to fifteen minutes if refresh fails,
  with `freshness=stale`, original `generatedAt`, and a public error code;
- returns a bounded MCP error when no valid cache exists;
- stops when stdin closes or the MCP client disconnects.

The helper does not persist its cache. Durable local state remains the Phase 2B
index and source Runtime stores.

### 7.4 MCP surface

Static resource:

- `godexu://projects`

Resource templates:

- `godexu://projects/{projectID}`
- `godexu://handoffs/{envelopeID}`

Tools:

- `godexu_project_list`
  - optional source runtime and state filters;
  - default limit 20, maximum 50;
  - returns project summaries and freshness.
- `godexu_project_get`
  - requires one validated GodexU project ID;
  - returns one project and at most 100 bounded task rows.
- `godexu_handoff_list`
  - optional local state and target-runtime filters;
  - default limit 20, maximum 50;
  - never returns `handoffNote`.

All tools declare:

- `readOnlyHint: true`;
- `destructiveHint: false`;
- `openWorldHint: false`;
- explicit input and output schemas.

MCP tool annotations are safety hints, not authorization. The server enforces
the read-only boundary in code.

The MCP Tasks extension is not used in this checkpoint. It represents a
long-running tool-call lifecycle, not GodexU's project database.

## 8. Privacy And Security

Allowed model-visible content:

- derived project names already visible in GodexU;
- bounded visible task titles;
- source Runtime, state, timestamps, counts, progress, stable normalized IDs;
- handoff routing metadata without notes.

Prohibited content:

- prompt, recent reply, transcript, tool arguments/results, attachment body;
- handoff note, raw thread/session ID, full path, SSH alias, address, command;
- auth, environment values, credentials, account identity, raw logs;
- CPU/memory/temperature history or usage/account statistics.

Controls:

- strict schema decoding and output allowlists;
- bounded collection sizes and string lengths;
- no shell invocation;
- fixed sibling executable discovery;
- read-only SQLite opens where supported;
- no HTTP listener and no network entitlement requirement;
- no telemetry;
- privacy self-test scans MCP results, stdout, stderr, and public dump output.

## 9. Failure Semantics

- Missing runtime: availability is `unavailable`; counts are omitted, not zero.
- Missing optional metadata: use a neutral label or omit the field.
- Unsupported schema or invalid JSON: reject the snapshot and keep the last
  valid bounded cache if it is not older than fifteen minutes.
- Main command timeout: terminate the child, report `snapshot_timeout`, and
  use bounded stale fallback if available.
- Unknown tool/resource/ID: standard invalid-parameters or not-found MCP error.
- Invalid filters, negative limits, excessive strings, or unknown enum values:
  fail before reading data.
- Client disconnect: stop the helper and child process.
- Helper unavailable: GodexU UI, status item, Dynamic Island, and local index
  continue unchanged.

No error includes a local path, task body, command line, raw database error, or
source record.

## 10. Build, Packaging, And Attribution

- Keep the main app's direct `swiftc` build.
- Add a separate SwiftPM helper package/target with exact dependency locking.
- Build one helper architecture matching each app/DMG architecture.
- Copy the helper into `Contents/Helpers` before signing.
- Preserve the existing arm64 and x86_64 release paths; a universal helper is
  not required for the current per-architecture DMGs.
- Verify helper and containing app signatures explicitly.
- Do not commit `.build`, app bundles, DMGs, or dependency checkouts.
- Add official SDK attribution and license information to a third-party notice
  and the eventual release documentation.
- Do not bump version during local implementation.

Persistent MCP registration is deferred until the final application name and
path are settled. Local acceptance uses an isolated protocol client and, if
separately authorized, a non-persistent Codex configuration override. The app
does not silently edit `~/.codex/config.toml`.

## 11. Checkpoints And Acceptance

### Checkpoint 1: index contract

- RED/GREEN tests for strict schema, stable normalized IDs, sorting, limits,
  runtime availability, and stale markers;
- Codex/OpenClaw metadata fixtures prove no transcript access;
- handoff fixtures prove notes and sensitive fields are absent;
- `--dump-project-index` emits exactly one valid document and no stderr on
  success.

### Checkpoint 2: MCP helper

- initialization negotiates `2025-11-25`;
- tools/resources list and valid reads pass;
- invalid method, ID, input, and malformed child output fail safely;
- stdout contains only valid JSON-RPC messages;
- child timeout, disconnect, fresh cache, stale fallback, and no-cache failure
  pass;
- startup and representative local reads stay within plan-defined latency
  budgets derived from the research baseline.

### Checkpoint 3: integration and regression

- arm64 and x86_64 helper builds pass;
- Mach-O architecture and codesign checks pass;
- main `make build`, existing Phase 2A/2B self-tests, parsers, task navigation,
  status item, display surface, and Dynamic Island checks pass;
- privacy scan returns zero prohibited hits;
- real local protocol probe reads current projects and handoffs;
- optional real Codex tool-call acceptance is run only after explicit
  authorization for the one-shot host/model use.

Acceptance denominator:

- index contract: all planned fixtures/checks passed;
- MCP protocol/error/cache: all planned cases passed;
- architectures/signing: 2/2 passed;
- existing regression suite: all applicable checks passed;
- privacy: zero prohibited hits;
- real Codex consumer acceptance: passed or explicitly reported as pending,
  never inferred from a custom probe.

Expansion gate: only after this read adapter passes may a new design consider
persistent registration UI, local handoff mutation, delivery, NAS transport,
repair, or Windows.

## 12. Risks, Rollback, And Implementation Handoff

Main risks:

- pre-1.0 SDK changes;
- transitive dependency drift;
- accidental reuse of slow/full task readers;
- task title or path leakage;
- helper path breakage during the future codexU-to-GodexU rename;
- conflating protocol-probe success with real Codex acceptance.

Mitigations:

- exact SDK and resolved dependency pins;
- dedicated metadata-only serializer and privacy allowlist;
- helper/main split and hard child timeout;
- no persistent registration before the final app name;
- separate reporting for implementation, local verification, real Codex
  acceptance, installation, and release.

Rollback:

- remove the helper target, bundle copy step, and `--dump-project-index`
  command;
- no database migration or durable helper cache exists;
- no persistent Codex configuration is modified in this phase;
- the Phase 2B local index and current UI remain the rollback baseline.

Implementation handoff:

- next flow: `writing-plans` -> isolated L3 ownership check -> TDD
  implementation -> review -> verification;
- first implementation step: define the metadata-only index contract and RED
  privacy/schema tests before adding the MCP dependency;
- do not touch Windows, NAS, update routes, version, installed app, default
  branch, or GitHub remote;
- ask again before any persistent Codex registration, model/API acceptance,
  installation, push, or release.
