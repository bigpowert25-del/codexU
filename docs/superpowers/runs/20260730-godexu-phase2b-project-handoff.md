# GodexU Phase 2B project hub and local handoff run

## Identity and boundary

- Run ID: `godexu-phase2b-project-handoff-20260730`
- Date: 2026-07-30 Asia/Shanghai
- Isolated worktree:
  `/Users/mac/.config/superpowers/worktrees/codexU/dynamic-island-local-prototype`
- Branch: `codex/dynamic-island-local-prototype`
- Baseline before Phase 2B: `9a69320`
- Design commits: `503ab44`, `2c4db82`
- Implementation commits: `a7dc481`, `1567fe8`, `52ad4ce`, `955a42e`
- Execution approval: the user explicitly said to continue and not stop.
- Remote-write approval: not granted for this checkpoint.
- Release approval: not granted for this checkpoint.

Allowed work was limited to the local project hub, local Agent handoff
envelopes, strict local persistence, native task-detail UI, tests, and
documentation. Excluded work remained excluded: real delivery, NAS writes,
repair, shared-memory mutation, MCP hosting/configuration, credentials,
version bump, installed-app replacement, GitHub push, PR, tag, DMG, and
release.

## Result

The existing Projects tab is now a two-pane project hub:

- the left pane groups real observed tasks by bounded project identity;
- the right pane shows project runtimes, active/done/Agent/handoff counts,
  task rows, and local handoff rows;
- task rows preserve the existing task-detail sheet;
- project overview does not show task summaries, recent replies, handoff
  notes, filesystem paths, network hosts, or credentials;
- handoff rows show the target Agent, role, A/B/C policy, local state, and an
  explicit local-only/not-delivered notice.

The existing task detail sheet now includes:

- a target picker for visible companion-Agent nodes;
- the target Agent role and policy;
- a bounded local handoff note;
- `保存草稿`;
- `标记本机就绪`;
- an explicit `未投递` label and success copy that says the record remains
  local.

The task-card primary action still opens details. Codex tasks still expose the
validated `codex://threads/<thread-id>` action. Summary, honest progress, and
recent reply remain inside the detail sheet.

## Local envelope contract

- File:
  `~/Library/Application Support/codexU/task-envelopes.json`
- Schema: `godexu-task-envelopes-v1`
- Maximum records: 256
- States: `draft`, `ready`
- Identity: canonical UUID plus stable origin node and derived source-task ID
- Updates: identical same-revision writes are idempotent; changed records
  require exactly the next revision
- Persistence: sorted, ISO-8601, exact-key validated, pretty-printed, atomic
- Failure behavior: malformed, duplicate, oversized, unsupported, unsafe, or
  unknown-key documents fail closed

Approved envelope keys:

```text
createdAt
handoffNote
id
originNodeID
projectID
projectName
revision
sourceRuntime
sourceTaskID
state
targetNodeID
targetRuntime
title
updatedAt
```

No queued, sent, delivered, accepted, running, acknowledgement, credential,
network, command, stdout, stderr, summary, or recent-reply field is stored.

## TDD evidence

RED:

1. Domain compilation failed because `AgentTaskEnvelope`,
   `AgentTaskEnvelopeState`, and the project workspace did not exist.
2. Store compilation failed because `AgentTaskEnvelopeStore` did not exist.
3. The first domain GREEN run exposed a real project-ID mismatch; the
   envelope and task grouping rules were then unified and re-tested.

GREEN:

- bounded envelope validation and stable source-task identity passed;
- runtime fallback grouping and task/activity ordering passed;
- missing-file, reload, atomic update, idempotency, revision conflict,
  immutable identity, deletion, strict-key, malformed-document, and
  256-record capacity tests passed;
- existing task-navigation behavior continued to pass.

## Automated verification

Automated denominator: `20`.

- Passed: `20/20`
- Failed: `0/20`
- Unverified: `0/20`

Passed built-in self-tests (`16/16`):

