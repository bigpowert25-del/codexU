import Foundation

enum GodexUIndexFreshness: String, Codable, Equatable {
    case fresh
    case stale
}

enum GodexUTaskState: String, Codable, Equatable {
    case active
    case pending
    case scheduled
    case done
}

struct GodexURuntimeAvailability: Codable, Equatable {
    let runtime: RuntimeScope
    let status: RuntimeMenuStatus
}

struct GodexUProjectTaskSummary: Codable, Equatable {
    let id: String
    let title: String
    let sourceRuntime: RuntimeScope
    let state: GodexUTaskState
    let updatedAt: Date?
    let progressPercent: Double?
}

struct GodexUProjectSummary: Codable, Equatable {
    let id: String
    let name: String
    let isDerived: Bool
    let sourceRuntimes: [RuntimeScope]
    let activeCount: Int
    let pendingCount: Int
    let scheduledCount: Int
    let doneCount: Int
    let totalCount: Int
    let handoffCount: Int
    let lastActiveAt: Date?
    let tasks: [GodexUProjectTaskSummary]
}

struct GodexUHandoffSummary: Codable, Equatable {
    let id: UUID
    let projectID: String
    let projectName: String
    let title: String
    let sourceRuntime: RuntimeScope
    let targetRuntime: RuntimeScope
    let state: AgentTaskEnvelopeState
    let revision: Int
    let createdAt: Date
    let updatedAt: Date
}

struct GodexUIndexWarning: Codable, Equatable {
    let code: String
}

struct GodexUProjectIndexTaskInput {
    let nativeID: String
    let title: String
    let projectName: String?
    let sourceRuntime: RuntimeScope
    let state: GodexUTaskState
    let updatedAt: Date?
    let progressPercent: Double?
}

struct GodexUProjectIndex: Codable, Equatable {
    static let schemaIdentifier = "godexu-project-index-v1"
    static let deviceScopeIdentifier = "local-mac"

    let schema: String
    let generatedAt: Date
    let deviceScope: String
    let freshness: GodexUIndexFreshness
    let runtimeAvailability: [GodexURuntimeAvailability]
    let projects: [GodexUProjectSummary]
    let handoffs: [GodexUHandoffSummary]
    let warnings: [GodexUIndexWarning]

    static func make(
        generatedAt: Date,
        freshness: GodexUIndexFreshness,
        runtimeAvailability: [GodexURuntimeAvailability],
        tasks: [GodexUProjectIndexTaskInput],
        envelopes: [GodexUHandoffSummary],
        warnings: [GodexUIndexWarning]
    ) -> GodexUProjectIndex {
        struct Accumulator {
            let id: String
            let name: String
            var tasks: [GodexUProjectTaskSummary]
            var handoffs: [GodexUHandoffSummary]
        }

        let publicEnvelopes = envelopes.compactMap(normalizedHandoff)
        var accumulators: [String: Accumulator] = [:]
        for task in tasks {
            let identity = projectIdentity(
                runtime: task.sourceRuntime,
                candidateName: task.projectName
            )
            let title = publicText(task.title, limit: 160)
            guard !title.isEmpty else { continue }
            let taskIdentity = "\(task.sourceRuntime.runtimeId):\(task.nativeID)"
            let normalizedID = "task-\(stableIdentifier(taskIdentity))"
            let progress = task.progressPercent.map {
                min(max($0, 0), 100)
            }
            let summary = GodexUProjectTaskSummary(
                id: normalizedID,
                title: title,
                sourceRuntime: task.sourceRuntime,
                state: task.state,
                updatedAt: task.updatedAt,
                progressPercent: progress
            )
            var value = accumulators[identity.id] ?? Accumulator(
                id: identity.id,
                name: identity.name,
                tasks: [],
                handoffs: []
            )
            value.tasks.append(summary)
            accumulators[identity.id] = value
        }

        for envelope in publicEnvelopes {
            let projectName = publicText(
                envelope.projectName,
                limit: AgentTaskEnvelope.maximumProjectNameLength
            )
            guard GodexUProjectIndexQuery.projectID(envelope.projectID) != nil,
                  !projectName.isEmpty
            else {
                continue
            }
            var value = accumulators[envelope.projectID] ?? Accumulator(
                id: envelope.projectID,
                name: projectName,
                tasks: [],
                handoffs: []
            )
            value.handoffs.append(envelope)
            accumulators[envelope.projectID] = value
        }

        let projects = accumulators.values.map { value in
            let sortedTasks = value.tasks.sorted(by: taskComesBefore)
            let boundedTasks = Array(sortedTasks.prefix(100))
            let runtimes = Set(
                value.tasks.map(\.sourceRuntime)
                    + value.handoffs.flatMap {
                        [$0.sourceRuntime, $0.targetRuntime]
                    }
            ).sorted { $0.runtimeId < $1.runtimeId }
            let lastActiveAt = (
                value.tasks.compactMap(\.updatedAt)
                    + value.handoffs.map(\.updatedAt)
            ).max()
            return GodexUProjectSummary(
                id: value.id,
                name: value.name,
                isDerived: true,
                sourceRuntimes: runtimes,
                activeCount: value.tasks.filter { $0.state == .active }.count,
                pendingCount: value.tasks.filter { $0.state == .pending }.count,
                scheduledCount: value.tasks.filter {
                    $0.state == .scheduled
                }.count,
                doneCount: value.tasks.filter { $0.state == .done }.count,
                totalCount: value.tasks.count,
                handoffCount: value.handoffs.count,
                lastActiveAt: lastActiveAt,
                tasks: boundedTasks
            )
        }.sorted {
            let left = $0.lastActiveAt ?? .distantPast
            let right = $1.lastActiveAt ?? .distantPast
            if left != right { return left > right }
            return $0.name.localizedCaseInsensitiveCompare($1.name)
                == .orderedAscending
        }

        return GodexUProjectIndex(
            schema: schemaIdentifier,
            generatedAt: generatedAt,
            deviceScope: deviceScopeIdentifier,
            freshness: freshness,
            runtimeAvailability: runtimeAvailability.sorted {
                $0.runtime.runtimeId < $1.runtime.runtimeId
            },
            projects: projects,
            handoffs: publicEnvelopes.sorted {
                if $0.updatedAt != $1.updatedAt {
                    return $0.updatedAt > $1.updatedAt
                }
                return $0.id.uuidString < $1.id.uuidString
            },
            warnings: warnings
        )
    }

