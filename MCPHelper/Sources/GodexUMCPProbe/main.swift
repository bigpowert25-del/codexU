import Foundation

@main
struct GodexUMCPProbe {
    static func main() {
        var failures: [String] = []
        guard CommandLine.arguments.count == 2 else {
            fputs("MCP probe failed: expected server binary\n", stderr)
            exit(1)
        }

        let serverSource = URL(
            fileURLWithPath: CommandLine.arguments[1]
        ).standardizedFileURL
        let fixture = FixtureBundle()
        defer { fixture.remove() }

        do {
            try fixture.prepare(serverSource: serverSource)
            try fixture.writeApp(mode: .valid)
            let valid = try ProtocolConnection(
                serverURL: fixture.serverURL
            )
            try runValidProtocol(
                valid,
                failures: &failures
            )
            try closeAndCheck(valid, fixture: fixture, failures: &failures)

            try fixture.writeApp(mode: .malformed)
            let malformed = try ProtocolConnection(
                serverURL: fixture.serverURL
            )
            try initialize(malformed, failures: &failures)
            let malformedResult = try malformed.request(
                method: "tools/call",
                params: [
                    "name": "godexu_project_list",
                    "arguments": [:]
                ]
            )
            check(
                toolIsError(malformedResult),
                "malformed snapshot was accepted",
                failures: &failures
            )
            try closeAndCheck(
                malformed,
                fixture: fixture,
                failures: &failures
            )

            try fixture.writeApp(mode: .timeout)
            let timeout = try ProtocolConnection(
                serverURL: fixture.serverURL
            )
            try initialize(timeout, failures: &failures)
            let start = Date()
            let timeoutResult = try timeout.request(
                method: "tools/call",
                params: [
                    "name": "godexu_project_list",
                    "arguments": [:]
                ]
            )
            let elapsed = Date().timeIntervalSince(start)
            check(
                toolIsError(timeoutResult),
                "snapshot timeout was accepted",
                failures: &failures
            )
            check(
                elapsed >= 2.5 && elapsed < 5,
                "snapshot timeout duration out of bounds",
                failures: &failures
            )
            try closeAndCheck(
                timeout,
                fixture: fixture,
                failures: &failures
            )
        } catch {
            failures.append("protocol probe execution failed")
        }

        failures.forEach {
            fputs("MCP probe failed: \($0)\n", stderr)
        }
        if failures.isEmpty {
            print("MCP protocol probe passed")
        }
        exit(failures.isEmpty ? 0 : 1)
    }

