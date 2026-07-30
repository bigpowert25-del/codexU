import Combine
import Foundation

final class AgentTaskDeliveryOutbox: ObservableObject {
    enum OutboxError: LocalizedError, Equatable {
        case envelopeNotReady
        case invalidPackage
        case capacityReached

        var errorDescription: String? {
            switch self {
            case .envelopeNotReady:
                return "The handoff must be locally ready before packaging."
            case .invalidPackage:
                return "The local delivery package is invalid."
            case .capacityReached:
                return "The local delivery outbox limit has been reached."
            }
        }
    }

    static let maximumPackages = AgentTaskEnvelopeStore.maximumEnvelopes

    private static let documentKeys: Set<String> = [
        "schema",
        "packageID",
        "envelope",
        "preparedAt",
        "checksum"
    ]
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

    @Published private(set) var packages: [AgentTaskDeliveryPackage]

    let directoryURL: URL

    init(directoryURL: URL = AgentTaskDeliveryOutbox.defaultDirectoryURL()) {
        self.directoryURL = directoryURL
        packages = Self.load(directoryURL: directoryURL)
    }

    @discardableResult
    func prepare(
        envelope: AgentTaskEnvelope,
        now: Date = Date()
    ) throws -> AgentTaskDeliveryPackage {
        guard envelope.state == .ready else {
            throw OutboxError.envelopeNotReady
        }
        if let existing = package(for: envelope.id),
           existing.envelope == envelope {
            try enforcePrivatePermissions(for: envelope.id)
            return existing
        }
        guard let package = AgentTaskDeliveryPackage.prepared(
            envelope: envelope,
            preparedAt: now
        ), package.isValid else {
            throw OutboxError.invalidPackage
        }
        guard self.package(for: envelope.id) != nil
            || packages.count < Self.maximumPackages
        else {
            throw OutboxError.capacityReached
        }

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directoryURL.path
        )
        let data = try Self.encoder().encode(package)
        try data.write(to: fileURL(for: envelope.id), options: .atomic)
        try enforcePrivatePermissions(for: envelope.id)
        packages.removeAll { $0.packageID == package.packageID }
        packages.append(package)
        packages = Self.sorted(packages)
        return package
    }

    func package(
        for envelopeID: UUID,
        revision: Int? = nil
    ) -> AgentTaskDeliveryPackage? {
        packages.first {
            $0.envelope.id == envelopeID
                && (revision == nil || $0.envelope.revision == revision)
        }
    }

    func cancel(envelopeID: UUID) throws {
        let fileURL = fileURL(for: envelopeID)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        packages.removeAll { $0.envelope.id == envelopeID }
    }

    static func defaultDirectoryURL() -> URL {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return root
            .appendingPathComponent("codexU", isDirectory: true)
            .appendingPathComponent("delivery-outbox", isDirectory: true)
            .appendingPathComponent("pending", isDirectory: true)
    }

    private func fileURL(for envelopeID: UUID) -> URL {
        directoryURL.appendingPathComponent(
            "\(envelopeID.uuidString.lowercased()).json"
        )
    }

    private func enforcePrivatePermissions(for envelopeID: UUID) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL(for: envelopeID).path
        )
    }

    private static func load(
        directoryURL: URL
    ) -> [AgentTaskDeliveryPackage] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        let packageURLs = urls.filter { $0.pathExtension.lowercased() == "json" }
        guard packageURLs.count <= maximumPackages else { return [] }
        let loaded = packageURLs.compactMap { url -> AgentTaskDeliveryPackage? in
            guard let data = try? Data(contentsOf: url),
                  hasStrictShape(data),
                  let package = try? decoder().decode(
                    AgentTaskDeliveryPackage.self,
                    from: data
                  ),
                  package.isValid,
                  url.deletingPathExtension().lastPathComponent
                    == package.packageID.uuidString.lowercased()
            else {
                return nil
            }
            return package
        }
        guard Set(loaded.map(\.packageID)).count == loaded.count else {
            return []
        }
        return sorted(loaded)
    }

    private static func hasStrictShape(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let document = object as? [String: Any],
              Set(document.keys) == documentKeys,
              let envelope = document["envelope"] as? [String: Any],
              Set(envelope.keys) == envelopeKeys
        else {
            return false
        }
        return true
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func sorted(
        _ packages: [AgentTaskDeliveryPackage]
    ) -> [AgentTaskDeliveryPackage] {
        packages.sorted {
            if $0.preparedAt != $1.preparedAt {
                return $0.preparedAt > $1.preparedAt
            }
            return $0.packageID.uuidString < $1.packageID.uuidString
        }
    }
}
