import Foundation

struct GodexUProjectIndexReader {
    private let homeDirectory: URL
    private let envelopeFileURL: URL
    private let now: Date
    private let fileManager: FileManager

    init(
        homeDirectory: URL,
        envelopeFileURL: URL,
        now: Date,
        fileManager: FileManager = .default
    ) {
        self.homeDirectory = homeDirectory
        self.envelopeFileURL = envelopeFileURL
        self.now = now
        self.fileManager = fileManager
    }

    static func live(now: Date = Date()) -> GodexUProjectIndexReader {
        GodexUProjectIndexReader(
            homeDirectory: FileManager.default.homeDirectoryForCurrentUser,
            envelopeFileURL: AgentTaskEnvelopeStore.defaultFileURL(),
            now: now
        )
    }

    func load() -> GodexUProjectIndex {
        let codex = readCodexTasks()
        let openClaw = readOpenClawTasks()
        let envelopes = readHandoffs()
        var warnings: [GodexUIndexWarning] = []
        if !codex.sourceAvailable {
            warnings.append(GodexUIndexWarning(
                code: "codex_metadata_unavailable"
            ))
        }
        if !openClaw.sourceAvailable {
            warnings.append(GodexUIndexWarning(
                code: "openclaw_metadata_unavailable"
            ))
        }

        return GodexUProjectIndex.make(
            generatedAt: now,
            freshness: .fresh,
            runtimeAvailability: [
                GodexURuntimeAvailability(
                    runtime: .codex,
                    status: codex.sourceAvailable ? .localOnly : .unavailable
                ),
                GodexURuntimeAvailability(
                    runtime: .openClaw,
                    status: openClaw.sourceAvailable
                        ? .localOnly
                        : .unavailable
                ),
                GodexURuntimeAvailability(
                    runtime: .claudeCode,
                    status: directoryExists(".claude")
                        ? .localOnly
                        : .unavailable
                ),
                GodexURuntimeAvailability(
                    runtime: .hermes,
                    status: directoryExists(".hermes")
                        ? .localOnly
                        : .unavailable
                )
            ],
            tasks: codex.tasks + openClaw.tasks,
            envelopes: envelopes,
            warnings: warnings
        )
    }

    private func readCodexTasks() -> (
        sourceAvailable: Bool,
        tasks: [GodexUProjectIndexTaskInput]
    ) {
        guard let databaseURL = firstExistingURL([
            homeDirectory.appendingPathComponent(".codex/state_5.sqlite"),
            homeDirectory.appendingPathComponent(
                ".codex/sqlite/state_5.sqlite"
            )
        ]) else {
            return (false, [])
        }

        let query = """
        SELECT id, title, cwd, updated_at AS updatedAt, archived
        FROM threads
        ORDER BY updated_at DESC
        LIMIT 500;
        """
        guard let objects = runSQLiteJSON(
            databaseURL: databaseURL,
            query: query
        ) else {
            return (false, [])
        }
        return (true, objects.compactMap { object in
            guard let nativeID = boundedIdentifier(object["id"]),
                  let title = boundedText(object["title"], limit: 160)
            else {
                return nil
            }
            let updatedAt = dateValue(object["updatedAt"])
            let archived = intValue(object["archived"]) != 0
            let state: GodexUTaskState
            if archived {
                state = .done
            } else if let updatedAt,
                      now.timeIntervalSince(updatedAt) <= 30 * 60 {
                state = .active
            } else {
                state = .pending
            }
            let projectName = pathTail(object["cwd"])
            return GodexUProjectIndexTaskInput(
                nativeID: nativeID,
                title: title,
                projectName: projectName,
                sourceRuntime: .codex,
                state: state,
                updatedAt: updatedAt,
                progressPercent: archived ? 100 : nil
            )
        })
    }

    private func readOpenClawTasks() -> (
        sourceAvailable: Bool,
        tasks: [GodexUProjectIndexTaskInput]
    ) {
        let taskURL = homeDirectory.appendingPathComponent(
            ".openclaw/workspace/memory/tasks.json"
        )
        let sessionsURL = homeDirectory.appendingPathComponent(
            ".openclaw/agents/main/sessions/sessions.json"
        )
        let tasksExist = fileManager.fileExists(atPath: taskURL.path)
        let sessionsExist = fileManager.fileExists(atPath: sessionsURL.path)
        return (
            tasksExist || sessionsExist,
            readOpenClawCanonicalTasks(at: taskURL)
                + readOpenClawSessions(at: sessionsURL)
        )
    }

    private func readOpenClawCanonicalTasks(
        at url: URL
    ) -> [GodexUProjectIndexTaskInput] {
        guard let data = try? Data(contentsOf: url),
              let rows = try? JSONSerialization.jsonObject(with: data)
                as? [[String: Any]]
        else {
            return []
        }
        return rows.prefix(500).compactMap { row in
            guard let nativeID = boundedIdentifier(row["id"]),
                  let title = boundedText(row["title"], limit: 160)
            else {
                return nil
            }
            let status = (row["status"] as? String) ?? "pending"
            let updatedAt = dateValue(row["updatedAt"])
                ?? dateValue(row["updated_at"])
                ?? dateValue(row["lastActiveAt"])
                ?? dateValue(row["created"])
            let state = openClawTaskState(status)
            return GodexUProjectIndexTaskInput(
                nativeID: nativeID,
                title: title,
                projectName: nil,
                sourceRuntime: .openClaw,
                state: state,
                updatedAt: updatedAt,
                progressPercent: progressValue(row["progress"])
                    ?? (state == .done ? 100 : nil)
            )
        }
    }

