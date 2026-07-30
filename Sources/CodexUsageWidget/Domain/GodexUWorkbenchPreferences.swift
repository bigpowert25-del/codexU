import Foundation

private func normalizedUnitInterval(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    return min(max(value, 0), 1)
}

private func normalizedNonnegative(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    return max(value, 0)
}

private func finiteOrZero(_ value: Double) -> Double {
    value.isFinite ? value : 0
}

struct GodexUNormalizedColor: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    init(
        red: Double,
        green: Double,
        blue: Double,
        opacity: Double = 1
    ) {
        self.red = normalizedUnitInterval(red)
        self.green = normalizedUnitInterval(green)
        self.blue = normalizedUnitInterval(blue)
        self.opacity = normalizedUnitInterval(opacity)
    }
}

struct GodexUShellShadow: Equatable {
    let color: GodexUNormalizedColor
    let opacity: Double
    let radius: Double
    let xOffset: Double
    let yOffset: Double

    init(
        color: GodexUNormalizedColor,
        opacity: Double,
        radius: Double,
        xOffset: Double,
        yOffset: Double
    ) {
        self.color = color
        self.opacity = normalizedUnitInterval(opacity)
        self.radius = normalizedNonnegative(radius)
        self.xOffset = finiteOrZero(xOffset)
        self.yOffset = finiteOrZero(yOffset)
    }
}

enum GodexUSkinDensity: String, Equatable {
    case spacious
    case standard
    case compact
}

struct GodexUSkinVisualTokens: Equatable {
    let identity: String
    let canvasColor: GodexUNormalizedColor
    let deepCanvasColor: GodexUNormalizedColor
    let shellColor: GodexUNormalizedColor
    let sidebarColor: GodexUNormalizedColor
    let primaryPanelColor: GodexUNormalizedColor
    let elevatedPanelColor: GodexUNormalizedColor
    let primaryTextColor: GodexUNormalizedColor
    let secondaryTextColor: GodexUNormalizedColor
    let dimTextColor: GodexUNormalizedColor
    let accentColor: GodexUNormalizedColor
    let secondaryAccentColor: GodexUNormalizedColor
    let attentionAccentColor: GodexUNormalizedColor
    let subtleSeparatorColor: GodexUNormalizedColor
    let strongSeparatorColor: GodexUNormalizedColor
    let controlRadius: Double
    let panelRadius: Double
    let density: GodexUSkinDensity
    let shellShadow: GodexUShellShadow
    let showsGrid: Bool
    let chromeOpacity: Double
    let selectedOpacity: Double

    init(
        identity: String,
        canvasColor: GodexUNormalizedColor,
        deepCanvasColor: GodexUNormalizedColor,
        shellColor: GodexUNormalizedColor,
        sidebarColor: GodexUNormalizedColor,
        primaryPanelColor: GodexUNormalizedColor,
        elevatedPanelColor: GodexUNormalizedColor,
        primaryTextColor: GodexUNormalizedColor,
        secondaryTextColor: GodexUNormalizedColor,
        dimTextColor: GodexUNormalizedColor,
        accentColor: GodexUNormalizedColor,
        secondaryAccentColor: GodexUNormalizedColor,
        attentionAccentColor: GodexUNormalizedColor,
        subtleSeparatorColor: GodexUNormalizedColor,
        strongSeparatorColor: GodexUNormalizedColor,
        controlRadius: Double,
        panelRadius: Double,
        density: GodexUSkinDensity,
        shellShadow: GodexUShellShadow,
        showsGrid: Bool,
        chromeOpacity: Double,
        selectedOpacity: Double
    ) {
        self.identity = identity
        self.canvasColor = canvasColor
        self.deepCanvasColor = deepCanvasColor
        self.shellColor = shellColor
        self.sidebarColor = sidebarColor
        self.primaryPanelColor = primaryPanelColor
        self.elevatedPanelColor = elevatedPanelColor
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.dimTextColor = dimTextColor
        self.accentColor = accentColor
        self.secondaryAccentColor = secondaryAccentColor
        self.attentionAccentColor = attentionAccentColor
        self.subtleSeparatorColor = subtleSeparatorColor
        self.strongSeparatorColor = strongSeparatorColor
        let normalizedControlRadius = normalizedNonnegative(controlRadius)
        self.controlRadius = normalizedControlRadius
        self.panelRadius = max(
            normalizedNonnegative(panelRadius),
            normalizedControlRadius
        )
        self.density = density
        self.shellShadow = shellShadow
        self.showsGrid = showsGrid
        self.chromeOpacity = normalizedUnitInterval(chromeOpacity)
        self.selectedOpacity = normalizedUnitInterval(selectedOpacity)
    }

