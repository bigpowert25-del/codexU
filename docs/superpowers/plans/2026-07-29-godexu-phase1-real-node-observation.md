# GodexU v2 Phase 1 Real Node Observation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve the existing CodexU dashboard, status bar, and Dynamic Island while adding honest local Codex plus real NAS OpenClaw/Hermes node observation through strict read-only SSH probes and a local stale-cache fallback.

**Architecture:** Add an Agent-node domain independent from token/task attribution. A validated local JSON file selects only compiled probe profiles; `/usr/bin/ssh` executes fixed metadata-only commands, a local cache preserves last-known snapshots, and a separate foreground store feeds a compact dashboard section plus a structured CLI dump.

**Tech Stack:** Swift, SwiftUI, Foundation `Process`, system `/usr/bin/ssh`, Codable JSON, existing Makefile/self-test conventions, no new dependency.

---

## Fixed File Map

- Create `Sources/CodexUsageWidget/Domain/AgentNode.swift`: node identity, health, probe observation, validation, and evaluation.
- Create `Sources/CodexUsageWidget/Domain/AgentNodeSelfTest.swift`: deterministic RED/GREEN coverage.
- Create `Sources/CodexUsageWidget/Services/AgentNodeConfigurationStore.swift`: optional local JSON configuration and strict DTO validation.
- Create `Sources/CodexUsageWidget/Services/AgentNodeProbe.swift`: injected command executor, fixed SSH profiles, bounded parser, and safe errors.
- Create `Sources/CodexUsageWidget/Services/AgentNodeSnapshotCache.swift`: versioned atomic normalized cache and reconciliation.
- Create `Sources/CodexUsageWidget/Services/AgentNodeReader.swift`: local Codex synthesis plus remote configuration/probe/cache orchestration.
- Create `Sources/CodexUsageWidget/UI/AgentNodeViews.swift`: foreground store and compact existing-style node section.
- Modify `Sources/CodexUsageWidget/main.swift`: dashboard wiring and CLI/self-test entry points only.
- Modify `Sources/CodexUsageWidget/Services/JSONDumpWriter.swift`: normalized node JSON output.
- Modify `Makefile`: `test-agent-nodes` target.
- Create `docs/examples/agent-nodes.example.json`: non-secret schema example.
- Create `docs/superpowers/runs/20260729-godexu-phase1-real-node-observation.md`: exact run evidence and authorization state.

Do not modify runtime token providers, task attribution, status-item rendering, Dynamic Island layout, update strategy, Windows prototype, version metadata, NAS files, or remote services.

### Task 1: Define node identity and health evaluation

**Files:**
- Create: `Sources/CodexUsageWidget/Domain/AgentNodeSelfTest.swift`
- Create: `Sources/CodexUsageWidget/Domain/AgentNode.swift`
- Modify: `Sources/CodexUsageWidget/main.swift`
- Modify: `Makefile`

- [ ] **Step 1: Write the failing domain self-test**

Create `AgentNodeSelfTest` with a first test that expects these public domain values:

```swift
import Foundation

enum AgentNodeSelfTest {
    static func run() -> Bool {
        var failures: [String] = []
        testHealthEvaluation(failures: &failures)

        if failures.isEmpty {
            print("agent node self-test passed")
            return true
        }
        failures.forEach { print("agent node self-test failed: \($0)") }
        return false
    }

    private static func testHealthEvaluation(failures: inout [String]) {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let descriptor = AgentNodeDescriptor(
            id: "nas-openclaw",
            displayName: "OpenClaw",
            deviceName: "NAS",
            runtime: .openClaw,
            location: .remote,
            sshHost: "spicy-nas-root0",
            probeProfile: .synologyTrimOpenClawV1
        )
        let fresh = AgentNodeProbeObservation(
            descriptor: descriptor,
            checkedAt: now,
            processCount: 1,
            heartbeatAt: now.addingTimeInterval(-60),
            sourceLabel: "SSH · NAS"
        )
        if AgentNodeHealthEvaluator.evaluate(fresh, now: now).health != .available {
            failures.append("fresh running node was not available")
        }
        let oldHeartbeat = AgentNodeProbeObservation(
            descriptor: descriptor,
            checkedAt: now,
            processCount: 1,
            heartbeatAt: now.addingTimeInterval(-3_600),
            sourceLabel: "SSH · NAS"
        )
        if AgentNodeHealthEvaluator.evaluate(oldHeartbeat, now: now).health != .degraded {
            failures.append("running node with stale heartbeat was not degraded")
        }
        let stopped = AgentNodeProbeObservation(
            descriptor: descriptor,
            checkedAt: now,
            processCount: 0,
            heartbeatAt: nil,
            sourceLabel: "SSH · NAS"
        )
        if AgentNodeHealthEvaluator.evaluate(stopped, now: now).health != .offline {
            failures.append("reachable stopped node was not offline")
        }
    }
}
```

