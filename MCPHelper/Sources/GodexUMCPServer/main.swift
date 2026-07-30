import Foundation
import GodexUMCPCore
import MCP

@main
struct GodexUMCPServerMain {
    static func main() async {
        guard CommandLine.arguments.count == 1 else {
            fputs("invalid_arguments\n", stderr)
            exit(2)
        }

        do {
            let helperURL = Bundle.main.executableURL
                ?? URL(fileURLWithPath: CommandLine.arguments[0])
            let command = try BundledAppCommand(
                helperExecutableURL: helperURL
            )
            let cache = ProjectIndexCache {
                try await Task.detached(priority: .userInitiated) {
                    try command.load(timeout: 3)
                }.value
            }
            let server = Server(
                name: "GodexU",
                version: "0.1.0",
                title: "GodexU Local Project Index",
                instructions: "Read-only Mac-local project and handoff metadata.",
                capabilities: .init(
                    resources: .init(),
                    tools: .init()
                ),
                configuration: .strict
            )
            await registerHandlers(server: server, cache: cache)
            let transport = StdioTransport()
            try await server.start(transport: transport)
            await server.waitUntilCompleted()
        } catch let error as PublicSnapshotError {
            fputs("\(error.code)\n", stderr)
            exit(1)
        } catch {
            fputs("mcp_server_unavailable\n", stderr)
            exit(1)
        }
    }

