import Foundation

enum AgentNodeSelfTest {
    static func run() -> Bool {
        var failures: [String] = []
        testHealthEvaluation(failures: &failures)
        testConfiguration(failures: &failures)
        testCacheFallback(failures: &failures)
        testSSHProbe(failures: &failures)
        testSSHProbeFailures(failures: &failures)
        testNodeReader(failures: &failures)
        testLocalCodexStateMapping(failures: &failures)
        testNodeJSON(failures: &failures)

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

    private static func testConfiguration(failures: inout [String]) {
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

        do {
            let descriptors = try AgentNodeConfigurationStore.decode(Data(json.utf8))
            if descriptors.map(\.id) != ["nas-openclaw", "nas-hermes"] {
                failures.append("configuration did not preserve node order")
            }
            if descriptors.map(\.runtime) != [.openClaw, .hermes] {
                failures.append("configuration did not map stored runtime identifiers")
            }
        } catch {
            failures.append("valid configuration failed to decode")
        }

        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("codexu-agent-node-missing-\(UUID().uuidString).json")
        do {
            let missing = try AgentNodeConfigurationStore(configurationURL: missingURL).load()
            if !missing.isEmpty {
                failures.append("missing configuration did not produce local-only state")
            }
        } catch {
            failures.append("missing configuration threw an error")
        }

        let invalidAliases = [
            "bad host",
            "bad/host",
            "bad;host",
            "bad$host",
            "bad`host"
        ]
        for alias in invalidAliases {
            let invalid = json.replacingOccurrences(of: "spicy-nas-root0", with: alias)
            if (try? AgentNodeConfigurationStore.decode(Data(invalid.utf8))) != nil {
                failures.append("unsafe SSH alias was accepted: \(alias)")
            }
        }

        let duplicate = json.replacingOccurrences(of: "\"nas-hermes\"", with: "\"nas-openclaw\"")
        if (try? AgentNodeConfigurationStore.decode(Data(duplicate.utf8))) != nil {
            failures.append("duplicate node IDs were accepted")
        }

        let mismatchedProfile = json.replacingOccurrences(
            of: "\"synology-trim-openclaw-v1\"",
            with: "\"synology-trim-hermes-v1\""
        )
        if (try? AgentNodeConfigurationStore.decode(Data(mismatchedProfile.utf8))) != nil {
            failures.append("runtime and probe profile mismatch was accepted")
        }

        let commandField = json.replacingOccurrences(
            of: "\"sshHost\": \"spicy-nas-root0\",",
            with: "\"sshHost\": \"spicy-nas-root0\", \"command\": \"cat /etc/passwd\","
        )
        if (try? AgentNodeConfigurationStore.decode(Data(commandField.utf8))) != nil {
            failures.append("configuration accepted an arbitrary command field")
        }
    }

    private static func testCacheFallback(failures: inout [String]) {
        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("codexu-agent-node-cache-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: cacheURL) }

        let descriptor = AgentNodeDescriptor(
            id: "nas-hermes",
            displayName: "Hermes",
            deviceName: "NAS",
            runtime: .hermes,
            location: .remote,
            sshHost: "spicy-nas-root0",
            probeProfile: .synologyTrimHermesV1
        )
        let checkedAt = Date(timeIntervalSince1970: 2_000_000)
        let live = AgentNodeSnapshot(
            descriptor: descriptor,
            health: .available,
            checkedAt: checkedAt,
            lastSeenAt: checkedAt,
            heartbeatAt: checkedAt.addingTimeInterval(-20),
            processCount: 1,
            sourceLabel: "SSH · NAS",
            detailCode: "process-and-heartbeat",
            isFromCache: false
        )
        let cache = AgentNodeSnapshotCache(cacheURL: cacheURL)

        do {
            try cache.save([live])
            let loaded = cache.load()
            if loaded != [live] {
                failures.append("normalized node cache did not round trip")
            }
            let stale = cache.staleSnapshot(
                for: descriptor,
                from: loaded,
                now: checkedAt.addingTimeInterval(30 * 60)
            )
            if stale?.health != .stale
                || stale?.lastSeenAt != checkedAt
                || stale?.isFromCache != true
                || stale?.sourceLabel != "SSH · NAS · cached" {
                failures.append("cache fallback did not preserve and label last-known state")
            }
        } catch {
            failures.append("node cache save failed")
        }
    }

    private static func testSSHProbe(failures: inout [String]) {
        let output = """
        schema=godexu-node-probe-v1
        host=Ginger
        process_count=1
        heartbeat_epoch=2000000
        observed_epoch=2000060

        """
        let executor = RecordingAgentNodeCommandExecutor(
            result: AgentNodeCommandResult(
                exitCode: 0,
                standardOutput: Data(output.utf8),
                standardError: Data(),
                timedOut: false
            )
        )
        let descriptor = AgentNodeDescriptor(
            id: "nas-openclaw",
            displayName: "OpenClaw",
            deviceName: "NAS",
            runtime: .openClaw,
            location: .remote,
            sshHost: "spicy-nas-root0",
            probeProfile: .synologyTrimOpenClawV1
        )
        let probe = AgentNodeProbe(executor: executor)
        let observation: AgentNodeProbeObservation
        switch probe.probe(descriptor) {
        case let .success(value):
            observation = value
        case .failure:
            failures.append("valid SSH probe output failed")
            return
        }

        if executor.executableURL?.path != "/usr/bin/ssh" {
            failures.append("probe did not use the system SSH executable")
        }
        let arguments = executor.arguments
        let required = [
            "BatchMode=yes",
            "StrictHostKeyChecking=yes",
            "ConnectionAttempts=1",
            "ConnectTimeout=4",
            "spicy-nas-root0"
        ]
        for value in required where !arguments.contains(where: { $0.contains(value) }) {
            failures.append("SSH arguments omitted \(value)")
        }
        let joinedArguments = arguments.joined(separator: " ")
        let forbidden = [
            "accept-new",
            "StrictHostKeyChecking=no",
            "IdentityFile",
            "password",
            "cat /etc/passwd"
        ]
        for value in forbidden where joinedArguments.localizedCaseInsensitiveContains(value) {
            failures.append("SSH arguments contained forbidden value \(value)")
        }
        if observation.processCount != 1
            || observation.checkedAt != Date(timeIntervalSince1970: 2_000_060)
            || observation.heartbeatAt != Date(timeIntervalSince1970: 2_000_000)
            || observation.sourceLabel != "SSH · Ginger" {
            failures.append("valid SSH probe output was normalized incorrectly")
        }

        let hermesExecutor = RecordingAgentNodeCommandExecutor(result: executor.result)
        let hermes = AgentNodeDescriptor(
            id: "nas-hermes",
            displayName: "Hermes",
            deviceName: "NAS",
            runtime: .hermes,
            location: .remote,
            sshHost: "spicy-nas-root0",
            probeProfile: .synologyTrimHermesV1
        )
        _ = AgentNodeProbe(executor: hermesExecutor).probe(hermes)
        if executor.arguments.last == hermesExecutor.arguments.last {
            failures.append("OpenClaw and Hermes used the same compiled probe command")
        }
    }

    private static func testSSHProbeFailures(failures: inout [String]) {
        let descriptor = AgentNodeDescriptor(
            id: "nas-openclaw",
            displayName: "OpenClaw",
            deviceName: "NAS",
            runtime: .openClaw,
            location: .remote,
            sshHost: "spicy-nas-root0",
            probeProfile: .synologyTrimOpenClawV1
        )
        let invalidOutputs = [
            """
            schema=unknown
            host=Ginger
            process_count=1
            heartbeat_epoch=0
            observed_epoch=2000060
            """,
            """
            schema=godexu-node-probe-v1
            host=Ginger
            host=Other
            process_count=1
            heartbeat_epoch=0
            observed_epoch=2000060
            """,
            """
            schema=godexu-node-probe-v1
            host=Ginger
            process_count=-1
            heartbeat_epoch=0
            observed_epoch=2000060
            """,
            """
            schema=godexu-node-probe-v1
            host=Ginger
            process_count=1
            heartbeat_epoch=0
            observed_epoch=2000060
            secret=unexpected
            """
        ]
        for output in invalidOutputs {
            let result = AgentNodeCommandResult(
                exitCode: 0,
                standardOutput: Data(output.utf8),
                standardError: Data(),
                timedOut: false
            )
            let probe = AgentNodeProbe(
                executor: RecordingAgentNodeCommandExecutor(result: result)
            )
            if probe.probe(descriptor) != .failure(.protocolError) {
                failures.append("invalid SSH protocol output was accepted")
            }
        }

        let oversized = AgentNodeCommandResult(
            exitCode: 0,
            standardOutput: Data(repeating: 65, count: 32 * 1_024 + 1),
            standardError: Data(),
            timedOut: false
        )
        if AgentNodeProbe(executor: RecordingAgentNodeCommandExecutor(result: oversized))
            .probe(descriptor) != .failure(.protocolError) {
            failures.append("oversized SSH output was accepted")
        }

        let failuresByResult: [(AgentNodeCommandResult, AgentNodeProbeError)] = [
            (
                AgentNodeCommandResult(
                    exitCode: 255,
                    standardOutput: Data(),
                    standardError: Data(),
                    timedOut: true
                ),
                .timeout
            ),
            (
                AgentNodeCommandResult(
                    exitCode: 255,
                    standardOutput: Data(),
                    standardError: Data("Permission denied (publickey)".utf8),
                    timedOut: false
                ),
                .authentication
            ),
            (
                AgentNodeCommandResult(
                    exitCode: 255,
                    standardOutput: Data(),
                    standardError: Data("Host key verification failed".utf8),
                    timedOut: false
                ),
                .hostKey
            ),
            (
                AgentNodeCommandResult(
                    exitCode: 255,
                    standardOutput: Data(),
                    standardError: Data("connection closed".utf8),
                    timedOut: false
                ),
                .transport
            )
        ]
        for (result, expected) in failuresByResult {
            let probe = AgentNodeProbe(
                executor: RecordingAgentNodeCommandExecutor(result: result)
            )
            if probe.probe(descriptor) != .failure(expected) {
                failures.append("SSH failure was not reduced to \(expected)")
            }
        }
    }

    private static func testNodeReader(failures: inout [String]) {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let openClaw = AgentNodeDescriptor(
            id: "nas-openclaw",
            displayName: "OpenClaw",
            deviceName: "NAS",
            runtime: .openClaw,
            location: .remote,
            sshHost: "spicy-nas-root0",
            probeProfile: .synologyTrimOpenClawV1
        )
        let hermes = AgentNodeDescriptor(
            id: "nas-hermes",
            displayName: "Hermes",
            deviceName: "NAS",
            runtime: .hermes,
            location: .remote,
            sshHost: "spicy-nas-root0",
            probeProfile: .synologyTrimHermesV1
        )
        let cachedHermes = AgentNodeSnapshot(
            descriptor: hermes,
            health: .degraded,
            checkedAt: now.addingTimeInterval(-600),
            lastSeenAt: now.addingTimeInterval(-600),
            heartbeatAt: now.addingTimeInterval(-3_600),
            processCount: 1,
            sourceLabel: "SSH · Ginger",
            detailCode: "process-without-fresh-heartbeat",
            isFromCache: false
        )
        let cache = InMemoryAgentNodeSnapshotCache(snapshots: [cachedHermes])
        let probe = StubAgentNodeProbe(results: [
            openClaw.id: .success(
                AgentNodeProbeObservation(
                    descriptor: openClaw,
                    checkedAt: now,
                    processCount: 1,
                    heartbeatAt: now.addingTimeInterval(-60),
                    sourceLabel: "SSH · Ginger"
                )
            ),
            hermes.id: .failure(.transport)
        ])
        let reader = AgentNodeReader(
            configurationStore: StubAgentNodeConfigurationStore(descriptors: [openClaw, hermes]),
            probe: probe,
            cache: cache,
            localDeviceName: { "Mac Studio" }
        )
        let codex = RuntimeUsageSnapshot(
            scope: .codex,
            snapshot: .empty,
            status: .available,
            quotaSourceLabel: "test",
            usageSourceLabel: "test"
        )
        let snapshots = reader.load(codexRuntime: codex, now: now)
        if snapshots.map(\.id) != ["local-codex", "nas-openclaw", "nas-hermes"] {
            failures.append("node reader did not preserve local-first configuration order")
        }
        if snapshots.map(\.health) != [.available, .available, .stale] {
            failures.append("node reader did not isolate live and cached outcomes")
        }
        if snapshots.last?.isFromCache != true
            || snapshots.last?.lastSeenAt != cachedHermes.lastSeenAt {
            failures.append("node reader did not preserve cached last-seen state")
        }
        if cache.savedSnapshots.first?.id != "local-codex"
            || !cache.savedSnapshots.contains(where: { $0.id == "nas-openclaw" })
            || !cache.savedSnapshots.contains(where: { $0.id == "nas-hermes" && !$0.isFromCache }) {
            failures.append("node reader cache merge discarded live or last-known nodes")
        }

        let noConfiguration = AgentNodeReader(
            configurationStore: StubAgentNodeConfigurationStore(descriptors: []),
            probe: StubAgentNodeProbe(results: [:]),
            cache: InMemoryAgentNodeSnapshotCache(snapshots: []),
            localDeviceName: { "Mac" }
        ).load(codexRuntime: codex, now: now)
        if noConfiguration.map(\.id) != ["local-codex"] {
            failures.append("no-NAS configuration was not a local-only state")
        }

        let noCache = AgentNodeReader(
            configurationStore: StubAgentNodeConfigurationStore(descriptors: [openClaw]),
            probe: StubAgentNodeProbe(results: [openClaw.id: .failure(.timeout)]),
            cache: InMemoryAgentNodeSnapshotCache(snapshots: []),
            localDeviceName: { "Mac" }
        ).load(codexRuntime: codex, now: now)
        if noCache.last?.health != .unreachable
            || noCache.last?.detailCode != "probe-timeout" {
            failures.append("failed live probe without cache was not unreachable")
        }
    }

    private static func testLocalCodexStateMapping(failures: inout [String]) {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let expected: [(RuntimeMenuStatus, AgentNodeHealth)] = [
            (.available, .available),
            (.localOnly, .available),
            (.stale, .stale),
            (.snapshotNeeded, .degraded),
            (.unavailable, .unreachable)
        ]
        for (runtimeStatus, nodeHealth) in expected {
            let runtime = RuntimeUsageSnapshot(
                scope: .codex,
                snapshot: .empty,
                status: runtimeStatus,
                quotaSourceLabel: "test",
                usageSourceLabel: "test"
            )
            let nodes = AgentNodeReader(
                configurationStore: StubAgentNodeConfigurationStore(descriptors: []),
                probe: StubAgentNodeProbe(results: [:]),
                cache: InMemoryAgentNodeSnapshotCache(snapshots: []),
                localDeviceName: { "Mac" }
            ).load(codexRuntime: runtime, now: now)
            if nodes.first?.health != nodeHealth {
                failures.append("Codex runtime \(runtimeStatus) mapped to the wrong node health")
            }
        }
    }

    private static func testNodeJSON(failures: inout [String]) {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let descriptor = AgentNodeDescriptor(
            id: "nas-openclaw",
            displayName: "OpenClaw",
            deviceName: "NAS",
            runtime: .openClaw,
            location: .remote,
            sshHost: "private-ssh-alias",
            probeProfile: .synologyTrimOpenClawV1
        )
        let snapshot = AgentNodeSnapshot(
            descriptor: descriptor,
            health: .degraded,
            checkedAt: now,
            lastSeenAt: now,
            heartbeatAt: now.addingTimeInterval(-3_600),
            processCount: 1,
            sourceLabel: "SSH · Ginger",
            detailCode: "process-without-fresh-heartbeat",
            isFromCache: false
        )
        let object = agentNodesJSONObject([snapshot], generatedAt: now)
        guard object["schema"] as? String == "godexu-agent-node-snapshots-v1",
              let nodes = object["nodes"] as? [[String: Any]],
              let node = nodes.first
        else {
            failures.append("agent node JSON schema was not emitted")
            return
        }
        if node["runtime"] as? String != "openclaw"
            || node["health"] as? String != "degraded"
            || node["processCount"] as? Int != 1
            || node["capabilities"] as? [String] != descriptor.capabilities {
            failures.append("agent node JSON omitted normalized fields")
        }
        let forbidden = [
            "sshHost",
            "probeProfile",
            "command",
            "stdout",
            "stderr",
            "environment",
            "credentials"
        ]
        for key in forbidden where node[key] != nil {
            failures.append("agent node JSON leaked \(key)")
        }
        let serialized = (try? JSONSerialization.data(withJSONObject: object))
            .flatMap { String(data: $0, encoding: .utf8) } ?? ""
        if serialized.contains("private-ssh-alias") {
            failures.append("agent node JSON leaked the SSH alias")
        }
    }
}

private final class RecordingAgentNodeCommandExecutor: AgentNodeCommandExecuting {
    let result: AgentNodeCommandResult
    private(set) var executableURL: URL?
    private(set) var arguments: [String] = []
    private(set) var timeout: TimeInterval?

    init(result: AgentNodeCommandResult) {
        self.result = result
    }

    func run(
        executableURL: URL,
        arguments: [String],
        timeout: TimeInterval
    ) -> AgentNodeCommandResult {
        self.executableURL = executableURL
        self.arguments = arguments
        self.timeout = timeout
        return result
    }
}

private struct StubAgentNodeConfigurationStore: AgentNodeConfigurationLoading {
    let descriptors: [AgentNodeDescriptor]

    func load() throws -> [AgentNodeDescriptor] {
        descriptors
    }
}

private struct StubAgentNodeProbe: AgentNodeProbing {
    let results: [String: Result<AgentNodeProbeObservation, AgentNodeProbeError>]

    func probe(
        _ descriptor: AgentNodeDescriptor
    ) -> Result<AgentNodeProbeObservation, AgentNodeProbeError> {
        results[descriptor.id] ?? .failure(.protocolError)
    }
}

private final class InMemoryAgentNodeSnapshotCache: AgentNodeSnapshotCaching {
    private(set) var snapshots: [AgentNodeSnapshot]
    private(set) var savedSnapshots: [AgentNodeSnapshot] = []

    init(snapshots: [AgentNodeSnapshot]) {
        self.snapshots = snapshots
    }

    func load() -> [AgentNodeSnapshot] {
        snapshots
    }

    func save(_ snapshots: [AgentNodeSnapshot]) throws {
        savedSnapshots = snapshots
        self.snapshots = snapshots
    }

    func staleSnapshot(
        for descriptor: AgentNodeDescriptor,
        from snapshots: [AgentNodeSnapshot],
        now: Date
    ) -> AgentNodeSnapshot? {
        AgentNodeSnapshotCache(
            cacheURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("unused-agent-node-cache.json")
        ).staleSnapshot(for: descriptor, from: snapshots, now: now)
    }
}
