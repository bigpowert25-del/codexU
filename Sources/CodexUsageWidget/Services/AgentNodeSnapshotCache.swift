import Foundation

struct AgentNodeSnapshotCache {
    private struct Document: Codable {
        let version: Int
        let snapshots: [AgentNodeSnapshot]
    }

    private static let version = 1
    private static let maximumStaleAge: TimeInterval = 24 * 60 * 60

    let cacheURL: URL

    init(cacheURL: URL = AgentNodeSnapshotCache.defaultCacheURL()) {
        self.cacheURL = cacheURL
    }

    func load() -> [AgentNodeSnapshot] {
        guard let data = try? Data(contentsOf: cacheURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let document = try? decoder.decode(Document.self, from: data),
              document.version == Self.version
        else {
            return []
        }
        return document.snapshots
    }

    func save(_ snapshots: [AgentNodeSnapshot]) throws {
        let directory = cacheURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(
            Document(version: Self.version, snapshots: snapshots)
        )
        try data.write(to: cacheURL, options: .atomic)
    }

    func staleSnapshot(
        for descriptor: AgentNodeDescriptor,
        from snapshots: [AgentNodeSnapshot],
        now: Date
    ) -> AgentNodeSnapshot? {
        guard let cached = snapshots.first(where: { $0.id == descriptor.id }),
              cached.health != .unreachable,
              cached.health != .stale,
              max(0, now.timeIntervalSince(cached.checkedAt)) <= Self.maximumStaleAge
        else {
            return nil
        }

        let sourceLabel = cached.sourceLabel.hasSuffix(" · cached")
            ? cached.sourceLabel
            : "\(cached.sourceLabel) · cached"
        return AgentNodeSnapshot(
            descriptor: descriptor,
            health: .stale,
            checkedAt: now,
            lastSeenAt: cached.lastSeenAt,
            heartbeatAt: cached.heartbeatAt,
            processCount: cached.processCount,
            sourceLabel: sourceLabel,
            detailCode: "live-probe-failed",
            isFromCache: true
        )
    }

    private static func defaultCacheURL() -> URL {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Caches", isDirectory: true)
        return root
            .appendingPathComponent("codexU", isDirectory: true)
            .appendingPathComponent("agent-node-snapshots.json")
    }
}