    private static func runValidProtocol(
        _ connection: ProtocolConnection,
        failures: inout [String]
    ) throws {
        let initializeResult = try initialize(
            connection,
            failures: &failures
        )
        let capabilities = initializeResult["capabilities"]
            as? [String: Any] ?? [:]
        check(
            Set(capabilities.keys) == Set(["resources", "tools"]),
            "server advertised extra capabilities",
            failures: &failures
        )

        let toolsResponse = try connection.request(method: "tools/list")
        let tools = (
            (toolsResponse["result"] as? [String: Any])?["tools"]
                as? [[String: Any]]
        ) ?? []
        let expectedTools = Set([
            "godexu_project_list",
            "godexu_project_get",
            "godexu_handoff_list"
        ])
        check(
            Set(tools.compactMap { $0["name"] as? String }) == expectedTools,
            "tool list mismatch",
            failures: &failures
        )
        check(
            tools.allSatisfy { tool in
                let annotations = tool["annotations"] as? [String: Any]
                let outputSchema = tool["outputSchema"]
                    as? [String: Any]
                let outputProperties = outputSchema?["properties"]
                    as? [String: Any]
                return annotations?["readOnlyHint"] as? Bool == true
                    && annotations?["destructiveHint"] as? Bool == false
                    && annotations?["openWorldHint"] as? Bool == false
                    && tool["inputSchema"] != nil
                    && outputSchema?["additionalProperties"] as? Bool == false
                    && outputProperties?.isEmpty == false
            },
            "tool safety annotations or schemas missing",
            failures: &failures
        )

        let resourcesResponse = try connection.request(
            method: "resources/list"
        )
        let resources = (
            (resourcesResponse["result"] as? [String: Any])?["resources"]
                as? [[String: Any]]
        ) ?? []
        check(
            resources.map { $0["uri"] as? String } == ["godexu://projects"],
            "static resource mismatch",
            failures: &failures
        )

        let templatesResponse = try connection.request(
            method: "resources/templates/list"
        )
        let templates = (
            (templatesResponse["result"] as? [String: Any])?[
                "resourceTemplates"
            ] as? [[String: Any]]
        ) ?? []
        check(
            Set(templates.compactMap {
                $0["uriTemplate"] as? String
            }) == Set([
                "godexu://projects/{projectID}",
                "godexu://handoffs/{envelopeID}"
            ]),
            "resource templates mismatch",
            failures: &failures
        )

        let listResponse = try connection.request(
            method: "tools/call",
            params: [
                "name": "godexu_project_list",
                "arguments": [
                    "runtime": "codex",
                    "state": "active",
                    "limit": 50
                ]
            ]
        )
        check(
            !toolIsError(listResponse)
                && structuredContent(listResponse)?["projects"] != nil,
            "project list failed",
            failures: &failures
        )

        let getResponse = try connection.request(
            method: "tools/call",
            params: [
                "name": "godexu_project_get",
                "arguments": [
                    "projectID": "project-1234567890abcdef"
                ]
            ]
        )
        check(
            !toolIsError(getResponse)
                && structuredContent(getResponse)?["tasks"] != nil,
            "project get failed",
            failures: &failures
        )

        let handoffResponse = try connection.request(
            method: "tools/call",
            params: [
                "name": "godexu_handoff_list",
                "arguments": [
                    "state": "ready",
                    "targetRuntime": "openclaw",
                    "limit": 20
                ]
            ]
        )
        check(
            !toolIsError(handoffResponse)
                && structuredContent(handoffResponse)?["handoffs"] != nil,
            "handoff list failed",
            failures: &failures
        )

        for uri in [
            "godexu://projects",
            "godexu://projects/project-1234567890abcdef",
            "godexu://handoffs/00000000-0000-0000-0000-000000000001"
        ] {
            let response = try connection.request(
                method: "resources/read",
                params: ["uri": uri]
            )
            check(
                resourceText(response) != nil,
                "resource read failed",
                failures: &failures
            )
        }

        let invalidTool = try connection.request(
            method: "tools/call",
            params: ["name": "godexu_unknown", "arguments": [:]]
        )
        check(
            toolIsError(invalidTool),
            "unknown tool was accepted",
            failures: &failures
        )
        let unsafeID = try connection.request(
            method: "tools/call",
            params: [
                "name": "godexu_project_get",
                "arguments": ["projectID": "../../../private"]
            ]
        )
        check(
            toolIsError(unsafeID),
            "unsafe project ID was accepted",
            failures: &failures
        )
        let negativeLimit = try connection.request(
            method: "tools/call",
            params: [
                "name": "godexu_project_list",
                "arguments": ["limit": -1]
            ]
        )
        check(
            toolIsError(negativeLimit),
            "negative limit was accepted",
            failures: &failures
        )

        let unknownMethod = try connection.request(method: "godexu/unknown")
        check(
            ((unknownMethod["error"] as? [String: Any])?["code"] as? Int)
                == -32601,
            "unknown method error mismatch",
            failures: &failures
        )
        let parseError = try connection.sendInvalidJSON()
        check(
            ((parseError["error"] as? [String: Any])?["code"] as? Int)
                == -32700,
            "parse error mismatch",
            failures: &failures
        )

        let publicText = connection.responses
            .compactMap {
                try? JSONSerialization.data(
                    withJSONObject: $0,
                    options: [.sortedKeys]
                )
            }
            .map { String(decoding: $0, as: UTF8.self) }
            .joined(separator: "\n")
        check(
            !publicText.contains("TRANSCRIPT_SENTINEL_DO_NOT_READ")
                && !publicText.contains("HANDOFF_NOTE_SENTINEL_DO_NOT_EMIT")
                && !publicText.contains("/Users/")
                && !publicText.contains("raw-thread"),
            "protocol output privacy scan failed",
            failures: &failures
        )
        let forbiddenKeys = Set([
            "handoffNote",
            "recentReply",
            "summary",
            "rolloutPath",
            "sessionFile",
            "prompt",
            "toolArguments"
        ])
        check(
            forbiddenKeys.isDisjoint(with: recursiveKeys(connection.responses)),
            "protocol output contains prohibited keys",
            failures: &failures
        )
    }

