import Foundation

enum AgentNodeConfigurationError: Error, Equatable {
    case invalidDocument
    case unsupportedSchema
    case tooManyNodes
    case duplicateID
    case invalidIdentifier
    case invalidRuntime
    case invalidProfile
    case incompatibleProfile
}

struct AgentNodeConfigurationStore {
    private struct Document: Decodable {
        let schema: String
        let nodes: [Node]
    }

    private struct Node: Decodable {
        let id: String
        let displayName: String
        let deviceName: String
        let runtime: String
        let sshHost: String
        let networkHost: String?
        let probeProfile: String
    }

    private static let documentKeys: Set<String> = ["schema", "nodes"]
    private static let requiredNodeKeys: Set<String> = [
        "id",
        "displayName",
        "deviceName",
        "runtime",
        "sshHost",
        "probeProfile"
    ]
    private static let allowedNodeKeys = requiredNodeKeys.union(["networkHost"])

    let configurationURL: URL

    init(configurationURL: URL = AgentNodeConfigurationStore.defaultConfigurationURL()) {
        self.configurationURL = configurationURL
    }

    func load() throws -> [AgentNodeDescriptor] {
        guard FileManager.default.fileExists(atPath: configurationURL.path) else {
            return []
        }
        return try Self.decode(Data(contentsOf: configurationURL))
    }

    static func decode(_ data: Data) throws -> [AgentNodeDescriptor] {
        try validateJSONShape(data)
        let document: Document
        do {
            document = try JSONDecoder().decode(Document.self, from: data)
        } catch {
            throw AgentNodeConfigurationError.invalidDocument
        }

        guard document.schema == "godexu-agent-nodes-v1" else {
            throw AgentNodeConfigurationError.unsupportedSchema
        }
        guard document.nodes.count <= 16 else {
            throw AgentNodeConfigurationError.tooManyNodes
        }

        var ids = Set<String>()
        return try document.nodes.map { node in
            guard isSafeIdentifier(node.id),
                  isSafeIdentifier(node.sshHost),
                  node.networkHost.map(isSafeNetworkHost) ?? true,
                  !node.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !node.deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                throw AgentNodeConfigurationError.invalidIdentifier
            }
            guard ids.insert(node.id).inserted else {
                throw AgentNodeConfigurationError.duplicateID
            }
            guard let runtime = RuntimeScope.storedIdentifier(node.runtime),
                  runtime.isCompanionAgent else {
                throw AgentNodeConfigurationError.invalidRuntime
            }
            guard let profile = AgentNodeProbeProfile(rawValue: node.probeProfile) else {
                throw AgentNodeConfigurationError.invalidProfile
            }
            guard profile.isCompatible(with: runtime) else {
                throw AgentNodeConfigurationError.incompatibleProfile
            }
            return AgentNodeDescriptor(
                id: node.id,
                displayName: String(node.displayName.prefix(64)),
                deviceName: String(node.deviceName.prefix(64)),
                runtime: runtime,
                location: .remote,
                sshHost: node.sshHost,
                probeProfile: profile,
                networkHost: node.networkHost
            )
        }
    }

    private static func validateJSONShape(_ data: Data) throws {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let document = object as? [String: Any],
              Set(document.keys) == documentKeys,
              document["schema"] is String,
              let nodes = document["nodes"] as? [[String: Any]]
        else {
            throw AgentNodeConfigurationError.invalidDocument
        }

        for node in nodes {
            let keys = Set(node.keys)
            guard requiredNodeKeys.isSubset(of: keys),
                  keys.isSubset(of: allowedNodeKeys),
                  node.values.allSatisfy({ $0 is String })
            else {
                throw AgentNodeConfigurationError.invalidDocument
            }
        }
    }

    private static func isSafeIdentifier(_ value: String) -> Bool {
        value.range(
            of: #"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$"#,
            options: .regularExpression
        ) != nil
    }

    private static func isSafeNetworkHost(_ value: String) -> Bool {
        value.range(
            of: #"^[A-Za-z0-9][A-Za-z0-9.:-]{0,252}$"#,
            options: .regularExpression
        ) != nil
    }

    private static func defaultConfigurationURL() -> URL {
        if let override = ProcessInfo.processInfo.environment["CODEXU_AGENT_NODES_CONFIG"],
           !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return root
            .appendingPathComponent("codexU", isDirectory: true)
            .appendingPathComponent("nodes.json")
    }
}

private extension AgentNodeProbeProfile {
    func isCompatible(with runtime: RuntimeScope) -> Bool {
        switch (self, runtime) {
        case (.synologyTrimOpenClawV1, .openClaw),
             (.synologyTrimHermesV1, .hermes):
            return true
        default:
            return false
        }
    }
}