    private func readOpenClawSessions(
        at url: URL
    ) -> [GodexUProjectIndexTaskInput] {
        guard let data = try? Data(contentsOf: url),
              let document = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else {
            return []
        }
        let calendar = Calendar.autoupdatingCurrent
        let dayStart = calendar.startOfDay(for: now)
        return document.sorted { $0.key < $1.key }.prefix(500).compactMap {
            key,
            rawValue -> GodexUProjectIndexTaskInput? in
            guard let value = rawValue as? [String: Any],
                  let updatedAt = dateValue(value["updatedAt"]),
                  updatedAt >= dayStart,
                  updatedAt <= now.addingTimeInterval(5 * 60)
            else {
                return nil
            }
            let nativeID = boundedIdentifier(value["sessionId"])
                ?? boundedIdentifier(key)
            guard let nativeID else { return nil }
            let status = (value["status"] as? String) ?? ""
            let scheduled = key.contains(":cron:")
            let state: GodexUTaskState = scheduled
                ? .scheduled
                : openClawSessionState(status, updatedAt: updatedAt)
            return GodexUProjectIndexTaskInput(
                nativeID: nativeID,
                title: scheduled
                    ? "OpenClaw Scheduled Session"
                    : "OpenClaw Session",
                projectName: nil,
                sourceRuntime: .openClaw,
                state: state,
                updatedAt: updatedAt,
                progressPercent: state == .done ? 100 : nil
            )
        }
    }

    private func readHandoffs() -> [GodexUHandoffSummary] {
        AgentTaskEnvelopeStore(fileURL: envelopeFileURL).envelopes.map {
            envelope in
            GodexUHandoffSummary(
                id: envelope.id,
                projectID: envelope.projectID,
                projectName: envelope.projectName,
                title: envelope.title,
                sourceRuntime: envelope.sourceRuntime,
                targetRuntime: envelope.targetRuntime,
                state: envelope.state,
                revision: envelope.revision,
                createdAt: envelope.createdAt,
                updatedAt: envelope.updatedAt
            )
        }
    }

    private func runSQLiteJSON(
        databaseURL: URL,
        query: String
    ) -> [[String: Any]]? {
        guard fileManager.fileExists(atPath: "/usr/bin/sqlite3") else {
            return nil
        }
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            "-readonly",
            "-json",
            databaseURL.path,
            query
        ]
        process.standardOutput = output
        process.standardError = errors
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0,
              let data = try? output.fileHandleForReading.readToEnd(),
              data.count <= 2 * 1_024 * 1_024,
              let objects = try? JSONSerialization.jsonObject(with: data)
                as? [[String: Any]]
        else {
            return nil
        }
        return objects
    }

    private func openClawTaskState(_ status: String) -> GodexUTaskState {
        switch status.lowercased() {
        case "active", "in_progress", "in-progress", "running", "doing":
            return .active
        case "done", "completed", "complete", "closed":
            return .done
        case "scheduled", "cron":
            return .scheduled
        default:
            return .pending
        }
    }

    private func openClawSessionState(
        _ status: String,
        updatedAt: Date
    ) -> GodexUTaskState {
        let normalized = status.lowercased()
        if ["done", "completed", "closed"].contains(normalized) {
            return .done
        }
        if ["active", "running", "in_progress"].contains(normalized)
            || now.timeIntervalSince(updatedAt) <= 30 * 60 {
            return .active
        }
        return .pending
    }

    private func progressValue(_ value: Any?) -> Double? {
        let progress: Double?
        switch value {
        case let number as NSNumber:
            progress = number.doubleValue
        case let text as String:
            progress = Double(text)
        default:
            progress = nil
        }
        return progress.map { min(max($0, 0), 100) }
    }

    private func boundedIdentifier(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 512 else { return nil }
        return normalized
    }

    private func boundedText(_ value: Any?, limit: Int) -> String? {
        guard let text = value as? String else { return nil }
        let normalized = text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard !normalized.isEmpty else { return nil }
        return String(normalized.prefix(limit))
    }

    private func pathTail(_ value: Any?) -> String? {
        guard let path = value as? String, !path.isEmpty else { return nil }
        let tail = URL(fileURLWithPath: path).lastPathComponent
        return boundedText(tail, limit: AgentTaskEnvelope.maximumProjectNameLength)
    }

    private func dateValue(_ value: Any?) -> Date? {
        if let number = value as? NSNumber {
            let raw = number.doubleValue
            let seconds = raw > 10_000_000_000 ? raw / 1_000 : raw
            return Date(timeIntervalSince1970: seconds)
        }
        guard let text = value as? String else { return nil }
        if let number = Double(text) {
            let seconds = number > 10_000_000_000 ? number / 1_000 : number
            return Date(timeIntervalSince1970: seconds)
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        return fractional.date(from: text)
            ?? ISO8601DateFormatter().date(from: text)
    }

    private func intValue(_ value: Any?) -> Int {
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let text = value as? String {
            return Int(text) ?? 0
        }
        return 0
    }

    private func directoryExists(_ relativePath: String) -> Bool {
        var isDirectory: ObjCBool = false
        let path = homeDirectory.appendingPathComponent(relativePath).path
        return fileManager.fileExists(
            atPath: path,
            isDirectory: &isDirectory
        ) && isDirectory.boolValue
    }

    private func firstExistingURL(_ candidates: [URL]) -> URL? {
        candidates.first { fileManager.fileExists(atPath: $0.path) }
    }
}
