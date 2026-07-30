# GodexU v2 Phase 2B Project Hub And Handoff Draft Design

## 1. Project Promise

- Source request: continue GodexU 2.0 toward a ChatGPT-like project page,
  multi-Agent task management, role-based assignment, and later cross-device
  delivery.
- User-visible outcome: the existing Projects tab becomes a local project hub
  that groups observed Codex/OpenClaw/Claude Code/Hermes tasks and shows locally
  prepared Agent handoff drafts beside the work.
- Why now: Phase 2A established stable node identities and A/B/C policy
  metadata. The next safe checkpoint is to make tasks addressable to those
  identities without pretending that a transport protocol already exists, and
  to keep the local record compatible with a later MCP adapter.
- Project type: local-first multi-Agent project-management foundation.

## 2. Boundary Card

```yaml
status: bounded
task_id: "godexu-v2-phase2b-project-handoff"
task_goal: "Build a local project hub and auditable Agent handoff drafts from existing observed tasks."
in_scope:
  - a versioned local task-envelope model and store
  - MCP-ready UUID, origin-node, revision, and idempotency semantics
  - deterministic project grouping from already displayed task metadata
  - target-node selection using Phase 1 nodes and Phase 2A identities
  - local draft and ready-for-delivery states
  - a ChatGPT-like two-pane project hub inside the existing Projects tab
  - source/runtime, target Agent, policy, status, and timestamps
  - RED/GREEN tests, optimized build, privacy checks, and real UI acceptance
out_of_scope:
  - sending a task to Codex, OpenClaw, Hermes, Claude Code, or NAS
  - running or registering an MCP server/client in this phase
  - inbox/outbox network transport, polling, acknowledgement, retry, or conflict resolution
  - autonomous execution, process control, repair, permissions, or credentials
  - shared-memory writes, Memory Router changes, or a second memory system
  - task-body or recent-reply export in public diagnostics
  - Dynamic Island, status-item, Windows, update route, version, release, or installed-app replacement
allowed_reads:
  - current isolated codexU worktree
  - existing normalized task boards, Agent node snapshots, and local identity profiles
allowed_writes:
  - allowlisted source and docs files in this worktree
  - a local codexU task-envelope file during acceptance
external_actions: "none; no NAS write, task dispatch, GitHub push, or release"
success_evidence:
  - observed tasks group into deterministic local projects
  - a task can create a target-Agent handoff draft without sending it
  - saved drafts survive reload and malformed records fail closed
  - Projects tab shows projects, participating runtimes, tasks, and handoff drafts
  - A/B/C remains descriptive policy and never becomes execution authority
  - existing task detail, Codex deep links, node cards, status bar, and Dynamic Island regressions stay green
stop_conditions:
  - implementation requires a remote write or credential
  - a draft is represented as delivered or executed
  - stored content enters public node or usage JSON
  - existing dashboard navigation regresses
next_action: "Write the TDD implementation plan and build the model/store before UI integration."
```

The user's “继续，别停” approves continued local implementation of the
previously announced Phase 2B direction. It does not authorize a changed-diff
GitHub push, installation, NAS write, release, or task delivery.

## 3. Requirement Status

- Gate: clear.
- Existing decisions reused:
  - the project page should aggregate tasks like ChatGPT Projects;
  - the Agent manager and current Dynamic Island remain separate surfaces;
  - users assign work according to Agent identity;
  - A/B/C is user-controlled and can become more customizable later;
  - every machine must remain useful without a NAS;
  - GodexU aggregates and links to native Agents rather than replacing them.
- Conservative assumption: Phase 2B records an addressable, reviewable handoff
  draft. “Ready for delivery” is still local state, not proof of delivery.
- Material unknown parked: the cross-device transport and acknowledgement
  contract. It belongs to Phase 2C and must have its own security and failure
  design.

## 4. Alternatives And Decision

### A. Adapt the existing Swift models and local JSON stores — selected

Add a compact envelope model, strict atomic store, pure project aggregator, and
native SwiftUI project hub. This preserves the lightweight app, gives immediate
visible value, and creates a migration point for a later transport.

### B. Add an embedded SQLite control-plane database now

