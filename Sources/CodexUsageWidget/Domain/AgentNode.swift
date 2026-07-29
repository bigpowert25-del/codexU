import Foundation

enum AgentNodeLocation: String, Codable, Equatable {
    case local
    case remote
}

enum AgentNodeHealth: String, Codable, Equatable {
    case available
    case degraded
    case offline
    case unreachable
    case stale
}

enum AgentNodeProbeProfile: String, Codable, Equatable {
    case synologyTrimOpenClawV1 = "synology-trim-openclaw-v1"
    case synologyTrimHermesV1 = "synology-trim-hermes-v1"
}

struct AgentNodeDescriptor: Identifiable, Codable, Equatable {
    let id: String
    let displayName: String
    let deviceName: String
    let runtime: RuntimeScope
    let location: AgentNodeLocation
    let sshHost: String?
    let probeProfile: AgentNodeProbeProfile?

    var capabilities: [String] {
        switch runtime {
        case .codex:
            return ["coding", "local-usage", "task-observation"]
        case .openClaw:
            return ["orchestration", "memory", "task-routing"]
        case .claudeCode:
            return ["coding", "local-sessions"]
        case .hermes:
            return ["analysis", "review", "research"]
        }
    }
}

struct AgentNodeProbeObservation: Equatable {
    let descriptor: AgentNodeDescriptor
    let checkedAt: Date
    let processCount: Int
    let heartbeatAt: Date?
    let sourceLabel: String
}

struct AgentNodeSnapshot: Identifiable, Codable, Equatable {
    let descriptor: AgentNodeDescriptor
    let health: AgentNodeHealth
    let checkedAt: Date
    let lastSeenAt: Date?
    let heartbeatAt: Date?
    let processCount: Int?
    let sourceLabel: String
    let detailCode: String
    let isFromCache: Bool

    var id: String { descriptor.id }
}

enum AgentNodeHealthEvaluator {
    static let freshHeartbeatInterval: TimeInterval = 15 * 60

    static func evaluate(
        _ observation: AgentNodeProbeObservation,
        now: Date
    ) -> AgentNodeSnapshot {
        guard observation.processCount > 0 else {
            return AgentNodeSnapshot(
                descriptor: observation.descriptor,
                health: .offline,
                checkedAt: observation.checkedAt,
                lastSeenAt: nil,
                heartbeatAt: observation.heartbeatAt,
                processCount: observation.processCount,
                sourceLabel: observation.sourceLabel,
                detailCode: "process-not-running",
                isFromCache: false
            )
        }

        let heartbeatIsFresh = observation.heartbeatAt.map {
            max(0, now.timeIntervalSince($0)) <= freshHeartbeatInterval
        } ?? false
        return AgentNodeSnapshot(
            descriptor: observation.descriptor,
            health: heartbeatIsFresh ? .available : .degraded,
            checkedAt: observation.checkedAt,
            lastSeenAt: observation.checkedAt,
            heartbeatAt: observation.heartbeatAt,
            processCount: observation.processCount,
            sourceLabel: observation.sourceLabel,
            detailCode: heartbeatIsFresh
                ? "process-and-heartbeat"
                : "process-without-fresh-heartbeat",
            isFromCache: false
        )
    }
}
