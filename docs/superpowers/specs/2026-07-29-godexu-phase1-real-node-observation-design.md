# GodexU v2 Phase 1 Real Node Observation Project Design

## 1. Project Promise

- Source request or signal: evolve the existing CodexU interface into the GodexU multi-device, multi-Agent aggregation surface while preserving the current dashboard, menu bar, and Dynamic Island.
- User-visible outcome: the existing macOS dashboard shows local Codex plus the real NAS OpenClaw and Hermes nodes with an honest online, degraded, offline, unreachable, or cached state.
- Why this is worth doing now: node identity and health are the smallest dependable foundation for later project aggregation, task delivery, memory indexes, permission levels, and one-click repair.
- Project type: local-first macOS tool and cross-device Agent workflow.

## 2. Boundary Card

```yaml
status: bounded
task_goal: "Add a read-only real-node observation slice to the existing CodexU macOS app."
in_scope:
  - local Codex node identity
  - configured NAS OpenClaw and Hermes nodes
  - strict SSH read-only probes
  - local snapshot cache and offline degradation
  - a compact node section inside the existing dashboard
  - structured CLI output, self-tests, build, real-node and visual acceptance
out_of_scope:
  - NAS writes or package changes
  - shared-memory writes
  - cross-Agent task delivery
  - one-click repair
  - permission A/B/C enforcement
  - Windows production implementation
  - app rename, version bump, release, GitHub push, merge, or deployment
allowed_reads:
  - the isolated codexU worktree
  - the local Codex runtime state already read by codexU
  - configured SSH host aliases and fixed non-secret NAS process/heartbeat metadata
allowed_writes:
  - allowlisted files in this isolated worktree
  - local codexU Application Support node configuration
  - local codexU cache snapshots
external_actions: "Read-only SSH probes are approved. Remote writes and publication require new approval."
success_evidence:
  - local Codex, NAS OpenClaw, and NAS Hermes have independent node snapshots
  - live SSH evidence is normalized without reading conversation content
  - failed probes fall back to a labeled local cache
  - no-NAS configuration remains a normal local-only state
  - the existing dashboard, menu bar, Dynamic Island, token attribution, and Agent selection still work
  - all applicable self-tests, build, signature, CLI probe, and visual checks pass
stop_conditions:
  - a probe needs a password prompt, credential change, package restart, or NAS write
  - the required host key is unknown or changed
  - an implementation would require arbitrary remote commands
next_action: "Write and execute a TDD implementation plan for this single slice."
```

Execution approval is the user's 2026-07-29 instruction: “继续按照方案推进，去做吧”. It authorizes local implementation and the already selected read-only test against the existing OpenClaw and Hermes nodes. It does not authorize a new GitHub push or release.

## 3. Reverse-Questioning Status

- Gate status: clear.
- Current confidence basis: the user already chose real OpenClaw/Hermes testing, approved local-first fallback, chose NAS as preferred coordinator when present, required no-NAS support, and asked to preserve the current CodexU surfaces.
- Material unknown: the final GodexU v2 project page, task-delivery protocol, permission editor, and repair actions are later independently testable slices.
- Assumptions if proceeding:
  - the current public app name and v1.2 version remain unchanged in this phase;
  - remote node observation is separate from token and task attribution;
  - a node can be visible even when it is not the currently selected companion Agent;
  - no remote node configuration is equivalent to a healthy local-only installation, not an error.

## 4. User And Operator

- Primary operator: a person using Codex locally and one or more Agents on a NAS or another machine.
- Trigger moment: the operator wants to know which Agent nodes exist and whether they are usable before switching tools or assigning work.
- Existing workaround: open terminals, remember SSH aliases, inspect processes, and separately check stale heartbeat files.
- Desired behavior change: open the existing CodexU dashboard and see a small, source-labeled node overview without exposing prompts, replies, logs, credentials, or full paths.

## 5. Core Project Loop

```text
configured node -> bounded read-only probe -> normalized snapshot -> local cache -> dashboard/CLI evidence -> next authorized phase
```

