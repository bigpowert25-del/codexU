import Foundation

public actor ProjectIndexCache {
    public typealias Loader = @Sendable () async throws -> Data

    private struct CachedSnapshot {
        let index: ProjectIndex
        let loadedAt: Date
    }

    private struct InFlightRefresh {
        let id: UUID
        let startedAt: Date
        let task: Task<ProjectIndex, Error>
    }

    private let loader: Loader
    private let freshTTL: TimeInterval
    private let staleTTL: TimeInterval
    private var cached: CachedSnapshot?
    private var inFlightRefresh: InFlightRefresh?

    public init(
        freshTTL: TimeInterval = 3,
        staleTTL: TimeInterval = 15 * 60,
        loader: @escaping Loader
    ) {
        self.freshTTL = freshTTL
        self.staleTTL = staleTTL
        self.loader = loader
    }

    public func snapshot(now: Date = Date()) async throws -> ProjectIndex {
        if let cached,
           now.timeIntervalSince(cached.loadedAt) <= freshTTL {
            return cached.index
        }

        let refresh: InFlightRefresh
        if let inFlightRefresh {
            refresh = inFlightRefresh
        } else {
            let loader = self.loader
            let created = InFlightRefresh(
                id: UUID(),
                startedAt: now,
                task: Task {
                    let data = try await loader()
                    return try ProjectIndexCodec.decode(data)
                }
            )
            inFlightRefresh = created
            refresh = created
        }

        do {
            let index = try await refresh.task.value
            if inFlightRefresh?.id == refresh.id {
                cached = CachedSnapshot(
                    index: index,
                    loadedAt: refresh.startedAt
                )
                inFlightRefresh = nil
            }
            return index
        } catch {
            if inFlightRefresh?.id == refresh.id {
                inFlightRefresh = nil
            }
            if let cached,
               now.timeIntervalSince(cached.loadedAt) <= staleTTL {
                return cached.index.withFreshness(.stale)
            }
            throw PublicSnapshotError(code: "snapshot_unavailable")
        }
    }
}