SQLite is a stronger eventual fit for comments, event history, conflict
resolution, and cross-device replication. It would also require a schema
migration, query layer, backup policy, and new acceptance surface before the
first handoff can be shown. That is too large for this checkpoint.

### C. Run FocusClaw or Mission Control as GodexU's backend

This offers mature project/task APIs faster, but changes a single lightweight
Swift app into a native client for a Node/React service. It introduces a
resident process, API authentication, lifecycle management, schema ownership,
and a second UI. It is unsuitable as the default GodexU architecture.

Decision: use A now. Keep the domain names and versioned envelope document
small enough that Phase 2C can migrate them into SQLite or a signed transport
without changing the visible project workflow.

## 5. First-Use And Return Loop

```text
observe tasks -> open a task -> choose target Agent -> write handoff note
-> save local draft or mark locally ready -> open Projects
-> see project, source task, target identity, and draft state -> review next action
```

Within 30 seconds the user can turn an existing task into a local handoff draft
addressed to one of the visible Agent nodes. Returning to the Projects tab shows
where work lives, which runtimes participate, and which handoffs still need
review or delivery.

## 6. Domain Semantics

### `AgentTaskEnvelope`

- `id`: canonical UUID generated by GodexU.
- `originNodeID`: the local GodexU/Agent node that authored the envelope.
- `revision`: positive monotonic local revision, starting at `1`.
- `sourceTaskID`: the normalized task identifier already used by the task
  board.
- `sourceRuntime`: Codex, OpenClaw, Claude Code, or Hermes.
- `projectID` and `projectName`: local derived project identity.
- `title`: bounded copy of the visible task title.
- `targetNodeID` and `targetRuntime`: stable Phase 1 node identity.
- `handoffNote`: user-authored local instruction, maximum 400 characters and
  eight logical lines.
- `state`: `draft` or `ready`.
- `createdAt` and `updatedAt`.

`ready` means “the user considers this local envelope ready for the future
delivery step.” It never means queued, sent, received, accepted, running, or
completed.

The envelope UUID is also the future idempotency key. A transport must not
create a second logical handoff when it receives the same UUID. Updates must
carry the expected revision; Phase 2C will define conflict handling instead of
silently overwriting a newer record.

### Project identity

The current task model exposes a user-safe `detail` label, not a canonical
workspace path. Phase 2B derives a project label from the part before the
existing ` · ` separator and normalizes it to a stable local key.

- Empty labels become `未归类 / Unsorted`.
- Labels are bounded and never reconstructed into a filesystem path.
- A fallback project is scoped by source runtime so unrelated unclassified
  tasks do not collapse together.
- Same-named projects can collide in this first local index; the UI labels the
  grouping as locally derived. Canonical cross-device project IDs are deferred
  to Phase 2C.

### Target policy

The draft editor displays the target Agent's Phase 2A role and policy:

- A: the draft can be recorded, but no action is implied.
- B: the draft can be prepared and marked ready, but not sent.
- C: the draft can be prepared and marked ready, but Phase 2B grants no extra
  permission.

The envelope does not copy or enforce the profile text. Runtime and node ID are
the stable references; current role/policy is resolved locally for display.

## 7. Persistence And Privacy

- File:
  `~/Library/Application Support/codexU/task-envelopes.json`
- Schema: `godexu-task-envelopes-v1`
- Maximum envelopes: 256.
- Entire documents decode strictly; unknown schema, unknown keys, duplicate
  IDs, unsafe node/task/project IDs, invalid runtimes, excessive content, or
  malformed dates fail closed to an empty local set.
- Writes are sorted by update time and atomic.
- Update operations preserve `createdAt` and replace the matching envelope
  only after full validation.
- Delete is local and explicit.
- Updates preserve `id`, `originNodeID`, and `createdAt`, and increment
  `revision` by exactly one.

Task titles and handoff notes remain local. They are excluded from
`--dump-agent-nodes`, `--dump-json`, logs, telemetry, node configuration,
identity profiles, and public screenshots. No prompt, recent reply, tool
argument, attachment body, raw log, credential, network address, or path is
copied into an envelope.

## 8. MCP Direction

