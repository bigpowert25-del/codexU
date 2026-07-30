import Combine
import Foundation

final class AgentIdentityProfileStore: ObservableObject {
    enum StoreError: LocalizedError {
        case invalidProfile
        case capacityReached

        var errorDescription: String? {
            switch self {
            case .invalidProfile:
                return "The Agent profile is invalid."
            case .capacityReached:
                return "The Agent profile limit has been reached."
            }
        }
    }

    private struct Document: Codable {
        let schema: String
        let profiles: [AgentIdentityProfile]
    }

    private static let schema = "godexu-agent-profiles-v1"
    private static let maximumProfiles = 32
    private static let documentKeys: Set<String> = ["schema", "profiles"]
    private static let profileKeys: Set<String> = [
        "nodeID",
        "runtime",
        "roleName",
        "responsibility",
        "policyLevel",
        "updatedAt"
    ]

    @Published private(set) var overrides: [String: AgentIdentityProfile]

    let fileURL: URL

    init(fileURL: URL = AgentIdentityProfileStore.defaultFileURL()) {
        self.fileURL = fileURL
        overrides = Self.load(fileURL: fileURL)
    }

    func profile(
        nodeID: String,
        runtime: RuntimeScope,
        now: Date
    ) -> AgentIdentityProfile {
        if let stored = overrides[nodeID], stored.runtime == runtime {
            return stored
        }
        return AgentIdentityProfile.defaultProfile(
            nodeID: nodeID,
            runtime: runtime,
            now: now
        )
    }

    func save(_ profile: AgentIdentityProfile) throws {
        guard AgentIdentityProfile.isValidStoredProfile(profile) else {
            throw StoreError.invalidProfile
        }
        if overrides[profile.nodeID] == nil,
           overrides.count >= Self.maximumProfiles {
            throw StoreError.capacityReached
        }
        var next = overrides
        next[profile.nodeID] = profile
        try persist(next)
        overrides = next
    }

    func reset(nodeID: String) throws {
        guard overrides[nodeID] != nil else { return }
        var next = overrides
        next.removeValue(forKey: nodeID)
        try persist(next)
        overrides = next
    }

    static func defaultFileURL() -> URL {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return root
            .appendingPathComponent("codexU", isDirectory: true)
            .appendingPathComponent("agent-profiles.json")
    }

    private func persist(_ profilesByID: [String: AgentIdentityProfile]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let document = Document(
            schema: Self.schema,
            profiles: profilesByID.values.sorted { $0.nodeID < $1.nodeID }
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func load(fileURL: URL) -> [String: AgentIdentityProfile] {
        guard let data = try? Data(contentsOf: fileURL),
              hasStrictShape(data)
        else {
            return [:]
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let document = try? decoder.decode(Document.self, from: data),
              document.schema == schema,
              document.profiles.count <= maximumProfiles,
              document.profiles.allSatisfy(AgentIdentityProfile.isValidStoredProfile)
        else {
            return [:]
        }
        let identifiers = document.profiles.map(\.nodeID)
        guard Set(identifiers).count == identifiers.count else { return [:] }
        return Dictionary(
            uniqueKeysWithValues: document.profiles.map { ($0.nodeID, $0) }
        )
    }

    private static func hasStrictShape(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let document = object as? [String: Any],
              Set(document.keys) == documentKeys,
              let profiles = document["profiles"] as? [[String: Any]]
        else {
            return false
        }
        return profiles.allSatisfy { Set($0.keys) == profileKeys }
    }
}