    @discardableResult
    private static func initialize(
        _ connection: ProtocolConnection,
        failures: inout [String]
    ) throws -> [String: Any] {
        let response = try connection.request(
            method: "initialize",
            params: [
                "protocolVersion": "2025-11-25",
                "capabilities": [:],
                "clientInfo": [
                    "name": "GodexUMCPProbe",
                    "version": "1.0"
                ]
            ]
        )
        let result = response["result"] as? [String: Any] ?? [:]
        check(
            result["protocolVersion"] as? String == "2025-11-25",
            "protocol negotiation mismatch",
            failures: &failures
        )
        let serverInfo = result["serverInfo"] as? [String: Any]
        check(
            serverInfo?["name"] as? String == "GodexU",
            "server identity mismatch",
            failures: &failures
        )
        try connection.notify(
            method: "notifications/initialized",
            params: [:]
        )
        return result
    }

    private static func closeAndCheck(
        _ connection: ProtocolConnection,
        fixture: FixtureBundle,
        failures: inout [String]
    ) throws {
        let stderrText = try connection.close()
        check(
            !stderrText.contains(fixture.root.path)
                && !stderrText.contains("TRANSCRIPT_SENTINEL")
                && !stderrText.contains("HANDOFF_NOTE_SENTINEL"),
            "server stderr leaked private data",
            failures: &failures
        )
        check(
            connection.rawLines.allSatisfy {
                (try? JSONSerialization.jsonObject(with: $0)) != nil
            },
            "server stdout contained non-JSON-RPC output",
            failures: &failures
        )
    }

    private static func toolIsError(_ response: [String: Any]) -> Bool {
        let result = response["result"] as? [String: Any]
        return result?["isError"] as? Bool == true
    }

    private static func structuredContent(
        _ response: [String: Any]
    ) -> [String: Any]? {
        (response["result"] as? [String: Any])?["structuredContent"]
            as? [String: Any]
    }

    private static func resourceText(
        _ response: [String: Any]
    ) -> String? {
        let result = response["result"] as? [String: Any]
        let contents = result?["contents"] as? [[String: Any]]
        return contents?.first?["text"] as? String
    }

    private static func recursiveKeys(_ values: [[String: Any]]) -> Set<String> {
        var result = Set<String>()
        func collect(_ value: Any) {
            if let object = value as? [String: Any] {
                result.formUnion(object.keys)
                object.values.forEach(collect)
            } else if let array = value as? [Any] {
                array.forEach(collect)
            }
        }
        values.forEach(collect)
        return result
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
}

private final class ProtocolConnection {
    private let process = Process()
    private let requestInput = Pipe()
    private let responseOutput = Pipe()
    private let diagnosticOutput = Pipe()
    private var nextID = 1
    private var pending = Data()
    private(set) var responses: [[String: Any]] = []
    private(set) var rawLines: [Data] = []

    init(serverURL: URL) throws {
        process.executableURL = serverURL
        process.standardInput = requestInput
        process.standardOutput = responseOutput
        process.standardError = diagnosticOutput
        try process.run()
    }

    func request(
        method: String,
        params: [String: Any]? = nil
    ) throws -> [String: Any] {
        let id = nextID
        nextID += 1
        var object: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method
        ]
        if let params {
            object["params"] = params
        }
        try send(object)
        return try readResponse()
    }

