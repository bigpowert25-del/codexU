import Foundation

public struct ProjectListItem: Codable, Equatable, Sendable {
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
}

public struct ProjectListResult: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let freshness: IndexFreshness
    public let runtimeAvailability: [RuntimeAvailability]
    public let warnings: [IndexWarning]
    public let appliedLimit: Int
    public let projects: [ProjectListItem]
}

public struct HandoffListResult: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let freshness: IndexFreshness
    public let runtimeAvailability: [RuntimeAvailability]
    public let warnings: [IndexWarning]
    public let appliedLimit: Int
    public let handoffs: [Handoff]
}

public struct ProjectIndexQueryService: Sendable {
    private let index: ProjectIndex

    public init(index: ProjectIndex) {
        self.index = index
    }

    public func projects(
        runtime: String?,
        state: String?,
        limit: Int?
    ) throws -> ProjectListResult {
        let runtimeFilter = try validatedRuntime(runtime)
        let stateFilter = try validatedTaskState(state)
        let appliedLimit = try validatedLimit(limit)
        let filtered = index.projects.filter { project in
            let matchesRuntime = runtimeFilter.map {
                project.sourceRuntimes.contains($0)
            } ?? true
            let matchesState = stateFilter.map { state in
                switch state {
                case .active:
                    return project.activeCount > 0
                case .pending:
                    return project.pendingCount > 0
                case .scheduled:
                    return project.scheduledCount > 0
                case .done:
                    return project.doneCount > 0
                }
            } ?? true
            return matchesRuntime && matchesState
        }
        return ProjectListResult(
            generatedAt: index.generatedAt,
            freshness: index.freshness,
            runtimeAvailability: index.runtimeAvailability,
            warnings: index.warnings,
            appliedLimit: appliedLimit,
            projects: Array(filtered.prefix(appliedLimit)).map {
                ProjectListItem(
                    id: $0.id,
                    name: $0.name,
                    isDerived: $0.isDerived,
                    sourceRuntimes: $0.sourceRuntimes,
                    activeCount: $0.activeCount,
                    pendingCount: $0.pendingCount,
                    scheduledCount: $0.scheduledCount,
                    doneCount: $0.doneCount,
                    totalCount: $0.totalCount,
                    handoffCount: $0.handoffCount,
                    lastActiveAt: $0.lastActiveAt
                )
            }
        )
    }

    public func project(id: String) throws -> Project {
        guard isProjectID(id) else {
            throw PublicSnapshotError(code: "invalid_parameters")
        }
        guard let project = index.projects.first(where: { $0.id == id }) else {
            throw PublicSnapshotError(code: "not_found")
        }
        return project
    }

    public func handoffs(
        state: String?,
        targetRuntime: String?,
        limit: Int?
    ) throws -> HandoffListResult {
        let stateFilter = try validatedHandoffState(state)
        let runtimeFilter = try validatedRuntime(targetRuntime)
        let appliedLimit = try validatedLimit(limit)
        let filtered = index.handoffs.filter { handoff in
            (stateFilter.map { handoff.state == $0 } ?? true)
                && (runtimeFilter.map {
                    handoff.targetRuntime == $0
                } ?? true)
        }
        return HandoffListResult(
            generatedAt: index.generatedAt,
            freshness: index.freshness,
            runtimeAvailability: index.runtimeAvailability,
            warnings: index.warnings,
            appliedLimit: appliedLimit,
            handoffs: Array(filtered.prefix(appliedLimit))
        )
    }

    public func handoff(id: String) throws -> Handoff {
        guard let identifier = UUID(uuidString: id),
              identifier.uuidString.lowercased() == id.lowercased()
        else {
            throw PublicSnapshotError(code: "invalid_parameters")
        }
        guard let handoff = index.handoffs.first(where: {
            $0.id == identifier
        }) else {
            throw PublicSnapshotError(code: "not_found")
        }
        return handoff
    }

    private func validatedRuntime(
        _ value: String?
    ) throws -> AgentRuntime? {
        guard let value else { return nil }
        guard value.count <= 32, let runtime = AgentRuntime(queryValue: value)
        else {
            throw PublicSnapshotError(code: "invalid_parameters")
        }
        return runtime
    }

    private func validatedTaskState(
        _ value: String?
    ) throws -> ProjectTaskState? {
        guard let value else { return nil }
        guard value.count <= 16,
              let state = ProjectTaskState(rawValue: value.lowercased())
        else {
            throw PublicSnapshotError(code: "invalid_parameters")
        }
        return state
    }

    private func validatedHandoffState(
        _ value: String?
    ) throws -> HandoffState? {
        guard let value else { return nil }
        guard value.count <= 16,
              let state = HandoffState(rawValue: value.lowercased())
        else {
            throw PublicSnapshotError(code: "invalid_parameters")
        }
        return state
    }

    private func validatedLimit(_ value: Int?) throws -> Int {
        guard let value else { return 20 }
        guard value > 0 else {
            throw PublicSnapshotError(code: "invalid_parameters")
        }
        return min(value, 50)
    }

    private func isProjectID(_ value: String) -> Bool {
        guard value.count <= 96,
              value.hasPrefix("project-") || value.hasPrefix("runtime-")
        else {
            return false
        }
        let allowed = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: "-")
        )
        return value.unicodeScalars.allSatisfy(allowed.contains)
    }
}