Add only the `--self-test-agent-nodes` dispatch and `test-agent-nodes` target. Do not add production domain types yet.

- [ ] **Step 2: Run the test to verify RED**

Run:

```sh
make build
```

Expected: compile failure naming missing `AgentNodeDescriptor`, `AgentNodeProbeObservation`, and `AgentNodeHealthEvaluator`.

- [ ] **Step 3: Add the minimal domain implementation**

Implement:

```swift
enum AgentNodeLocation: String, Codable, Equatable {
    case local
    case remote
}

enum AgentNodeHealth: String, Codable, Equatable {
    case available
    case degraded
    case offline
    case unreachable
    case stale
}

enum AgentNodeProbeProfile: String, Codable, Equatable {
    case synologyTrimOpenClawV1 = "synology-trim-openclaw-v1"
    case synologyTrimHermesV1 = "synology-trim-hermes-v1"
}

struct AgentNodeDescriptor: Identifiable, Codable, Equatable {
    let id: String
    let displayName: String
    let deviceName: String
    let runtime: RuntimeScope
    let location: AgentNodeLocation
    let sshHost: String?
    let probeProfile: AgentNodeProbeProfile?

    var capabilities: [String] {
        switch runtime {
        case .codex: return ["coding", "local-usage", "task-observation"]
        case .openClaw: return ["orchestration", "memory", "task-routing"]
        case .hermes: return ["analysis", "review", "research"]
        case .claudeCode: return ["coding", "local-sessions"]
        }
    }
}

struct AgentNodeProbeObservation: Equatable {
    let descriptor: AgentNodeDescriptor
    let checkedAt: Date
    let processCount: Int
    let heartbeatAt: Date?
    let sourceLabel: String
}

struct AgentNodeSnapshot: Identifiable, Codable, Equatable {
    let descriptor: AgentNodeDescriptor
    let health: AgentNodeHealth
    let checkedAt: Date
    let lastSeenAt: Date?
    let heartbeatAt: Date?
    let processCount: Int?
    let sourceLabel: String
    let detailCode: String
    let isFromCache: Bool

    var id: String { descriptor.id }
}

enum AgentNodeHealthEvaluator {
    static let freshHeartbeatInterval: TimeInterval = 15 * 60

    static func evaluate(
        _ observation: AgentNodeProbeObservation,
        now: Date
    ) -> AgentNodeSnapshot {
        guard observation.processCount > 0 else {
            return AgentNodeSnapshot(
                descriptor: observation.descriptor,
                health: .offline,
                checkedAt: observation.checkedAt,
                lastSeenAt: nil,
                heartbeatAt: observation.heartbeatAt,
                processCount: observation.processCount,
                sourceLabel: observation.sourceLabel,
                detailCode: "process-not-running",
                isFromCache: false
            )
        }
        let heartbeatIsFresh = observation.heartbeatAt.map {
            max(0, now.timeIntervalSince($0)) <= freshHeartbeatInterval
        } ?? false
        return AgentNodeSnapshot(
            descriptor: observation.descriptor,
            health: heartbeatIsFresh ? .available : .degraded,
            checkedAt: observation.checkedAt,
            lastSeenAt: observation.checkedAt,
            heartbeatAt: observation.heartbeatAt,
            processCount: observation.processCount,
            sourceLabel: observation.sourceLabel,
            detailCode: heartbeatIsFresh ? "process-and-heartbeat" : "process-without-fresh-heartbeat",
            isFromCache: false
        )
    }
}
```

