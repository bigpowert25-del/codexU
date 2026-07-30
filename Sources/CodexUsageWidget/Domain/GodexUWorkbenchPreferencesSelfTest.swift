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

        let lightLayout = GodexUWorkbenchStage.light.layoutProfile
        let syncLayout = GodexUWorkbenchStage.sync.layoutProfile
        let commandLayout = GodexUWorkbenchStage.command.layoutProfile
        expect(
            Set([lightLayout.identity, syncLayout.identity, commandLayout.identity]).count == 3,
            "Light, Sync, and Command should have unique layout profile identities"
        )
        expect(
            lightLayout.sections == Set([
                .goalHero,
                .relationshipGraph,
                .metricRail,
                .taskComposer
            ]),
            "Light should keep only the glance modules and compact composer"
        )
        expect(
            syncLayout.sections == Set([
                .goalHero,
                .relationshipGraph,
                .metricRail,
                .projectContinuation,
                .systemTelemetry,
                .statusTicker,
                .taskComposer
            ]),
            "Sync should expose the complete seven-module overview"
        )
        expect(
            commandLayout.sections == Set([
                .goalHero,
                .relationshipGraph,
                .metricRail,
                .projectContinuation,
                .systemTelemetry,
                .statusTicker,
                .taskComposer,
                .commandInspector
            ]),
            "Command should add the persistent operations inspector"
        )
        expect(
            lightLayout.heroPresentation == .focus,
            "Light should prioritize a focused hero"
        )
        expect(
            syncLayout.heroPresentation == .balanced,
            "Sync should balance the hero and relationship graph"
        )
        expect(
            commandLayout.heroPresentation == .graphWeighted,
            "Command should give the relationship graph more hero space"
        )
        expect(
            lightLayout.lowerContentPresentation == .hidden,
            "Light should hide lower operational content"
        )
        expect(
            syncLayout.lowerContentPresentation == .split,
            "Sync should split projects and telemetry in the lower region"
        )
        expect(
            commandLayout.lowerContentPresentation == .singleColumn,
            "Command should use one operational column beside the inspector"
        )
        expect(
            lightLayout.composerPresentation == .compact,
            "Light should use the compact composer"
        )
        expect(
            syncLayout.composerPresentation == .standard
                && commandLayout.composerPresentation == .standard,
            "Sync and Command should use the standard composer"
        )
        expect(
            lightLayout.inspectorPresentation == .hidden
                && syncLayout.inspectorPresentation == .hidden,
            "Light and Sync should not reserve a persistent inspector"
        )
        expect(
            commandLayout.inspectorPresentation == .persistent,
            "Command should reserve a persistent read-only inspector"
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

        let skinTokens = GodexUSkin.allCases.map(\.visualTokens)

        expect(
            Set(skinTokens.map(\.identity)).count == skinTokens.count,
            "full-surface palette identities should be unique"
        )

        func hasSameVisualPayload(
            _ left: GodexUSkinVisualTokens,
            _ right: GodexUSkinVisualTokens
        ) -> Bool {
            left.canvasColor == right.canvasColor
                && left.deepCanvasColor == right.deepCanvasColor
                && left.shellColor == right.shellColor
                && left.sidebarColor == right.sidebarColor
                && left.primaryPanelColor == right.primaryPanelColor
                && left.elevatedPanelColor == right.elevatedPanelColor
                && left.primaryTextColor == right.primaryTextColor
                && left.secondaryTextColor == right.secondaryTextColor
                && left.dimTextColor == right.dimTextColor
                && left.accentColor == right.accentColor
                && left.secondaryAccentColor == right.secondaryAccentColor
                && left.attentionAccentColor == right.attentionAccentColor
                && left.subtleSeparatorColor == right.subtleSeparatorColor
                && left.strongSeparatorColor == right.strongSeparatorColor
                && left.controlRadius == right.controlRadius
                && left.panelRadius == right.panelRadius
                && left.density == right.density
                && left.shellShadow == right.shellShadow
                && left.showsGrid == right.showsGrid
                && left.chromeOpacity == right.chromeOpacity
                && left.selectedOpacity == right.selectedOpacity
        }

        for leftIndex in skinTokens.indices {
            for rightIndex in skinTokens.indices where rightIndex > leftIndex {
                expect(
                    !hasSameVisualPayload(skinTokens[leftIndex], skinTokens[rightIndex]),
                    "\(GodexUSkin.allCases[leftIndex].rawValue) and "
                        + "\(GodexUSkin.allCases[rightIndex].rawValue) should have "
                        + "different complete visual tokens"
                )
            }
        }
        for (skin, tokens) in zip(GodexUSkin.allCases, skinTokens) {
            let fullSurfacePalette = [
                tokens.canvasColor,
                tokens.deepCanvasColor,
                tokens.shellColor,
                tokens.sidebarColor,
                tokens.primaryPanelColor,
                tokens.elevatedPanelColor,
                tokens.primaryTextColor,
                tokens.secondaryTextColor,
                tokens.dimTextColor,
                tokens.accentColor,
                tokens.secondaryAccentColor,
                tokens.attentionAccentColor,
                tokens.subtleSeparatorColor,
                tokens.strongSeparatorColor
            ]
            expect(
                fullSurfacePalette.allSatisfy { color in
                    (0.0...1.0).contains(color.red)
                        && (0.0...1.0).contains(color.green)
                        && (0.0...1.0).contains(color.blue)
                        && (0.0...1.0).contains(color.opacity)
                },
                "\(skin.rawValue) should provide a complete normalized surface palette"
            )
            let essentialSurfaceAndTextColors = [
                tokens.canvasColor,
                tokens.deepCanvasColor,
                tokens.shellColor,
                tokens.sidebarColor,
                tokens.primaryPanelColor,
                tokens.elevatedPanelColor,
                tokens.primaryTextColor,
                tokens.secondaryTextColor,
                tokens.dimTextColor
            ]
            expect(
                essentialSurfaceAndTextColors.allSatisfy { $0.opacity > 0 },
                "\(skin.rawValue) should keep essential surfaces and text visible"
            )
            let backgroundColors = [
                tokens.canvasColor,
                tokens.deepCanvasColor,
                tokens.shellColor,
                tokens.sidebarColor,
                tokens.primaryPanelColor,
                tokens.elevatedPanelColor
            ]
            let foregroundColors = [
                tokens.primaryTextColor,
                tokens.secondaryTextColor,
                tokens.dimTextColor
            ]
            expect(
                foregroundColors.allSatisfy { !backgroundColors.contains($0) },
                "\(skin.rawValue) text colors should differ from every background surface"
            )
            expect(
                tokens.controlRadius >= 0
                    && tokens.panelRadius >= tokens.controlRadius,
                "\(skin.rawValue) should provide coherent control and panel radii"
            )
            expect(
                (0.0...1.0).contains(tokens.shellShadow.opacity)
                    && tokens.shellShadow.opacity.isFinite
                    && tokens.shellShadow.radius.isFinite
                    && tokens.shellShadow.radius >= 0
                    && tokens.shellShadow.xOffset.isFinite
                    && tokens.shellShadow.yOffset.isFinite,
                "\(skin.rawValue) should provide a valid shell shadow"
            )
            let shellShadowColorComponents = [
                tokens.shellShadow.color.red,
                tokens.shellShadow.color.green,
                tokens.shellShadow.color.blue,
                tokens.shellShadow.color.opacity
            ]
            expect(
                shellShadowColorComponents.allSatisfy {
                    $0.isFinite && (0.0...1.0).contains($0)
                },
                "\(skin.rawValue) should provide a normalized shell shadow color"
            )
            expect(
                tokens.chromeOpacity.isFinite
                    && (0.0...1.0).contains(tokens.chromeOpacity)
                    && tokens.selectedOpacity.isFinite
                    && (0.0...1.0).contains(tokens.selectedOpacity),
                "\(skin.rawValue) should provide normalized chrome and selection opacity"
            )
        }

        let normalizedInvalidColor = GodexUNormalizedColor(
            red: -0.5,
            green: 1.5,
            blue: .nan,
            opacity: .infinity
        )
        expect(
            normalizedInvalidColor.red == 0
                && normalizedInvalidColor.green == 1
                && normalizedInvalidColor.blue == 0
                && normalizedInvalidColor.opacity == 0,
            "normalized colors should clamp finite components and replace nonfinite values with zero"
        )
        let normalizedInvalidShadow = GodexUShellShadow(
            color: normalizedInvalidColor,
            opacity: 1.5,
            radius: -8,
            xOffset: .nan,
            yOffset: -.infinity
        )
        expect(
            normalizedInvalidShadow.opacity == 1
                && normalizedInvalidShadow.radius == 0
                && normalizedInvalidShadow.xOffset == 0
                && normalizedInvalidShadow.yOffset == 0,
            "shell shadows should clamp opacity and radius and zero nonfinite offsets"
        )
        let normalizedNonfiniteShadow = GodexUShellShadow(
            color: normalizedInvalidColor,
            opacity: .nan,
            radius: .infinity,
            xOffset: 0,
            yOffset: 0
        )
        expect(
            normalizedNonfiniteShadow.opacity == 0
                && normalizedNonfiniteShadow.radius == 0,
            "shell shadows should replace nonfinite opacity and radius with zero"
        )

        func canvasLuminance(_ tokens: GodexUSkinVisualTokens) -> Double {
            0.2126 * tokens.canvasColor.red
                + 0.7152 * tokens.canvasColor.green
                + 0.0722 * tokens.canvasColor.blue
        }

        let lightCanvasLuminanceFloor = 0.65
        let tacticalCanvasLuminanceCeiling = 0.10
        let tacticalMaximumControlRadius = 2.0
        let tacticalMaximumPanelRadius = 4.0
        let tactical = GodexUSkin.tacticalOLED.visualTokens
        expect(
            canvasLuminance(titanium) >= lightCanvasLuminanceFloor,
            "Titanium Studio should retain a light canvas"
        )
        expect(
            canvasLuminance(tactical) <= tacticalCanvasLuminanceCeiling,
            "Tactical OLED should retain a near-black canvas"
        )
        expect(
            tactical.controlRadius <= tacticalMaximumControlRadius
                && tactical.panelRadius <= tacticalMaximumPanelRadius
                && tactical.density != titanium.density,
            "Tactical OLED should retain compact square geometry and distinct density"
        )
        expect(
            skinTokens.contains(where: \.showsGrid)
                && skinTokens.contains(where: { !$0.showsGrid }),
            "skin contract should support both visible and hidden canvas grids"
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