    func notify(method: String, params: [String: Any]) throws {
        try send([
            "jsonrpc": "2.0",
            "method": method,
            "params": params
        ])
    }

    func sendInvalidJSON() throws -> [String: Any] {
        try requestInput.fileHandleForWriting.write(
            contentsOf: Data("{invalid-json}\n".utf8)
        )
        return try readResponse()
    }

    func close() throws -> String {
        try requestInput.fileHandleForWriting.close()
        let deadline = Date().addingTimeInterval(3)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            throw ProbeError.serverDidNotStop
        }
        let data = try diagnosticOutput.fileHandleForReading.readToEnd()
            ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    private func send(_ object: [String: Any]) throws {
        var data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        data.append(0x0a)
        try requestInput.fileHandleForWriting.write(contentsOf: data)
    }

    private func readResponse() throws -> [String: Any] {
        while true {
            if let newline = pending.firstIndex(of: 0x0a) {
                let line = Data(pending[..<newline])
                pending.removeSubrange(...newline)
                if line.isEmpty { continue }
                rawLines.append(line)
                guard let object = try JSONSerialization.jsonObject(with: line)
                        as? [String: Any]
                else {
                    throw ProbeError.invalidResponse
                }
                responses.append(object)
                return object
            }
            let chunk = responseOutput.fileHandleForReading.availableData
            guard !chunk.isEmpty else {
                throw ProbeError.unexpectedEOF
            }
            pending.append(chunk)
        }
    }
}

private final class FixtureBundle {
    enum Mode {
        case valid
        case malformed
        case timeout
    }

    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
        "godexu-mcp-probe-\(UUID().uuidString)",
        isDirectory: true
    )
    var serverURL: URL {
        root.appendingPathComponent(
            "codexU.app/Contents/Helpers/GodexUMCPServer"
        )
    }
    private var appURL: URL {
        root.appendingPathComponent("codexU.app/Contents/MacOS/codexU")
    }
    private var fixtureURL: URL {
        root.appendingPathComponent(
            "codexU.app/Contents/Resources/project-index.json"
        )
    }

    func prepare(serverSource: URL) throws {
        let fileManager = FileManager.default
        for directory in [
            serverURL.deletingLastPathComponent(),
            appURL.deletingLastPathComponent(),
            fixtureURL.deletingLastPathComponent()
        ] {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }
        try fileManager.copyItem(at: serverSource, to: serverURL)
        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: serverURL.path
        )
        try Data(validFixtureJSON.utf8).write(
            to: fixtureURL,
            options: .atomic
        )
    }

    func writeApp(mode: Mode) throws {
        let body: String
        switch mode {
        case .valid:
            body = """
            #!/bin/sh
            test "$#" -eq 1
            test "$1" = "--dump-project-index"
            DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../Resources" && pwd)"
            exec /bin/cat "$DIR/project-index.json"
            """
        case .malformed:
            body = """
            #!/bin/sh
            printf '%s' 'not-json'
            """
        case .timeout:
            body = """
            #!/bin/sh
            while :; do :; done
            """
        }
        try body.write(to: appURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: appURL.path
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    private let validFixtureJSON = """
    {
      "schema": "godexu-project-index-v1",
      "generatedAt": "2027-01-15T08:00:00Z",
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
          "pendingCount": 0,
          "scheduledCount": 0,
          "doneCount": 0,
          "totalCount": 1,
          "handoffCount": 1,
          "lastActiveAt": "2027-01-15T08:00:00Z",
          "tasks": [
            {
              "id": "task-fedcba0987654321",
              "title": "Safe title",
              "sourceRuntime": "codex",
              "state": "active",
              "updatedAt": "2027-01-15T08:00:00Z",
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
          "createdAt": "2027-01-15T08:00:00Z",
          "updatedAt": "2027-01-15T08:00:00Z"
        }
      ],
      "warnings": []
    }
    """
}

private enum ProbeError: Error {
    case invalidResponse
    case unexpectedEOF
    case serverDidNotStop
}
