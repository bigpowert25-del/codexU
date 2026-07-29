# GodexU v2 Phase 2A Agent Identity And Policy Design

## 1. Project Promise

- Source request: continue GodexU 2.0 after real-node observation, let users define Agent identities, and prepare role-based task routing with A/B/C levels.
- User-visible outcome: every visible Codex, OpenClaw, or Hermes node opens a native detail sheet showing health, role, capabilities, and a locally editable A/B/C policy level.
- Why now: task delivery and project aggregation need stable Agent identities and an explicit user-owned policy before any cross-device write is safe.
- Project type: local-first multi-Agent management foundation.

## 2. Boundary Card

```yaml
status: bounded
task_id: "godexu-v2-phase2a-agent-identity-policy"
task_goal: "Add local Agent identity profiles and A/B/C policy levels to the existing node cards."
in_scope:
  - default roles for Codex, OpenClaw, Claude Code, and Hermes
  - local profile persistence keyed by stable node ID
  - A/B/C policy presentation and selection
  - editable role name and short responsibility summary
  - clickable node cards and a native detail sheet
  - reset to runtime defaults
  - deterministic self-tests, build, and visual acceptance
out_of_scope:
  - task dispatch or inbox/outbox transport
  - NAS writes, process restarts, repair, or permission execution
  - shared-memory writes or a second memory system
  - project aggregation page
  - Dynamic Island or status-item redesign
  - Windows production changes
  - app rename, version bump, push, merge, tag, release, or notarization
allowed_reads:
  - current isolated codexU worktree
  - existing normalized node snapshots and runtime capabilities
allowed_writes:
  - allowlisted source and docs files in this worktree
  - local codexU Application Support profile file during acceptance
external_actions: "none; all profile changes are Mac-local"
success_evidence:
  - profile defaults are deterministic by runtime
  - edits survive store reload and invalid records fail closed
  - no-NAS mode still shows an editable local Codex profile
  - remote node cards open without exposing SSH aliases, paths, or logs
  - existing self-tests, parser fixtures, build, and UI smoke checks pass
stop_conditions:
  - implementation needs a NAS write or credential change
  - profile data would be mixed into public node JSON
  - existing dashboard, status bar, or Dynamic Island behavior regresses
next_action: "Write a TDD plan, then implement the local profile model, store, and node-detail UI."
```

The user's current “继续做…赶紧继续做” continues the already approved GodexU 2.0 direction and authorizes this local, reversible Phase 2A implementation. It does not authorize a changed-diff GitHub push or release.

## 3. Requirement Status

- Gate: clear.
- Existing decisions reused:
  - preserve the current codexU dashboard and Dynamic Island;
  - use real OpenClaw and Hermes nodes for development;
  - let users define Agent identity and assign work by identity;
  - expose three A/B/C levels and allow later customization;
  - remain usable without a NAS.
- Conservative assumption: A/B/C are policy metadata in Phase 2A, not execution authority.
- Material unknown parked: exact dispatch permissions inside each level. That belongs to the later task-delivery phase and must be enforced by its own protocol.

## 4. First-Use And Return Loop

```text
see node -> open Agent detail -> review default identity and policy
-> edit locally -> save -> node card reflects profile -> later routing consumes it
```

Within 30 seconds the user can click a node, understand its assigned role, choose A/B/C, change the role text, and save. The value is reduced ambiguity: later task routing can target a stable role rather than guessing from a runtime name.

## 5. MVP Semantics

### Default identities

| Runtime | Default role | Responsibility |
| --- | --- | --- |
| Codex | 开发执行 / Build & execute | 研究、实现、验证与可交付成果 |
| OpenClaw | 协调调度 / Coordinate | 连续理解、任务编排与跨端状态协调 |
| Claude Code | 代码协作 / Code collaboration | 本机代码会话与实现协作 |
| Hermes | 分析复核 / Analyze & review | 独立分析、研究与结果复核 |

### Policy levels

- **A 保守 / Guarded**: observe and advise. No external action is implied.
- **B 协作 / Collaborative**: may prepare work and handoff drafts. Dispatch still requires the later transport and confirmation contract.
- **C 灵活 / Flexible**: reserved for user-defined rules in a later phase. In Phase 2A it is stored and displayed but grants nothing by itself.

All runtimes default to A. This is fail-closed and makes the future execution boundary explicit.

### Editable fields

- Role name: trimmed, single line, 1–32 characters.
- Responsibility summary: trimmed, at most 120 characters and three logical lines.
- Policy level: A, B, or C.
- Reset restores the runtime default profile.

Node identity, runtime, device, health, capabilities, SSH alias, and probe profile are not editable in this sheet.

## 6. Reuse Scan

