import CoreGraphics
import Foundation

enum DynamicIslandPresentationSelfTest {
    static func run() -> Bool {
        let now = Date(timeIntervalSince1970: 1_785_120_000)
        let codexSnapshot = RuntimeUsageSnapshot(
            scope: .codex,
            snapshot: UsageSnapshot(
                refreshedAt: now,
                account: nil,
                limitId: nil,
                limitName: nil,
                quotaReadSucceeded: true,
                fiveHourQuota: RateWindow(
                    usedPercent: 42,
                    windowDurationMins: 300,
                    resetsAt: now.addingTimeInterval(60 * 45)
                ),
                sevenDayQuota: RateWindow(
                    usedPercent: 64,
                    windowDurationMins: 10_080,
                    resetsAt: now.addingTimeInterval(60 * 60 * 36)
                ),
                credits: nil,
                cloudLifetimeTokens: nil,
                cloudPeakDailyTokens: nil,
                cloudUsageTrend: nil,
                local: nil,
                taskBoard: nil,
                messages: []
            ),
            status: .available,
            quotaSourceLabel: "official",
            usageSourceLabel: "local"
        )
        let openClawSnapshot = RuntimeUsageSnapshot(
            scope: .openClaw,
            snapshot: .empty,
            status: .snapshotNeeded,
            quotaSourceLabel: "nas snapshot",
            usageSourceLabel: "nas snapshot"
        )
        let board = TaskBoard(
            refreshedAt: now,
            columns: [
                TaskColumn(
                    id: .pending,
                    title: "Pending",
                    count: 1,
                    items: [
                        TaskItem(
                            id: "codex-attention",
                            code: "COD-1",
                            title: "Needs input",
                            detail: "Waiting for approval",
                            chip: "pending",
                            updatedAt: now.addingTimeInterval(-120),
                            tokens: nil,
                            kind: .pending,
                            source: .codex,
                            summary: nil,
                            recentReply: nil,
                            timing: nil,
                            progress: nil,
                            navigationTarget: nil
                        )
                    ]
                )
            ]
        )
        let presentation = DynamicIslandPresentationBuilder().build(
            DynamicIslandPresentationInput(
                runtimes: [codexSnapshot, openClawSnapshot],
                visibleScopes: [.codex, .openClaw],
                aggregateTaskBoard: board,
                system: LocalSystemSnapshot(
                    cpuUsagePercent: 37.6,
                    memoryUsedBytes: 12 * 1024 * 1024 * 1024,
                    memoryTotalBytes: 16 * 1024 * 1024 * 1024,
                    temperatureCelsius: nil,
                    thermalLevel: .nominal,
                    sampledAt: now
                ),
                language: .zh,
                now: now
            )
        )

        var failures: [String] = []
        if presentation.headline != "Codex 42%" {
            failures.append("expected Codex quota headline")
        }
        if presentation.systemMetrics.map(\.value) != ["38%", "75%", "正常"] {
            failures.append("expected formatted CPU, memory, and thermal metrics")
        }
        if presentation.runtimeRows.map(\.name) != ["Codex", "OpenClaw"] {
            failures.append("expected visible runtime rows")
        }
        if presentation.attentionTasks.map(\.title) != ["Needs input"] {
            failures.append("expected attention task summary")
        }
        failures.append(contentsOf: runQuotaTopologyTest(now: now, sevenDay: codexSnapshot.snapshot.sevenDayQuota))
        failures.append(contentsOf: runInteractionStabilityTest())
        failures.append(contentsOf: runDockingTest())
        failures.append(contentsOf: runSideLayoutContentFitTest())

        if failures.isEmpty {
            print("dynamic island presentation self-test passed")
            return true
        }
        failures.forEach { print("dynamic island presentation self-test failed: \($0)") }
        return false
    }

    private static func runQuotaTopologyTest(now: Date, sevenDay: RateWindow?) -> [String] {
        var failures: [String] = []
        let weeklyOnlyRuntime = RuntimeUsageSnapshot(
            scope: .codex,
            snapshot: UsageSnapshot(
                refreshedAt: now,
                account: nil,
                limitId: nil,
                limitName: nil,
                quotaReadSucceeded: true,
                fiveHourQuota: nil,
                sevenDayQuota: sevenDay,
                credits: nil,
                cloudLifetimeTokens: nil,
                cloudPeakDailyTokens: nil,
                cloudUsageTrend: nil,
                local: nil,
                taskBoard: nil,
                messages: []
            ),
            status: .available,
            quotaSourceLabel: "official",
            usageSourceLabel: "local"
        )
        let presentation = DynamicIslandPresentationBuilder().build(
            DynamicIslandPresentationInput(
                runtimes: [weeklyOnlyRuntime],
                visibleScopes: [.codex],
                aggregateTaskBoard: nil,
                system: .empty,
                language: .zh,
                now: now
            )
        )

        if presentation.headline != "Codex 64% 7d" {
            failures.append("weekly-only quota should label the headline as 7d")
        }
        if presentation.quotaLine != "36% 7d" {
            failures.append("weekly-only quota line should omit the missing 5h window")
        }
        if presentation.quotaLine.contains("5h") {
            failures.append("weekly-only quota line must not render a fake 5h placeholder")
        }

        return failures
    }

