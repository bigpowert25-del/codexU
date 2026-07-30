import Foundation

enum GodexUProjectIndexSelfTest {
    static func run() -> Bool {
        var failures: [String] = []
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let projectID = AgentProjectWorkspaceBuilder.projectID(
            forDerivedName: "Workspace"
        )
        let index = GodexUProjectIndex.make(
            generatedAt: now,
            freshness: .fresh,
            runtimeAvailability: [
                GodexURuntimeAvailability(
                    runtime: .codex,
                    status: .available
                ),
                GodexURuntimeAvailability(
                    runtime: .hermes,
                    status: .unavailable
                )
            ],
            tasks: [
                GodexUProjectIndexTaskInput(
                    nativeID: "raw-thread-secret",
                    title: "  Safe task title  ",
                    projectName: "Workspace",
                    sourceRuntime: .codex,
                    state: .active,
                    updatedAt: now,
                    progressPercent: 45
                )
            ],
            envelopes: [
                GodexUHandoffSummary(
                    id: UUID(
                        uuidString: "00000000-0000-0000-0000-000000000001"
                    )!,
                    projectID: projectID,
                    projectName: "Workspace",
                    title: "Review result",
                    sourceRuntime: .codex,
                    targetRuntime: .openClaw,
                    state: .ready,
                    revision: 1,
                    createdAt: now,
                    updatedAt: now
                )
            ],
            warnings: []
        )

        do {
            let data = try GodexUProjectIndexCodec.encode(index)
            let text = String(decoding: data, as: UTF8.self)
            check(
                index.schema == "godexu-project-index-v1",
                "schema mismatch",
                failures: &failures
            )
            check(
                index.deviceScope == "local-mac",
                "device scope mismatch",
                failures: &failures
            )
            check(
                !text.contains("raw-thread-secret"),
                "raw native task ID leaked",
                failures: &failures
            )
            check(
                !text.contains("handoffNote"),
                "handoff note key leaked",
                failures: &failures
            )
            let decoded = try GodexUProjectIndexCodec.decode(data)
            check(
                decoded == index,
                "strict codec round trip failed",
                failures: &failures
            )

            var object = try JSONSerialization.jsonObject(with: data)
                as! [String: Any]
            object["unknown"] = true
            let unknownData = try JSONSerialization.data(withJSONObject: object)
            check(
                (try? GodexUProjectIndexCodec.decode(unknownData)) == nil,
                "unknown top-level key was accepted",
                failures: &failures
            )
        } catch {
            failures.append("codec error")
        }

        let firstTaskID = index.projects.first?.tasks.first?.id
        let repeated = GodexUProjectIndex.make(
            generatedAt: now,
            freshness: .fresh,
            runtimeAvailability: [],
            tasks: [
                GodexUProjectIndexTaskInput(
                    nativeID: "raw-thread-secret",
                    title: "Safe task title",
                    projectName: "Workspace",
                    sourceRuntime: .codex,
                    state: .active,
                    updatedAt: now,
                    progressPercent: 45
                )
            ],
            envelopes: [],
            warnings: []
        )
        check(
            firstTaskID == repeated.projects.first?.tasks.first?.id,
            "normalized task ID is unstable",
            failures: &failures
        )
        check(
            firstTaskID?.contains("raw-thread-secret") == false,
            "normalized task ID contains native ID",
            failures: &failures
        )
        check(
            GodexUProjectIndexQuery.limit(500) == 50,
            "query limit was not bounded",
            failures: &failures
        )
        check(
            GodexUProjectIndexQuery.projectID("../../../tmp") == nil,
            "unsafe project ID was accepted",
            failures: &failures
        )
        check(
            GodexUProjectIndexQuery.projectID(projectID) == projectID,
            "valid project ID was rejected",
            failures: &failures
        )

        failures.forEach {
            fputs("project index self-test failed: \($0)\n", stderr)
        }
        if failures.isEmpty {
            print("project index self-test passed")
        }
        return failures.isEmpty
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