Use explicit memberwise initialization for the local Codex descriptor; do not add mutable state or network behavior.

- [ ] **Step 4: Verify GREEN**

Run:

```sh
make test-agent-nodes
```

Expected: `agent node self-test passed`.

- [ ] **Step 5: Commit Task 1**

Deterministically compare the complete changed path set with the four-file Task 1 allowlist, then commit:

```sh
git add -- Makefile Sources/CodexUsageWidget/main.swift Sources/CodexUsageWidget/Domain/AgentNode.swift Sources/CodexUsageWidget/Domain/AgentNodeSelfTest.swift
git commit -m "feat: define agent node health model"
```

### Task 2: Add strict configuration and local cache

**Files:**
- Modify: `Sources/CodexUsageWidget/Domain/AgentNodeSelfTest.swift`
- Create: `Sources/CodexUsageWidget/Services/AgentNodeConfigurationStore.swift`
- Create: `Sources/CodexUsageWidget/Services/AgentNodeSnapshotCache.swift`
- Create: `docs/examples/agent-nodes.example.json`

- [ ] **Step 1: Add failing configuration and cache tests**

Extend `AgentNodeSelfTest.run()` with `testConfiguration` and `testCacheFallback`.

The configuration fixture must prove:

```swift
let json = """
{
  "schema": "godexu-agent-nodes-v1",
  "nodes": [
    {
      "id": "nas-openclaw",
      "displayName": "OpenClaw",
      "deviceName": "NAS",
      "runtime": "openclaw",
      "sshHost": "spicy-nas-root0",
      "probeProfile": "synology-trim-openclaw-v1"
    },
    {
      "id": "nas-hermes",
      "displayName": "Hermes",
      "deviceName": "NAS",
      "runtime": "hermes",
      "sshHost": "spicy-nas-root0",
      "probeProfile": "synology-trim-hermes-v1"
    }
  ]
}
"""
let descriptors = try AgentNodeConfigurationStore.decode(Data(json.utf8))
```

Assertions:

- both descriptors decode in source order;
- runtime identifiers use `RuntimeScope.storedIdentifier`;
- missing file returns an empty list;
- duplicate IDs fail;
- `sshHost` containing whitespace, slash, semicolon, dollar sign, or backtick fails;
- OpenClaw cannot select the Hermes probe profile;
- configuration has no command, path, key, password, or environment fields.

The cache test must write one normalized snapshot to a temporary URL, read it back, and verify `AgentNodeSnapshotCache.staleSnapshot`:

- returns `.stale`;
- preserves original `lastSeenAt`;
- sets `isFromCache=true`;
- never promotes cached data to `.available`.

- [ ] **Step 2: Run RED**

Run:

```sh
make test-agent-nodes
```

Expected: compile failure for missing configuration/cache types.

- [ ] **Step 3: Implement strict configuration**

Use a private Codable DTO:

```swift
private struct AgentNodeConfigurationDocument: Decodable {
    let schema: String
    let nodes: [AgentNodeConfigurationDTO]
}

private struct AgentNodeConfigurationDTO: Decodable {
    let id: String
    let displayName: String
    let deviceName: String
    let runtime: String
    let sshHost: String
    let probeProfile: String
}
```

`AgentNodeConfigurationStore` must:

- use `CODEXU_AGENT_NODES_CONFIG` only as a local test/acceptance path override;
- otherwise use `~/Library/Application Support/codexU/nodes.json`;
- return `[]` if the file is absent;
- reject any schema other than `godexu-agent-nodes-v1`;
- cap nodes at 16;
- validate IDs and SSH aliases with `^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$`;
- require `.openClaw` ↔ `.synologyTrimOpenClawV1` and `.hermes` ↔ `.synologyTrimHermesV1`;
- construct only remote descriptors.

- [ ] **Step 4: Implement normalized cache**

Use:

```swift
private struct AgentNodeSnapshotCacheDocument: Codable {
    let version: Int
    let snapshots: [AgentNodeSnapshot]
}
```

Requirements:

