import Foundation

enum GodexUProjectIndexReaderSelfTest {
    static func run() -> Bool {
        var failures: [String] = []
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "godexu-project-index-reader-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? fileManager.removeItem(at: root) }

        do {
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            let transcriptSentinel = "TRANSCRIPT_SENTINEL_DO_NOT_READ"
            let noteSentinel = "HANDOFF_NOTE_SENTINEL_DO_NOT_EMIT"
            let codexDirectory = root.appendingPathComponent(
                ".codex",
                isDirectory: true
            )
            let openClawSessions = root.appendingPathComponent(
                ".openclaw/agents/main/sessions",
                isDirectory: true
            )
            let openClawMemory = root.appendingPathComponent(
                ".openclaw/workspace/memory",
                isDirectory: true
            )
            try fileManager.createDirectory(
                at: codexDirectory,
                withIntermediateDirectories: true
            )
            try fileManager.createDirectory(
                at: openClawSessions,
                withIntermediateDirectories: true
            )
            try fileManager.createDirectory(
                at: openClawMemory,
                withIntermediateDirectories: true
            )

            let codexTranscript = codexDirectory.appendingPathComponent(
                "secret-transcript.jsonl"
            )
            try transcriptSentinel.write(
                to: codexTranscript,
                atomically: true,
                encoding: .utf8
            )
            let databaseURL = codexDirectory.appendingPathComponent(
                "state_5.sqlite"
            )
            try createCodexDatabase(
                at: databaseURL,
                transcriptPath: codexTranscript.path,
                updatedAt: Int(now.timeIntervalSince1970)
            )

            let openClawTranscript = openClawSessions.appendingPathComponent(
                "secret-transcript.jsonl"
            )
            try transcriptSentinel.write(
                to: openClawTranscript,
                atomically: true,
                encoding: .utf8
            )
            let tasks: [[String: Any]] = [[
                "id": "openclaw-native-secret",
                "title": "Safe OpenClaw task",
                "status": "in_progress",
                "updatedAt": "2027-01-15T08:00:00Z",
                "progress": 30,
                "summary": transcriptSentinel
            ]]
            try writeJSON(
                tasks,
                to: openClawMemory.appendingPathComponent("tasks.json")
            )
            let sessions: [String: Any] = [
                "agent:main:session-secret": [
                    "sessionId": "openclaw-session-native-secret",
                    "updatedAt": Int(now.timeIntervalSince1970 * 1_000),
                    "status": "active",
                    "sessionFile": openClawTranscript.path,
                    "channel": "local",
                    "model": "safe-model"
                ]
            ]
            try writeJSON(
                sessions,
                to: openClawSessions.appendingPathComponent("sessions.json")
            )

            let envelopeURL = root.appendingPathComponent(
                "Library/Application Support/codexU/task-envelopes.json"
            )
            let envelopeStore = AgentTaskEnvelopeStore(fileURL: envelopeURL)
            let projectID = AgentProjectWorkspaceBuilder.projectID(
                forDerivedName: "Fixture Workspace"
            )
            let envelope = AgentTaskEnvelope.sanitized(
                id: UUID(
                    uuidString: "00000000-0000-0000-0000-000000000002"
                )!,
                originNodeID: "local-codex",
                revision: 1,
                sourceTaskID: "private-source-task",
                sourceRuntime: .codex,
                projectID: projectID,
                projectName: "Fixture Workspace",
                title: "Safe handoff title",
                targetNodeID: "nas-openclaw",
                targetRuntime: .openClaw,
                handoffNote: noteSentinel,
                state: .ready,
                createdAt: now.addingTimeInterval(-60),
                updatedAt: now
            )!
            try envelopeStore.upsert(envelope)

            let index = GodexUProjectIndexReader(
                homeDirectory: root,
                envelopeFileURL: envelopeURL,
                now: now
            ).load()
            let data = try GodexUProjectIndexCodec.encode(index)
            let text = String(decoding: data, as: UTF8.self)

            check(
                text.contains("Safe Codex title"),
                "Codex metadata is missing",
                failures: &failures
            )
            check(
                text.contains("Safe OpenClaw task"),
                "OpenClaw task metadata is missing",
                failures: &failures
            )
            check(
                text.contains("OpenClaw Session"),
                "neutral OpenClaw session label is missing",
                failures: &failures
            )
            check(
                text.contains("Safe handoff title"),
                "handoff metadata is missing",
                failures: &failures
            )
            check(
                !text.contains(transcriptSentinel),
                "transcript or non-allowlisted task content leaked",
                failures: &failures
            )
            check(
                !text.contains(noteSentinel),
                "handoff note leaked",
                failures: &failures
            )
            check(
                !text.contains(root.path),
                "local path leaked",
                failures: &failures
            )
            check(
                !text.contains("/Users/private")
                    && !text.contains("$CODEX_HOME"),
                "sensitive path inside a visible title leaked",
                failures: &failures
            )
            check(
                !text.contains("private-source-task"),
                "source task ID leaked",
                failures: &failures
            )
            check(
                index.runtimeAvailability.count == RuntimeScope.allCases.count,
                "runtime availability is incomplete",
                failures: &failures
            )
            let hermesStatus = index.runtimeAvailability.first {
                $0.runtime == .hermes
            }?.status
            check(
                hermesStatus == .unavailable,
                "missing Hermes state was not unavailable",
                failures: &failures
            )
        } catch {
            failures.append("fixture execution failed")
        }

        failures.forEach {
            fputs("project index reader self-test failed: \($0)\n", stderr)
        }
        if failures.isEmpty {
            print("project index reader self-test passed")
        }
        return failures.isEmpty
    }

    private static func createCodexDatabase(
        at url: URL,
        transcriptPath: String,
        updatedAt: Int
    ) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            url.path,
            """
            CREATE TABLE threads (
              id TEXT,
              title TEXT,
              cwd TEXT,
              updated_at INTEGER,
              archived INTEGER,
              rollout_path TEXT
            );
            INSERT INTO threads VALUES (
              'codex-native-secret',
              'Safe Codex title',
              '/private/Fixture Workspace',
              \(updatedAt),
              0,
              '\(transcriptPath.replacingOccurrences(of: "'", with: "''"))'
            );
            INSERT INTO threads VALUES (
              'codex-native-path-title',
              'Inspect /Users/private/.codex and $CODEX_HOME/config.toml',
              '/private/Fixture Workspace',
              \(updatedAt - 1),
              0,
              '\(transcriptPath.replacingOccurrences(of: "'", with: "''"))'
            );
            """
        ]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw FixtureError.sqlite
        }
    }

    private static func writeJSON(_ object: Any, to url: URL) throws {
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        try data.write(to: url, options: .atomic)
    }

    private static func check(
        _ condition: @autoclosure () -> Bool,
        _ message: String,
        failures: inout [String]
    ) {
        if !condition() {
            failures.append(message)
        }
    }

    private enum FixtureError: Error {
        case sqlite
    }
}
