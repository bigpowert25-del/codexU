import Foundation

enum AgentTaskEnvelopeStoreSelfTest {
    static func run() -> Bool {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codexu-envelope-store-\(UUID().uuidString)")
        let fileURL = root.appendingPathComponent("task-envelopes.json")
        defer { try? FileManager.default.removeItem(at: root) }

        do {
            let store = AgentTaskEnvelopeStore(fileURL: fileURL)
            guard check(store.envelopes.isEmpty, "missing file should load empty") else {
                return false
            }

            let original = makeEnvelope(revision: 1)
            try store.upsert(original)
            guard check(store.envelopes == [original], "new draft should persist") else {
                return false
            }

            let reloaded = AgentTaskEnvelopeStore(fileURL: fileURL)
            guard check(reloaded.envelopes == [original], "saved draft should reload") else {
                return false
            }

            try reloaded.upsert(original)
            guard check(
                reloaded.envelopes == [original],
                "same revision and body should be idempotent"
            ) else {
                return false
            }

            let updated = makeEnvelope(
                revision: 2,
                note: "Hermes checks the evidence package.",
                state: .ready,
                updatedAt: original.updatedAt.addingTimeInterval(10)
            )
            try reloaded.upsert(updated)
            guard check(
                reloaded.envelopes == [updated],
                "next revision should replace the draft"
            ) else {
                return false
            }

            do {
                try reloaded.upsert(original)
                return fail("stale revision should be rejected")
            } catch AgentTaskEnvelopeStore.StoreError.revisionConflict {
            }

            let changedSameRevision = makeEnvelope(
                revision: 2,
                note: "Changed without a new revision.",
                state: .ready,
                updatedAt: updated.updatedAt
            )
            do {
                try reloaded.upsert(changedSameRevision)
                return fail("changed body at the same revision should be rejected")
            } catch AgentTaskEnvelopeStore.StoreError.revisionConflict {
            }

            let changedOrigin = makeEnvelope(
                originNodeID: "other-node",
                revision: 3,
                note: updated.handoffNote,
                state: updated.state,
                updatedAt: updated.updatedAt.addingTimeInterval(10)
            )
            do {
                try reloaded.upsert(changedOrigin)
                return fail("origin node should remain immutable")
            } catch AgentTaskEnvelopeStore.StoreError.immutableIdentity {
            }

            try reloaded.delete(id: updated.id)
            guard check(reloaded.envelopes.isEmpty, "delete should persist") else {
                return false
            }

            try verifyStrictLoading(fileURL: fileURL)
            try verifyCapacity(root: root)
        } catch {
            return fail("unexpected store error: \(error.localizedDescription)")
        }

        print("agent task envelope store self-test passed")
        return true
    }

    private static func verifyStrictLoading(fileURL: URL) throws {
        let unknownDocument = """
        {"schema":"godexu-task-envelopes-v1","envelopes":[],"sent":true}
        """
        try Data(unknownDocument.utf8).write(to: fileURL)
        guard check(
            AgentTaskEnvelopeStore(fileURL: fileURL).envelopes.isEmpty,
            "unknown document keys should fail closed"
        ) else {
            throw TestFailure()
        }

        let unknownEnvelope = """
        {
          "schema":"godexu-task-envelopes-v1",
          "envelopes":[{
            "id":"11111111-1111-1111-1111-111111111111",
            "originNodeID":"local-godexu",
            "revision":1,
            "sourceTaskID":"codex-thread-1",
            "sourceRuntime":"codex",
            "projectID":"project-spicy",
            "projectName":"Spicy",
            "title":"Review",
            "targetNodeID":"nas-hermes",
            "targetRuntime":"hermes",
            "handoffNote":"",
            "state":"draft",
            "createdAt":"1970-01-01T02:46:40Z",
            "updatedAt":"1970-01-01T02:46:40Z",
            "deliveryState":"sent"
          }]
        }
        """
        try Data(unknownEnvelope.utf8).write(to: fileURL)
        guard check(
            AgentTaskEnvelopeStore(fileURL: fileURL).envelopes.isEmpty,
            "transport-like fields should fail closed"
        ) else {
            throw TestFailure()
        }

        try Data("{not-json".utf8).write(to: fileURL)
        guard check(
            AgentTaskEnvelopeStore(fileURL: fileURL).envelopes.isEmpty,
            "malformed JSON should fail closed"
        ) else {
            throw TestFailure()
        }
    }

    private static func verifyCapacity(root: URL) throws {
        let fileURL = root.appendingPathComponent("capacity.json")
        let store = AgentTaskEnvelopeStore(fileURL: fileURL)
        for index in 0..<AgentTaskEnvelopeStore.maximumEnvelopes {
            let id = UUID(uuidString: String(
                format: "00000000-0000-0000-0000-%012d",
                index
            ))!
            try store.upsert(makeEnvelope(id: id, sourceTaskID: "task-\(index)"))
        }
        do {
            try store.upsert(makeEnvelope(id: UUID(), sourceTaskID: "overflow"))
            throw TestFailure()
        } catch AgentTaskEnvelopeStore.StoreError.capacityReached {
        }
    }

    private static func makeEnvelope(
        id: UUID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        originNodeID: String = "local-godexu",
        revision: Int = 1,
        sourceTaskID: String = "codex-thread-1",
        note: String = "Check the evidence package.",
        state: AgentTaskEnvelopeState = .draft,
        updatedAt: Date = Date(timeIntervalSince1970: 10_000)
    ) -> AgentTaskEnvelope {
        AgentTaskEnvelope.sanitized(
            id: id,
            originNodeID: originNodeID,
            revision: revision,
            sourceTaskID: sourceTaskID,
            sourceRuntime: .codex,
            projectID: AgentProjectWorkspaceBuilder.projectID(
                forDerivedName: "Spicy"
            ),
            projectName: "Spicy",
            title: "Review daily package",
            targetNodeID: "nas-hermes",
            targetRuntime: .hermes,
            handoffNote: note,
            state: state,
            createdAt: Date(timeIntervalSince1970: 10_000),
            updatedAt: updatedAt
        )!
    }

    private static func check(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
        guard condition() else { return fail(message) }
        return true
    }

    private static func fail(_ message: String) -> Bool {
        fputs("agent task envelope store self-test failed: \(message)\n", stderr)
        return false
    }

    private struct TestFailure: Error {}
}
