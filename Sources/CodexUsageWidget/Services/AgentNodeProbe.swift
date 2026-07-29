import Foundation
import Darwin
import Network

protocol AgentNodeCommandExecuting {
    func run(
        executableURL: URL,
        arguments: [String],
        timeout: TimeInterval
    ) -> AgentNodeCommandResult
}

struct AgentNodeCommandResult: Equatable {
    let exitCode: Int32
    let standardOutput: Data
    let standardError: Data
    let timedOut: Bool
}

enum AgentNodeLocalNetworkPreflightResult: Equatable {
    case ready
    case denied
    case unavailable
}

protocol AgentNodeLocalNetworkPreflighting {
    func check(
        host: String,
        port: UInt16,
        timeout: TimeInterval
    ) -> AgentNodeLocalNetworkPreflightResult
}

struct SystemAgentNodeLocalNetworkPreflight: AgentNodeLocalNetworkPreflighting {
    func check(
        host: String,
        port: UInt16,
        timeout: TimeInterval
    ) -> AgentNodeLocalNetworkPreflightResult {
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            return .unavailable
        }

        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: endpointPort,
            using: .tcp
        )
        let completion = DispatchSemaphore(value: 0)
        let queue = DispatchQueue(label: "codexu.agent-node.local-network")
        var result = AgentNodeLocalNetworkPreflightResult.unavailable
        var completed = false

        connection.stateUpdateHandler = { state in
            guard !completed else { return }
            switch state {
            case .ready:
                completed = true
                result = .ready
                completion.signal()
            case .waiting:
                if #available(macOS 15.0, *),
                   connection.currentPath?.unsatisfiedReason == .localNetworkDenied {
                    completed = true
                    result = .denied
                    completion.signal()
                }
            case .failed:
                completed = true
                result = .unavailable
                completion.signal()
            default:
                break
            }
        }
        connection.start(queue: queue)
        _ = completion.wait(timeout: .now() + timeout)
        connection.cancel()
        return result
    }
}

enum AgentNodeProbeError: Error, Equatable {
    case timeout
    case authentication
    case hostKey
    case localNetworkDenied
    case connectionClosed
    case nameResolution
    case processLaunch
    case transportNoDetail
    case transport
    case protocolError
}

struct SystemAgentNodeCommandExecutor: AgentNodeCommandExecuting {
    func run(
        executableURL: URL,
        arguments: [String],
        timeout: TimeInterval
    ) -> AgentNodeCommandResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()

        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
        } catch {
            return AgentNodeCommandResult(
                exitCode: 127,
                standardOutput: Data(),
                standardError: Data(),
                timedOut: false
            )
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        let timedOut = process.isRunning
        if timedOut {
            process.terminate()
            let terminationDeadline = Date().addingTimeInterval(1)
            while process.isRunning && Date() < terminationDeadline {
                Thread.sleep(forTimeInterval: 0.02)
            }
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
                let killDeadline = Date().addingTimeInterval(0.5)
                while process.isRunning && Date() < killDeadline {
                    Thread.sleep(forTimeInterval: 0.02)
                }
            }
        }

        let stopped = !process.isRunning
        return AgentNodeCommandResult(
            exitCode: timedOut || !stopped ? 255 : process.terminationStatus,
            standardOutput: stopped
                ? standardOutput.fileHandleForReading.readDataToEndOfFile()
                : Data(),
            standardError: stopped
                ? standardError.fileHandleForReading.readDataToEndOfFile()
                : Data(),
            timedOut: timedOut
        )
    }
}

struct AgentNodeProbe {
    private static let outputLimit = 32 * 1_024
    private static let timeout: TimeInterval = 6
    private static let sshExecutableURL = URL(fileURLWithPath: "/usr/bin/ssh")
    private static let protocolKeys: Set<String> = [
        "schema",
        "host",
        "process_count",
        "heartbeat_epoch",
        "observed_epoch"
    ]

    private let executor: any AgentNodeCommandExecuting
    private let localNetworkPreflight: any AgentNodeLocalNetworkPreflighting

    init(
        executor: any AgentNodeCommandExecuting = SystemAgentNodeCommandExecutor(),
        localNetworkPreflight: any AgentNodeLocalNetworkPreflighting =
            SystemAgentNodeLocalNetworkPreflight()
    ) {
        self.executor = executor
        self.localNetworkPreflight = localNetworkPreflight
    }