- version is `1`;
- cache URL is injectable for tests and defaults to `<RuntimeLoadContext.cacheDirectory>/agent-node-snapshots.json`;
- writes use `.atomic`;
- load failure returns `[]` rather than deleting or rewriting the file;
- stale fallback uses only the same node ID and a cache age no greater than 24 hours;
- stale output source label appends ` · cached` once;
- raw command output and errors have no cache field.

- [ ] **Step 5: Add the non-secret example**

Create exactly:

```json
{
  "schema": "godexu-agent-nodes-v1",
  "nodes": [
    {
      "id": "nas-openclaw",
      "displayName": "OpenClaw",
      "deviceName": "NAS",
      "runtime": "openclaw",
      "sshHost": "my-nas-readonly",
      "probeProfile": "synology-trim-openclaw-v1"
    },
    {
      "id": "nas-hermes",
      "displayName": "Hermes",
      "deviceName": "NAS",
      "runtime": "hermes",
      "sshHost": "my-nas-readonly",
      "probeProfile": "synology-trim-hermes-v1"
    }
  ]
}
```

- [ ] **Step 6: Verify GREEN and commit**

Run:

```sh
make test-agent-nodes
git diff --check
```

Expected: test passes and diff check prints nothing.

After deterministic four-file allowlist validation:

```sh
git add -- Sources/CodexUsageWidget/Domain/AgentNodeSelfTest.swift Sources/CodexUsageWidget/Services/AgentNodeConfigurationStore.swift Sources/CodexUsageWidget/Services/AgentNodeSnapshotCache.swift docs/examples/agent-nodes.example.json
git commit -m "feat: load and cache agent node metadata"
```

### Task 3: Add the bounded SSH probe

**Files:**
- Modify: `Sources/CodexUsageWidget/Domain/AgentNodeSelfTest.swift`
- Create: `Sources/CodexUsageWidget/Services/AgentNodeProbe.swift`

- [ ] **Step 1: Add failing parser and command tests**

Add an injected executor:

```swift
protocol AgentNodeCommandExecuting {
    func run(
        executableURL: URL,
        arguments: [String],
        timeout: TimeInterval
    ) -> AgentNodeCommandResult
}

struct AgentNodeCommandResult: Equatable {
    let exitCode: Int32
    let standardOutput: Data
    let standardError: Data
    let timedOut: Bool
}
```

Tests must assert:

- executable is exactly `/usr/bin/ssh`;
- arguments contain `BatchMode=yes`, `StrictHostKeyChecking=yes`, `ConnectionAttempts=1`, `ConnectTimeout=4`, and the validated alias as one argument;
- arguments never contain `accept-new`, `StrictHostKeyChecking=no`, a key path, a password, or a config-provided command;
- OpenClaw and Hermes profiles choose different compiled commands;
- valid output parses:

```text
schema=godexu-node-probe-v1
host=Ginger
process_count=1
heartbeat_epoch=2000000
observed_epoch=2000060
```

- unknown schema, duplicate keys, non-integer counts, negative counts, oversized output, and unexpected keys fail as protocol errors;
- a timeout becomes `.timeout`;
- authentication/host-key/transport errors become safe categories and do not echo stderr.

- [ ] **Step 2: Run RED**

Run:

```sh
make test-agent-nodes
```

Expected: compile failure for missing probe/executor types.

- [ ] **Step 3: Implement fixed probe profiles**

The only remote command strings are compiled constants:

```swift
case .synologyTrimOpenClawV1:
    return """
    LC_ALL=C; count=$(ps -eo comm= 2>/dev/null | awk '$1=="openclaw"{n++} END{print n+0}'); heartbeat=$(stat -c %Y /vol1/1000/openclaw/tongbu/health/openclaw.json 2>/dev/null || echo 0); now=$(date +%s); printf 'schema=godexu-node-probe-v1\\nhost=%s\\nprocess_count=%s\\nheartbeat_epoch=%s\\nobserved_epoch=%s\\n' "$(hostname)" "$count" "$heartbeat" "$now"
    """
case .synologyTrimHermesV1:
    return """
    LC_ALL=C; count=$(ps -eo comm= 2>/dev/null | awk '$1=="hermes"{n++} END{print n+0}'); heartbeat=$(stat -c %Y /vol1/@appdata/trim.hermes/trim.hermes.log 2>/dev/null || echo 0); now=$(date +%s); printf 'schema=godexu-node-probe-v1\\nhost=%s\\nprocess_count=%s\\nheartbeat_epoch=%s\\nobserved_epoch=%s\\n' "$(hostname)" "$count" "$heartbeat" "$now"
    """
```