    // Compatibility getters for the legacy accent-only workbench UI.
    var accentRed: Double { accentColor.red }
    var accentGreen: Double { accentColor.green }
    var accentBlue: Double { accentColor.blue }
    var secondaryRed: Double { secondaryAccentColor.red }
    var secondaryGreen: Double { secondaryAccentColor.green }
    var secondaryBlue: Double { secondaryAccentColor.blue }
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
                identity: "titanium-studio-v2",
                canvasColor: GodexUNormalizedColor(
                    red: 0.906, green: 0.918, blue: 0.941
                ),
                deepCanvasColor: GodexUNormalizedColor(
                    red: 0.765, green: 0.788, blue: 0.827
                ),
                shellColor: GodexUNormalizedColor(
                    red: 0.953, green: 0.957, blue: 0.969
                ),
                sidebarColor: GodexUNormalizedColor(
                    red: 0.835, green: 0.855, blue: 0.890
                ),
                primaryPanelColor: GodexUNormalizedColor(
                    red: 0.980, green: 0.984, blue: 0.992
                ),
                elevatedPanelColor: GodexUNormalizedColor(
                    red: 1.000, green: 1.000, blue: 1.000
                ),
                primaryTextColor: GodexUNormalizedColor(
                    red: 0.075, green: 0.086, blue: 0.106
                ),
                secondaryTextColor: GodexUNormalizedColor(
                    red: 0.278, green: 0.302, blue: 0.349
                ),
                dimTextColor: GodexUNormalizedColor(
                    red: 0.443, green: 0.471, blue: 0.525
                ),
                accentColor: GodexUNormalizedColor(
                    red: 0.157, green: 0.400, blue: 0.969
                ),
                secondaryAccentColor: GodexUNormalizedColor(
                    red: 0.545, green: 0.427, blue: 1.000
                ),
                attentionAccentColor: GodexUNormalizedColor(
                    red: 0.149, green: 0.627, blue: 0.416
                ),
                subtleSeparatorColor: GodexUNormalizedColor(
                    red: 0.490, green: 0.525, blue: 0.584, opacity: 0.22
                ),
                strongSeparatorColor: GodexUNormalizedColor(
                    red: 0.286, green: 0.318, blue: 0.373, opacity: 0.48
                ),
                controlRadius: 8,
                panelRadius: 14,
                density: .spacious,
                shellShadow: GodexUShellShadow(
                    color: GodexUNormalizedColor(
                        red: 0.047, green: 0.055, blue: 0.071
                    ),
                    opacity: 0.20,
                    radius: 28,
                    xOffset: 0,
                    yOffset: 14
                ),
                showsGrid: false,
                chromeOpacity: 0.42,
                selectedOpacity: 0.16
            )
        case .nebulaGlass:
            return GodexUSkinVisualTokens(
                identity: "nebula-glass-v2",
                canvasColor: GodexUNormalizedColor(
                    red: 0.027, green: 0.039, blue: 0.094
                ),
                deepCanvasColor: GodexUNormalizedColor(
                    red: 0.016, green: 0.020, blue: 0.051
                ),
                shellColor: GodexUNormalizedColor(
                    red: 0.055, green: 0.063, blue: 0.137, opacity: 0.96
                ),
                sidebarColor: GodexUNormalizedColor(
                    red: 0.035, green: 0.039, blue: 0.094, opacity: 0.98
                ),
                primaryPanelColor: GodexUNormalizedColor(
                    red: 0.075, green: 0.082, blue: 0.169, opacity: 0.88
                ),
                elevatedPanelColor: GodexUNormalizedColor(
                    red: 0.110, green: 0.114, blue: 0.224, opacity: 0.92
                ),
                primaryTextColor: GodexUNormalizedColor(
                    red: 0.941, green: 0.949, blue: 1.000
                ),
                secondaryTextColor: GodexUNormalizedColor(
                    red: 0.714, green: 0.733, blue: 0.859
                ),
                dimTextColor: GodexUNormalizedColor(
                    red: 0.486, green: 0.510, blue: 0.655
                ),
                accentColor: GodexUNormalizedColor(
                    red: 0.400, green: 0.345, blue: 0.980
                ),
                secondaryAccentColor: GodexUNormalizedColor(
                    red: 0.149, green: 0.608, blue: 0.969
                ),
                attentionAccentColor: GodexUNormalizedColor(
                    red: 0.867, green: 0.420, blue: 1.000
                ),
                subtleSeparatorColor: GodexUNormalizedColor(
                    red: 0.463, green: 0.482, blue: 0.733, opacity: 0.25
                ),
                strongSeparatorColor: GodexUNormalizedColor(
                    red: 0.553, green: 0.514, blue: 0.945, opacity: 0.55
                ),
                controlRadius: 10,
                panelRadius: 18,
                density: .standard,
                shellShadow: GodexUShellShadow(
                    color: GodexUNormalizedColor(
                        red: 0.004, green: 0.008, blue: 0.027
                    ),
                    opacity: 0.46,
                    radius: 36,
                    xOffset: 0,
                    yOffset: 18
                ),
                showsGrid: true,
                chromeOpacity: 0.34,
                selectedOpacity: 0.18
            )
        case .tacticalOLED:
            return GodexUSkinVisualTokens(
                identity: "tactical-oled-v2",
                canvasColor: GodexUNormalizedColor(
                    red: 0.008, green: 0.010, blue: 0.009
                ),
                deepCanvasColor: GodexUNormalizedColor(
                    red: 0.000, green: 0.000, blue: 0.000
                ),
                shellColor: GodexUNormalizedColor(
                    red: 0.018, green: 0.022, blue: 0.020
                ),
                sidebarColor: GodexUNormalizedColor(
                    red: 0.025, green: 0.031, blue: 0.028
                ),
                primaryPanelColor: GodexUNormalizedColor(
                    red: 0.031, green: 0.039, blue: 0.035
                ),
                elevatedPanelColor: GodexUNormalizedColor(
                    red: 0.047, green: 0.059, blue: 0.051
                ),
                primaryTextColor: GodexUNormalizedColor(
                    red: 0.851, green: 1.000, blue: 0.902
                ),
                secondaryTextColor: GodexUNormalizedColor(
                    red: 0.486, green: 0.710, blue: 0.565
                ),
                dimTextColor: GodexUNormalizedColor(
                    red: 0.286, green: 0.435, blue: 0.337
                ),
                accentColor: GodexUNormalizedColor(
                    red: 0.110, green: 0.635, blue: 0.890
                ),
                secondaryAccentColor: GodexUNormalizedColor(
                    red: 0.506, green: 0.961, blue: 0.216
                ),
                attentionAccentColor: GodexUNormalizedColor(
                    red: 0.922, green: 0.827, blue: 0.161
                ),
                subtleSeparatorColor: GodexUNormalizedColor(
                    red: 0.204, green: 0.353, blue: 0.255, opacity: 0.35
                ),
                strongSeparatorColor: GodexUNormalizedColor(
                    red: 0.506, green: 0.961, blue: 0.216, opacity: 0.66
                ),
                controlRadius: 1,
                panelRadius: 2,
                density: .compact,
                shellShadow: GodexUShellShadow(
                    color: GodexUNormalizedColor(
                        red: 0.000, green: 0.000, blue: 0.000
                    ),
                    opacity: 0.72,
                    radius: 12,
                    xOffset: 0,
                    yOffset: 6
                ),
                showsGrid: true,
                chromeOpacity: 0.20,
                selectedOpacity: 0.20
            )
        case .mineralLight:
            return GodexUSkinVisualTokens(
                identity: "mineral-light-v2",
                canvasColor: GodexUNormalizedColor(
                    red: 0.608, green: 0.620, blue: 0.608
                ),
                deepCanvasColor: GodexUNormalizedColor(
                    red: 0.075, green: 0.078, blue: 0.071
                ),
                shellColor: GodexUNormalizedColor(
                    red: 0.694, green: 0.706, blue: 0.686
                ),
                sidebarColor: GodexUNormalizedColor(
                    red: 0.063, green: 0.067, blue: 0.059
                ),
                primaryPanelColor: GodexUNormalizedColor(
                    red: 0.094, green: 0.102, blue: 0.086
                ),
                elevatedPanelColor: GodexUNormalizedColor(
                    red: 0.145, green: 0.157, blue: 0.133
                ),
                primaryTextColor: GodexUNormalizedColor(
                    red: 0.949, green: 0.961, blue: 0.925
                ),
                secondaryTextColor: GodexUNormalizedColor(
                    red: 0.722, green: 0.745, blue: 0.682
                ),
                dimTextColor: GodexUNormalizedColor(
                    red: 0.486, green: 0.514, blue: 0.447
                ),
                accentColor: GodexUNormalizedColor(
                    red: 0.659, green: 0.890, blue: 0.239
                ),
                secondaryAccentColor: GodexUNormalizedColor(
                    red: 0.286, green: 0.506, blue: 0.745
                ),
                attentionAccentColor: GodexUNormalizedColor(
                    red: 0.957, green: 0.714, blue: 0.196
                ),
                subtleSeparatorColor: GodexUNormalizedColor(
                    red: 0.545, green: 0.584, blue: 0.498, opacity: 0.30
                ),
                strongSeparatorColor: GodexUNormalizedColor(
                    red: 0.659, green: 0.890, blue: 0.239, opacity: 0.58
                ),
                controlRadius: 4,
                panelRadius: 8,
                density: .standard,
                shellShadow: GodexUShellShadow(
                    color: GodexUNormalizedColor(
                        red: 0.024, green: 0.027, blue: 0.020
                    ),
                    opacity: 0.36,
                    radius: 24,
                    xOffset: 0,
                    yOffset: 12
                ),
                showsGrid: false,
                chromeOpacity: 0.52,
                selectedOpacity: 0.14
            )
        case .orbitCommand:
            return GodexUSkinVisualTokens(
                identity: "orbit-command-v2",
                canvasColor: GodexUNormalizedColor(
                    red: 0.024, green: 0.022, blue: 0.020
                ),
                deepCanvasColor: GodexUNormalizedColor(
                    red: 0.008, green: 0.008, blue: 0.007
                ),
                shellColor: GodexUNormalizedColor(
                    red: 0.047, green: 0.043, blue: 0.039
                ),
                sidebarColor: GodexUNormalizedColor(
                    red: 0.063, green: 0.055, blue: 0.047
                ),
                primaryPanelColor: GodexUNormalizedColor(
                    red: 0.078, green: 0.071, blue: 0.063
                ),
                elevatedPanelColor: GodexUNormalizedColor(
                    red: 0.118, green: 0.102, blue: 0.086
                ),
                primaryTextColor: GodexUNormalizedColor(
                    red: 0.973, green: 0.941, blue: 0.894
                ),
                secondaryTextColor: GodexUNormalizedColor(
                    red: 0.749, green: 0.698, blue: 0.631
                ),
                dimTextColor: GodexUNormalizedColor(
                    red: 0.490, green: 0.443, blue: 0.388
                ),
                accentColor: GodexUNormalizedColor(
                    red: 0.980, green: 0.424, blue: 0.102
                ),
                secondaryAccentColor: GodexUNormalizedColor(
                    red: 0.263, green: 0.835, blue: 0.435
                ),
                attentionAccentColor: GodexUNormalizedColor(
                    red: 1.000, green: 0.678, blue: 0.173
                ),
                subtleSeparatorColor: GodexUNormalizedColor(
                    red: 0.455, green: 0.318, blue: 0.200, opacity: 0.32
                ),
                strongSeparatorColor: GodexUNormalizedColor(
                    red: 0.980, green: 0.424, blue: 0.102, opacity: 0.64
                ),
                controlRadius: 5,
                panelRadius: 10,
                density: .compact,
                shellShadow: GodexUShellShadow(
                    color: GodexUNormalizedColor(
                        red: 0.000, green: 0.000, blue: 0.000
                    ),
                    opacity: 0.62,
                    radius: 30,
                    xOffset: 0,
                    yOffset: 16
                ),
                showsGrid: true,
                chromeOpacity: 0.24,
                selectedOpacity: 0.20
            )
        }
    }
}

