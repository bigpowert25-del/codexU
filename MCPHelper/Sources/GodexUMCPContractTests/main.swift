import Foundation
import GodexUMCPCore

@main
struct GodexUMCPContractTests {
    static func main() async {
        var failures: [String] = []
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let data = sampleIndexData(generatedAt: now)

        do {
            let index = try ProjectIndexCodec.decode(data)
            check(
                index.schema == "godexu-project-index-v1",
                "schema decode",
                failures: &failures
            )
            check(
                index.projects.first?.tasks.count == 1,
                "task decode",
                failures: &failures
            )
            let encoded = try ProjectIndexCodec.encode(index)
            let text = String(decoding: encoded, as: UTF8.self)
            check(
                !text.contains("handoffNote")
                    && !text.contains("/Users/")
                    && !text.contains("raw-thread"),
                "public mirror leaked prohibited data",
                failures: &failures
            )
        } catch {
            failures.append("valid index rejected")
        }

        do {
            var object = try JSONSerialization.jsonObject(with: data)
                as! [String: Any]
            object["unknown"] = true
            let invalid = try JSONSerialization.data(withJSONObject: object)
            check(
                (try? ProjectIndexCodec.decode(invalid)) == nil,
                "unknown key accepted",
                failures: &failures
            )
        } catch {
            failures.append("unknown-key fixture failed")
        }

        do {
            var object = try JSONSerialization.jsonObject(with: data)
                as! [String: Any]
            var projects = object["projects"] as! [[String: Any]]
            var tasks = projects[0]["tasks"] as! [[String: Any]]
            tasks[0]["title"] = "sk-proj-0123456789abcdef0123456789abcdef"
            projects[0]["tasks"] = tasks
            object["projects"] = projects
            let invalid = try JSONSerialization.data(withJSONObject: object)
            check(
                (try? ProjectIndexCodec.decode(invalid)) == nil,
                "credential-shaped title accepted",
                failures: &failures
            )
        } catch {
            failures.append("credential fixture failed")
        }

        let loader = SequencedLoader([
            .success(sampleIndexData(generatedAt: now)),
            .failure(PublicSnapshotError(code: "fixture_failure"))
        ])
        let cache = ProjectIndexCache(loader: {
            try await loader.load()
        })
        do {
            let first = try await cache.snapshot(now: now)
            let cached = try await cache.snapshot(
                now: now.addingTimeInterval(2)
            )
            let stale = try await cache.snapshot(
                now: now.addingTimeInterval(4)
            )
            let callCount = await loader.callCount
            check(callCount == 2, "fresh cache miss", failures: &failures)
            check(first == cached, "fresh cache changed", failures: &failures)
            check(stale.freshness == .stale, "stale marker", failures: &failures)
            check(
                stale.generatedAt == first.generatedAt,
                "stale generatedAt changed",
                failures: &failures
            )
        } catch {
            failures.append("cache fallback failed")
        }

        let concurrentLoader = DelayedLoader(
            data: sampleIndexData(generatedAt: now)
        )
        let concurrentCache = ProjectIndexCache(loader: {
            try await concurrentLoader.load()
        })
        do {
            async let first = concurrentCache.snapshot(now: now)
            async let second = concurrentCache.snapshot(now: now)
            _ = try await (first, second)
            let callCount = await concurrentLoader.callCount
            check(
                callCount == 1,
                "concurrent cache refresh was not coalesced",
                failures: &failures
            )
        } catch {
            failures.append("concurrent cache fixture failed")
        }

        let emptyCache = ProjectIndexCache(loader: {
            throw PublicSnapshotError(code: "fixture_failure")
        })
        do {
            _ = try await emptyCache.snapshot(now: now)
            failures.append("empty cache failure was accepted")
        } catch let error as PublicSnapshotError {
            check(
                error.code == "snapshot_unavailable",
                "unbounded empty-cache error",
                failures: &failures
            )
        } catch {
            failures.append("unexpected empty-cache error")
        }

        do {
            let index = try ProjectIndexCodec.decode(data)
            let service = ProjectIndexQueryService(index: index)
            let list = try service.projects(
                runtime: "codex",
                state: "active",
                limit: 500
            )
            check(list.projects.count == 1, "project list", failures: &failures)
            check(list.appliedLimit == 50, "list bound", failures: &failures)
            check(
                list.runtimeAvailability.count == 1,
                "project list dropped runtime availability",
                failures: &failures
            )
            check(
                list.warnings.isEmpty,
                "project list warning projection",
                failures: &failures
            )
            let pendingList = try service.projects(
                runtime: nil,
                state: "pending",
                limit: 20
            )
            check(
                pendingList.projects.count == 1,
                "state filter ignored aggregate counts",
                failures: &failures
            )
            let project = try service.project(
                id: "project-1234567890abcdef"
            )
            check(
                project.tasks.count == 1,
                "project get",
                failures: &failures
            )
            let handoffs = try service.handoffs(
                state: "ready",
                targetRuntime: "openclaw",
                limit: 20
            )
            check(
                handoffs.handoffs.count == 1,
                "handoff list",
                failures: &failures
            )
            check(
                handoffs.runtimeAvailability.count == 1,
                "handoff list dropped runtime availability",
                failures: &failures
            )
            check(
                throwsQuery {
                    _ = try service.project(id: "../../../private")
                },
                "unsafe project ID accepted",
                failures: &failures
            )
            check(
                throwsQuery {
                    _ = try service.projects(
                        runtime: "unknown",
                        state: nil,
                        limit: nil
                    )
                },
                "unknown runtime accepted",
                failures: &failures
            )
            check(
                throwsQuery {
                    _ = try service.projects(
                        runtime: nil,
                        state: nil,
                        limit: -1
                    )
                },
                "negative limit accepted",
                failures: &failures
            )
        } catch {
            failures.append("query service failed")
        }

        do {
            try commandPathChecks(failures: &failures)
        } catch {
            failures.append("fixed command path checks failed")
        }

        for failure in failures {
            fputs("MCP contract self-test failed: \(failure)\n", stderr)
        }
        if failures.isEmpty {
            print("MCP contract self-tests passed")
        }
        exit(failures.isEmpty ? 0 : 1)
    }