- Input: local Codex state plus an optional local `nodes.json` containing node identity, runtime, SSH host alias, and a known probe profile.
- Work action: validate configuration, run a fixed SSH probe with a short timeout, evaluate process and heartbeat freshness, then reconcile with the last local cache.
- Output artifact: `AgentNodeSnapshot` values for local Codex, NAS OpenClaw, and NAS Hermes.
- Verification: self-test fixtures, structured CLI output, real NAS probe, dashboard screenshot, and no-NAS/offline checks.
- Next-step trigger: the user accepts the node model and separately authorizes task delivery, memory exchange, repair actions, or publication.

## 6. Scope And Non-Goals

### MVP includes

- A local Codex node synthesized from the existing Codex runtime snapshot.
- Optional remote nodes loaded from `~/Library/Application Support/codexU/nodes.json`.
- Two fixed Phase 1 probe profiles:
  - `synology-trim-openclaw-v1`
  - `synology-trim-hermes-v1`
- SSH through `/usr/bin/ssh` with:
  - key-only, non-interactive `BatchMode=yes`;
  - `StrictHostKeyChecking=yes`;
  - one connection attempt and a four-second connect timeout;
  - a validated host alias;
  - a fixed profile command, never a command from configuration.
- Process count and heartbeat/log modification time only. No transcript, message, environment, database, token, key, or config-file content is read.
- Local cache with last-known snapshot and a visible cached/stale label.
- A compact “Agent nodes” section below the current local-system strip.
- A `--dump-agent-nodes` structured acceptance entry point.
- A `--self-test-agent-nodes` regression entry point.

### MVP excludes

- Remote token/session parsing. Existing token attribution remains unchanged.
- Opening remote shells or Agent UIs.
- Adding, editing, pairing, or deleting nodes from the GUI.
- Automatic host-key acceptance.
- Polling while the main dashboard is closed.
- Dynamic Island node rows, status-item redesign, project aggregation, task delivery, memory replication, permission execution, and repair.

### Side-task parking lot

- ChatGPT-like cross-Agent project page.
- Full Agent manager with presets and user-defined identities.
- A/B/C permission defaults, per-project overrides, and per-Agent ceilings.
- Immutable task event log and conflict center.
- Local memory index/outbox/inbox and NAS/no-NAS coordinator election.
- One-click safe repair with high-risk confirmation.
- Windows node and Windows Dynamic Island production work.

### Privacy and dependency boundary

- The app never stores a password or private-key path.
- SSH uses the user's existing SSH configuration and known-hosts policy.
- Probe stderr is reduced to a local, user-readable category; remote paths and raw output are not shown in the UI.
- Cache contains only normalized node metadata.
- No new package, daemon, global install, analytics, telemetry, paid API, or cloud relay.

## 7. Reuse Scan

```text
reuse_decision: adapt
reason: Reuse codexU's RuntimeScope, UsageStore refresh patterns, native Liquid Glass cards, and Foundation.Process. Reference the Hermes Swift Mac SSH monitoring approach, but avoid a new SSH library or WebUI tunnel because this phase only needs bounded read-only probes.
checked_at: 2026-07-29
sources:
  - local codexU RuntimeScope, UsageStore, RuntimeViews, LocalSystemStatusStrip, self-test entry points
  - Apple Foundation Process executableURL/arguments documentation
  - hermes-webui/hermes-swift-mac SSH mode and connection-test pattern
  - apple/swift-nio and swift-nio-ssh considered but not adopted
```

- Local patterns: the app already builds all Swift files without a package manager, performs background refreshes, exposes deterministic CLI self-tests, and uses compact section/card components.
- Open-source candidates:
  - `hermes-webui/hermes-swift-mac` demonstrates a native Swift app using existing SSH key authentication, test-before-save, and connection-state UI;
  - SwiftNIO SSH and high-level Swift SSH clients are capable but add package, build, and maintenance weight that this fixed read-only probe does not need.
