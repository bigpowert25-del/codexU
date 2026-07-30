import Foundation

enum AgentTaskEnvelopeSelfTest {
    static func run() -> Bool {
        let testDate = Date(timeIntervalSince1970: 10_000)
        let envelope = AgentTaskEnvelope.sanitized(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            originNodeID: "local-godexu",
            revision: 1,
            sourceTaskID: "codex-thread-1",
            sourceRuntime: .codex,
            projectID: AgentProjectWorkspaceBuilder.projectID(
                forDerivedName: "Spicy"
            ),
            projectName: "Spicy",
            title: "Review daily package",
            targetNodeID: "nas-hermes",
            targetRuntime: .hermes,
            handoffNote: "Check evidence coverage.",
            state: .draft,
            createdAt: testDate,
            updatedAt: testDate
        )

        let longTitle = String(repeating: "x", count: 180)
        let longNote = (1...10).map { "line \($0)" }.joined(separator: "\n")
        let clamped = AgentTaskEnvelope.sanitized(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            originNodeID: "local-godexu",
            revision: 2,
            sourceTaskID: "codex-thread-2",
            sourceRuntime: .codex,
            projectID: "spicy",
            projectName: "Spicy",
            title: longTitle,
            targetNodeID: "nas-openclaw",
            targetRuntime: .openClaw,
            handoffNote: longNote,
            state: .ready,
            createdAt: testDate,
            updatedAt: testDate.addingTimeInterval(10)
        )
        let invalidID = AgentTaskEnvelope.sanitized(
            id: UUID(),
            originNodeID: "local/godexu",
            revision: 1,
            sourceTaskID: "task",
            sourceRuntime: .codex,
            projectID: "project",
            projectName: "Project",
            title: "Title",
            targetNodeID: "nas-hermes",
            targetRuntime: .hermes,
            handoffNote: "",
            state: .draft,
            createdAt: testDate,
            updatedAt: testDate
        )
        let invalidTime = AgentTaskEnvelope.sanitized(
            id: UUID(),
            originNodeID: "local-godexu",
            revision: 1,
            sourceTaskID: "task",
            sourceRuntime: .codex,
            projectID: "project",
            projectName: "Project",
            title: "Title",
            targetNodeID: "nas-hermes",
            targetRuntime: .hermes,
            handoffNote: "",
            state: .draft,
            createdAt: testDate,
            updatedAt: testDate.addingTimeInterval(-1)
        )
        let invalidRevision = AgentTaskEnvelope.sanitized(
            id: UUID(),
            originNodeID: "local-godexu",
            revision: 0,
            sourceTaskID: "task",
            sourceRuntime: .codex,
            projectID: "project",
            projectName: "Project",
            title: "Title",
            targetNodeID: "nas-hermes",
            targetRuntime: .hermes,
            handoffNote: "",
            state: .draft,
            createdAt: testDate,
            updatedAt: testDate
        )

        let activeTask = makeTask(
            id: "codex-active",
            title: "Active task",
            detail: "Spicy · 10K",
            kind: .active,
            source: .codex,
            updatedAt: testDate.addingTimeInterval(30)
        )
        let doneTask = makeTask(
            id: "codex-done",
            title: "Done task",
            detail: "Spicy · 20K",
            kind: .done,
            source: .codex,
            updatedAt: testDate.addingTimeInterval(40)
        )
        let openClawTask = makeTask(
            id: "openclaw-active",
            title: "Coordinate",
            detail: "high · telegram",
            kind: .active,
            source: .openClaw,
            updatedAt: testDate.addingTimeInterval(20)
        )
        let hermesTask = makeTask(
            id: "hermes-active",
            title: "Review",
            detail: "",
            kind: .active,
            source: .hermes,
            updatedAt: testDate.addingTimeInterval(10)
        )
        let taskBoard = TaskBoard(
            refreshedAt: testDate,
            columns: [
                TaskColumn(id: .active, title: "active", count: 3, items: [
                    activeTask,
                    openClawTask,
                    hermesTask
                ]),
                TaskColumn(id: .done, title: "done", count: 1, items: [doneTask])
            ]
        )
        let workspaces = AgentProjectWorkspaceBuilder.make(
            taskBoard: taskBoard,
            envelopes: envelope.map { [$0] } ?? []
        )
        let spicy = workspaces.first { $0.identity.name == "Spicy" }
        let openClawWorkspace = workspaces.first {
            $0.identity.id == "runtime-openclaw"
        }
        let hermesWorkspace = workspaces.first {
            $0.identity.id == "runtime-hermes"
        }

        let checks = [
            check(envelope?.state == .draft, "valid draft should be accepted"),
            check(envelope?.revision == 1, "revision should be preserved"),
            check(
                AgentTaskEnvelopeState.allCases.map(\.rawValue) == ["draft", "ready"],
                "only local pre-delivery states should exist"
            ),
            check(
                clamped?.title.count == AgentTaskEnvelope.maximumTitleLength,
                "title should be clamped"
            ),
            check(
                clamped?.handoffNote.components(separatedBy: "\n").count
                    == AgentTaskEnvelope.maximumNoteLines,
                "note should keep at most eight lines"
            ),
            check(invalidID == nil, "unsafe identifiers should fail"),
            check(invalidTime == nil, "updated time before created time should fail"),
            check(invalidRevision == nil, "revision should start at one"),
            check(
                spicy?.tasks.map(\.id) == ["codex-active", "codex-done"],
                "active work should sort ahead of completed work"
            ),
            check(spicy?.envelopes.count == 1, "matching handoff should join project"),
            check(
                openClawWorkspace?.identity.name == "OpenClaw workspace",
                "OpenClaw should use a runtime-scoped fallback"
            ),
            check(
                hermesWorkspace?.identity.name == "Hermes workspace",
                "Hermes should use a separate runtime-scoped fallback"
            ),
            check(
                openClawWorkspace?.identity.id != hermesWorkspace?.identity.id,
                "unclassified runtimes should not merge"
            )
        ]

        let passed = checks.allSatisfy { $0 }
        if passed {
            print("agent task envelope self-test passed")
        }
        return passed
    }

    private static func check(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
        guard condition() else {
            fputs("agent task envelope self-test failed: \(message)\n", stderr)
            return false
        }
        return true
    }

    private static func makeTask(
        id: String,
        title: String,
        detail: String,
        kind: TaskColumnKind,
        source: RuntimeScope,
        updatedAt: Date
    ) -> TaskItem {
        TaskItem(
            id: id,
            code: id,
            title: title,
            detail: detail,
            chip: kind.rawValue,
            updatedAt: updatedAt,
            tokens: nil,
            kind: kind,
            source: source,
            summary: nil,
            recentReply: nil,
            timing: nil,
            progress: nil,
            navigationTarget: nil
        )
    }
}