The configuration cannot override any part of these strings.

- [ ] **Step 4: Implement bounded process execution and parsing**

Requirements:

- launch with `Process.executableURL` and an argument array;
- use pipes only for stdout/stderr;
- wait on a private semaphore up to six seconds, terminate on timeout, and never block the main thread;
- cap accepted stdout and stderr at 32 KiB;
- parse UTF-8 only;
- allow exactly the five keys above;
- require schema and host, nonnegative count, positive observed epoch;
- treat heartbeat `0` as absent;
- return `AgentNodeProbeObservation` using remote observed time for `checkedAt`;
- UI-safe error enum has only `timeout`, `authentication`, `hostKey`, `transport`, and `protocolError`.

- [ ] **Step 5: Verify GREEN and commit**

Run:

```sh
make test-agent-nodes
git diff --check
```

After deterministic two-file allowlist validation:

```sh
git add -- Sources/CodexUsageWidget/Domain/AgentNodeSelfTest.swift Sources/CodexUsageWidget/Services/AgentNodeProbe.swift
git commit -m "feat: probe remote agent nodes safely"
```

### Task 4: Orchestrate local Codex, remote probes, cache, and CLI

**Files:**
- Modify: `Sources/CodexUsageWidget/Domain/AgentNodeSelfTest.swift`
- Create: `Sources/CodexUsageWidget/Services/AgentNodeReader.swift`
- Modify: `Sources/CodexUsageWidget/Services/JSONDumpWriter.swift`
- Modify: `Sources/CodexUsageWidget/main.swift`

- [ ] **Step 1: Add failing reader tests**

Use fake configuration, probe, and cache inputs to verify:

- local Codex is always first;
- no remote configuration returns only local Codex and no error;
- live remote success replaces old cache;
- live remote failure returns matching cache as `.stale`;
- live remote failure with no cache returns `.unreachable`;
- remote nodes preserve configuration order;
- one failing node does not remove successful nodes;
- local Codex runtime status maps:
  - `.available` and `.localOnly` → `.available`;
  - `.stale` → `.stale`;
  - `.unavailable` → `.unreachable`.

- [ ] **Step 2: Run RED**

Run:

```sh
make test-agent-nodes
```

Expected: compile failure for missing `AgentNodeReader`.

- [ ] **Step 3: Implement the reader**

Create injectable protocols for configuration loading, probing, and cache storage. `AgentNodeReader.load(codexRuntime:now:)` must:

1. synthesize `local-codex` with device name from `Host.current().localizedName ?? "Mac"`;
2. load optional remote descriptors;
3. probe each descriptor without concurrent duplicate work;
4. evaluate live observations;
5. reconcile failures with cache;
6. save only live local/remote normalized results;
7. return stable local-first/config-order output.

The reader does not load token providers, transcripts, task boards, or remote databases.

- [ ] **Step 4: Add structured JSON**

Add:

```swift
func dumpAgentNodesJSON(_ snapshots: [AgentNodeSnapshot])
```

Output:

```json
{
  "schema": "godexu-agent-node-snapshots-v1",
  "generatedAt": "ISO-8601",
  "nodes": [
    {
      "id": "nas-openclaw",
      "runtime": "openclaw",
      "displayName": "OpenClaw",
      "deviceName": "NAS",
      "location": "remote",
      "health": "degraded",
      "checkedAt": "ISO-8601",
      "lastSeenAt": "ISO-8601 or null",
      "heartbeatAt": "ISO-8601 or null",
      "processCount": 1,
      "sourceLabel": "SSH · NAS",
      "detailCode": "process-without-fresh-heartbeat",
      "isFromCache": false,
      "capabilities": ["orchestration", "memory", "task-routing"]
    }
  ]
}
```

Do not include SSH host, remote path, command, stdout, stderr, environment, or credentials.

- [ ] **Step 5: Add the CLI entry point**

Before launching `NSApplication`, handle:

