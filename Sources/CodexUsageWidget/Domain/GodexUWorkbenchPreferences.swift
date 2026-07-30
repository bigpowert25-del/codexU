import Foundation

struct GodexUSkinVisualTokens: Equatable {
    let identity: String
    let accentRed: Double
    let accentGreen: Double
    let accentBlue: Double
    let secondaryRed: Double
    let secondaryGreen: Double
    let secondaryBlue: Double
    let chromeOpacity: Double
    let selectedOpacity: Double
}

enum GodexUSkin: String, CaseIterable, Codable, Identifiable, Equatable {
    case titaniumStudio
    case nebulaGlass
    case tacticalOLED
    case mineralLight
    case orbitCommand

    static let storageKey = "codexU.workbenchSkin.v1"
    static let `default`: GodexUSkin = .titaniumStudio

    var id: String { rawValue }

    static func storedOrDefault(
        defaults: UserDefaults = .standard
    ) -> GodexUSkin {
        guard let rawValue = defaults.string(forKey: storageKey),
              let skin = GodexUSkin(rawValue: rawValue)
        else { return .default }
        return skin
    }

    func persist(defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.storageKey)
    }

    func displayName(language: WidgetLanguage) -> String {
        switch self {
        case .titaniumStudio:
            return language.text("钛金工作室", "Titanium Studio")
        case .nebulaGlass:
            return language.text("星云玻璃", "Nebula Glass")
        case .tacticalOLED:
            return language.text("战术 OLED", "Tactical OLED")
        case .mineralLight:
            return language.text("矿物浅色", "Mineral Light")
        case .orbitCommand:
            return language.text("轨道指挥", "Orbit Command")
        }
    }

    var systemImage: String {
        switch self {
        case .titaniumStudio:
            return "circle.hexagongrid.fill"
        case .nebulaGlass:
            return "sparkles"
        case .tacticalOLED:
            return "scope"
        case .mineralLight:
            return "diamond.fill"
        case .orbitCommand:
            return "orbit"
        }
    }

    var visualTokens: GodexUSkinVisualTokens {
        switch self {
        case .titaniumStudio:
            return GodexUSkinVisualTokens(
                identity: "titanium-studio-v1",
                accentRed: 0.157,
                accentGreen: 0.400,
                accentBlue: 0.969,
                secondaryRed: 0.545,
                secondaryGreen: 0.427,
                secondaryBlue: 1.000,
                chromeOpacity: 0.42,
                selectedOpacity: 0.16
            )
        case .nebulaGlass:
            return GodexUSkinVisualTokens(
                identity: "nebula-glass-v1",
                accentRed: 0.400,
                accentGreen: 0.345,
                accentBlue: 0.980,
                secondaryRed: 0.149,
                secondaryGreen: 0.608,
                secondaryBlue: 0.969,
                chromeOpacity: 0.34,
                selectedOpacity: 0.18
            )
        case .tacticalOLED:
            return GodexUSkinVisualTokens(
                identity: "tactical-oled-v1",
                accentRed: 0.110,
                accentGreen: 0.635,
                accentBlue: 0.890,
                secondaryRed: 0.220,
                secondaryGreen: 0.490,
                secondaryBlue: 0.780,
                chromeOpacity: 0.20,
                selectedOpacity: 0.20
            )
        case .mineralLight:
            return GodexUSkinVisualTokens(
                identity: "mineral-light-v1",
                accentRed: 0.286,
                accentGreen: 0.506,
                accentBlue: 0.745,
                secondaryRed: 0.475,
                secondaryGreen: 0.561,
                secondaryBlue: 0.639,
                chromeOpacity: 0.52,
                selectedOpacity: 0.14
            )
        case .orbitCommand:
            return GodexUSkinVisualTokens(
                identity: "orbit-command-v1",
                accentRed: 0.745,
                accentGreen: 0.310,
                accentBlue: 0.920,
                secondaryRed: 0.360,
                secondaryGreen: 0.470,
                secondaryBlue: 0.960,
                chromeOpacity: 0.24,
                selectedOpacity: 0.20
            )
        }
    }
}

enum GodexUWorkbenchStage: String, CaseIterable, Codable, Identifiable, Equatable {
    case light
    case sync
    case command

    static let storageKey = "codexU.workbenchStage.v1"
    static let `default`: GodexUWorkbenchStage = .sync

    var id: String { rawValue }

    static func storedOrDefault(
        defaults: UserDefaults = .standard
    ) -> GodexUWorkbenchStage {
        guard let rawValue = defaults.string(forKey: storageKey),
              let stage = GodexUWorkbenchStage(rawValue: rawValue)
        else { return .default }
        return stage
    }

    func persist(defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.storageKey)
    }

    func displayName(language: WidgetLanguage) -> String {
        switch self {
        case .light:
            return language.text("轻览", "Light")
        case .sync:
            return language.text("协同", "Sync")
        case .command:
            return language.text("指挥", "Command")
        }
    }

    func detail(language: WidgetLanguage) -> String {
        switch self {
        case .light:
            return language.text("快速查看核心状态", "Core status at a glance")
        case .sync:
            return language.text("日常多 Agent 协同", "Daily multi-Agent coordination")
        case .command:
            return language.text("完整运行与项目视图", "Full operations and project view")
        }
    }

    var systemImage: String {
        switch self {
        case .light:
            return "rectangle.compress.vertical"
        case .sync:
            return "point.3.connected.trianglepath.dotted"
        case .command:
            return "rectangle.3.group.fill"
        }
    }

    var showsAgentNodes: Bool {
        self != .light
    }

    var usesExpandedOverview: Bool {
        self == .command
    }

    var usesCompactSystemStatus: Bool {
        self == .light
    }

    var showsMetricSourceLabels: Bool {
        true
    }
}

struct GodexUWorkbenchOverview: Equatable {
    let officialLatestDayTokens: Int64?
    let officialSevenDayTokens: Int64?
    let activeTaskCount: Int?
    let pendingTaskCount: Int?
    let availableNodeCount: Int?
    let observedNodeCount: Int?

    static func make(
        officialLatestDayTokens: Int64?,
        officialSevenDayTokens: Int64?,
        taskBoard: TaskBoard?,
        nodes: [AgentNodeSnapshot]
    ) -> GodexUWorkbenchOverview {
        let activeTaskCount = taskBoard?.columns.first {
            $0.id == .active
        }?.count
        let pendingTaskCount = taskBoard?.columns.first {
            $0.id == .pending
        }?.count
        let hasNodeObservations = !nodes.isEmpty
        return GodexUWorkbenchOverview(
            officialLatestDayTokens: officialLatestDayTokens,
            officialSevenDayTokens: officialSevenDayTokens,
            activeTaskCount: activeTaskCount,
            pendingTaskCount: pendingTaskCount,
            availableNodeCount: hasNodeObservations
                ? nodes.filter { $0.health == .available }.count
                : nil,
            observedNodeCount: hasNodeObservations ? nodes.count : nil
        )
    }

    static func make(
        officialTrend: UsageTrend?,
        taskBoard: TaskBoard?,
        nodes: [AgentNodeSnapshot]
    ) -> GodexUWorkbenchOverview {
        make(
            officialLatestDayTokens: officialTrend?
                .dayBuckets
                .last(where: { $0.tokens > 0 })?
                .tokens,
            officialSevenDayTokens: officialTrend?
                .summary
                .sevenDay
                .tokens
                .visibleTotalTokens,
            taskBoard: taskBoard,
            nodes: nodes
        )
    }
}
