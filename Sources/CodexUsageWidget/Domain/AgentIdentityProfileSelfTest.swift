import Foundation

enum AgentIdentityProfileSelfTest {
    static func run() -> Bool {
        var failures: [String] = []
        testPolicyLevels(failures: &failures)
        testRuntimeDefaults(failures: &failures)
        testSanitization(failures: &failures)
        testValidationLimits(failures: &failures)
        testCoding(failures: &failures)
        testStorePersistence(failures: &failures)
        testStoreFailureModes(failures: &failures)
        testStoredPrivacyBoundary(failures: &failures)

        if failures.isEmpty {
            print("agent identity self-test passed")
            return true
        }
        failures.forEach { print("agent identity self-test failed: \($0)") }
        return false
    }

    private static func testPolicyLevels(failures: inout [String]) {
        if AgentPolicyLevel.allCases.map(\.rawValue) != ["a", "b", "c"] {
            failures.append("policy levels are not stable A/B/C identifiers")
        }
        if AgentPolicyLevel.allCases.map(\.id) != ["a", "b", "c"] {
            failures.append("policy identifiers do not match stored values")
        }
    }

    private static func testRuntimeDefaults(failures: inout [String]) {
        let now = Date(timeIntervalSince1970: 1_000)
        let expected: [(RuntimeScope, String, String)] = [
            (.codex, "Build & execute", "Research, implement, verify, and deliver"),
            (.openClaw, "Coordinate", "Maintain context, orchestrate work, and coordinate nodes"),
            (.claudeCode, "Code collaboration", "Collaborate on local coding sessions and implementation"),
            (.hermes, "Analyze & review", "Analyze independently, research, and review results")
        ]
        for (runtime, roleName, responsibility) in expected {
            let profile = AgentIdentityProfile.defaultProfile(
                nodeID: "node-\(runtime.runtimeId)",
                runtime: runtime,
                now: now
            )
            if profile.roleName != roleName
                || profile.responsibility != responsibility
                || profile.policyLevel != .guarded
                || profile.updatedAt != now {
                failures.append("\(runtime.runtimeId) default profile was not deterministic")
            }
        }
    }

    private static func testSanitization(failures: inout [String]) {
        let updatedAt = Date(timeIntervalSince1970: 2_000)
        let profile = AgentIdentityProfile.sanitized(
            nodeID: "nas-hermes",
            runtime: .hermes,
            roleName: "  Lead\n  Reviewer  ",
            responsibility: "  independent analysis  \n review results \n research evidence \n ignored line ",
            policyLevel: .collaborative,
            updatedAt: updatedAt
        )
        if profile?.nodeID != "nas-hermes"
            || profile?.runtime != .hermes
            || profile?.roleName != "Lead Reviewer"
            || profile?.responsibility != "independent analysis\nreview results\nresearch evidence"
            || profile?.policyLevel != .collaborative
            || profile?.updatedAt != updatedAt {
            failures.append("profile sanitization did not preserve identity and normalized fields")
        }
        if AgentIdentityProfile.sanitized(
            nodeID: "nas-hermes",
            runtime: .hermes,
            roleName: " \n ",
            responsibility: "Review",
            policyLevel: .guarded,
            updatedAt: updatedAt
        ) != nil {
            failures.append("empty role name was accepted")
        }
        if AgentIdentityProfile.sanitized(
            nodeID: "bad node",
            runtime: .hermes,
            roleName: "Reviewer",
            responsibility: "Review",
            policyLevel: .guarded,
            updatedAt: updatedAt
        ) != nil {
            failures.append("unsafe node identifier was accepted")
        }
    }

    private static func testValidationLimits(failures: inout [String]) {
        let profile = AgentIdentityProfile.sanitized(
            nodeID: "local-codex",
            runtime: .codex,
            roleName: String(repeating: "R", count: 50),
            responsibility: String(repeating: "S", count: 150),
            policyLevel: .flexible,
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )
        if profile?.roleName.count != 32 {
            failures.append("role name was not limited to 32 characters")
        }
        if profile?.responsibility.count != 120 {
            failures.append("responsibility was not limited to 120 characters")
        }
    }