```swift
if CommandLine.arguments.contains("--dump-agent-nodes") {
    let runtimes = MultiRuntimeUsageReader().load(scopes: [.codex])
    let nodes = AgentNodeReader().load(
        codexRuntime: runtimes.runtime(for: .codex),
        now: Date()
    )
    dumpAgentNodesJSON(nodes)
    return
}
```

- [ ] **Step 6: Verify GREEN and commit**

Run:

```sh
make test-agent-nodes
CODEXU_AGENT_NODES_CONFIG=/tmp/nonexistent-godexu-nodes.json build/codexU.app/Contents/MacOS/codexU --dump-agent-nodes | python3 -m json.tool >/dev/null
git diff --check
```

Expected: self-test passes; the no-NAS dump is valid JSON with exactly `local-codex`.

After deterministic four-file allowlist validation:

```sh
git add -- Sources/CodexUsageWidget/Domain/AgentNodeSelfTest.swift Sources/CodexUsageWidget/Services/AgentNodeReader.swift Sources/CodexUsageWidget/Services/JSONDumpWriter.swift Sources/CodexUsageWidget/main.swift
git commit -m "feat: aggregate agent node snapshots"
```

### Task 5: Add the node section without changing existing surfaces

**Files:**
- Modify: `Sources/CodexUsageWidget/Domain/AgentNodeSelfTest.swift`
- Create: `Sources/CodexUsageWidget/UI/AgentNodeViews.swift`
- Modify: `Sources/CodexUsageWidget/main.swift`

- [ ] **Step 1: Add failing presentation tests**

Define a small pure `AgentNodePresentation` builder and test:

- local Codex, NAS OpenClaw, NAS Hermes preserve order;
- every health state has a localized label and SF Symbol;
- color is not the only status channel;
- cached snapshots include a cached marker;
- node subtitles never contain SSH aliases, full paths, commands, stdout, or stderr;
- capability count is visible but capability internals stay in help/accessibility text.

- [ ] **Step 2: Run RED**

Run:

```sh
make test-agent-nodes
```

Expected: compile failure for missing presentation builder.

- [ ] **Step 3: Implement `AgentNodeStore`**

`@MainActor final class AgentNodeStore: ObservableObject` must:

- publish `[AgentNodeSnapshot]`;
- accept `() -> RuntimeUsageSnapshot?` for current local Codex state;
- refresh on start using a utility queue;
- use one non-overlapping refresh at a time;
- refresh at 120 seconds with 20% timer tolerance while the dashboard is visible;
- stop and invalidate the timer on dashboard disappearance;
- update the local Codex row when the runtime snapshot changes;
- never hold or expose raw probe output.

- [ ] **Step 4: Implement the compact section**

`AgentNodeStatusSection` must:

- use the existing `.sectionBackground()` and `RuntimeLogoView`;
- title the section `Agent 节点 / Agent nodes`;
- show up to four equal-width rows/tiles without nested card-on-card styling;
- show display name, device name, location, health label, relative last seen, and capability count;
- use `checkmark.circle.fill`, `exclamationmark.triangle.fill`, `stop.circle.fill`, `wifi.slash`, or `clock.arrow.circlepath` as status channels;
- use the existing `WidgetPalette` status colors;
- truncate long names and avoid layout jumps;
- remain readable in light, dark, and increased-contrast modes.

- [ ] **Step 5: Wire only the main dashboard**

In `UsageWidgetView`:

- add `@StateObject private var nodeStore = AgentNodeStore()`;
- insert `AgentNodeStatusSection` immediately after `LocalSystemStatusStrip`;
- start/stop it in the existing appearance lifecycle;
- update local Codex state on `store.runtimeSnapshots` changes.

Do not modify `RuntimeStatusMenuView`, status-item renderer/preferences, or Dynamic Island files in this task.

- [ ] **Step 6: Verify GREEN and commit**

Run:

```sh
make test-agent-nodes
make build
git diff --check
```

After deterministic three-file allowlist validation:

```sh
git add -- Sources/CodexUsageWidget/Domain/AgentNodeSelfTest.swift Sources/CodexUsageWidget/UI/AgentNodeViews.swift Sources/CodexUsageWidget/main.swift
git commit -m "feat: show agent nodes in existing dashboard"
```