1. Agent identity
2. Agent nodes
3. Agent selection
4. Codex token events
5. Display surface
6. Dynamic Island presentation
7. Global shortcut
8. Local system monitor
9. Particle animation
10. Rate-limit normalization
11. Statistics time zone
12. Status item
13. Task envelope store
14. Task envelope domain/project grouping
15. Task navigation
16. Update routing

Passed parser fixtures (`4/4`):

1. Codex
2. OpenClaw
3. Claude Code
4. Hermes

Additional checks:

- fresh optimized `make build`: passed;
- ad-hoc signing plus strict code-signature verification: passed;
- `Resources/Info.plist` validation: passed;
- `git diff --check`: passed;
- public Agent-node dump: no envelope/private-field hits;
- public aggregate JSON dump: no envelope/private-field hits.

## Real UI acceptance

Acceptance denominator: `10`.

- Passed: `10/10`
- Failed: `0/10`
- Unverified: `0/10`

Passed flows:

1. The exact isolated app bundle launched without replacing the installed app.
2. Fourteen real observed tasks grouped into five projects.
3. The project list and detail pane rendered without clipping or excess blank
   space.
4. A real Codex task opened its existing detail sheet with summary, progress,
   recent reply, and `在 Codex 中打开`.
5. Hermes and OpenClaw were available as local draft targets; Hermes displayed
   its localized role and A policy.
6. Saving a draft updated the project count and displayed
   `草稿已保存在本机，尚未发送`.
7. Disk inspection confirmed schema v1, one draft, exact approved keys, and
   zero forbidden delivery/private keys.
8. A cold start restored the draft and its target identity.
9. Marking ready advanced revision `1 -> 2`, displayed
   `已标记为本机就绪，尚未发送`, and a second cold start restored
   `本机就绪`.
10. The acceptance file was removed from Application Support, the isolated
    process ended, and the original `/Applications/codexU.app` process
    remained running.

## MCP direction

MCP is intentionally treated as an adapter, not the memory database or project
database.

Future read-only resources/tools can expose the local index:

```text
godexu://projects
godexu://projects/{projectID}
godexu://handoffs/{envelopeID}
godexu_project_list
godexu_project_get
godexu_handoff_list
```

Future local mutation tools can prepare or update drafts:

```text
godexu_handoff_prepare
godexu_handoff_update
godexu_handoff_mark_ready
```

Actual delivery, acknowledgement, retry, and one-click repair remain separate
higher-risk tools for Phase 2C. Local stdio comes before remote HTTP/OAuth.
The MCP Tasks extension may later represent long-running tool-call lifecycle;
it must not replace the local project/task index.

## Status

| Dimension | Status | Evidence |
| --- | --- | --- |
| Implementation | passed | Project hub, envelope model, strict store, and task-detail draft editor are implemented. |
| Local verification | passed | 20/20 automated checks plus build, signing, plist, diff, and privacy checks passed. |
| End-to-end UI | passed | 10/10 real-task, persistence, revision, reload, and cleanup flows passed. |
| MCP adapter | designed, not implemented | Resource/tool boundary recorded; no SDK, server, port, or config change. |
| NAS / cross-device | not performed | Existing node data was observed only through the established read-only path. |
| Installed app | not modified | `/Applications/codexU.app` remained the original running installation. |
| GitHub | not pushed | No fresh remote-write approval for this Phase 2B checkpoint. |
| Release | not authorized | No version bump, tag, DMG, notarization, or release. |

## Rollback

- Source: revert `955a42e`, `52ad4ce`, `1567fe8`, and `a7dc481`.
- Local handoff data: exit the test build, then restore or remove
  `task-envelopes.json` according to its pre-change backup.
- No NAS, MCP-host, installed-app, GitHub, or release rollback is required
  because none of those surfaces were modified.

## Phase 2C remaining work

1. Add a local, read-only stdio MCP adapter over the validated project and
   handoff index.
2. Define explicit delivery receipts, retries, duplicate suppression, and
   failure states without reusing `ready` as a delivery claim.
3. Add user-confirmed Agent-to-Agent delivery and optional repair tools behind
   policy gates.
4. Keep one local index on every device and allow an optional NAS authority
   without making NAS availability mandatory.