- License and maintenance notes: the referenced Hermes macOS project and candidate high-level SSH client are open source; no source is copied in this phase. Apple Foundation APIs and the system SSH binary avoid a bundled third-party dependency.
- MyAInet note: a bounded exact-name public search did not find a verifiable repository, so it remains product inspiration rather than an implementation dependency.
- Adaptation cost: low for `Foundation.Process`; high and unjustified for a new SSH stack.

## 8. Architecture And Work Units

### Domain

`AgentNodeDescriptor`

- stable node ID;
- display name and device label;
- `RuntimeScope`;
- location (`local` or `remote`);
- optional fixed `AgentNodeProbeProfile`;
- SSH host alias for a remote node;
- capability identifiers supplied by the known profile.

`AgentNodeSnapshot`

- descriptor;
- health state: `available`, `degraded`, `offline`, `unreachable`, or `stale`;
- checked time, optional last-seen time, optional heartbeat time;
- process count;
- source label;
- safe detail code, not raw remote output;
- `isFromCache`.

### Configuration

`AgentNodeConfigurationStore`

- reads optional schema `godexu-agent-nodes-v1`;
- validates IDs, runtime/profile compatibility, SSH aliases, duplicates, and node count;
- never accepts a remote command, executable path, credential, private-key path, or arbitrary health path;
- returns an empty remote list for a missing file.

### Probe

`AgentNodeProbeRunner`

- receives a descriptor and executes `/usr/bin/ssh` using argument arrays;
- profile code selects the complete fixed remote command;
- caps stdout/stderr and total duration;
- parses a small `key=value` protocol;
- classifies host-key, authentication, timeout, transport, protocol, and remote-process failures without exposing raw text.

`AgentNodeHealthEvaluator`

- process present and fresh heartbeat: `available`;
- process present with missing or old heartbeat: `degraded`;
- reachable host with no runtime process: `offline`;
- SSH or protocol failure with no usable cache: `unreachable`;
- failed live probe with a usable last-known snapshot: `stale`.

### Cache

`AgentNodeSnapshotCache`

- stores versioned normalized snapshots in the codexU cache directory;
- writes atomically;
- never stores probe output;
- uses the last-known state only when the live probe fails;
- preserves the original last-seen timestamp.

### Store and UI

`AgentNodeStore`

- synthesizes local Codex state from the current runtime snapshot;
- probes configured remote nodes off the main thread;
- publishes stable node ordering;
- refreshes on dashboard appearance and at a low-frequency foreground interval;
- stops remote polling when the dashboard disappears.

`AgentNodeStatusSection`

- reuses section/card tokens;
- shows one compact row per node;
- displays runtime logo, node/device name, health label, last-seen text, location, and capability count;
- uses both icon/text and status color;
- shows no raw path, prompt, reply, log, or command;
- if no remote node is configured, shows the local Codex node without an error banner.

### CLI and tests

- `--dump-agent-nodes` reads the same configuration and prints normalized JSON.
- `--self-test-agent-nodes` covers configuration, validation, parser, evaluator, cache fallback, and no-NAS behavior using fixtures and injected command results.

### Likely files

- Create `Sources/CodexUsageWidget/Domain/AgentNode.swift`.
- Create `Sources/CodexUsageWidget/Domain/AgentNodeSelfTest.swift`.
- Create `Sources/CodexUsageWidget/Services/AgentNodeConfigurationStore.swift`.
- Create `Sources/CodexUsageWidget/Services/AgentNodeProbe.swift`.
- Create `Sources/CodexUsageWidget/Services/AgentNodeSnapshotCache.swift`.
- Create `Sources/CodexUsageWidget/UI/AgentNodeViews.swift`.
- Modify `Sources/CodexUsageWidget/main.swift`.
- Modify `Makefile`.
- Add a non-secret example under `docs/examples/agent-nodes.example.json`.
- Add the implementation plan and run record under `docs/superpowers/`.

## 9. Checkpoints