MCP is the preferred future integration surface, not the storage engine.
GodexU's local index remains authoritative for offline operation; an MCP adapter
will expose carefully separated read and mutation capabilities.

### Proposed read resources/tools

- `godexu://projects`
- `godexu://projects/{projectID}`
- `godexu://handoffs/{envelopeID}`
- `godexu_project_list`
- `godexu_project_get`
- `godexu_handoff_list`

These are read-only, closed-world operations. A future server should declare
the corresponding MCP tool hints as read-only and non-destructive.

### Proposed local mutation tools

- `godexu_handoff_prepare`
- `godexu_handoff_update`
- `godexu_handoff_mark_ready`

These mutate only the local GodexU index. They require envelope UUID,
`originNodeID`, and expected `revision`, and are idempotent for the same
arguments.

### Proposed transport tools

Actual delivery, acknowledgement, execution, repair, and cancellation are
separate Phase 2C tools with stronger approval and open-world annotations. They
must never be hidden behind `handoff_update`.

The MCP `io.modelcontextprotocol/tasks` extension represents a long-running
tool invocation lifecycle. It is not GodexU's project/task database. Phase 2C
may return an MCP Task handle for a long-running delivery or repair call, while
the durable GodexU envelope continues to carry business identity, routing, and
audit state.

Initial local integration should prefer stdio because it needs no listening
port or OAuth. NAS/remote Streamable HTTP requires explicit authentication and
is outside Phase 2B.

## 9. Project Hub UI

The existing Projects tab becomes `AgentProjectHubView` without adding a new
top-level window.

### Left pane

- derived project name;
- active/total task count;
- locally saved handoff count;
- compact participating-runtime marks;
- selected state using existing control surfaces.

### Right pane

- project title and “本机归类 / Local grouping” explanation;
- summary tiles for active tasks, completed tasks, Agents, and handoffs;
- task list with source badge, state, relative time, and existing detail
  action;
- handoff list with target Agent role, A/B/C policy, draft/ready state, and
  relative time;
- honest empty states for no tasks and no handoffs.

The view uses the existing Liquid Glass palette, list-row tokens, runtime logos,
and source badges. It does not expose task summaries or replies on the project
overview.

### Task detail integration

`TaskDetailView` keeps its current summary, progress, recent-reply, and Codex
deep-link behavior. It adds a compact “准备 Agent 交接” section below progress:

- target Agent picker;
- current role and A/B/C description;
- bounded handoff-note editor;
- `保存草稿` and `标记待投递` actions;
- a persistent notice: “仅保存在本机，尚未投递”.

If there is no compatible target node, the section shows a local explanatory
empty state and does not create an envelope.

## 10. Reuse Scan

```text
reuse_decision: adapt
reason: reuse codexU TaskItem/TaskBoard, AgentNodeSnapshot, AgentIdentityProfileStore, atomic JSON store pattern, TaskDetailView, runtime badges, and existing project-tab shell. Reference external task products for domain boundaries only; do not import their web stacks.
checked_at: 2026-07-30
sources:
  - local Sources/CodexUsageWidget/main.swift
  - local Sources/CodexUsageWidget/Services/AgentIdentityProfileStore.swift
  - local Sources/CodexUsageWidget/UI/AgentNodeViews.swift
  - https://github.com/emiliojohann/FocusClaw
  - https://github.com/builderz-labs/mission-control
  - https://github.com/PerpetualSoftware/pad
```

- FocusClaw: MIT, local-first SQLite, structured projects/tasks/comments, and
  OpenClaw/Hermes REST access. It explicitly treats Agent ownership as a
  coordination label rather than automatic execution. The repository is very
  young and uses React/Fastify/Node, so it is reference-only.
- Builderz Mission Control: MIT, SQLite control plane with Codex/OpenClaw
  adapters, but explicitly alpha and much broader than this checkpoint.
- Pad: Apache-2.0, local-first SQLite with agent-readable project conventions;
  useful as a future project-schema reference, not a native Swift dependency.
- Local adaptation cost is lower: no new dependency, service, port, account,
  key, or network permission.
