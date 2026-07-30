import Combine
import Foundation

final class AgentTaskEnvelopeStore: ObservableObject {
    enum StoreError: LocalizedError, Equatable {
        case invalidEnvelope
        case capacityReached
        case revisionConflict
        case immutableIdentity

        var errorDescription: String? {
            switch self {
            case .invalidEnvelope:
                return "The task handoff draft is invalid."
            case .capacityReached:
                return "The local task handoff draft limit has been reached."
            case .revisionConflict:
                return "This task handoff draft changed in another revision."
            case .immutableIdentity:
                return "The task handoff draft identity cannot be changed."
            }
        }
    }

    private struct Document: Codable {
        let schema: String
        let envelopes: [AgentTaskEnvelope]
    }

    static let maximumEnvelopes = 256

    private static let schema = "godexu-task-envelopes-v1"
    private static let documentKeys: Set<String> = ["schema", "envelopes"]
    private static let envelopeKeys: Set<String> = [
        "id",
        "originNodeID",
        "revision",
        "sourceTaskID",
        "sourceRuntime",
        "projectID",
        "projectName",
        "title",
        "targetNodeID",
        "targetRuntime",
        "handoffNote",
        "state",
        "createdAt",
        "updatedAt"
    ]

    @Published private(set) var envelopes: [AgentTaskEnvelope]

    let fileURL: URL

    init(fileURL: URL = AgentTaskEnvelopeStore.defaultFileURL()) {
        self.fileURL = fileURL
        envelopes = Self.load(fileURL: fileURL)
    }

    func upsert(_ envelope: AgentTaskEnvelope) throws {
        guard AgentTaskEnvelope.isValidStoredEnvelope(envelope) else {
            throw StoreError.invalidEnvelope
        }

        var next = envelopes
        if let index = next.firstIndex(where: { $0.id == envelope.id }) {
            let current = next[index]
            if current == envelope {
                return
            }
            guard envelope.originNodeID == current.originNodeID,
                  envelope.sourceTaskID == current.sourceTaskID,
                  envelope.sourceRuntime == current.sourceRuntime,
                  envelope.projectID == current.projectID,
                  envelope.createdAt == current.createdAt
            else {
                throw StoreError.immutableIdentity
            }
            guard envelope.revision == current.revision + 1 else {
                throw StoreError.revisionConflict
            }
            next[index] = envelope
        } else {
            guard envelope.revision == 1 else {
                throw StoreError.revisionConflict
            }
            guard next.count < Self.maximumEnvelopes else {
                throw StoreError.capacityReached
            }
            next.append(envelope)
        }

        next = Self.sorted(next)
        try persist(next)
        envelopes = next
    }

    func delete(id: UUID) throws {
        let next = envelopes.filter { $0.id != id }
        guard next.count != envelopes.count else { return }
        try persist(next)
        envelopes = next
    }

    static func defaultFileURL() -> URL {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return root
            .appendingPathComponent("codexU", isDirectory: true)
            .appendingPathComponent("task-envelopes.json")
    }

    private func persist(_ envelopes: [AgentTaskEnvelope]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let document = Document(schema: Self.schema, envelopes: envelopes)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func load(fileURL: URL) -> [AgentTaskEnvelope] {
        guard let data = try? Data(contentsOf: fileURL),
              hasStrictShape(data)
        else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let document = try? decoder.decode(Document.self, from: data),
              document.schema == schema,
              document.envelopes.count <= maximumEnvelopes,
              document.envelopes.allSatisfy(
                  AgentTaskEnvelope.isValidStoredEnvelope
              )
        else {
            return []
        }
        let identifiers = document.envelopes.map(\.id)
        guard Set(identifiers).count == identifiers.count else { return [] }
        return sorted(document.envelopes)
    }

    private static func hasStrictShape(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let document = object as? [String: Any],
              Set(document.keys) == documentKeys,
              document["schema"] is String,
              let envelopes = document["envelopes"] as? [[String: Any]]
        else {
            return false
        }
        return envelopes.allSatisfy { Set($0.keys) == envelopeKeys }
    }

    private static func sorted(
        _ envelopes: [AgentTaskEnvelope]
    ) -> [AgentTaskEnvelope] {
        envelopes.sorted {
            if $0.updatedAt != $1.updatedAt {
                return $0.updatedAt > $1.updatedAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}