- Checkpoint 1: domain, configuration, health evaluation, and cache pass RED/GREEN self-tests without network access.
- Checkpoint 2: fixed SSH probe produces normalized JSON from the real NAS OpenClaw and Hermes processes.
- Checkpoint 3: the existing main dashboard renders all three nodes and survives simulated NAS loss using the cache.
- Expansion gate: only after these checkpoints may task delivery, memory sync, GUI pairing, repair, status-item/Dynamic-Island node display, or publication be planned.

## 10. Risks And Fallbacks

- Risk: SSH blocks or prompts. Mitigation: `BatchMode=yes`, strict host-key checking, one attempt, hard timeout, background queue.
- Risk: a changed host key is silently trusted. Mitigation: `StrictHostKeyChecking=yes`; the UI reports that terminal confirmation is required.
- Risk: remote shell injection. Mitigation: configuration selects an enum profile only; all command text is compiled into the app; host alias validation and argument-array process launch are mandatory.
- Risk: process presence is mistaken for full Agent health. Mitigation: process and heartbeat are separate signals; missing/stale heartbeat is `degraded`, not healthy.
- Risk: a missing NAS makes the whole app look broken. Mitigation: local-only is a first-class state; remote failures do not affect Codex usage refresh.
- Risk: repeated SSH probes waste energy. Mitigation: separate foreground timer, no polling when the dashboard is hidden, no overlapping probes.
- Risk: remote output grows unexpectedly. Mitigation: hard output cap and protocol rejection.
- Fallback mode: show last-known normalized snapshot as `stale`, or `unreachable` with no cache.
- Rollback plan: remove the node section and local node configuration/cache; existing runtime, status bar, and Dynamic Island code remains untouched.

## 11. Acceptance Evidence

- Local run: built app launched from the isolated worktree and then installed only after backup.
- Test/check:
  - `--self-test-agent-nodes`;
  - all existing self-tests and parser fixtures;
  - `make build`;
  - `codesign --verify --deep --strict`;
  - `git diff --check`.
- Workflow proof:
  - real `--dump-agent-nodes` output for local Codex, NAS OpenClaw, and NAS Hermes;
  - live screenshot of the node section;
  - repeat with an unreachable test alias to prove cached degradation;
  - repeat with no node config to prove local-only behavior.
- Known unknowns: remote process and heartbeat metadata prove observation quality, not Agent semantic correctness, task readiness, memory freshness, or repairability.
- Handoff: record implementation, local verification, E2E acceptance, publication authorization, rollback, and remaining phases separately.

## 12. Implementation Handoff

- Recommended flow: `writing-plans` then inline `executing-plans` with TDD.
- First implementation step: add a failing self-test that describes configuration validation and health-state evaluation.
- What not to touch: NAS files/services, token accounting, task attribution, update channel, app version, Windows prototype, existing menu bar and Dynamic Island layouts.
- When to ask again: before any NAS write, credential or host-key change, package restart, task delivery, repair action, GitHub push, merge, version bump, or release.

## 13. macOS local-network privacy addendum

Real UI acceptance found a platform distinction that is not visible from a
Terminal-only test:

- macOS exempts Terminal-launched command-line tools from local-network
  privacy, but treats an SSH child launched by a GUI app as the app's network
  access;
- each remote node may therefore provide an optional, validated
  `networkHost` used only for a native TCP preflight to port 22;
- `networkHost`, the SSH alias, commands, stdout, stderr, paths, and credentials
  remain absent from public node snapshot JSON and visible cards;
- denied local-network access must render as a cached or unreachable state with
  a local `允许局域网 / Allow local network` explanation;
- `NSLocalNetworkUsageDescription` is required in the app bundle;
- a Developer ID or other Apple-issued signing identity is a release gate for
  reliable macOS local-network permission tracking. An ad-hoc build may remain
  correctly degraded even when the same probe succeeds from Terminal.

This addendum does not authorize a certificate change, notarization, NAS write,
or system-wide network exception.
