import Foundation

struct AgentProjectIdentity: Identifiable, Equatable {
    let id: String
    let name: String
    let isDerived: Bool
}

struct AgentProjectWorkspace: Identifiable, Equatable {
    let identity: AgentProjectIdentity
    let tasks: [TaskItem]
    let envelopes: [AgentTaskEnvelope]
    let runtimes: [RuntimeScope]
    let lastActiveAt: Date?

    var id: String { identity.id }
}

enum AgentProjectWorkspaceBuilder {
    static func identity(for item: TaskItem) -> AgentProjectIdentity {
        switch item.source {
        case .codex, .claudeCode:
            let candidate = item.detail
                .components(separatedBy: " · ")
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !candidate.isEmpty {
                let name = String(candidate.prefix(
                    AgentTaskEnvelope.maximumProjectNameLength
                ))
                return AgentProjectIdentity(
                    id: projectID(forDerivedName: name),
                    name: name,
                    isDerived: true
                )
            }
        case .openClaw, .hermes:
            break
        }
        return AgentProjectIdentity(
            id: "runtime-\(item.source.runtimeId)",
            name: "\(item.source.displayName) workspace",
            isDerived: true
        )
    }

    static func projectID(forDerivedName name: String) -> String {
        "project-\(stableIdentifier(name))"
    }

    static func make(
        taskBoard: TaskBoard?,
        envelopes: [AgentTaskEnvelope]
    ) -> [AgentProjectWorkspace] {
        struct Accumulator {
            var identity: AgentProjectIdentity
            var tasks: [TaskItem] = []
            var envelopes: [AgentTaskEnvelope] = []
        }

        var values: [String: Accumulator] = [:]
        for task in taskBoard?.columns.flatMap(\.items) ?? [] {
            let identity = identity(for: task)
            var value = values[identity.id] ?? Accumulator(identity: identity)
            value.tasks.append(task)
            values[identity.id] = value
        }
        for envelope in envelopes {
            let identity = AgentProjectIdentity(
                id: envelope.projectID,
                name: envelope.projectName,
                isDerived: true
            )
            var value = values[identity.id] ?? Accumulator(identity: identity)
            value.envelopes.append(envelope)
            values[identity.id] = value
        }

        return values.values.map { value in
            let tasks = value.tasks.sorted(by: taskComesBefore)
            let envelopes = value.envelopes.sorted {
                if $0.updatedAt != $1.updatedAt {
                    return $0.updatedAt > $1.updatedAt
                }
                return $0.id.uuidString < $1.id.uuidString
            }
            let runtimes = Set(
                tasks.map(\.source)
                    + envelopes.flatMap { [$0.sourceRuntime, $0.targetRuntime] }
            ).sorted { $0.runtimeId < $1.runtimeId }
            let lastActiveAt = (
                tasks.compactMap(\.updatedAt)
                    + envelopes.map(\.updatedAt)
            ).max()
            return AgentProjectWorkspace(
                identity: value.identity,
                tasks: tasks,
                envelopes: envelopes,
                runtimes: runtimes,
                lastActiveAt: lastActiveAt
            )
        }.sorted {
            let left = $0.lastActiveAt ?? .distantPast
            let right = $1.lastActiveAt ?? .distantPast
            if left != right { return left > right }
            return $0.identity.name.localizedCaseInsensitiveCompare(
                $1.identity.name
            ) == .orderedAscending
        }
    }

    private static func taskComesBefore(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        let leftRank = taskRank(lhs.kind)
        let rightRank = taskRank(rhs.kind)
        if leftRank != rightRank { return leftRank < rightRank }
        let leftDate = lhs.updatedAt ?? .distantPast
        let rightDate = rhs.updatedAt ?? .distantPast
        if leftDate != rightDate { return leftDate > rightDate }
        return lhs.id < rhs.id
    }

    private static func taskRank(_ kind: TaskColumnKind) -> Int {
        switch kind {
        case .active:
            return 0
        case .pending:
            return 1
        case .scheduled:
            return 2
        case .done:
            return 3
        }
    }

    private static func stableIdentifier(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }
}
