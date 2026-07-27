import Foundation

struct DynamicIslandPresentationInput {
    let runtimes: [RuntimeUsageSnapshot]
    let visibleScopes: [RuntimeScope]
    let aggregateTaskBoard: TaskBoard?
    let system: LocalSystemSnapshot
    let language: WidgetLanguage
    let now: Date
}

struct DynamicIslandMetric: Equatable {
    let id: String
    let title: String
    let value: String
    let detail: String
    let systemName: String
    let severity: DynamicIslandMetricSeverity
}

enum DynamicIslandMetricSeverity: Equatable {
    case normal
    case warning
    case danger
    case unknown
}

struct DynamicIslandRuntimeRow: Equatable, Identifiable {
    let scope: RuntimeScope
    let name: String
    let statusText: String
    let todayTokensText: String
    let quotaText: String
    let sourceText: String

    var id: String { scope.runtimeId }
}

struct DynamicIslandTaskSummary: Equatable, Identifiable {
    let id: String
    let source: RuntimeScope
    let title: String
    let statusText: String
    let updatedAt: Date?
}

struct DynamicIslandTaskCounts: Equatable {
    let active: Int
    let pending: Int
    let scheduled: Int
    let done: Int

    static let empty = DynamicIslandTaskCounts(active: 0, pending: 0, scheduled: 0, done: 0)
}

struct DynamicIslandPresentation: Equatable {
    let headline: String
    let subheadline: String
    let quotaLine: String
    let totalTodayTokensText: String
    let systemMetrics: [DynamicIslandMetric]
    let runtimeRows: [DynamicIslandRuntimeRow]
    let attentionTasks: [DynamicIslandTaskSummary]
    let taskCounts: DynamicIslandTaskCounts
    let refreshedAt: Date
}

struct DynamicIslandPresentationBuilder {
    func build(_ input: DynamicIslandPresentationInput) -> DynamicIslandPresentation {
        let visibleScopes = input.visibleScopes.isEmpty ? [.codex, .openClaw] : input.visibleScopes
        let runtimesByScope = Dictionary(uniqueKeysWithValues: input.runtimes.map { ($0.scope, $0) })
        let visibleRuntimeRows = visibleScopes.map { scope in
            runtimeRow(
                scope: scope,
                runtime: runtimesByScope[scope],
                language: input.language
            )
        }
        let codexRuntime = runtimesByScope[.codex]
        let headline = codexHeadline(runtime: codexRuntime, language: input.language)
        let totalToday = input.runtimes.reduce(Int64(0)) { total, runtime in
            total + (runtime.todayTokens ?? 0)
        }

        return DynamicIslandPresentation(
            headline: headline,
            subheadline: subheadline(
                attentionCount: attentionTasks(from: input, visibleScopes: visibleScopes).count,
                language: input.language
            ),
            quotaLine: quotaLine(runtime: codexRuntime, language: input.language),
            totalTodayTokensText: TokenFormatter.format(totalToday),
            systemMetrics: systemMetrics(from: input.system, language: input.language),
            runtimeRows: visibleRuntimeRows,
            attentionTasks: attentionTasks(from: input, visibleScopes: visibleScopes),
            taskCounts: taskCounts(from: input.aggregateTaskBoard),
            refreshedAt: input.now
        )
    }

    private func codexHeadline(runtime: RuntimeUsageSnapshot?, language: WidgetLanguage) -> String {
        guard let runtime else { return "Codex --" }
        if let window = runtime.snapshot.fiveHourQuota {
            return "Codex \(Int(window.usedPercent.rounded()))%"
        }
        if let window = runtime.snapshot.sevenDayQuota {
            return "Codex \(Int(window.usedPercent.rounded()))% 7d"
        }
        if runtime.status == .available, runtime.snapshot.quotaReadSucceeded {
            return language.text("Codex 可用", "Codex OK")
        }
        return "Codex --"
    }

    private func quotaLine(runtime: RuntimeUsageSnapshot?, language: WidgetLanguage) -> String {
        guard let runtime else { return language.text("额度暂无", "Quota unavailable") }
        let parts = quotaTextParts(runtime.snapshot)
        if !parts.isEmpty {
            return parts.joined(separator: " · ")
        }
        if runtime.status == .available, runtime.snapshot.quotaReadSucceeded {
            return language.text("当前无额度限制", "No active quota limits")
        }
        return language.text("额度暂无", "Quota unavailable")
    }

    private func quotaTextParts(_ snapshot: UsageSnapshot) -> [String] {
        var parts: [String] = []
        if let fiveHour = snapshot.fiveHourQuota {
            parts.append("\(Int(fiveHour.remainingPercent.rounded()))% 5h")
        }
        if let sevenDay = snapshot.sevenDayQuota {
            parts.append("\(Int(sevenDay.remainingPercent.rounded()))% 7d")
        }
        return parts
    }

    private func subheadline(attentionCount: Int, language: WidgetLanguage) -> String {
        if attentionCount > 0 {
            return language.text("\(attentionCount) 个任务需要注意", "\(attentionCount) task\(attentionCount == 1 ? "" : "s") need attention")
        }
        return language.text("任务正常流动", "Tasks flowing")
    }

    private func runtimeRow(
        scope: RuntimeScope,
        runtime: RuntimeUsageSnapshot?,
        language: WidgetLanguage
    ) -> DynamicIslandRuntimeRow {
        let todayTokens = runtime?.todayTokens.map(TokenFormatter.format) ?? "--"
        return DynamicIslandRuntimeRow(
            scope: scope,
            name: scope.displayName,
            statusText: (runtime?.status ?? .unavailable).localized(language),
            todayTokensText: todayTokens,
            quotaText: quotaLine(runtime: runtime, language: language),
            sourceText: runtime?.quotaSourceLabel ?? language.text("未读取", "Not read")
        )
    }

