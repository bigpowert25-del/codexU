import Foundation

public enum IndexFreshness: String, Codable, Equatable, Sendable {
    case fresh
    case stale
}

public enum AgentRuntime: String, Codable, Equatable, Hashable, Sendable {
    case codex
    case openClaw
    case claudeCode
    case hermes

    public init?(queryValue: String) {
        switch queryValue.lowercased() {
        case "codex":
            self = .codex
        case "openclaw", "open-claw":
            self = .openClaw
        case "claude", "claude-code", "claudecode":
            self = .claudeCode
        case "hermes":
            self = .hermes
        default:
            return nil
        }
    }
}

public enum RuntimeAvailabilityStatus: String, Codable, Equatable, Sendable {
    case available
    case localOnly
    case snapshotNeeded
    case stale
    case unavailable
}

public enum ProjectTaskState: String, Codable, Equatable, Sendable {
    case active
    case pending
    case scheduled
    case done
}

public enum HandoffState: String, Codable, Equatable, Sendable {
    case draft
    case ready
}

public struct RuntimeAvailability: Codable, Equatable, Sendable {
    public let runtime: AgentRuntime
    public let status: RuntimeAvailabilityStatus
}

public struct ProjectTask: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let sourceRuntime: AgentRuntime
    public let state: ProjectTaskState
    public let updatedAt: Date?
    public let progressPercent: Double?
}

public struct Project: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let isDerived: Bool
    public let sourceRuntimes: [AgentRuntime]
    public let activeCount: Int
    public let pendingCount: Int
    public let scheduledCount: Int
    public let doneCount: Int
    public let totalCount: Int
    public let handoffCount: Int
    public let lastActiveAt: Date?
    public let tasks: [ProjectTask]
}

public struct Handoff: Codable, Equatable, Sendable {
    public let id: UUID
    public let projectID: String
    public let projectName: String
    public let title: String
    public let sourceRuntime: AgentRuntime
    public let targetRuntime: AgentRuntime
    public let state: HandoffState
    public let revision: Int
    public let createdAt: Date
    public let updatedAt: Date
}

public struct IndexWarning: Codable, Equatable, Sendable {
    public let code: String
}

public struct ProjectIndex: Codable, Equatable, Sendable {
    public let schema: String
    public let generatedAt: Date
    public let deviceScope: String
    public let freshness: IndexFreshness
    public let runtimeAvailability: [RuntimeAvailability]
    public let projects: [Project]
    public let handoffs: [Handoff]
    public let warnings: [IndexWarning]

    public func withFreshness(_ value: IndexFreshness) -> ProjectIndex {
        ProjectIndex(
            schema: schema,
            generatedAt: generatedAt,
            deviceScope: deviceScope,
            freshness: value,
            runtimeAvailability: runtimeAvailability,
            projects: projects,
            handoffs: handoffs,
            warnings: warnings
        )
    }
}

public struct PublicSnapshotError: Error, Equatable, Sendable {
    public let code: String

    public init(code: String) {
        self.code = code
    }
}

public enum ProjectIndexCodec {
    private static let documentKeys: Set<String> = [
        "schema",
        "generatedAt",
        "deviceScope",
        "freshness",
        "runtimeAvailability",
        "projects",
        "handoffs",
        "warnings"
    ]
    private static let availabilityKeys: Set<String> = ["runtime", "status"]
    private static let projectKeys: Set<String> = [
        "id",
        "name",
        "isDerived",
        "sourceRuntimes",
        "activeCount",
        "pendingCount",
        "scheduledCount",
        "doneCount",
        "totalCount",
        "handoffCount",
        "lastActiveAt",
        "tasks"
    ]
    private static let taskKeys: Set<String> = [
        "id",
        "title",
        "sourceRuntime",
        "state",
        "updatedAt",
        "progressPercent"
    ]
    private static let handoffKeys: Set<String> = [
        "id",
        "projectID",
        "projectName",
        "title",
        "sourceRuntime",
        "targetRuntime",
        "state",
        "revision",
        "createdAt",
        "updatedAt"
    ]
    private static let warningKeys: Set<String> = ["code"]