    func probe(
        _ descriptor: AgentNodeDescriptor
    ) -> Result<AgentNodeProbeObservation, AgentNodeProbeError> {
        guard descriptor.location == .remote,
              let sshHost = descriptor.sshHost,
              isSafeSSHHost(sshHost),
              let profile = descriptor.probeProfile
        else {
            return .failure(.protocolError)
        }

        if let networkHost = descriptor.networkHost,
           localNetworkPreflight.check(
               host: networkHost,
               port: 22,
               timeout: Self.timeout
           ) == .denied {
            return .failure(.localNetworkDenied)
        }

        let arguments = [
            "-T",
            "-o", "BatchMode=yes",
            "-o", "StrictHostKeyChecking=yes",
            "-o", "ConnectionAttempts=1",
            "-o", "ConnectTimeout=4",
            sshHost,
            profile.remoteCommand
        ]
        let result = executor.run(
            executableURL: Self.sshExecutableURL,
            arguments: arguments,
            timeout: Self.timeout
        )
        guard result.standardOutput.count <= Self.outputLimit,
              result.standardError.count <= Self.outputLimit
        else {
            return .failure(.protocolError)
        }
        guard !result.timedOut else {
            return .failure(.timeout)
        }
        guard result.exitCode == 0 else {
            return .failure(classifyFailure(result))
        }
        return parse(result.standardOutput, descriptor: descriptor)
    }

    private func parse(
        _ data: Data,
        descriptor: AgentNodeDescriptor
    ) -> Result<AgentNodeProbeObservation, AgentNodeProbeError> {
        guard let text = String(data: data, encoding: .utf8) else {
            return .failure(.protocolError)
        }

        var values: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let components = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard components.count == 2 else {
                return .failure(.protocolError)
            }
            let key = String(components[0])
            let value = String(components[1])
            guard Self.protocolKeys.contains(key), values[key] == nil else {
                return .failure(.protocolError)
            }
            values[key] = value
        }

        guard Set(values.keys) == Self.protocolKeys,
              values["schema"] == "godexu-node-probe-v1",
              let host = values["host"],
              isSafeRemoteHostLabel(host),
              let processText = values["process_count"],
              let processCount = Int(processText),
              processCount >= 0,
              processCount <= 1_000_000,
              let heartbeatText = values["heartbeat_epoch"],
              let heartbeatEpoch = TimeInterval(heartbeatText),
              heartbeatEpoch >= 0,
              let observedText = values["observed_epoch"],
              let observedEpoch = TimeInterval(observedText),
              observedEpoch > 0
        else {
            return .failure(.protocolError)
        }

        return .success(
            AgentNodeProbeObservation(
                descriptor: descriptor,
                checkedAt: Date(timeIntervalSince1970: observedEpoch),
                processCount: processCount,
                heartbeatAt: heartbeatEpoch > 0
                    ? Date(timeIntervalSince1970: heartbeatEpoch)
                    : nil,
                sourceLabel: "SSH · \(host)"
            )
        )
    }

    private func classifyFailure(_ result: AgentNodeCommandResult) -> AgentNodeProbeError {
        if result.exitCode == 127 {
            return .processLaunch
        }
        guard !result.standardError.isEmpty else {
            return .transportNoDetail
        }
        guard let text = String(data: result.standardError, encoding: .utf8)?.lowercased() else {
            return .transport
        }
        if text.contains("permission denied")
            || text.contains("authentication failed")
            || text.contains("no supported authentication") {
            return .authentication
        }
        if text.contains("host key verification failed")
            || text.contains("remote host identification has changed") {
            return .hostKey
        }
        if text.contains("operation not permitted") {
            return .localNetworkDenied
        }
        if text.contains("could not resolve hostname") {
            return .nameResolution
        }
        if text.contains("connection closed") {
            return .connectionClosed
        }
        return .transport
    }

    private func isSafeSSHHost(_ value: String) -> Bool {
        value.range(
            of: #"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$"#,
            options: .regularExpression
        ) != nil
    }

    private func isSafeRemoteHostLabel(_ value: String) -> Bool {
        value.range(
            of: #"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$"#,
            options: .regularExpression
        ) != nil
    }
}

private extension AgentNodeProbeProfile {
    var remoteCommand: String {
        switch self {
        case .synologyTrimOpenClawV1:
            return #"LC_ALL=C; count=$(ps -eo comm= 2>/dev/null | awk '$1=="openclaw"{n++} END{print n+0}'); heartbeat=$(stat -c %Y /vol1/1000/openclaw/tongbu/health/openclaw.json 2>/dev/null || echo 0); now=$(date +%s); printf 'schema=godexu-node-probe-v1\nhost=%s\nprocess_count=%s\nheartbeat_epoch=%s\nobserved_epoch=%s\n' "$(hostname)" "$count" "$heartbeat" "$now""#
        case .synologyTrimHermesV1:
            return #"LC_ALL=C; count=$(ps -eo comm= 2>/dev/null | awk '$1=="hermes"{n++} END{print n+0}'); heartbeat=$(stat -c %Y /vol1/@appdata/trim.hermes/trim.hermes.log 2>/dev/null || echo 0); now=$(date +%s); printf 'schema=godexu-node-probe-v1\nhost=%s\nprocess_count=%s\nheartbeat_epoch=%s\nobserved_epoch=%s\n' "$(hostname)" "$count" "$heartbeat" "$now""#
        }
    }
}