    private static func runInteractionStabilityTest() -> [String] {
        var failures: [String] = []
        var interaction = DynamicIslandInteractionState()

        if interaction.hoverChanged(true) == nil {
            failures.append("expected hover enter to schedule a peek transition")
        }
        _ = interaction.hoverChanged(false)
        _ = interaction.applyPendingHover(token: 1)
        if interaction.mode != .compact {
            failures.append("quick enter/exit should remain compact")
        }

        guard let stableEnter = interaction.hoverChanged(true) else {
            failures.append("expected stable hover enter to schedule a transition")
            return failures
        }
        _ = interaction.applyPendingHover(token: stableEnter.token)
        if interaction.mode != .peek {
            failures.append("stable hover should enter peek mode")
        }

        guard let stableExit = interaction.hoverChanged(false) else {
            failures.append("expected stable hover exit to schedule a transition")
            return failures
        }
        _ = interaction.toggleExpanded()
        _ = interaction.applyPendingHover(token: stableExit.token)
        if interaction.mode != .expanded {
            failures.append("stale hover exit should not collapse pinned expanded mode")
        }

        _ = interaction.closeExpanded()
        if interaction.mode != .compact {
            failures.append("close button should return to compact mode")
        }

        return failures
    }

    private static func runDockingTest() -> [String] {
        var failures: [String] = []
        let screen = CGRect(x: 0, y: 0, width: 1_000, height: 800)

        let topSize = DynamicIslandMode.compact.size(for: .top)
        if !(topSize.width > topSize.height) {
            failures.append("top compact island should remain a horizontal capsule")
        }

        let leftSize = DynamicIslandMode.compact.size(for: .left)
        if !(leftSize.height > leftSize.width) {
            failures.append("left compact island should become a vertical capsule")
        }

        if DynamicIslandDockResolver.nearestDock(
            proposedCenter: CGPoint(x: 18, y: 420),
            screenFrame: screen
        ) != .left {
            failures.append("drag near left edge should snap to left dock")
        }

        if DynamicIslandDockResolver.nearestDock(
            proposedCenter: CGPoint(x: 982, y: 420),
            screenFrame: screen
        ) != .right {
            failures.append("drag near right edge should snap to right dock")
        }

        if DynamicIslandDockResolver.nearestDock(
            proposedCenter: CGPoint(x: 500, y: 790),
            screenFrame: screen
        ) != .top {
            failures.append("drag near top edge should snap to top dock")
        }

        let leftFrame = DynamicIslandDockResolver.windowRect(
            for: .compact,
            dock: .left,
            screenFrame: screen,
            sideCenterY: 720
        )
        if leftFrame.minX != DynamicIslandDockResolver.edgeMargin {
            failures.append("left dock should attach to the left edge margin")
        }
        if leftFrame.height <= leftFrame.width {
            failures.append("left dock frame should be vertical")
        }

        let rightFrame = DynamicIslandDockResolver.windowRect(
            for: .compact,
            dock: .right,
            screenFrame: screen,
            sideCenterY: 80
        )
        if rightFrame.maxX != screen.maxX - DynamicIslandDockResolver.edgeMargin {
            failures.append("right dock should attach to the right edge margin")
        }
        if rightFrame.minY < screen.minY + DynamicIslandDockResolver.edgeMargin {
            failures.append("right dock should clamp low side positions inside the screen")
        }

        var comboGate = DynamicIslandComboDragGate()
        _ = comboGate.apply(.leftDown)
        if comboGate.isReady {
            failures.append("left button alone must not start reposition dragging")
        }
        _ = comboGate.apply(.rightDown)
        if !comboGate.isReady {
            failures.append("left and right buttons together should enable reposition dragging")
        }
        _ = comboGate.apply(.leftUp)
        if comboGate.isReady {
            failures.append("releasing either button should end reposition dragging")
        }

        return failures
    }

    private static func runSideLayoutContentFitTest() -> [String] {
        var failures: [String] = []
        let expectedCompactSize = CGSize(width: 54, height: 142)
        let expectedPeekSize = CGSize(width: 92, height: 270)

        let rightCompactSize = DynamicIslandMode.compact.size(for: .right)
        if rightCompactSize != expectedCompactSize {
            failures.append("side compact island should fit its content without surplus vertical space")
        }

        let rightPeekSize = DynamicIslandMode.peek.size(for: .right)
        if rightPeekSize != expectedPeekSize {
            failures.append("side peek island should fit its content without surplus vertical space")
        }

        if DynamicIslandMode.compact.size(for: .left) != rightCompactSize {
            failures.append("left and right compact islands should use symmetric sizes")
        }
        if DynamicIslandMode.peek.size(for: .left) != rightPeekSize {
            failures.append("left and right peek islands should use symmetric sizes")
        }

        return failures
    }
}