    private static func projectIdentity(
        runtime: RuntimeScope,
        candidateName: String?
    ) -> (id: String, name: String) {
        if runtime == .codex || runtime == .claudeCode {
            let name = publicText(
                candidateName ?? "",
                limit: AgentTaskEnvelope.maximumProjectNameLength
            )
            if !name.isEmpty {
                return (
                    AgentProjectWorkspaceBuilder.projectID(
                        forDerivedName: name
                    ),
                    name
                )
            }
        }
        return (
            "runtime-\(runtime.runtimeId)",
            "\(runtime.displayName) workspace"
        )
    }

    private static func taskComesBefore(
        _ lhs: GodexUProjectTaskSummary,
        _ rhs: GodexUProjectTaskSummary
    ) -> Bool {
        let leftRank = taskRank(lhs.state)
        let rightRank = taskRank(rhs.state)
        if leftRank != rightRank { return leftRank < rightRank }
        let leftDate = lhs.updatedAt ?? .distantPast
        let rightDate = rhs.updatedAt ?? .distantPast
        if leftDate != rightDate { return leftDate > rightDate }
        return lhs.id < rhs.id
    }

    private static func taskRank(_ state: GodexUTaskState) -> Int {
        switch state {
        case .active: return 0
        case .pending: return 1
        case .scheduled: return 2
        case .done: return 3
        }
    }

    private static func normalizedHandoff(
        _ envelope: GodexUHandoffSummary
    ) -> GodexUHandoffSummary? {
        let projectName = publicText(
            envelope.projectName,
            limit: AgentTaskEnvelope.maximumProjectNameLength
        )
        let title = publicText(
            envelope.title,
            limit: AgentTaskEnvelope.maximumTitleLength
        )
        guard !projectName.isEmpty, !title.isEmpty else { return nil }
        return GodexUHandoffSummary(
            id: envelope.id,
            projectID: envelope.projectID,
            projectName: projectName,
            title: title,
            sourceRuntime: envelope.sourceRuntime,
            targetRuntime: envelope.targetRuntime,
            state: envelope.state,
            revision: envelope.revision,
            createdAt: envelope.createdAt,
            updatedAt: envelope.updatedAt
        )
    }

    private static func publicText(
        _ value: String,
        limit: Int
    ) -> String {
        let normalized = value
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .map(redactedToken)
            .joined(separator: " ")
        return String(normalized.prefix(limit))
    }

    private static func redactedToken(_ token: String) -> String {
        let lowered = token.lowercased()
        let pathMarkers = [
            "/users/",
            "/volumes/",
            "/private/",
            "/var/",
            "$codex_home",
            "~/.codex",
            "~/.openclaw"
        ]
        if pathMarkers.contains(where: lowered.contains) {
            return "[path]"
        }
        let range = NSRange(token.startIndex..<token.endIndex, in: token)
        if uuidExpression.firstMatch(in: token, range: range) != nil {
            return uuidExpression.stringByReplacingMatches(
                in: token,
                range: range,
                withTemplate: "[id]"
            )
        }
        return token
    }

    private static let uuidExpression = try! NSRegularExpression(
        pattern: "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"
    )

    private static func stableIdentifier(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }
}

enum GodexUProjectIndexQuery {
    static func limit(_ requested: Int?) -> Int {
        min(max(requested ?? 20, 1), 50)
    }

    static func projectID(_ value: String) -> String? {
        guard value.count <= AgentTaskEnvelope.maximumIdentifierLength,
              value.hasPrefix("project-") || value.hasPrefix("runtime-")
        else {
            return nil
        }
        let allowed = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: "-")
        )
        guard value.unicodeScalars.allSatisfy(allowed.contains) else {
            return nil
        }
        return value
    }
}

enum GodexUProjectIndexCodec {
    enum CodecError: Error {
        case invalidShape
        case unsupportedSchema
    }

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

    static func encode(_ index: GodexUProjectIndex) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(index)
    }

    static func decode(_ data: Data) throws -> GodexUProjectIndex {
        guard hasStrictShape(data) else {
            throw CodecError.invalidShape
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let index = try decoder.decode(GodexUProjectIndex.self, from: data)
        guard index.schema == GodexUProjectIndex.schemaIdentifier,
              index.deviceScope == GodexUProjectIndex.deviceScopeIdentifier
        else {
            throw CodecError.unsupportedSchema
        }
        return index
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
                of: project,
                required: projectKeys.subtracting(["lastActiveAt"]),
                allowed: projectKeys
            ),
            let tasks = project["tasks"] as? [[String: Any]]
            else {
                return false
            }
            return tasks.allSatisfy {
                keys(
                    of: $0,
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
        of object: [String: Any],
        required: Set<String>,
        allowed: Set<String>
    ) -> Bool {
        let actual = Set(object.keys)
        return required.isSubset(of: actual) && actual.isSubset(of: allowed)
    }
}