    private static func commandPathChecks(
        failures: inout [String]
    ) throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "godexu-mcp-command-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? fileManager.removeItem(at: root) }
        let helpers = root.appendingPathComponent(
            "codexU.app/Contents/Helpers",
            isDirectory: true
        )
        let macOS = root.appendingPathComponent(
            "codexU.app/Contents/MacOS",
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: helpers,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: macOS,
            withIntermediateDirectories: true
        )
        let helperURL = helpers.appendingPathComponent("GodexUMCPServer")
        let appURL = macOS.appendingPathComponent("codexU")
        try Data().write(to: helperURL)
        try """
        #!/bin/sh
        test "$#" -eq 1
        test "$1" = "--dump-project-index"
        printf '%s' '\(String(decoding: sampleIndexData(
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        ), as: UTF8.self))'
        """.write(to: appURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: appURL.path
        )

        let command = try BundledAppCommand(
            helperExecutableURL: helperURL
        )
        check(
            command.executableURL == appURL.standardizedFileURL,
            "bundle-relative command mismatch",
            failures: &failures
        )
        let output = try command.load(timeout: 1)
        check(
            (try? ProjectIndexCodec.decode(output)) != nil,
            "fixed command output",
            failures: &failures
        )

        let escapedRoot = root.appendingPathComponent(
            "escaped-bundle",
            isDirectory: true
        )
        let escapedHelpers = escapedRoot.appendingPathComponent(
            "codexU.app/Contents/Helpers",
            isDirectory: true
        )
        let escapedMacOS = escapedRoot.appendingPathComponent(
            "codexU.app/Contents/MacOS",
            isDirectory: true
        )
        let outsideMacOS = root.appendingPathComponent(
            "outside-macos",
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: escapedHelpers,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: outsideMacOS,
            withIntermediateDirectories: true
        )
        let escapedHelper = escapedHelpers.appendingPathComponent(
            "GodexUMCPServer"
        )
        try Data().write(to: escapedHelper)
        let outsideApp = outsideMacOS.appendingPathComponent("codexU")
        try "#!/bin/sh\nexit 0\n".write(
            to: outsideApp,
            atomically: true,
            encoding: .utf8
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: outsideApp.path
        )
        try fileManager.createSymbolicLink(
            at: escapedMacOS,
            withDestinationURL: outsideMacOS
        )
        do {
            _ = try BundledAppCommand(helperExecutableURL: escapedHelper)
            failures.append("bundle ancestor symlink was accepted")
        } catch {
            // Expected: fixed command discovery may not leave the app bundle.
        }

