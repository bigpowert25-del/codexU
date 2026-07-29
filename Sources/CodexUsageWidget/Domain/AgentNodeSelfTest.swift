import Foundation

enum AgentNodeSelfTest {
    static func run() -> Bool {
        var failures: [String] = []
        testHealthEvaluation(failures: &failures)
        testConfiguration(failures: &failures)
        testCacheFallback(failures: &failures)

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
}