    private static func testCoding(failures: inout [String]) {
        let profile = AgentIdentityProfile.defaultProfile(
            nodeID: "local-codex",
            runtime: .codex,
            now: Date(timeIntervalSince1970: 4_000)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? encoder.encode(profile),
              let decoded = try? decoder.decode(AgentIdentityProfile.self, from: data),
              decoded == profile
        else {
            failures.append("profile did not round-trip through Codable")
            return
        }
    }

    private static func testStorePersistence(failures: inout [String]) {
        guard let temporary = makeTemporaryStore() else {
            failures.append("could not create temporary profile directory")
            return
        }
        defer { try? FileManager.default.removeItem(at: temporary.directory) }
        let fileURL = temporary.fileURL
        let now = Date(timeIntervalSince1970: 5_000)
        let missingStore = AgentIdentityProfileStore(fileURL: fileURL)
        let missing = missingStore.profile(
            nodeID: "nas-hermes",
            runtime: .hermes,
            now: now
        )
        if missing
            != AgentIdentityProfile.defaultProfile(
                nodeID: "nas-hermes",
                runtime: .hermes,
                now: now
            ) {
            failures.append("missing profile file did not use the runtime default")
        }

        guard let custom = AgentIdentityProfile.sanitized(
            nodeID: "nas-hermes",
            runtime: .hermes,
            roleName: "Independent reviewer",
            responsibility: "Review difficult results",
            policyLevel: .collaborative,
            updatedAt: now
        ) else {
            failures.append("could not create store test profile")
            return
        }
        do {
            try missingStore.save(custom)
            let restoredStore = AgentIdentityProfileStore(fileURL: fileURL)
            if restoredStore.profile(
                nodeID: "nas-hermes",
                runtime: .hermes,
                now: now
            ) != custom {
                failures.append("saved profile did not survive store reload")
            }
            if restoredStore.profile(
                nodeID: "nas-hermes",
                runtime: .codex,
                now: now
            ).runtime != .codex {
                failures.append("runtime mismatch reused an unsafe override")
            }
            try restoredStore.reset(nodeID: "nas-hermes")
            let reset = AgentIdentityProfileStore(fileURL: fileURL).profile(
                nodeID: "nas-hermes",
                runtime: .hermes,
                now: now
            )
            if reset.policyLevel != .guarded
                || reset.roleName != "Analyze & review" {
                failures.append("reset did not restore the runtime default")
            }
        } catch {
            failures.append("store persistence failed: \(error)")
        }
    }

    private static func testStoreFailureModes(failures: inout [String]) {
        guard let temporary = makeTemporaryStore() else {
            failures.append("could not create temporary profile directory")
            return
        }
        defer { try? FileManager.default.removeItem(at: temporary.directory) }
        let documents = [
            #"{"schema":"unsupported","profiles":[]}"#,
            #"{"schema":"godexu-agent-profiles-v1","profiles":[{"nodeID":"same","runtime":"codex","roleName":"One","responsibility":"","policyLevel":"a","updatedAt":"1970-01-01T00:00:01Z"},{"nodeID":"same","runtime":"codex","roleName":"Two","responsibility":"","policyLevel":"a","updatedAt":"1970-01-01T00:00:02Z"}]}"#,
            #"{"schema":"godexu-agent-profiles-v1","profiles":[{"nodeID":"bad node","runtime":"codex","roleName":"Builder","responsibility":"","policyLevel":"a","updatedAt":"1970-01-01T00:00:01Z"}]}"#,
            #"{not-json}"#
        ]
        for document in documents {
            do {
                try Data(document.utf8).write(to: temporary.fileURL, options: .atomic)
                if !AgentIdentityProfileStore(fileURL: temporary.fileURL).overrides.isEmpty {
                    failures.append("invalid store document was partially trusted")
                }
            } catch {
                failures.append("could not write invalid store fixture: \(error)")
            }
        }
    }

    private static func testStoredPrivacyBoundary(failures: inout [String]) {
        guard let temporary = makeTemporaryStore() else {
            failures.append("could not create temporary profile directory")
            return
        }
        defer { try? FileManager.default.removeItem(at: temporary.directory) }
        let now = Date(timeIntervalSince1970: 6_000)
        let store = AgentIdentityProfileStore(fileURL: temporary.fileURL)
        guard let profile = AgentIdentityProfile.sanitized(
            nodeID: "nas-openclaw",
            runtime: .openClaw,
            roleName: "Coordinator",
            responsibility: "Coordinate safe handoffs",
            policyLevel: .flexible,
            updatedAt: now
        ) else {
            failures.append("could not create privacy fixture")
            return
        }
        do {
            try store.save(profile)
            let text = String(
                data: try Data(contentsOf: temporary.fileURL),
                encoding: .utf8
            ) ?? ""
            let forbidden = [
                "sshHost",
                "networkHost",
                "probeProfile",
                "command",
                "stdout",
                "stderr",
                "credential",
                "keyPath"
            ]
            if forbidden.contains(where: text.contains) {
                failures.append("profile store crossed the node privacy boundary")
            }
        } catch {
            failures.append("could not verify stored privacy boundary: \(error)")
        }
    }

    private static func makeTemporaryStore() -> (directory: URL, fileURL: URL)? {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "codexu-agent-profile-self-test-\(UUID().uuidString)",
                isDirectory: true
            )
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            return nil
        }
        return (
            directory,
            directory.appendingPathComponent("agent-profiles.json")
        )
    }
}