```text
reuse_decision: adapt
reason: extend the existing AgentNodeDescriptor, AgentNodeStatusSection, TaskDetailView sheet pattern, WidgetPalette, and Application Support storage style; no new dependency is needed.
checked_at: 2026-07-29
sources:
  - Sources/CodexUsageWidget/Domain/AgentNode.swift
  - Sources/CodexUsageWidget/UI/AgentNodeViews.swift
  - Sources/CodexUsageWidget/main.swift
  - Sources/CodexUsageWidget/Services/AgentNodeSnapshotCache.swift
  - docs/DESIGN_SYSTEM.md
```

Public agent-manager frameworks are unnecessary for this slice. The risk is policy meaning and local persistence, not transport or orchestration. Building the small model locally is lower risk than importing a plugin framework.

## 7. Architecture

### `AgentIdentityProfile`

- stable `nodeID`;
- runtime;
- role name;
- responsibility summary;
- `AgentPolicyLevel`;
- update timestamp.

It provides deterministic runtime defaults and sanitized user-edit construction.

### `AgentIdentityProfileStore`

- versioned schema `godexu-agent-profiles-v1`;
- file `~/Library/Application Support/codexU/agent-profiles.json`;
- atomic local write;
- strict node/runtime validation and bounded strings;
- unknown or malformed records are ignored rather than partially trusted;
- only non-default overrides need persistence.

The store does not read or write node SSH configuration and never contacts a remote node.

### UI state

`AgentNodeStore` owns an `AgentIdentityProfileStore` and publishes a profile for every current snapshot. Node cards receive both snapshot presentation and profile presentation.

Clicking a node card opens `AgentIdentityDetailView`. The view uses a draft copy so Cancel makes no change; Save validates and persists; Reset writes the deterministic runtime default. A policy badge on the card makes the selected level visible without adding another dashboard section.

### Privacy

User-written role text stays local. It is not added to `--dump-agent-nodes`, `--dump-json`, task cards, logs, telemetry, or screenshots intended for publication. The detail view never shows SSH alias, network host, remote command, raw output, path, prompt, reply, or credential.

## 8. Files

- Create `Sources/CodexUsageWidget/Domain/AgentIdentityProfile.swift`.
- Create `Sources/CodexUsageWidget/Domain/AgentIdentityProfileSelfTest.swift`.
- Create `Sources/CodexUsageWidget/Services/AgentIdentityProfileStore.swift`.
- Modify `Sources/CodexUsageWidget/UI/AgentNodeViews.swift`.
- Modify `Sources/CodexUsageWidget/main.swift`.
- Modify `Makefile`.
- Add the Phase 2A plan and run record under `docs/superpowers/`.

No provider, token-accounting, update-channel, Dynamic Island, Windows, NAS, or memory-router file is in scope.

## 9. Checkpoints

1. RED/GREEN model tests prove defaults, validation, equality, and A/B/C decoding.
2. RED/GREEN store tests prove save/reload, reset, malformed-record rejection, node/runtime mismatch rejection, and no-NAS local defaults.
3. UI tests/presentation tests plus live UI prove node click, draft cancel, save, reset, truncation, accessibility, and existing surface stability.

Expansion gate: only after these pass may the project page or task-delivery protocol consume the profiles.

## 10. Risks, Fallback, And Rollback

- Risk: users interpret C as unrestricted execution. Mitigation: every level description says this phase grants no execution authority.
- Risk: stale profiles attach to the wrong node. Mitigation: key by stable node ID and require runtime match.
- Risk: corrupt local JSON breaks the dashboard. Mitigation: fail closed to deterministic defaults.
- Risk: custom text leaks through public diagnostics. Mitigation: keep profile data out of node JSON and add a regression assertion.
- Fallback: if the profile file is absent or invalid, all visible nodes use runtime defaults at A.
- Rollback: remove `agent-profiles.json` and the Phase 2A UI/model files; Phase 1 node observation remains intact.

## 11. Acceptance

- Targeted Phase 2A self-test shows an intentional RED before production code and GREEN after implementation.
- All 14 built-in self-tests, four parser fixtures, optimized build, strict codesign, plist, JSON privacy, and diff checks pass.
- Live macOS UI shows three clickable nodes, correct default roles, A/B/C selection, save/reload, reset, and no overflow in Chinese.
- A temporary no-node configuration proves local Codex-only mode remains healthy.
- No NAS write is performed.

## 12. Handoff

- Next flow: `writing-plans` then inline `executing-plans` with TDD.
- First implementation step: create the self-test entry point with desired default and validation assertions and observe the missing-type compile failure.
- Do not touch task delivery, memory synchronization, repair, update routing, or release files.
- Ask again before any remote write, changed-diff push, merge, version bump, release, or policy enforcement.