    public static func decode(_ data: Data) throws -> ProjectIndex {
        guard data.count <= 2 * 1_024 * 1_024,
              hasStrictShape(data)
        else {
            throw PublicSnapshotError(code: "snapshot_invalid")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let index: ProjectIndex
        do {
            index = try decoder.decode(ProjectIndex.self, from: data)
        } catch {
            throw PublicSnapshotError(code: "snapshot_invalid")
        }
        guard isValid(index) else {
            throw PublicSnapshotError(code: "snapshot_invalid")
        }
        return index
    }

    public static func encode(_ index: ProjectIndex) throws -> Data {
        guard isValid(index) else {
            throw PublicSnapshotError(code: "snapshot_invalid")
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(index)
    }

    private static func isValid(_ index: ProjectIndex) -> Bool {
        guard index.schema == "godexu-project-index-v1",
              index.deviceScope == "local-mac",
              index.runtimeAvailability.count <= AgentRuntime.allCasesCount,
              index.projects.count <= 512,
              index.handoffs.count <= 256,
              index.warnings.count <= 32
        else {
            return false
        }
        return index.projects.allSatisfy { project in
            isProjectID(project.id)
                && isPublicText(project.name, limit: 64)
                && project.tasks.count <= 100
                && project.activeCount >= 0
                && project.pendingCount >= 0
                && project.scheduledCount >= 0
                && project.doneCount >= 0
                && project.totalCount >= project.tasks.count
                && project.handoffCount >= 0
                && project.tasks.allSatisfy { task in
                    isNormalizedTaskID(task.id)
                        && isPublicText(task.title, limit: 160)
                        && task.progressPercent.map {
                            $0 >= 0 && $0 <= 100
                        } ?? true
                }
        } && index.handoffs.allSatisfy { handoff in
            isProjectID(handoff.projectID)
                && isPublicText(handoff.projectName, limit: 64)
                && isPublicText(handoff.title, limit: 160)
                && handoff.revision >= 1
                && handoff.updatedAt >= handoff.createdAt
        } && index.warnings.allSatisfy {
            isPublicCode($0.code)
        }
    }

    private static func hasStrictShape(_ data: Data) -> Bool {
        guard let document = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any],
              Set(document.keys) == documentKeys,
              let availability = document["runtimeAvailability"]
                as? [[String: Any]],
              let projects = document["projects"] as? [[String: Any]],
              let handoffs = document["handoffs"] as? [[String: Any]],
              let warnings = document["warnings"] as? [[String: Any]]
        else {
            return false
        }
        return availability.allSatisfy {
            Set($0.keys) == availabilityKeys
        } && projects.allSatisfy { project in
            guard keys(
                project,
                required: projectKeys.subtracting(["lastActiveAt"]),
                allowed: projectKeys
            ),
            let tasks = project["tasks"] as? [[String: Any]]
            else {
                return false
            }
            return tasks.allSatisfy {
                keys(
                    $0,
                    required: taskKeys.subtracting(
                        ["updatedAt", "progressPercent"]
                    ),
                    allowed: taskKeys
                )
            }
        } && handoffs.allSatisfy {
            Set($0.keys) == handoffKeys
        } && warnings.allSatisfy {
            Set($0.keys) == warningKeys
        }
    }

    private static func keys(
        _ object: [String: Any],
        required: Set<String>,
        allowed: Set<String>
    ) -> Bool {
        let actual = Set(object.keys)
        return required.isSubset(of: actual) && actual.isSubset(of: allowed)
    }

    private static func isProjectID(_ value: String) -> Bool {
        guard value.count <= 96,
              value.hasPrefix("project-") || value.hasPrefix("runtime-")
        else {
            return false
        }
        return value.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.union(
                CharacterSet(charactersIn: "-")
            ).contains($0)
        }
    }

    private static func isNormalizedTaskID(_ value: String) -> Bool {
        guard value.hasPrefix("task-"), value.count == 21 else { return false }
        return value.dropFirst(5).allSatisfy { character in
            character.isHexDigit
        }
    }

    private static func isPublicText(_ value: String, limit: Int) -> Bool {
        guard !value.isEmpty, value.count <= limit, !value.contains("\n") else {
            return false
        }
        let lowered = value.lowercased()
        let pathMarkers = [
            "/users/",
            "/volumes/",
            "/private/",
            "/var/",
            "$codex_home",
            "~/.codex",
            "~/.openclaw"
        ]
        guard !pathMarkers.contains(where: lowered.contains) else {
            return false
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return !credentialExpressions.contains {
            $0.firstMatch(in: value, range: range) != nil
        }
    }

    private static let credentialExpressions: [NSRegularExpression] = [
        #"(?i)(?<![a-z0-9])sk-(?:proj-)?[a-z0-9_-]{16,}"#,
        #"(?i)(?<![a-z0-9])gh[pousr]_[a-z0-9]{16,}"#,
        #"(?i)\bAKIA[A-Z0-9]{16}\b"#,
        #"(?i)\b(?:password|passwd|api[_-]?key|secret|token)\s*[:=]\s*\S+"#,
        #"(?i)\bbearer\s+[a-z0-9._~-]{12,}"#
    ].map { try! NSRegularExpression(pattern: $0) }

    private static func isPublicCode(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 64 else { return false }
        return value.unicodeScalars.allSatisfy {
            CharacterSet.lowercaseLetters.union(.decimalDigits).union(
                CharacterSet(charactersIn: "_")
            ).contains($0)
        }
    }
}

private extension AgentRuntime {
    static var allCasesCount: Int { 4 }
}