enum GodexUWorkbenchSection: String, CaseIterable, Hashable {
    case goalHero
    case relationshipGraph
    case metricRail
    case projectContinuation
    case systemTelemetry
    case statusTicker
    case taskComposer
    case commandInspector
}

enum GodexUInspectorPresentation: String, Equatable {
    case hidden
    case persistent
}

enum GodexUHeroPresentation: String, Equatable {
    case focus
    case balanced
    case graphWeighted
}

enum GodexULowerContentPresentation: String, Equatable {
    case hidden
    case split
    case singleColumn
}

enum GodexUComposerPresentation: String, Equatable {
    case compact
    case standard
}

struct GodexUWorkbenchLayoutProfile: Equatable {
    let identity: String
    let sections: Set<GodexUWorkbenchSection>
    let heroPresentation: GodexUHeroPresentation
    let lowerContentPresentation: GodexULowerContentPresentation
    let composerPresentation: GodexUComposerPresentation
    let inspectorPresentation: GodexUInspectorPresentation
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

    /// Controls the legacy stacked `AgentNodeStatusSection` only.
    /// The native relationship graph is governed by `layoutProfile.sections`.
    var showsAgentNodes: Bool {
        self != .light
    }

    var usesExpandedOverview: Bool {
        layoutProfile.heroPresentation == .graphWeighted
    }

