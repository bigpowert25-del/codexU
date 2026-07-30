import Foundation

public actor ProjectIndexCache {
    public typealias Loader = @Sendable () async throws -> Data

    private struct CachedSnapshot {
        let index: ProjectIndex
        let loadedAt: Date
    }

    private let loader: Loader
    private let freshTTL: TimeInterval
    private let staleTTL: TimeInterval
    private var cached: CachedSnapshot?

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
        do {
            let data = try await loader()
            let index = try ProjectIndexCodec.decode(data)
            cached = CachedSnapshot(index: index, loadedAt: now)
            return index
        } catch {
            if let cached,
               now.timeIntervalSince(cached.loadedAt) <= staleTTL {
                return cached.index.withFreshness(.stale)
            }
            throw PublicSnapshotError(code: "snapshot_unavailable")
        }
    }
}
