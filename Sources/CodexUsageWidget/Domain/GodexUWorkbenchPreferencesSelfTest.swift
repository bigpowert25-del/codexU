import Foundation

enum GodexUWorkbenchPreferencesSelfTest {
    static func run() -> Bool {
        var failures: [String] = []

        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() {
                failures.append(message)
            }
        }

        let suiteName = "codexU.workbench-preferences-self-test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            print("workbench preferences self-test failed: could not create UserDefaults suite")
            return false
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        expect(
            GodexUSkin.storedOrDefault(defaults: defaults) == .titaniumStudio,
            "fresh skin should default to Titanium Studio"
        )
        expect(
            GodexUWorkbenchStage.storedOrDefault(defaults: defaults) == .sync,
            "fresh workbench stage should default to Sync"
        )
        expect(
            GodexUSkin.allCases.map(\.rawValue) == [
                "titaniumStudio",
                "nebulaGlass",
                "tacticalOLED",
                "mineralLight",
                "orbitCommand"
            ],
            "skin identifiers changed"
        )
        expect(
            GodexUWorkbenchStage.allCases.map(\.rawValue) == [
                "light",
                "sync",
                "command"
            ],
            "workbench stage identifiers changed"
        )
        expect(
            GodexUWorkbenchStage.light.usesCompactSystemStatus,
            "Light stage should use compact local system status"
        )
        expect(
            !GodexUWorkbenchStage.sync.usesCompactSystemStatus
                && !GodexUWorkbenchStage.command.usesCompactSystemStatus,
            "Sync and Command should keep full local system status"
        )
        expect(
            GodexUWorkbenchStage.allCases.allSatisfy(\.showsMetricSourceLabels),
            "every stage should show metric source labels"
        )

        let initial = AppSettings(defaults: defaults)
        expect(initial.workbenchSkin == .titaniumStudio, "AppSettings skin default changed")
        expect(initial.workbenchStage == .sync, "AppSettings stage default changed")

        initial.workbenchSkin = .orbitCommand
        initial.workbenchStage = .command
        expect(
            defaults.string(forKey: GodexUSkin.storageKey) == GodexUSkin.orbitCommand.rawValue,
            "skin did not persist immediately"
        )
        expect(
            defaults.string(forKey: GodexUWorkbenchStage.storageKey)
                == GodexUWorkbenchStage.command.rawValue,
            "stage did not persist immediately"
        )

        let restored = AppSettings(defaults: defaults)
        expect(restored.workbenchSkin == .orbitCommand, "stored skin did not round-trip")
        expect(restored.workbenchStage == .command, "stored stage did not round-trip")

        defaults.set("future-skin", forKey: GodexUSkin.storageKey)
        defaults.set("future-stage", forKey: GodexUWorkbenchStage.storageKey)
        expect(
            GodexUSkin.storedOrDefault(defaults: defaults) == .titaniumStudio,
            "unknown skin should fall back to Titanium Studio"
        )
        expect(
            GodexUWorkbenchStage.storedOrDefault(defaults: defaults) == .sync,
            "unknown stage should fall back to Sync"
        )

        let titanium = GodexUSkin.titaniumStudio.visualTokens
        expect(titanium.accentBlue > titanium.accentRed, "Titanium accent should remain blue-led")
        expect(titanium.chromeOpacity > 0, "Titanium chrome opacity should be visible")
        expect(
            Set(GodexUSkin.allCases.map(\.visualTokens.identity)).count
                == GodexUSkin.allCases.count,
            "skin token identities should be unique"
        )