    private static func registerHandlers(
        server: Server,
        cache: ProjectIndexCache
    ) async {
        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: tools)
        }
        await server.withMethodHandler(CallTool.self) { parameters in
            guard Set([
                "godexu_project_list",
                "godexu_project_get",
                "godexu_handoff_list"
            ]).contains(parameters.name) else {
                throw MCPError.invalidParams("tool_not_found")
            }
            do {
                let index = try await cache.snapshot()
                let service = ProjectIndexQueryService(index: index)
                switch parameters.name {
                case "godexu_project_list":
                    let arguments = try validatedArguments(
                        parameters.arguments,
                        allowed: ["runtime", "state", "limit"]
                    )
                    let result = try service.projects(
                        runtime: try stringArgument(
                            "runtime",
                            in: arguments
                        ),
                        state: try stringArgument("state", in: arguments),
                        limit: try integerArgument("limit", in: arguments)
                    )
                    return try toolResult(result)
                case "godexu_project_get":
                    let arguments = try validatedArguments(
                        parameters.arguments,
                        allowed: ["projectID"],
                        required: ["projectID"]
                    )
                    guard let projectID = try stringArgument(
                        "projectID",
                        in: arguments
                    ) else {
                        throw PublicSnapshotError(code: "invalid_parameters")
                    }
                    return try toolResult(
                        service.project(id: projectID)
                    )
                case "godexu_handoff_list":
                    let arguments = try validatedArguments(
                        parameters.arguments,
                        allowed: ["state", "targetRuntime", "limit"]
                    )
                    let result = try service.handoffs(
                        state: try stringArgument("state", in: arguments),
                        targetRuntime: try stringArgument(
                            "targetRuntime",
                            in: arguments
                        ),
                        limit: try integerArgument("limit", in: arguments)
                    )
                    return try toolResult(result)
                default:
                    throw PublicSnapshotError(code: "tool_not_found")
                }
            } catch let error as PublicSnapshotError {
                return errorToolResult(code: error.code)
            } catch {
                return errorToolResult(code: "snapshot_unavailable")
            }
        }
        await server.withMethodHandler(ListResources.self) { _ in
            ListResources.Result(resources: [
                Resource(
                    name: "GodexU Projects",
                    uri: "godexu://projects",
                    title: "Local project index",
                    description: "Bounded Mac-local project summaries.",
                    mimeType: "application/json"
                )
            ])
        }
        await server.withMethodHandler(ListResourceTemplates.self) { _ in
            ListResourceTemplates.Result(templates: [
                Resource.Template(
                    uriTemplate: "godexu://projects/{projectID}",
                    name: "GodexU Project",
                    title: "Local project",
                    description: "One bounded local project and its task rows.",
                    mimeType: "application/json"
                ),
                Resource.Template(
                    uriTemplate: "godexu://handoffs/{envelopeID}",
                    name: "GodexU Handoff",
                    title: "Local handoff",
                    description: "One bounded handoff without its note.",
                    mimeType: "application/json"
                )
            ])
        }
        await server.withMethodHandler(ReadResource.self) { parameters in
            do {
                let index = try await cache.snapshot()
                let service = ProjectIndexQueryService(index: index)
                let payload: EncodablePayload
                if parameters.uri == "godexu://projects" {
                    payload = try encodedPayload(
                        service.projects(
                            runtime: nil,
                            state: nil,
                            limit: 50
                        )
                    )
                } else if parameters.uri.hasPrefix("godexu://projects/") {
                    let id = String(
                        parameters.uri.dropFirst("godexu://projects/".count)
                    )
                    payload = try encodedPayload(service.project(id: id))
                } else if parameters.uri.hasPrefix("godexu://handoffs/") {
                    let id = String(
                        parameters.uri.dropFirst("godexu://handoffs/".count)
                    )
                    payload = try encodedPayload(service.handoff(id: id))
                } else {
                    throw PublicSnapshotError(code: "not_found")
                }
                return ReadResource.Result(contents: [
                    .text(
                        payload.text,
                        uri: parameters.uri,
                        mimeType: "application/json"
                    )
                ])
            } catch let error as PublicSnapshotError {
                throw MCPError.invalidParams(error.code)
            } catch {
                throw MCPError.internalError("snapshot_unavailable")
            }
        }
    }

    private static let annotations = Tool.Annotations(
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false
    )

    private static let runtimeSchema: Value = [
        "type": "string",
        "enum": ["codex", "openclaw", "claude-code", "hermes"]
    ]

    private static let taskStateSchema: Value = [
        "type": "string",
        "enum": ["active", "pending", "scheduled", "done"]
    ]

    private static let limitSchema: Value = [
        "type": "integer",
        "minimum": 1,
        "maximum": 50,
        "default": 20
    ]

    private static let dateSchema: Value = [
        "type": "string",
        "format": "date-time"
    ]

    private static let freshnessSchema: Value = [
        "type": "string",
        "enum": ["fresh", "stale"]
    ]

    private static let runtimeOutputSchema: Value = [
        "type": "string",
        "enum": ["codex", "openClaw", "claudeCode", "hermes"]
    ]

    private static let runtimeAvailabilitySchema: Value = [
        "type": "array",
        "maxItems": 4,
        "items": [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "runtime": runtimeOutputSchema,
                "status": [
                    "type": "string",
                    "enum": [
                        "available",
                        "localOnly",
                        "snapshotNeeded",
                        "stale",
                        "unavailable"
                    ]
                ]
            ],
            "required": ["runtime", "status"]
        ]
    ]

    private static let warningsSchema: Value = [
        "type": "array",
        "maxItems": 32,
        "items": [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "code": ["type": "string", "maxLength": 64]
            ],
            "required": ["code"]
        ]
    ]

    private static let countSchema: Value = [
        "type": "integer",
        "minimum": 0
    ]

    private static let projectListItemSchema: Value = [
        "type": "object",
        "additionalProperties": false,
        "properties": [
            "id": ["type": "string"],
            "name": ["type": "string"],
            "isDerived": ["type": "boolean"],
            "sourceRuntimes": [
                "type": "array",
                "items": runtimeOutputSchema
            ],
            "activeCount": countSchema,
            "pendingCount": countSchema,
            "scheduledCount": countSchema,
            "doneCount": countSchema,
            "totalCount": countSchema,
            "handoffCount": countSchema,
            "lastActiveAt": dateSchema
        ],
        "required": [
            "id",
            "name",
            "isDerived",
            "sourceRuntimes",
            "activeCount",
            "pendingCount",
            "scheduledCount",
            "doneCount",
            "totalCount",
            "handoffCount"
        ]
    ]

    private static let projectTaskSchema: Value = [
        "type": "object",
        "additionalProperties": false,
        "properties": [
            "id": ["type": "string"],
            "title": ["type": "string"],
            "sourceRuntime": runtimeOutputSchema,
            "state": taskStateSchema,
            "updatedAt": dateSchema,
            "progressPercent": [
                "type": "number",
                "minimum": 0,
                "maximum": 100
            ]
        ],
        "required": ["id", "title", "sourceRuntime", "state"]
    ]

    private static let projectOutputSchema: Value = [
        "type": "object",
        "additionalProperties": false,
        "properties": [
            "id": ["type": "string"],
            "name": ["type": "string"],
            "isDerived": ["type": "boolean"],
            "sourceRuntimes": [
                "type": "array",
                "items": runtimeOutputSchema
            ],
            "activeCount": countSchema,
            "pendingCount": countSchema,
            "scheduledCount": countSchema,
            "doneCount": countSchema,
            "totalCount": countSchema,
            "handoffCount": countSchema,
            "lastActiveAt": dateSchema,
            "tasks": [
                "type": "array",
                "maxItems": 100,
                "items": projectTaskSchema
            ]
        ],
        "required": [
            "id",
            "name",
            "isDerived",
            "sourceRuntimes",
            "activeCount",
            "pendingCount",
            "scheduledCount",
            "doneCount",
            "totalCount",
            "handoffCount",
            "tasks"
        ]
    ]

    private static let handoffSchema: Value = [
        "type": "object",
        "additionalProperties": false,
        "properties": [
            "id": ["type": "string", "format": "uuid"],
            "projectID": ["type": "string"],
            "projectName": ["type": "string"],
            "title": ["type": "string"],
            "sourceRuntime": runtimeOutputSchema,
            "targetRuntime": runtimeOutputSchema,
            "state": [
                "type": "string",
                "enum": ["draft", "ready"]
            ],
            "revision": ["type": "integer", "minimum": 1],
            "createdAt": dateSchema,
            "updatedAt": dateSchema
        ],
        "required": [
            "id",
            "projectID",
            "projectName",
            "title",
            "sourceRuntime",
            "targetRuntime",
            "state",
            "revision",
            "createdAt",
            "updatedAt"
        ]
    ]

    private static let projectListOutputSchema: Value = [
        "type": "object",
        "additionalProperties": false,
        "properties": [
            "generatedAt": dateSchema,
            "freshness": freshnessSchema,
            "runtimeAvailability": runtimeAvailabilitySchema,
            "warnings": warningsSchema,
            "appliedLimit": [
                "type": "integer",
                "minimum": 1,
                "maximum": 50
            ],
            "projects": [
                "type": "array",
                "maxItems": 50,
                "items": projectListItemSchema
            ]
        ],
        "required": [
            "generatedAt",
            "freshness",
            "runtimeAvailability",
            "warnings",
            "appliedLimit",
            "projects"
        ]
    ]

    private static let handoffListOutputSchema: Value = [
        "type": "object",
        "additionalProperties": false,
        "properties": [
            "generatedAt": dateSchema,
            "freshness": freshnessSchema,
            "runtimeAvailability": runtimeAvailabilitySchema,
            "warnings": warningsSchema,
            "appliedLimit": [
                "type": "integer",
                "minimum": 1,
                "maximum": 50
            ],
            "handoffs": [
                "type": "array",
                "maxItems": 50,
                "items": handoffSchema
            ]
        ],
        "required": [
            "generatedAt",
            "freshness",
            "runtimeAvailability",
            "warnings",
            "appliedLimit",
            "handoffs"
        ]
    ]

    private static let tools: [Tool] = [
        Tool(
            name: "godexu_project_list",
            title: "List GodexU projects",
            description: "List bounded Mac-local project summaries.",
            inputSchema: [
                "type": "object",
                "additionalProperties": false,
                "properties": [
                    "runtime": runtimeSchema,
                    "state": taskStateSchema,
                    "limit": limitSchema
                ]
            ],
            annotations: annotations,
            outputSchema: projectListOutputSchema
        ),
        Tool(
            name: "godexu_project_get",
            title: "Get a GodexU project",
            description: "Read one bounded Mac-local project.",
            inputSchema: [
                "type": "object",
                "additionalProperties": false,
                "properties": [
                    "projectID": [
                        "type": "string",
                        "maxLength": 96
                    ]
                ],
                "required": ["projectID"]
            ],
            annotations: annotations,
            outputSchema: projectOutputSchema
        ),
        Tool(
            name: "godexu_handoff_list",
            title: "List GodexU handoffs",
            description: "List bounded handoff metadata without notes.",
            inputSchema: [
                "type": "object",
                "additionalProperties": false,
                "properties": [
                    "state": [
                        "type": "string",
                        "enum": ["draft", "ready"]
                    ],
                    "targetRuntime": runtimeSchema,
                    "limit": limitSchema
                ]
            ],
            annotations: annotations,
            outputSchema: handoffListOutputSchema
        )
    ]

    private static func validatedArguments(
        _ value: [String: Value]?,
        allowed: Set<String>,
        required: Set<String> = []
    ) throws -> [String: Value] {
        let arguments = value ?? [:]
        let keys = Set(arguments.keys)
        guard keys.isSubset(of: allowed), required.isSubset(of: keys) else {
            throw PublicSnapshotError(code: "invalid_parameters")
        }
        return arguments
    }

    private static func stringArgument(
        _ key: String,
        in arguments: [String: Value]
    ) throws -> String? {
        guard let value = arguments[key] else { return nil }
        guard let text = value.stringValue, text.count <= 96 else {
            throw PublicSnapshotError(code: "invalid_parameters")
        }
        return text
    }

    private static func integerArgument(
        _ key: String,
        in arguments: [String: Value]
    ) throws -> Int? {
        guard let value = arguments[key] else { return nil }
        guard let number = value.intValue else {
            throw PublicSnapshotError(code: "invalid_parameters")
        }
        return number
    }

    private static func toolResult<T: Encodable>(
        _ value: T
    ) throws -> CallTool.Result {
        let payload = try encodedPayload(value)
        return try CallTool.Result(
            content: [
                .text(
                    text: payload.text,
                    annotations: nil,
                    _meta: nil
                )
            ],
            structuredContent: payload.value
        )
    }

    private static func errorToolResult(code: String) -> CallTool.Result {
        CallTool.Result(
            content: [
                .text(
                    text: code,
                    annotations: nil,
                    _meta: nil
                )
            ],
            isError: true
        )
    }

    private static func encodedPayload<T: Encodable>(
        _ value: T
    ) throws -> EncodablePayload {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        return EncodablePayload(
            text: String(decoding: data, as: UTF8.self),
            value: try JSONDecoder().decode(Value.self, from: data)
        )
    }
}

private struct EncodablePayload {
    let text: String
    let value: Value
}
