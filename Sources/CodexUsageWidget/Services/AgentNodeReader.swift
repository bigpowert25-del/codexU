import Foundation

protocol AgentNodeConfigurationLoading {
    func load() throws -> [AgentNodeDescriptor]
}

protocol AgentNodeProbing {
    func probe(
        _ descriptor: AgentNodeDescriptor
    ) -> Result<AgentNodeProbeObservation, AgentNodeProbeError>
}

protocol AgentNodeSnapshotCaching {
    func load() -> [AgentNodeSnapshot]
    func save(_ snapshots: [AgentNodeSnapshot]) throws
    func staleSnapshot(
        for descriptor: AgentNodeDescriptor,
        from snapshots: [AgentNodeSnapshot],
        now: Date
    ) -> AgentNodeSnapshot?
}

extension AgentNodeConfigurationStore: AgentNodeConfigurationLoading {}
extension AgentNodeProbe: AgentNodeProbing {}
extension AgentNodeSnapshotCache: AgentNodeSnapshotCaching {}

struct AgentNodeReader {
    private let configurationStore: any AgentNodeConfigurationLoading
    private let probe: any AgentNodeProbing
    private let cache: any AgentNodeSnapshotCaching
    private let localDeviceName: () -> String

    init(
        configurationStore: any AgentNodeConfigurationLoading = AgentNodeConfigurationStore(),
        probe: any AgentNodeProbing = AgentNodeProbe(),
        cache: any AgentNodeSnapshotCaching = AgentNodeSnapshotCache(),
        localDeviceName: @escaping () -> String = {
            Host.current().localizedName ?? "Mac"
        }
    ) {
        self.configurationStore = configurationStore
        self.probe = probe
        self.cache = cache
        self.localDeviceName = localDeviceName
    }

    func load(
        codexRuntime: RuntimeUsageSnapshot?,
        now: Date
    ) -> [AgentNodeSnapshot] {
        let local = makeLocalCodexSnapshot(codexRuntime, now: now)
        let descriptors = (try? configurationStore.load()) ?? []
        let cachedSnapshots = cache.load()
        var displayedSnapshots = [local]
        var liveSnapshotsByID = [local.id: local]

        for descriptor in descriptors {
            switch probe.probe(descriptor) {
            case let .success(observation):
                let snapshot = AgentNodeHealthEvaluator.evaluate(observation, now: now)
                displayedSnapshots.append(snapshot)
                liveSnapshotsByID[snapshot.id] = snapshot
            case let .failure(error):
                if let stale = cache.staleSnapshot(
                    for: descriptor,
                    from: cachedSnapshots,
                    now: now
                ) {
                    displayedSnapshots.append(
                        staleSnapshot(stale, failure: error)
                    )
                } else {
                    displayedSnapshots.append(
                        makeUnreachableSnapshot(
                            descriptor,
                            error: error,
                            now: now
                        )
                    )
                }
            }
        }

        let cachedByID = Dictionary(
            cachedSnapshots.map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        let cacheOutput = [local] + descriptors.compactMap { descriptor in
            liveSnapshotsByID[descriptor.id] ?? cachedByID[descriptor.id]
        }
        try? cache.save(cacheOutput)
        return displayedSnapshots
    }

    private func makeLocalCodexSnapshot(
        _ runtime: RuntimeUsageSnapshot?,
        now: Date
    ) -> AgentNodeSnapshot {
        let descriptor = AgentNodeDescriptor(
            id: "local-codex",
            displayName: "Codex",
            deviceName: localDeviceName(),
            runtime: .codex,
            location: .local,
            sshHost: nil,
            probeProfile: nil
        )
        let status = runtime?.status ?? .unavailable
        let health: AgentNodeHealth
        let detailCode: String
        switch status {
        case .available, .localOnly:
            health = .available
            detailCode = "local-runtime-available"
        case .snapshotNeeded:
            health = .degraded
            detailCode = "local-snapshot-needed"
        case .stale:
            health = .stale
            detailCode = "local-runtime-stale"
        case .unavailable:
            health = .unreachable
            detailCode = "local-runtime-unavailable"
        }
        return AgentNodeSnapshot(
            descriptor: descriptor,
            health: health,
            checkedAt: now,
            lastSeenAt: health == .unreachable ? nil : now,
            heartbeatAt: nil,
            processCount: nil,
            sourceLabel: "Local Codex",
            detailCode: detailCode,
            isFromCache: health == .stale
        )
    }

    private func makeUnreachableSnapshot(
        _ descriptor: AgentNodeDescriptor,
        error: AgentNodeProbeError,
        now: Date
    ) -> AgentNodeSnapshot {
        let detailCode: String
        switch error {
        case .timeout:
            detailCode = "probe-timeout"
        case .authentication:
            detailCode = "probe-authentication"
        case .hostKey:
            detailCode = "probe-host-key"
        case .localNetworkDenied:
            detailCode = "probe-local-network"
        case .connectionClosed:
            detailCode = "probe-connection-closed"
        case .nameResolution:
            detailCode = "probe-name-resolution"
        case .processLaunch:
            detailCode = "probe-process-launch"
        case .transportNoDetail:
            detailCode = "probe-transport-no-detail"
        case .transport:
            detailCode = "probe-transport"
        case .protocolError:
            detailCode = "probe-protocol"
        }
        return AgentNodeSnapshot(
            descriptor: descriptor,
            health: .unreachable,
            checkedAt: now,
            lastSeenAt: nil,
            heartbeatAt: nil,
            processCount: nil,
            sourceLabel: "SSH",
            detailCode: detailCode,
            isFromCache: false
        )
    }

    private func staleSnapshot(
        _ snapshot: AgentNodeSnapshot,
        failure: AgentNodeProbeError
    ) -> AgentNodeSnapshot {
        AgentNodeSnapshot(
            descriptor: snapshot.descriptor,
            health: snapshot.health,
            checkedAt: snapshot.checkedAt,
            lastSeenAt: snapshot.lastSeenAt,
            heartbeatAt: snapshot.heartbeatAt,
            processCount: snapshot.processCount,
            sourceLabel: snapshot.sourceLabel,
            detailCode: "live-probe-\(failure.safeCode)",
            isFromCache: snapshot.isFromCache
        )
    }
}

private extension AgentNodeProbeError {
    var safeCode: String {
        switch self {
        case .timeout:
            return "timeout"
        case .authentication:
            return "authentication"
        case .hostKey:
            return "host-key"
        case .localNetworkDenied:
            return "local-network"
        case .connectionClosed:
            return "connection-closed"
        case .nameResolution:
            return "name-resolution"
        case .processLaunch:
            return "process-launch"
        case .transportNoDetail:
            return "transport-no-detail"
        case .transport:
            return "transport"
        case .protocolError:
            return "protocol"
        }
    }
}
