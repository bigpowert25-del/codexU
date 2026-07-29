import Foundation

enum AgentIdentityProfileSelfTest {
    static func run() -> Bool {
        var failures: [String] = []
        testPolicyLevels(failures: &failures)
        testRuntimeDefaults(failures: &failures)
        testSanitization(failures: &failures)
        testValidationLimits(failures: &failures)
        testCoding(failures: &failures)

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
}