### Task 6: Real NAS acceptance, offline fallback, installation, and record

**Files:**
- Create: `docs/superpowers/runs/20260729-godexu-phase1-real-node-observation.md`
- Local-only, not committed: `~/Library/Application Support/codexU/nodes.json`

- [ ] **Step 1: Run a clean baseline-to-candidate verification**

Run:

```sh
make build
app=build/codexU.app/Contents/MacOS/codexU
for flag in global-shortcut status-item particle-animation display-surface rate-limits updates statistics-time-zone task-navigation local-system agent-selection agent-nodes codex-token-events dynamic-island; do
  "$app" "--self-test-$flag"
done
CODEXU_SKIP_BUILD=1 ./scripts/test-parsers.sh
codesign --verify --deep --strict build/codexU.app
git diff --check
```

Expected: 13 built-in self-test entry points plus parser fixtures pass with zero failures.

- [ ] **Step 2: Install the local real-node configuration**

Create the Application Support directory if absent and install a local configuration using:

- `sshHost`: `spicy-nas-root0`;
- the OpenClaw and Hermes descriptors from the example;
- no password, key path, command, remote path, token, or environment value.

Validate with `python3 -m json.tool`. This is local user state and must not be staged or committed.

- [ ] **Step 3: Run the real structured probe**

Run:

```sh
build/codexU.app/Contents/MacOS/codexU --dump-agent-nodes
```

Acceptance:

- exactly three node IDs: `local-codex`, `nas-openclaw`, `nas-hermes`;
- both remote nodes report `processCount >= 1`;
- both remote node records contain only normalized fields;
- OpenClaw and Hermes may correctly report `degraded` when heartbeat/log freshness is insufficient;
- no node is described as fully healthy from process presence alone.

- [ ] **Step 4: Prove cache degradation**

Copy the local configuration to a temporary acceptance file, replace only the SSH alias with a valid-format nonexistent alias, and run with `CODEXU_AGENT_NODES_CONFIG` pointing to it.

Acceptance:

- local Codex remains live;
- matching remote nodes are `.stale` and `isFromCache=true`;
- last-seen timestamps are preserved;
- command returns within the bounded timeout;
- no password prompt or host-key acceptance occurs.

Delete the temporary acceptance file after the result is recorded.

- [ ] **Step 5: Prove no-NAS behavior**

Run with `CODEXU_AGENT_NODES_CONFIG` pointing to an absent file.

Acceptance:

- output contains only `local-codex`;
- exit code is zero;
- no environment-check error is added to the existing usage UI.

- [ ] **Step 6: Perform visual acceptance**

Launch the built app, capture light/dark screenshots, and verify:

- existing quota/usage cards are unchanged;
- Local System strip remains aligned;
- Agent nodes section shows local Codex, NAS OpenClaw, and NAS Hermes;
- long names truncate;
- health has icon plus text;
- the node section does not show SSH alias, path, logs, messages, or credentials;
- existing status bar and Dynamic Island still open and render.

- [ ] **Step 7: Back up and install locally**

After visual acceptance:

1. quit the installed app;
2. copy `/Applications/codexU.app` to a timestamped backup;
3. replace it with `build/codexU.app`;
4. verify build/installed executable hashes match;
5. launch `/Applications/codexU.app`;
6. repeat the real-node dashboard smoke check.

Do not bump version or create release assets.

- [ ] **Step 8: Write the run record**

Record:

- run ID and time;
- baseline SHA and candidate SHA;
- exact allowlist and excluded paths;
- design and execution approvals;
- real SSH target label without credentials;
- live, cache-fallback, no-NAS, build, test, signature, and visual evidence;
- installed-app backup path and hash comparison;
- implementation/local verification/E2E/release/rollback statuses;
- `release_status: not_authorized`;
- remaining task-delivery, memory, permission, repair, Windows, status-item/Dynamic-Island-node, and publication phases.

- [ ] **Step 9: Final code review and clean-tree check**

Re-read the design, inspect the complete diff/commit series, and verify:

```sh
git status --short
git diff --check
git log --oneline --decorate -8
```

Do not push. A GitHub push requires a new authorization for this changed diff.