    private func systemMetrics(
        from snapshot: LocalSystemSnapshot,
        language: WidgetLanguage
    ) -> [DynamicIslandMetric] {
        [
            DynamicIslandMetric(
                id: "cpu",
                title: "CPU",
                value: snapshot.cpuUsagePercent.map { String(format: "%.0f%%", $0) } ?? "--",
                detail: language.text("系统总占用", "System total"),
                systemName: "cpu",
                severity: percentSeverity(snapshot.cpuUsagePercent)
            ),
            DynamicIslandMetric(
                id: "memory",
                title: language.text("内存", "Memory"),
                value: memoryPercentText(snapshot),
                detail: memoryDetailText(snapshot, language: language),
                systemName: "memorychip",
                severity: percentSeverity(memoryPercent(snapshot))
            ),
            DynamicIslandMetric(
                id: "thermal",
                title: language.text("温度", "Thermal"),
                value: thermalText(snapshot, language: language),
                detail: snapshot.temperatureCelsius == nil
                    ? language.text("macOS 热状态", "macOS thermal state")
                    : language.text("本机传感器", "Local sensor"),
                systemName: "thermometer.medium",
                severity: thermalSeverity(snapshot.thermalLevel)
            )
        ]
    }

    private func memoryPercent(_ snapshot: LocalSystemSnapshot) -> Double? {
        guard let used = snapshot.memoryUsedBytes,
              let total = snapshot.memoryTotalBytes,
              total > 0 else { return nil }
        return Double(used) / Double(total) * 100
    }

    private func memoryPercentText(_ snapshot: LocalSystemSnapshot) -> String {
        memoryPercent(snapshot).map { String(format: "%.0f%%", $0) } ?? "--"
    }

    private func memoryDetailText(_ snapshot: LocalSystemSnapshot, language: WidgetLanguage) -> String {
        guard let used = snapshot.memoryUsedBytes,
              let total = snapshot.memoryTotalBytes else {
            return language.text("物理内存", "Physical memory")
        }
        return "\(formatBytes(used)) / \(formatBytes(total))"
    }

    private func thermalText(_ snapshot: LocalSystemSnapshot, language: WidgetLanguage) -> String {
        if let temperature = snapshot.temperatureCelsius {
            return String(format: "%.0f°C", temperature)
        }
        switch snapshot.thermalLevel {
        case .nominal:
            return language.text("正常", "Normal")
        case .fair:
            return language.text("偏热", "Warm")
        case .serious:
            return language.text("较热", "Hot")
        case .critical:
            return language.text("严重", "Critical")
        case .unknown:
            return "--"
        }
    }

    private func percentSeverity(_ percent: Double?) -> DynamicIslandMetricSeverity {
        guard let percent else { return .unknown }
        if percent >= 90 { return .danger }
        if percent >= 75 { return .warning }
        return .normal
    }

    private func thermalSeverity(_ level: LocalThermalLevel) -> DynamicIslandMetricSeverity {
        switch level {
        case .nominal:
            return .normal
        case .fair:
            return .warning
        case .serious, .critical:
            return .danger
        case .unknown:
            return .unknown
        }
    }

    private func attentionTasks(
        from input: DynamicIslandPresentationInput,
        visibleScopes: [RuntimeScope]
    ) -> [DynamicIslandTaskSummary] {
        let visibleSet = Set(visibleScopes)
        return input.aggregateTaskBoard?.columns
            .flatMap(\.items)
            .filter { item in
                guard visibleSet.contains(item.source), item.kind != .done else { return false }
                guard let updatedAt = item.updatedAt else { return true }
                let age = input.now.timeIntervalSince(updatedAt)
                if item.kind == .active, age > 6 * 60 * 60 { return false }
                if item.kind == .scheduled, age > 24 * 60 * 60 { return false }
                return true
            }
            .sorted { lhs, rhs in
                let lhsRank = taskPriority(lhs.kind)
                let rhsRank = taskPriority(rhs.kind)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return (lhs.updatedAt ?? .distantPast) > (rhs.updatedAt ?? .distantPast)
            }
            .prefix(3)
            .map { item in
                DynamicIslandTaskSummary(
                    id: item.id,
                    source: item.source,
                    title: item.title,
                    statusText: item.chip,
                    updatedAt: item.updatedAt
                )
            } ?? []
    }

    private func taskCounts(from board: TaskBoard?) -> DynamicIslandTaskCounts {
        guard let board else { return .empty }
        var counts = DynamicIslandTaskCounts.empty
        for column in board.columns {
            switch column.id {
            case .active:
                counts = DynamicIslandTaskCounts(
                    active: column.count,
                    pending: counts.pending,
                    scheduled: counts.scheduled,
                    done: counts.done
                )
            case .pending:
                counts = DynamicIslandTaskCounts(
                    active: counts.active,
                    pending: column.count,
                    scheduled: counts.scheduled,
                    done: counts.done
                )
            case .scheduled:
                counts = DynamicIslandTaskCounts(
                    active: counts.active,
                    pending: counts.pending,
                    scheduled: column.count,
                    done: counts.done
                )
            case .done:
                counts = DynamicIslandTaskCounts(
                    active: counts.active,
                    pending: counts.pending,
                    scheduled: counts.scheduled,
                    done: column.count
                )
            }
        }
        return counts
    }

    private func taskPriority(_ kind: TaskColumnKind) -> Int {
        switch kind {
        case .pending:
            return 0
        case .active:
            return 1
        case .scheduled:
            return 2
        case .done:
            return 3
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB]
        formatter.countStyle = .memory
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(clamping: bytes))
    }
}