        try "#!/bin/sh\nwhile :; do :; done\n".write(
            to: appURL,
            atomically: true,
            encoding: .utf8
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: appURL.path
        )
        do {
            _ = try command.load(timeout: 0.05)
            failures.append("child timeout was accepted")
        } catch let error as PublicSnapshotError {
            check(
                error.code == "snapshot_timeout",
                "child timeout error leaked detail",
                failures: &failures
            )
        }

        try "#!/bin/sh\nexec /usr/bin/yes 0123456789abcdef\n".write(
            to: appURL,
            atomically: true,
            encoding: .utf8
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: appURL.path
        )
        let oversizedStart = Date()
        do {
            _ = try command.load(timeout: 2)
            failures.append("unbounded child output was accepted")
        } catch let error as PublicSnapshotError {
            check(
                error.code == "snapshot_too_large",
                "unbounded child output did not fail at the size limit",
                failures: &failures
            )
            check(
                Date().timeIntervalSince(oversizedStart) < 1.5,
                "unbounded child output was not stopped promptly",
                failures: &failures
            )
        }
    }

    private static func throwsQuery(_ body: () throws -> Void) -> Bool {
        do {
            try body()
            return false
        } catch {
            return true
        }
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

    private static func sampleIndexData(generatedAt: Date) -> Data {
        let formatter = ISO8601DateFormatter()
        let date = formatter.string(from: generatedAt)
        let json = """
        {
          "schema": "godexu-project-index-v1",
          "generatedAt": "\(date)",
          "deviceScope": "local-mac",
          "freshness": "fresh",
          "runtimeAvailability": [
            {"runtime": "codex", "status": "localOnly"}
          ],
          "projects": [
            {
              "id": "project-1234567890abcdef",
              "name": "Workspace",
              "isDerived": true,
              "sourceRuntimes": ["codex"],
              "activeCount": 1,
              "pendingCount": 1,
              "scheduledCount": 0,
              "doneCount": 0,
              "totalCount": 2,
              "handoffCount": 1,
              "lastActiveAt": "\(date)",
              "tasks": [
                {
                  "id": "task-fedcba0987654321",
                  "title": "Safe title",
                  "sourceRuntime": "codex",
                  "state": "active",
                  "updatedAt": "\(date)",
                  "progressPercent": 25
                }
              ]
            }
          ],
          "handoffs": [
            {
              "id": "00000000-0000-0000-0000-000000000001",
              "projectID": "project-1234567890abcdef",
              "projectName": "Workspace",
              "title": "Safe handoff",
              "sourceRuntime": "codex",
              "targetRuntime": "openClaw",
              "state": "ready",
              "revision": 1,
              "createdAt": "\(date)",
              "updatedAt": "\(date)"
            }
          ],
          "warnings": []
        }
        """
        return Data(json.utf8)
    }
}

private actor SequencedLoader {
    private var results: [Result<Data, Error>]
    private(set) var callCount = 0

    init(_ results: [Result<Data, Error>]) {
        self.results = results
    }

    func load() async throws -> Data {
        callCount += 1
        guard !results.isEmpty else {
            throw PublicSnapshotError(code: "fixture_exhausted")
        }
        return try results.removeFirst().get()
    }
}

private actor DelayedLoader {
    let data: Data
    private(set) var callCount = 0

    init(data: Data) {
        self.data = data
    }

    func load() async throws -> Data {
        callCount += 1
        try await Task.sleep(for: .milliseconds(100))
        return data
    }
}
