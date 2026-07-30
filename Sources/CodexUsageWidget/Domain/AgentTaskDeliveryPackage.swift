import CryptoKit
import Foundation

struct AgentTaskDeliveryPackage: Identifiable, Codable, Equatable {
    static let schemaIdentifier = "godexu-task-delivery-package-v1"

    let schema: String
    let packageID: UUID
    let envelope: AgentTaskEnvelope
    let preparedAt: Date
    let checksum: String

    var id: UUID { packageID }

    var isValid: Bool {
        schema == Self.schemaIdentifier
            && packageID == envelope.id
            && envelope.state == .ready
            && AgentTaskEnvelope.isValidStoredEnvelope(envelope)
            && preparedAt >= envelope.updatedAt
            && checksum == Self.checksum(
                packageID: packageID,
                envelope: envelope,
                preparedAt: preparedAt
            )
    }

    static func prepared(
        envelope: AgentTaskEnvelope,
        preparedAt: Date
    ) -> AgentTaskDeliveryPackage? {
        guard envelope.state == .ready,
              AgentTaskEnvelope.isValidStoredEnvelope(envelope),
              preparedAt >= envelope.updatedAt
        else {
            return nil
        }
        return AgentTaskDeliveryPackage(
            schema: schemaIdentifier,
            packageID: envelope.id,
            envelope: envelope,
            preparedAt: preparedAt,
            checksum: checksum(
                packageID: envelope.id,
                envelope: envelope,
                preparedAt: preparedAt
            )
        )
    }

    private struct ChecksumPayload: Codable {
        let schema: String
        let packageID: UUID
        let envelope: AgentTaskEnvelope
        let preparedAt: Date
    }

    private static func checksum(
        packageID: UUID,
        envelope: AgentTaskEnvelope,
        preparedAt: Date
    ) -> String {
        let payload = ChecksumPayload(
            schema: schemaIdentifier,
            packageID: packageID,
            envelope: envelope,
            preparedAt: preparedAt
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(payload) else { return "" }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
