import Foundation

enum AgentTaskDeliveryPackageSelfTest {
    static func run() -> Bool {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("godexu-delivery-outbox-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        do {
            let outbox = AgentTaskDeliveryOutbox(directoryURL: root)
            guard check(outbox.packages.isEmpty, "new outbox should be empty") else {
                return false
            }

            let draft = makeEnvelope(state: .draft)
            do {
                _ = try outbox.prepare(envelope: draft, now: draft.updatedAt)
                return fail("draft envelope should not prepare a package")
            } catch AgentTaskDeliveryOutbox.OutboxError.envelopeNotReady {
            }

            let ready = makeEnvelope(state: .ready)
            let prepared = try outbox.prepare(
                envelope: ready,
                now: ready.updatedAt.addingTimeInterval(5)
            )
            let packagePermissions = try filePermissions(
                at: packageFileURL(in: root)
            )
            let directoryPermissions = try filePermissions(at: root)
            guard check(
                prepared.packageID == ready.id,
                "package identity should be stable per envelope"
            ), check(
                prepared.envelope == ready,
                "package should snapshot the ready envelope"
            ), check(
                prepared.checksum.count == 64,
                "package should carry a SHA-256 checksum"
            ), check(
                prepared.isValid,
                "prepared package should validate"
            ), check(
                packagePermissions == 0o600,
                "package file should be private to the local user"
            ), check(
                directoryPermissions == 0o700,
                "outbox directory should be private to the local user"
            ) else {
                return false
            }

            let repeated = try outbox.prepare(
                envelope: ready,
                now: ready.updatedAt.addingTimeInterval(30)
            )
            guard check(
                repeated == prepared,
                "same envelope revision should prepare idempotently"
            ) else {
                return false
            }

            let reloaded = AgentTaskDeliveryOutbox(directoryURL: root)
            guard check(
                reloaded.packages == [prepared],
                "prepared package should reload"
            ) else {
                return false
            }
            try addUnknownPackageField(at: root)
            guard check(
                AgentTaskDeliveryOutbox(directoryURL: root).packages.isEmpty,
                "unknown package fields should fail closed"
            ) else {
                return false
            }
            try preparedData(prepared).write(
                to: packageFileURL(in: root),
                options: .atomic
            )

            let revised = makeEnvelope(
                revision: 2,
                note: "Review the revised evidence.",
                state: .ready,
                updatedAt: ready.updatedAt.addingTimeInterval(20)
            )
            let replacement = try reloaded.prepare(
                envelope: revised,
                now: revised.updatedAt.addingTimeInterval(5)
            )
            guard check(
                reloaded.packages == [replacement],
                "new envelope revision should replace the pending package"
            ), check(
                replacement.checksum != prepared.checksum,
                "revised package should have a different checksum"
            ) else {
                return false
            }

            try tamperWithPackage(at: root)
            guard check(
                AgentTaskDeliveryOutbox(directoryURL: root).packages.isEmpty,
                "tampered package should fail closed"
            ) else {
                return false
            }

            let restored = AgentTaskDeliveryOutbox(directoryURL: root)
            _ = try restored.prepare(
                envelope: revised,
                now: revised.updatedAt.addingTimeInterval(5)
            )
            try restored.cancel(envelopeID: revised.id)
            guard check(
                restored.packages.isEmpty,
                "cancel should remove the pending package"
            ), check(
                !FileManager.default.fileExists(
                    atPath: root
                        .appendingPathComponent("\(revised.id.uuidString.lowercased()).json")
                        .path
                ),
                "cancel should remove the package file"
            ) else {
                return false
            }
        } catch {
            return fail("unexpected outbox error: \(error.localizedDescription)")
        }

        print("agent task delivery package self-test passed")
        return true
    }

    private static func makeEnvelope(
        revision: Int = 1,
        note: String = "Check the evidence package.",
        state: AgentTaskEnvelopeState,
        updatedAt: Date = Date(timeIntervalSince1970: 20_000)
    ) -> AgentTaskEnvelope {
        AgentTaskEnvelope.sanitized(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            originNodeID: "local-godexu",
            revision: revision,
            sourceTaskID: "codex-thread-2",
            sourceRuntime: .codex,
            projectID: "project-spicy",
            projectName: "Spicy",
            title: "Review daily evidence",
            targetNodeID: "nas-hermes",
            targetRuntime: .hermes,
            handoffNote: note,
            state: state,
            createdAt: Date(timeIntervalSince1970: 20_000),
            updatedAt: updatedAt
        )!
    }

    private static func tamperWithPackage(at directoryURL: URL) throws {
        let fileURL = packageFileURL(in: directoryURL)
        var document = try JSONSerialization.jsonObject(
            with: Data(contentsOf: fileURL)
        ) as! [String: Any]
        document["checksum"] = String(repeating: "0", count: 64)
        try JSONSerialization.data(
            withJSONObject: document,
            options: [.prettyPrinted, .sortedKeys]
        ).write(to: fileURL, options: .atomic)
    }

    private static func addUnknownPackageField(
        at directoryURL: URL
    ) throws {
        let fileURL = packageFileURL(in: directoryURL)
        var document = try JSONSerialization.jsonObject(
            with: Data(contentsOf: fileURL)
        ) as! [String: Any]
        document["deliveryState"] = "sent"
        try JSONSerialization.data(
            withJSONObject: document,
            options: [.prettyPrinted, .sortedKeys]
        ).write(to: fileURL, options: .atomic)
    }

    private static func preparedData(
        _ package: AgentTaskDeliveryPackage
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(package)
    }

    private static func packageFileURL(in directoryURL: URL) -> URL {
        directoryURL.appendingPathComponent(
            "22222222-2222-2222-2222-222222222222.json"
        )
    }

    private static func filePermissions(at url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(
            atPath: url.path
        )
        return (attributes[.posixPermissions] as? NSNumber)?.intValue ?? -1
    }

    private static func check(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) -> Bool {
        guard condition() else { return fail(message) }
        return true
    }

    private static func fail(_ message: String) -> Bool {
        fputs("agent task delivery package self-test failed: \(message)\n", stderr)
        return false
    }
}
