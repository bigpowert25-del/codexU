import Foundation

enum AgentPolicyLevel: String, CaseIterable, Codable, Equatable, Identifiable {
    case guarded = "a"
    case collaborative = "b"
    case flexible = "c"

    var id: String { rawValue }
}

struct AgentIdentityProfile: Identifiable, Codable, Equatable {
    static let maximumRoleNameLength = 32
    static let maximumResponsibilityLength = 120
    static let maximumResponsibilityLines = 3

    let nodeID: String
    let runtime: RuntimeScope
    let roleName: String
    let responsibility: String
    let policyLevel: AgentPolicyLevel
    let updatedAt: Date

    var id: String { nodeID }

    static func defaultProfile(
        nodeID: String,
        runtime: RuntimeScope,
        now: Date
    ) -> AgentIdentityProfile {
        let identity: (roleName: String, responsibility: String)
        switch runtime {
        case .codex:
            identity = (
                "Build & execute",
                "Research, implement, verify, and deliver"
            )
        case .openClaw:
            identity = (
                "Coordinate",
                "Maintain context, orchestrate work, and coordinate nodes"
            )
        case .claudeCode:
            identity = (
                "Code collaboration",
                "Collaborate on local coding sessions and implementation"
            )
        case .hermes:
            identity = (
                "Analyze & review",
                "Analyze independently, research, and review results"
            )
        }
        return AgentIdentityProfile(
            nodeID: nodeID,
            runtime: runtime,
            roleName: identity.roleName,
            responsibility: identity.responsibility,
            policyLevel: .guarded,
            updatedAt: now
        )
    }

    static func sanitized(
        nodeID: String,
        runtime: RuntimeScope,
        roleName: String,
        responsibility: String,
        policyLevel: AgentPolicyLevel,
        updatedAt: Date
    ) -> AgentIdentityProfile? {
        guard isSafeNodeID(nodeID) else { return nil }
        let normalizedRole = normalizedRoleName(roleName)
        guard !normalizedRole.isEmpty else { return nil }
        return AgentIdentityProfile(
            nodeID: nodeID,
            runtime: runtime,
            roleName: String(normalizedRole.prefix(maximumRoleNameLength)),
            responsibility: normalizedResponsibility(responsibility),
            policyLevel: policyLevel,
            updatedAt: updatedAt
        )
    }

    static func isValidStoredProfile(_ profile: AgentIdentityProfile) -> Bool {
        guard let normalized = sanitized(
            nodeID: profile.nodeID,
            runtime: profile.runtime,
            roleName: profile.roleName,
            responsibility: profile.responsibility,
            policyLevel: profile.policyLevel,
            updatedAt: profile.updatedAt
        ) else {
            return false
        }
        return normalized == profile
    }

    private static func normalizedRoleName(_ value: String) -> String {
        value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func normalizedResponsibility(_ value: String) -> String {
        let lines = value
            .components(separatedBy: .newlines)
            .map {
                $0
                    .split(whereSeparator: \.isWhitespace)
                    .joined(separator: " ")
            }
            .filter { !$0.isEmpty }
            .prefix(maximumResponsibilityLines)
        return String(lines.joined(separator: "\n").prefix(maximumResponsibilityLength))
    }

    private static func isSafeNodeID(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 64 else { return false }
        let allowed = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: "._-")
        )
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