        let taskBoard = TaskBoard(
            refreshedAt: Date(timeIntervalSince1970: 2_000_000),
            columns: [
                TaskColumn(id: .active, title: "Active", count: 3, items: []),
                TaskColumn(id: .pending, title: "Pending", count: 7, items: []),
                TaskColumn(id: .scheduled, title: "Scheduled", count: 2, items: []),
                TaskColumn(id: .done, title: "Done", count: 11, items: [])
            ]
        )
        let node = AgentNodeSnapshot(
            descriptor: AgentNodeDescriptor(
                id: "local-codex",
                displayName: "Codex",
                deviceName: "Mac",
                runtime: .codex,
                location: .local,
                sshHost: nil,
                probeProfile: nil
            ),
            health: .available,
            checkedAt: Date(timeIntervalSince1970: 2_000_000),
            lastSeenAt: Date(timeIntervalSince1970: 2_000_000),
            heartbeatAt: nil,
            processCount: 1,
            sourceLabel: "Local",
            detailCode: "available",
            isFromCache: false
        )
        let overview = GodexUWorkbenchOverview.make(
            officialLatestDayTokens: 313_600_000,
            officialSevenDayTokens: 2_700_000_000,
            taskBoard: taskBoard,
            nodes: [node]
        )
        expect(overview.activeTaskCount == 3, "active task count was not preserved")
        expect(overview.pendingTaskCount == 7, "pending task count was not preserved")
        expect(overview.availableNodeCount == 1, "available node count was not preserved")
        expect(overview.observedNodeCount == 1, "observed node count was not preserved")

        let unavailable = GodexUWorkbenchOverview.make(
            officialLatestDayTokens: nil,
            officialSevenDayTokens: nil,
            taskBoard: nil,
            nodes: []
        )
        expect(unavailable.activeTaskCount == nil, "missing task board became a fake zero")
        expect(unavailable.pendingTaskCount == nil, "missing pending count became a fake zero")
        expect(unavailable.availableNodeCount == nil, "missing nodes became a fake zero")
        expect(unavailable.observedNodeCount == nil, "missing node total became a fake zero")

        let latestActiveUsage = PricedTokenUsage(
            tokens: TokenBreakdown(
                inputTokens: 500,
                cachedInputTokens: 0,
                outputTokens: 0,
                reasoningOutputTokens: 0,
                totalTokens: 500
            ),
            estimatedCostUSD: 0
        )
        let emptyTodayUsage = PricedTokenUsage(tokens: .zero, estimatedCostUSD: 0)
        let sevenDayUsage = PricedTokenUsage(
            tokens: TokenBreakdown(
                inputTokens: 3_200,
                cachedInputTokens: 0,
                outputTokens: 0,
                reasoningOutputTokens: 0,
                totalTokens: 3_200
            ),
            estimatedCostUSD: 0
        )
        let trend = UsageTrend(
            dayBuckets: [
                UsageDayBucket(
                    id: "2026-07-29",
                    date: Date(timeIntervalSince1970: 1_775_000_000),
                    usage: latestActiveUsage,
                    sourceQuality: .official
                ),
                UsageDayBucket(
                    id: "2026-07-30",
                    date: Date(timeIntervalSince1970: 1_775_086_400),
                    usage: emptyTodayUsage,
                    sourceQuality: .official
                )
            ],
            heatmapWeeks: [],
            heatmapThresholds: [],
            summary: UsageTrendSummary(
                sevenDay: sevenDayUsage,
                dailyAverageTokens: 457,
                peakDay: nil,
                changePercent: nil,
                isNewActivity: false
            ),
            month: sevenDayUsage,
            projectedMonthCostUSD: nil,
            activeDayCount: 1,
            sourceQuality: .official
        )
        let officialOverview = GodexUWorkbenchOverview.make(
            officialTrend: trend,
            taskBoard: nil,
            nodes: []
        )
        expect(
            officialOverview.officialLatestDayTokens == 500,
            "empty current-day bucket replaced the latest official active day"
        )
        expect(
            officialOverview.officialSevenDayTokens == 3_200,
            "official seven-day total did not use the official trend summary"
        )

        if failures.isEmpty {
            print("workbench preferences self-test passed")
            return true
        }
        failures.forEach { print("workbench preferences self-test failed: \($0)") }
        return false
    }
}