    var usesCompactSystemStatus: Bool {
        layoutProfile.lowerContentPresentation == .hidden
    }

    var showsMetricSourceLabels: Bool {
        true
    }

    var layoutProfile: GodexUWorkbenchLayoutProfile {
        switch self {
        case .light:
            return GodexUWorkbenchLayoutProfile(
                identity: "light-glance-v2",
                sections: [
                    .goalHero,
                    .relationshipGraph,
                    .metricRail,
                    .taskComposer
                ],
                heroPresentation: .focus,
                lowerContentPresentation: .hidden,
                composerPresentation: .compact,
                inspectorPresentation: .hidden
            )
        case .sync:
            return GodexUWorkbenchLayoutProfile(
                identity: "sync-overview-v2",
                sections: [
                    .goalHero,
                    .relationshipGraph,
                    .metricRail,
                    .projectContinuation,
                    .systemTelemetry,
                    .statusTicker,
                    .taskComposer
                ],
                heroPresentation: .balanced,
                lowerContentPresentation: .split,
                composerPresentation: .standard,
                inspectorPresentation: .hidden
            )
        case .command:
            return GodexUWorkbenchLayoutProfile(
                identity: "command-operations-v2",
                sections: [
                    .goalHero,
                    .relationshipGraph,
                    .metricRail,
                    .projectContinuation,
                    .systemTelemetry,
                    .statusTicker,
                    .taskComposer,
                    .commandInspector
                ],
                heroPresentation: .graphWeighted,
                lowerContentPresentation: .singleColumn,
                composerPresentation: .standard,
                inspectorPresentation: .persistent
            )
        }
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