- MCP official documentation: tools/resources/prompts are distinct
  capabilities; tool annotations are risk hints rather than authorization; the
  `2026-07-28` Tasks extension is opt-in and intended for durable asynchronous
  tool calls. Phase 2B therefore prepares stable data semantics but does not
  ship a partial server.

## 11. Architecture And Files

### Domain

- Create `Domain/AgentTaskEnvelope.swift`.
- Create `Domain/AgentTaskEnvelopeSelfTest.swift`.
- Create `Domain/AgentProjectWorkspace.swift`.

The project aggregator is pure: task board plus envelopes in, ordered project
summaries out. It never reads disk or contacts a runtime.

### Store

- Create `Services/AgentTaskEnvelopeStore.swift`.

The store mirrors the proven Phase 2A Application Support pattern but uses its
own schema and capacity. It is independent from node polling and identity
profiles.

The model includes transport-neutral `originNodeID` and monotonic `revision`;
no MCP SDK or server dependency is added.

### UI

- Create `UI/AgentProjectHubView.swift`.
- Modify `main.swift` to own one envelope store, pass node/profile/envelope
  state to task details, and route the Projects tab to the hub.

### Tests and build

- Register `--self-test-task-envelopes` in `main.swift`.
- Add `test-task-envelopes` to `Makefile`.
- Keep existing task-navigation, Agent, display, status-item, Dynamic Island,
  parser, build, plist, signature, and privacy checks.

No provider, token-accounting, node-probe, update-channel, Windows, release, or
NAS file is in scope.

## 12. Checkpoints

1. RED/GREEN domain tests prove validation, project derivation, ordering, and
   draft/ready semantics.
2. RED/GREEN store tests prove create, update, reload, delete, capacity,
   strict decoding, and public-diagnostic isolation.
3. Presentation tests and real UI prove target selection, local save, reload,
   project aggregation, empty state, and no regression to existing detail/deep
   link behavior.

Expansion gate: only after Phase 2B passes may Phase 2C define transport,
acknowledgement, retry, cross-device project IDs, or one-click repair.

## 13. Risks And Rollback

- Risk: users read “待投递” as already queued. Mitigation: use
  `ready` internally and repeat “仅保存在本机，尚未投递” in the editor and hub.
- Risk: title/note leakage. Mitigation: separate local store, no JSON diagnostic
  integration, and forbidden-field/content regression checks.
- Risk: project-name collisions. Mitigation: label grouping as derived and defer
  canonical IDs; never claim cross-device identity.
- Risk: confusing MCP Tasks with user project tasks. Mitigation: keep the
  GodexU envelope domain independent and use the MCP Tasks extension only for
  long-running tool-call lifecycle.
- Risk: the existing dashboard becomes cramped. Mitigation: use a two-pane view
  only within Projects and keep task summaries/replies in the existing detail
  sheet.
- Fallback: absent or invalid envelope file yields observed projects with zero
  handoffs.
- Rollback: remove `task-envelopes.json` and the Phase 2B domain/store/UI files;
  route Projects back to `ProjectBoardPanel`. Phase 2A remains intact.

## 14. Acceptance

- Fresh RED is observed before each production unit.
- Targeted envelope tests pass after GREEN.
- All existing self-tests and four parser fixtures pass.
- Optimized build, strict code signature, plist, diff, allowlist, and privacy
  checks pass.
- Real macOS UI shows:
  1. projects derived from real local tasks;
  2. a task detail with target Agent selection;
  3. a saved local draft;
  4. the draft in the correct project with target role/policy;
  5. reload persistence;
  6. explicit not-delivered language;
  7. deletion or cleanup restoring the original local state.
- No NAS write, dispatch, installation, GitHub push, version bump, or release is
  performed.
- No MCP server, port, client configuration, OAuth flow, or tool registration is
  performed; schema/revision/idempotency behavior is covered by local tests.

## 15. Handoff

- Next flow: `writing-plans`, then inline `executing-plans` with TDD.
- First implementation step: register the envelope self-test and observe the
  missing domain types fail compilation.
- Do not touch transport, NAS, Memory Router, repair, update routing, Windows,
  release assets, the installed app, or MCP host configuration.
- Ask again before any changed-diff push, installation, remote write, transport
  activation, merge, version bump, or release.
