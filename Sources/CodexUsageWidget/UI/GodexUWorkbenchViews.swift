import SwiftUI

struct GodexUWorkbenchTheme {
    let skin: GodexUSkin

    var tokens: GodexUSkinVisualTokens {
        skin.visualTokens
    }

    private func color(_ value: GodexUNormalizedColor) -> Color {
        Color(
            red: value.red,
            green: value.green,
            blue: value.blue,
            opacity: value.opacity
        )
    }

    var canvas: Color { color(tokens.canvasColor) }
    var deepCanvas: Color { color(tokens.deepCanvasColor) }
    var shell: Color { color(tokens.shellColor) }
    var sidebar: Color { color(tokens.sidebarColor) }
    var panel: Color { color(tokens.primaryPanelColor) }
    var elevatedPanel: Color { color(tokens.elevatedPanelColor) }
    var primaryText: Color { color(tokens.primaryTextColor) }
    var secondaryText: Color { color(tokens.secondaryTextColor) }
    var dimText: Color { color(tokens.dimTextColor) }

    var accent: Color {
        color(tokens.accentColor)
    }

    var secondaryAccent: Color {
        color(tokens.secondaryAccentColor)
    }

    var attentionAccent: Color { color(tokens.attentionAccentColor) }
    var subtleSeparator: Color { color(tokens.subtleSeparatorColor) }
    var strongSeparator: Color { color(tokens.strongSeparatorColor) }
    var controlRadius: CGFloat { CGFloat(tokens.controlRadius) }
    var panelRadius: CGFloat { CGFloat(tokens.panelRadius) }
    var showsGrid: Bool { tokens.showsGrid }

    var contentSpacing: CGFloat {
        switch tokens.density {
        case .spacious: return 16
        case .standard: return 12
        case .compact: return 8
        }
    }

    var shellShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        let shadow = tokens.shellShadow
        return (
            color(shadow.color).opacity(shadow.opacity),
            CGFloat(shadow.radius),
            CGFloat(shadow.xOffset),
            CGFloat(shadow.yOffset)
        )
    }

    var contentColorScheme: ColorScheme {
        let text = tokens.primaryTextColor
        let panel = tokens.primaryPanelColor
        let textLuminance = (0.2126 * text.red) + (0.7152 * text.green)
            + (0.0722 * text.blue)
        let panelLuminance = (0.2126 * panel.red) + (0.7152 * panel.green)
            + (0.0722 * panel.blue)
        return textLuminance > panelLuminance ? .dark : .light
    }

    func chromeFill(
        _ colorScheme: ColorScheme,
        reduceTransparency: Bool
    ) -> Color {
        reduceTransparency ? shell : shell.opacity(max(0.74, 1 - tokens.chromeOpacity))
    }

    func selectedFill(_ colorScheme: ColorScheme) -> Color {
        accent.opacity(tokens.selectedOpacity)
    }

    func stroke(_ colorScheme: ColorScheme) -> Color {
        subtleSeparator
    }
}

enum GodexUWorkbenchDestination: String, CaseIterable, Identifiable {
    case overview
    case projects
    case tasks
    case agents
    case usage
    case skills

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .overview: return "house"
        case .projects: return "folder"
        case .tasks: return "checklist"
        case .agents: return "person.2"
        case .usage: return "chart.bar.xaxis"
        case .skills: return "brain.head.profile"
        }
    }

    func title(language: WidgetLanguage) -> String {
        switch self {
        case .overview: return language.text("总览", "Overview")
        case .projects: return language.text("项目", "Projects")
        case .tasks: return language.text("任务", "Tasks")
        case .agents: return language.text("Agent", "Agents")
        case .usage: return language.text("用量", "Usage")
        case .skills: return language.text("Skills", "Skills")
        }
    }
}

struct GodexUWorkbenchShell<Content: View>: View {
    @ObservedObject var settings: AppSettings
    @Binding var destination: GodexUWorkbenchDestination
    let onOpenSettings: () -> Void
    @ViewBuilder let content: () -> Content

    private var language: WidgetLanguage { settings.language }
    private var theme: GodexUWorkbenchTheme {
        GodexUWorkbenchTheme(skin: settings.workbenchSkin)
    }

    var body: some View {
        VStack(spacing: 0) {
            GodexUWorkbenchHeader(settings: settings)
                .padding(.horizontal, 18)
                .frame(height: 64)
                .background(theme.shell)

            HStack(spacing: 0) {
                rail
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(canvasBackground)
            }
        }
        .foregroundStyle(theme.primaryText)
        .background(theme.deepCanvas)
        .overlay(
            RoundedRectangle(
                cornerRadius: UsageWidgetView.windowCornerRadius,
                style: .continuous
            )
            .strokeBorder(theme.strongSeparator, lineWidth: 0.8)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: UsageWidgetView.windowCornerRadius,
                style: .continuous
            )
        )
        .shadow(
            color: theme.shellShadow.color,
            radius: theme.shellShadow.radius,
            x: theme.shellShadow.x,
            y: theme.shellShadow.y
        )
    }

    private var rail: some View {
        VStack(spacing: 8) {
            ForEach(GodexUWorkbenchDestination.allCases) { item in
                railButton(item)
            }
            Spacer(minLength: 16)
            Button(action: onOpenSettings) {
                railLabel(
                    systemName: "gearshape",
                    title: language.text("设置", "Settings"),
                    selected: false
                )
            }
            .buttonStyle(.plain)
            .help(language.text("打开设置", "Open settings"))
            .accessibilityLabel(language.text("设置", "Settings"))
        }
        .padding(.vertical, 14)
        .frame(width: 74)
        .background(theme.sidebar)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(theme.strongSeparator)
                .frame(width: 1)
        }
    }

    private func railButton(_ item: GodexUWorkbenchDestination) -> some View {
        Button {
            destination = item
        } label: {
            railLabel(
                systemName: item.systemImage,
                title: item.title(language: language),
                selected: destination == item
            )
        }
        .buttonStyle(.plain)
        .help(item.title(language: language))
        .accessibilityLabel(item.title(language: language))
        .accessibilityValue(
            destination == item
                ? language.text("已选择", "Selected")
                : language.text("未选择", "Not selected")
        )
    }

    private func railLabel(
        systemName: String,
        title: String,
        selected: Bool
    ) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
            Text(title)
                .font(.system(size: 8, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(selected ? theme.accent : theme.secondaryText)
        .frame(width: 58, height: 48)
        .background(
            RoundedRectangle(cornerRadius: theme.controlRadius, style: .continuous)
                .fill(selected ? theme.accent.opacity(0.15) : Color.clear)
        )
        .overlay(alignment: .leading) {
            if selected {
                Capsule()
                    .fill(theme.accent)
                    .frame(width: 3, height: 20)
                    .offset(x: -6)
            }
        }
        .contentShape(Rectangle())
    }

    private var canvasBackground: some View {
        ZStack {
            LinearGradient(
                colors: [theme.canvas, theme.deepCanvas.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if theme.showsGrid {
                GodexUWorkbenchGrid(color: theme.subtleSeparator.opacity(0.34))
            }
        }
    }
}

private struct GodexUWorkbenchGrid: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let step: CGFloat = 40
            stride(from: CGFloat.zero, through: size.width, by: step).forEach {
                path.move(to: CGPoint(x: $0, y: 0))
                path.addLine(to: CGPoint(x: $0, y: size.height))
            }
            stride(from: CGFloat.zero, through: size.height, by: step).forEach {
                path.move(to: CGPoint(x: 0, y: $0))
                path.addLine(to: CGPoint(x: size.width, y: $0))
            }
            context.stroke(path, with: .color(color), lineWidth: 0.5)
        }
        .accessibilityHidden(true)
    }
}

struct GodexUWorkbenchDestinationSurface<Content: View>: View {
    let title: String
    let detail: String
    let skin: GodexUSkin
    @ViewBuilder let content: () -> Content

    private var theme: GodexUWorkbenchTheme {
        GodexUWorkbenchTheme(skin: skin)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.contentSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Spacer(minLength: 12)
                Text(detail)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
            }
            Rectangle()
                .fill(theme.subtleSeparator)
                .frame(height: 1)
            content()
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(16)
        .foregroundStyle(theme.primaryText)
        .tint(theme.accent)
        .environment(\.colorScheme, theme.contentColorScheme)
        .background(
            RoundedRectangle(cornerRadius: theme.panelRadius, style: .continuous)
                .fill(theme.panel)
                .overlay(
                    RoundedRectangle(
                        cornerRadius: theme.panelRadius,
                        style: .continuous
                    )
                    .stroke(theme.subtleSeparator, lineWidth: 0.8)
                )
        )
    }
}

struct GodexUOverviewDashboard: View {
    let overview: GodexUWorkbenchOverview
    let stage: GodexUWorkbenchStage
    let skin: GodexUSkin
    let language: WidgetLanguage
    let nodes: [AgentNodeSnapshot]
    let projects: [AgentProjectWorkspace]
    let systemSnapshot: LocalSystemSnapshot
    @ObservedObject var identityStore: AgentIdentityProfileStore
    @ObservedObject var envelopeStore: AgentTaskEnvelopeStore
    let openProjects: (String?) -> Void
    let openTasks: () -> Void
    let openAgents: () -> Void

    @State private var selectedNodeID: String?
    @State private var identityDetailNode: AgentNodeSnapshot?
    @State private var selectedTargetNodeID = ""
    @State private var taskGoal = ""
    @State private var composerFeedback: String?
    @State private var composerFeedbackIsError = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var theme: GodexUWorkbenchTheme {
        GodexUWorkbenchTheme(skin: skin)
    }

    private var profile: GodexUWorkbenchLayoutProfile {
        stage.layoutProfile
    }

    private var selectedNode: AgentNodeSnapshot? {
        nodes.first { $0.id == selectedNodeID } ?? nodes.first
    }

    var body: some View {
        HStack(alignment: .top, spacing: theme.contentSpacing) {
            VStack(alignment: .leading, spacing: theme.contentSpacing) {
                hero
                metricRail

                if profile.lowerContentPresentation != .hidden {
                    lowerContent
                    ticker
                }

                composerBar
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            if profile.inspectorPresentation == .persistent {
                commandInspector
                    .frame(width: 270)
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.22),
            value: stage
        )
        .sheet(item: $identityDetailNode) { node in
            AgentIdentityDetailView(
                snapshot: node,
                profileStore: identityStore,
                language: language
            )
        }
        .onAppear {
            selectFirstTargetIfNeeded()
        }
        .onChange(of: nodes.map(\.id)) { _, ids in
            if let selectedNodeID, !ids.contains(selectedNodeID) {
                self.selectedNodeID = ids.first
            }
            selectFirstTargetIfNeeded()
        }
    }

    private var hero: some View {
        GeometryReader { proxy in
            let graphFraction: CGFloat = {
                switch profile.heroPresentation {
                case .focus: return 0.54
                case .balanced: return 0.52
                case .graphWeighted: return 0.64
                }
            }()
            HStack(spacing: theme.contentSpacing) {
                goalHero
                    .frame(width: max(300, proxy.size.width * (1 - graphFraction)))
                GodexURelationshipGraph(
                    nodes: nodes,
                    selectedNodeID: selectedNode?.id,
                    theme: theme,
                    language: language
                ) { node in
                    selectedNodeID = node.id
                    identityDetailNode = node
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: profile.heroPresentation == .focus ? 350 : 255)
    }

    private var goalHero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Capsule()
                    .fill(theme.accent)
                    .frame(width: 28, height: 2)
                Text(heroKicker)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer(minLength: 12)
            Text(language.text("你定目标，\n它们各司其职。", "Set the goal.\nLet every Agent do its part."))
                .font(.system(size: stage == .light ? 42 : 36, weight: .semibold, design: .rounded))
                .tracking(-1.8)
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(language.text(
                "Codex 负责开发与验证，OpenClaw 保持连续理解，Hermes 独立复核；GodexU 只聚合、解释和投递，不替代任何 Agent。",
                "Codex builds and verifies, OpenClaw preserves continuity, and Hermes reviews independently. GodexU aggregates and routes without replacing them."
            ))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(theme.secondaryText)
            .lineSpacing(4)
            .padding(.top, 12)
            Spacer(minLength: 16)
            HStack(spacing: 10) {
                Button(action: openTasks) {
                    Label(language.text("发起协同任务", "Start a task"), systemImage: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 15)
                        .frame(height: 38)
                        .foregroundStyle(theme.deepCanvas)
                        .background(Capsule().fill(theme.primaryText))
                }
                .buttonStyle(.plain)
                Button(action: openAgents) {
                    Text(language.text("查看 Agent", "Inspect Agents"))
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(Capsule().fill(theme.elevatedPanel))
                        .overlay(Capsule().stroke(theme.subtleSeparator))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .godexUPanel(theme: theme)
    }

    private var heroKicker: String {
        guard !nodes.isEmpty else {
            return language.text("正在读取节点 · 本地优先", "Reading nodes · Local first")
        }
        let available = nodes.filter { $0.health == .available }.count
        let pending = overview.pendingTaskCount.map(String.init) ?? "--"
        return language.text(
            "\(available)/\(nodes.count) 个节点可用 · \(pending) 个任务待处理",
            "\(available)/\(nodes.count) nodes available · \(pending) tasks pending"
        )
    }

    private var metricRail: some View {
        let all = [
            GodexUDashboardMetric(
                title: language.text("Codex · 最近一天", "Codex · Latest day"),
                value: overview.officialLatestDayTokens.map(TokenFormatter.format) ?? "--",
                detail: language.text("官方活动", "Official activity")
            ),
            GodexUDashboardMetric(
                title: language.text("Codex · 近 7 日", "Codex · 7 days"),
                value: overview.officialSevenDayTokens.map(TokenFormatter.format) ?? "--",
                detail: language.text("官方活动", "Official activity")
            ),
            GodexUDashboardMetric(
                title: language.text("进行中任务", "Active tasks"),
                value: overview.activeTaskCount.map(String.init) ?? "--",
                detail: language.text("聚合任务", "Aggregated tasks")
            ),
            GodexUDashboardMetric(
                title: language.text("待处理", "Pending"),
                value: overview.pendingTaskCount.map(String.init) ?? "--",
                detail: language.text("聚合任务", "Aggregated tasks")
            ),
            GodexUDashboardMetric(
                title: language.text("可用节点", "Available nodes"),
                value: nodeValue,
                detail: language.text("本机探测 / 缓存", "Local probe / cache")
            )
        ]
        let metrics = stage == .light ? [all[1], all[2], all[4]] : all
        return HStack(spacing: 0) {
            ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                VStack(alignment: .leading, spacing: 5) {
                    Text(metric.title)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.secondaryText)
                    Text(metric.value)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(metric.detail)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(theme.dimText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                if index < metrics.count - 1 {
                    Rectangle().fill(theme.subtleSeparator).frame(width: 1)
                }
            }
        }
        .godexUPanel(theme: theme)
    }

    @ViewBuilder
    private var lowerContent: some View {
        if profile.lowerContentPresentation == .split {
            HStack(alignment: .top, spacing: theme.contentSpacing) {
                projectPanel.frame(maxWidth: .infinity)
                telemetryGrid.frame(width: 360)
            }
        } else {
            VStack(spacing: theme.contentSpacing) {
                projectPanel
                telemetryGrid
            }
        }
    }

    private var projectPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.text("继续推进", "Continue"))
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(language.text("不活跃项目自动沉底", "Inactive projects sink automatically"))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(theme.dimText)
            }
            .padding(.horizontal, 15)
            .frame(height: 42)
            Rectangle().fill(theme.subtleSeparator).frame(height: 1)
            if projects.isEmpty {
                Text(language.text("暂无可聚合项目", "No aggregated projects yet"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                VStack(spacing: 4) {
                    ForEach(projects.prefix(3)) { project in
                        Button {
                            openProjects(project.id)
                        } label: {
                            HStack(spacing: 11) {
                                RoundedRectangle(cornerRadius: theme.controlRadius)
                                    .fill(theme.accent.opacity(0.14))
                                    .overlay(
                                        Image(systemName: "diamond")
                                            .foregroundStyle(theme.accent)
                                    )
                                    .frame(width: 38, height: 38)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(project.identity.name)
                                        .font(.system(size: 11, weight: .semibold))
                                        .lineLimit(1)
                                    Text(projectSummary(project))
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(theme.secondaryText)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(project.runtimes.map(\.displayName).joined(separator: " · "))
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(theme.dimText)
                                    .lineLimit(1)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(theme.dimText)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 58)
                            .background(
                                RoundedRectangle(cornerRadius: theme.controlRadius)
                                    .fill(theme.elevatedPanel.opacity(0.72))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
            }
        }
        .godexUPanel(theme: theme)
    }

    private var telemetryGrid: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
            GodexUTelemetryCard(
                title: "CPU",
                value: systemSnapshot.cpuUsagePercent.map { String(format: "%.0f%%", $0) } ?? "--",
                detail: language.text("本机采样", "Local sample"),
                symbol: "cpu",
                theme: theme
            )
            GodexUTelemetryCard(
                title: language.text("内存", "Memory"),
                value: memoryPercentText,
                detail: memoryDetailText,
                symbol: "memorychip",
                theme: theme
            )
            GodexUTelemetryCard(
                title: language.text("热状态", "Thermal"),
                value: thermalText,
                detail: language.text("macOS thermal state", "macOS thermal state"),
                symbol: "thermometer.medium",
                theme: theme
            )
            GodexUTelemetryCard(
                title: language.text("记忆索引", "Memory index"),
                value: "--",
                detail: language.text("未接入可验证健康信号", "No verified health signal"),
                symbol: "externaldrive.badge.questionmark",
                theme: theme
            )
        }
    }

    private var ticker: some View {
        HStack(spacing: 18) {
            if nodes.isEmpty {
                Label(
                    language.text("节点状态读取中", "Reading node status"),
                    systemImage: "clock.arrow.circlepath"
                )
            } else {
                ForEach(nodes.prefix(4)) { node in
                    HStack(spacing: 5) {
                        Circle().fill(healthColor(node.health)).frame(width: 6, height: 6)
                        Text(node.descriptor.displayName).fontWeight(.semibold)
                        Text(nodeStatus(node.health)).foregroundStyle(theme.secondaryText)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 9, weight: .medium))
        .padding(.horizontal, 12)
        .frame(height: 34)
        .overlay(alignment: .top) { Rectangle().fill(theme.subtleSeparator).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(theme.subtleSeparator).frame(height: 1) }
    }

    private var composerBar: some View {
        VStack(spacing: 5) {
            HStack(spacing: 10) {
                Image(systemName: "command")
                    .foregroundStyle(theme.accent)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(theme.accent.opacity(0.13)))
                TextField(
                    language.text("描述目标，先生成本机可审核任务包…", "Describe a goal and prepare a local reviewable task package…"),
                    text: $taskGoal
                )
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                if let selectedTarget {
                    Menu {
                        ForEach(composerTargets) { node in
                            Button {
                                selectedTargetNodeID = node.id
                            } label: {
                                Text(
                                    "\(node.descriptor.displayName) · "
                                        + node.descriptor.deviceName
                                )
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            RuntimeLogoView(
                                scope: selectedTarget.descriptor.runtime,
                                size: 16
                            )
                            Text(selectedTarget.descriptor.displayName)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 7, weight: .bold))
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.secondaryText)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                Button {
                    saveLocalTaskPackage()
                } label: {
                    Text(language.text("生成任务包", "Prepare task package"))
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 15)
                        .frame(height: profile.composerPresentation == .compact ? 32 : 38)
                        .foregroundStyle(.white)
                        .background(Capsule().fill(theme.accent))
                }
                .buttonStyle(.plain)
                .disabled(
                    taskGoal.trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty || selectedTarget == nil
                )
            }
            if let composerFeedback {
                Label(
                    composerFeedback,
                    systemImage: composerFeedbackIsError
                        ? "exclamationmark.triangle.fill"
                        : "checkmark.circle.fill"
                )
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(
                    composerFeedbackIsError
                        ? WidgetPalette.statusDanger
                        : WidgetPalette.statusSuccess
                )
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: 680)
        .frame(minHeight: profile.composerPresentation == .compact ? 46 : 54)
        .background(Capsule().fill(theme.shell))
        .overlay(Capsule().stroke(theme.strongSeparator, lineWidth: 0.8))
        .frame(maxWidth: .infinity)
        .help(language.text("仅在本机准备草稿，不会自动投递", "Prepares a local draft; it is not delivered automatically"))
    }

    private var commandInspector: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language.text("指挥检查器", "Command inspector"))
                .font(.system(size: 16, weight: .semibold))
            if let node = selectedNode {
                RuntimeLogoView(scope: node.descriptor.runtime, size: 34)
                Text(node.descriptor.displayName)
                    .font(.system(size: 18, weight: .semibold))
                Text(node.descriptor.deviceName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                inspectorRow(
                    language.text("身份", "Role"),
                    identityStore.profile(
                        nodeID: node.id,
                        runtime: node.descriptor.runtime,
                        now: Date()
                    ).roleName
                )
                inspectorRow(language.text("状态", "Status"), nodeStatus(node.health))
                inspectorRow(language.text("来源", "Source"), node.sourceLabel)
                Text(language.text("能力", "Capabilities"))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.dimText)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 70), spacing: 6)],
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(node.descriptor.capabilities, id: \.self) { capability in
                        Text(capability)
                            .font(.system(size: 8, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(theme.elevatedPanel))
                    }
                }
            } else {
                Text(language.text("尚未观察到 Agent 节点", "No Agent node observed"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer()
            Label(
                language.text("只读检查 · 无修复写入", "Read-only inspection · No repair writes"),
                systemImage: "lock.shield"
            )
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(theme.secondaryText)
        }
        .padding(18)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .godexUPanel(theme: theme)
    }

    private func inspectorRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 8, weight: .semibold)).foregroundStyle(theme.dimText)
            Text(value).font(.system(size: 10, weight: .medium)).lineLimit(2)
        }
    }

    private var nodeValue: String {
        guard let available = overview.availableNodeCount,
              let observed = overview.observedNodeCount else { return "--" }
        return "\(available)/\(observed)"
    }

    private var memoryPercentText: String {
        guard let used = systemSnapshot.memoryUsedBytes,
              let total = systemSnapshot.memoryTotalBytes,
              total > 0 else { return "--" }
        return String(format: "%.0f%%", Double(used) / Double(total) * 100)
    }

    private var memoryDetailText: String {
        guard let used = systemSnapshot.memoryUsedBytes,
              let total = systemSnapshot.memoryTotalBytes else {
            return language.text("系统物理内存", "Physical memory")
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB]
        formatter.countStyle = .memory
        return "\(formatter.string(fromByteCount: Int64(clamping: used))) / \(formatter.string(fromByteCount: Int64(clamping: total)))"
    }

    private var thermalText: String {
        if let temperature = systemSnapshot.temperatureCelsius {
            return String(format: "%.0f°C", temperature)
        }
        switch systemSnapshot.thermalLevel {
        case .nominal: return language.text("正常", "Normal")
        case .fair: return language.text("偏热", "Warm")
        case .serious: return language.text("较热", "Hot")
        case .critical: return language.text("严重", "Critical")
        case .unknown: return "--"
        }
    }

    private func projectSummary(_ project: AgentProjectWorkspace) -> String {
        language.text(
            "\(project.tasks.count) 任务 · \(project.envelopes.count) 本机交接",
            "\(project.tasks.count) tasks · \(project.envelopes.count) local handoffs"
        )
    }

    private func healthColor(_ health: AgentNodeHealth) -> Color {
        switch health {
        case .available: return WidgetPalette.statusSuccess
        case .degraded: return WidgetPalette.statusWarning
        case .unreachable: return WidgetPalette.statusDanger
        case .offline, .stale: return WidgetPalette.statusNeutral
        }
    }

    private func nodeStatus(_ health: AgentNodeHealth) -> String {
        switch health {
        case .available: return language.text("可用", "Available")
        case .degraded: return language.text("需关注", "Needs attention")
        case .offline: return language.text("离线", "Offline")
        case .unreachable: return language.text("不可达", "Unreachable")
        case .stale: return language.text("缓存", "Cached")
        }
    }

    private var composerTargets: [AgentNodeSnapshot] {
        nodes.filter {
            AgentProjectWorkspaceBuilder.isCompatibleHandoffTarget(
                source: .codex,
                target: $0.descriptor.runtime
            )
        }
    }

    private var selectedTarget: AgentNodeSnapshot? {
        composerTargets.first { $0.id == selectedTargetNodeID }
            ?? composerTargets.first
    }

    private func selectFirstTargetIfNeeded() {
        guard !composerTargets.isEmpty else {
            selectedTargetNodeID = ""
            return
        }
        if !composerTargets.contains(where: { $0.id == selectedTargetNodeID }) {
            selectedTargetNodeID = composerTargets[0].id
        }
    }

    private func saveLocalTaskPackage() {
        composerFeedback = nil
        composerFeedbackIsError = false
        let goal = taskGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !goal.isEmpty, let selectedTarget else { return }
        let id = UUID()
        let originNodeID = nodes.first {
            $0.descriptor.runtime == .codex
        }?.id ?? "codex-local"
        guard let draft = AgentTaskEnvelope.localWorkbenchDraft(
            id: id,
            originNodeID: originNodeID,
            title: goal,
            targetNodeID: selectedTarget.id,
            targetRuntime: selectedTarget.descriptor.runtime,
            now: Date()
        ) else {
            composerFeedback = language.text(
                "无法生成有效的本机任务包。",
                "Could not prepare a valid local task package."
            )
            composerFeedbackIsError = true
            return
        }
        do {
            try envelopeStore.upsert(draft)
            taskGoal = ""
            composerFeedback = language.text(
                "已保存本机草稿，尚未投递。",
                "Local draft saved; not delivered."
            )
            openProjects(AgentTaskEnvelope.workbenchInboxProjectID)
        } catch {
            composerFeedback = language.text(
                "无法保存本机任务包。",
                "Could not save the local task package."
            )
            composerFeedbackIsError = true
        }
    }
}

private struct GodexURelationshipGraph: View {
    let nodes: [AgentNodeSnapshot]
    let selectedNodeID: String?
    let theme: GodexUWorkbenchTheme
    let language: WidgetLanguage
    let onSelect: (AgentNodeSnapshot) -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    for point in nodePoints(size: size).prefix(min(nodes.count, 4)) {
                        var path = Path()
                        path.move(to: center)
                        path.addLine(to: point)
                        context.stroke(
                            path,
                            with: .color(theme.accent.opacity(0.42)),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 7])
                        )
                    }
                }
                .accessibilityHidden(true)

                RoundedRectangle(cornerRadius: theme.controlRadius)
                    .fill(theme.accent.opacity(0.16))
                    .rotationEffect(.degrees(45))
                    .frame(width: 62, height: 62)
                    .overlay(
                        Text("ROUTER")
                            .font(.system(size: 7, weight: .bold))
                            .tracking(1)
                    )

                if nodes.isEmpty {
                    Text(language.text("正在读取真实节点", "Reading observed nodes"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                        .offset(y: 66)
                } else {
                    ForEach(Array(nodes.prefix(4).enumerated()), id: \.element.id) { index, node in
                        let point = nodePoints(size: proxy.size)[index]
                        Button { onSelect(node) } label: {
                            HStack(spacing: 7) {
                                RuntimeLogoView(scope: node.descriptor.runtime, size: 21)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(node.descriptor.displayName)
                                        .font(.system(size: 10, weight: .semibold))
                                    Text(node.descriptor.deviceName)
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundStyle(theme.secondaryText)
                                }
                            }
                            .padding(.horizontal, 9)
                            .frame(height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: theme.controlRadius)
                                    .fill(theme.elevatedPanel)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: theme.controlRadius)
                                            .stroke(
                                                node.id == selectedNodeID
                                                    ? theme.accent
                                                    : theme.subtleSeparator
                                            )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .position(point)
                    }
                }
            }
            .padding(10)
        }
        .godexUPanel(theme: theme)
        .overlay(alignment: .topLeading) {
            HStack(spacing: 6) {
                Circle()
                    .fill(relationshipHeaderColor)
                    .frame(width: 6, height: 6)
                Text(relationshipHeaderTitle)
            }
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(theme.secondaryText)
            .padding(12)
        }
    }

    private func nodePoints(size: CGSize) -> [CGPoint] {
        [
            CGPoint(x: size.width * 0.23, y: size.height * 0.30),
            CGPoint(x: size.width * 0.77, y: size.height * 0.30),
            CGPoint(x: size.width * 0.76, y: size.height * 0.74),
            CGPoint(x: size.width * 0.24, y: size.height * 0.74)
        ]
    }

    private var relationshipHeaderColor: Color {
        if nodes.contains(where: { $0.health == .available }) {
            return WidgetPalette.statusSuccess
        }
        if nodes.contains(where: {
            $0.health == .degraded || $0.health == .unreachable
        }) {
            return WidgetPalette.statusWarning
        }
        return WidgetPalette.statusNeutral
    }

    private var relationshipHeaderTitle: String {
        if nodes.contains(where: { $0.health == .available }) {
            return language.text(
                "实时关系图 · 来源可追溯",
                "Live relationship graph · Traceable sources"
            )
        }
        return language.text(
            "关系图 · 本机探测 / 缓存",
            "Relationship graph · Local probe / cache"
        )
    }
}

private struct GodexUTelemetryCard: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String
    let theme: GodexUWorkbenchTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: symbol).foregroundStyle(theme.secondaryAccent)
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(theme.secondaryText)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(detail)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(theme.dimText)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: theme.controlRadius)
                .fill(theme.elevatedPanel)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.controlRadius)
                        .stroke(theme.subtleSeparator)
                )
        )
    }
}

private struct GodexUDashboardMetric {
    let title: String
    let value: String
    let detail: String
}

private extension View {
    func godexUPanel(theme: GodexUWorkbenchTheme) -> some View {
        background(
            RoundedRectangle(cornerRadius: theme.panelRadius, style: .continuous)
                .fill(theme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.panelRadius, style: .continuous)
                        .stroke(theme.subtleSeparator, lineWidth: 0.8)
                )
        )
    }
}

struct GodexUWorkbenchHeader: View {
    @ObservedObject var settings: AppSettings

    @Environment(\.colorScheme) private var colorScheme

    private var language: WidgetLanguage { settings.language }
    private var theme: GodexUWorkbenchTheme {
        GodexUWorkbenchTheme(skin: settings.workbenchSkin)
    }

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(theme.selectedFill(colorScheme))
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(theme.accent)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("GodexU")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.primaryText)
                        Text("2.0")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(theme.selectedFill(colorScheme))
                            )
                    }
                    Text(settings.workbenchStage.detail(language: language))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            GodexUWorkbenchStageControl(
                selection: $settings.workbenchStage,
                skin: settings.workbenchSkin,
                language: language
            )

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Circle()
                    .fill(WidgetPalette.statusSuccess)
                    .frame(width: 7, height: 7)
                Text(language.text("本地数据", "Local data"))
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
            }

            GodexUSkinMenu(
                selection: $settings.workbenchSkin,
                language: language
            )
        }
        .accessibilityElement(children: .contain)
    }
}

struct GodexUWorkbenchStageControl: View {
    @Binding var selection: GodexUWorkbenchStage
    let skin: GodexUSkin
    let language: WidgetLanguage

    @Environment(\.colorScheme) private var colorScheme

    private var theme: GodexUWorkbenchTheme {
        GodexUWorkbenchTheme(skin: skin)
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(GodexUWorkbenchStage.allCases) { stage in
                Button {
                    selection = stage
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: stage.systemImage)
                            .font(.system(size: 9, weight: .semibold))
                        Text(stage.displayName(language: language))
                            .font(.system(size: 9.5, weight: .semibold))
                    }
                    .foregroundStyle(
                        selection == stage
                            ? theme.primaryText
                            : theme.secondaryText
                    )
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(
                                selection == stage
                                    ? theme.selectedFill(colorScheme)
                                    : Color.clear
                            )
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(stage.detail(language: language))
                .accessibilityLabel(stage.displayName(language: language))
                .accessibilityValue(
                    selection == stage
                        ? language.text("已选择", "Selected")
                        : language.text("未选择", "Not selected")
                )
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: theme.controlRadius, style: .continuous)
                .fill(theme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.controlRadius, style: .continuous)
                        .strokeBorder(theme.subtleSeparator, lineWidth: 0.8)
                )
        )
    }
}

struct GodexUSkinMenu: View {
    @Binding var selection: GodexUSkin
    let language: WidgetLanguage

    @Environment(\.colorScheme) private var colorScheme

    private var theme: GodexUWorkbenchTheme {
        GodexUWorkbenchTheme(skin: selection)
    }

    var body: some View {
        Menu {
            ForEach(GodexUSkin.allCases) { skin in
                Button {
                    selection = skin
                } label: {
                    Label {
                        Text(skin.displayName(language: language))
                    } icon: {
                        Image(systemName: selection == skin ? "checkmark.circle.fill" : skin.systemImage)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 7, height: 7)
                Text(selection.displayName(language: language))
                    .font(.system(size: 9.5, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(theme.secondaryText)
            }
            .foregroundStyle(theme.primaryText)
            .padding(.horizontal, 9)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: theme.controlRadius, style: .continuous)
                    .fill(theme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.controlRadius, style: .continuous)
                            .strokeBorder(theme.subtleSeparator, lineWidth: 0.8)
                    )
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: true, vertical: false)
        .help(language.text("切换工作台皮肤", "Change workbench skin"))
        .accessibilityLabel(language.text("工作台皮肤", "Workbench skin"))
        .accessibilityValue(selection.displayName(language: language))
    }
}

struct GodexUCoreOverviewStrip: View {
    let overview: GodexUWorkbenchOverview
    let stage: GodexUWorkbenchStage
    let skin: GodexUSkin
    let language: WidgetLanguage

    @Environment(\.colorScheme) private var colorScheme

    private var theme: GodexUWorkbenchTheme {
        GodexUWorkbenchTheme(skin: skin)
    }

    private var metrics: [GodexUOverviewMetric] {
        let all = [
            GodexUOverviewMetric(
                id: "official-latest-day",
                title: language.text("Codex 最近一天", "Codex latest day"),
                value: overview.officialLatestDayTokens.map(TokenFormatter.format) ?? "--",
                detail: language.text("官方活动", "Official activity"),
                systemName: "bolt.horizontal.circle.fill"
            ),
            GodexUOverviewMetric(
                id: "official-seven-day",
                title: language.text("Codex 近 7 天", "Codex 7 days"),
                value: overview.officialSevenDayTokens.map(TokenFormatter.format) ?? "--",
                detail: language.text("官方活动", "Official activity"),
                systemName: "calendar.circle.fill"
            ),
            GodexUOverviewMetric(
                id: "active-tasks",
                title: language.text("进行中", "Active"),
                value: overview.activeTaskCount.map(String.init) ?? "--",
                detail: language.text("聚合任务", "Aggregated tasks"),
                systemName: "play.circle.fill"
            ),
            GodexUOverviewMetric(
                id: "pending-tasks",
                title: language.text("待处理", "Pending"),
                value: overview.pendingTaskCount.map(String.init) ?? "--",
                detail: language.text("聚合任务", "Aggregated tasks"),
                systemName: "clock.fill"
            ),
            GodexUOverviewMetric(
                id: "available-nodes",
                title: language.text("可用节点", "Available nodes"),
                value: nodeValue,
                detail: language.text("本机探测 / 缓存", "Local probe / cache"),
                systemName: "point.3.filled.connected.trianglepath.dotted"
            )
        ]
        if stage == .light {
            return [all[1], all[2], all[4]]
        }
        return all
    }

    var body: some View {
        HStack(spacing: 7) {
            ForEach(metrics) { metric in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Image(systemName: metric.systemName)
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(theme.accent)
                        Text(metric.title)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text(metric.value)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    if stage.showsMetricSourceLabels {
                        Text(metric.detail)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(WidgetPalette.cardFill(colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    metric.id == "official-latest-day"
                                        ? theme.stroke(colorScheme)
                                        : WidgetPalette.cardStroke(colorScheme),
                                    lineWidth: 0.8
                                )
                        )
                )
                .help("\(metric.title) · \(metric.detail)")
            }
        }
        .padding(8)
        .sectionBackground()
        .accessibilityElement(children: .contain)
    }

    private var nodeValue: String {
        guard let available = overview.availableNodeCount,
              let observed = overview.observedNodeCount else {
            return "--"
        }
        return "\(available)/\(observed)"
    }
}

private struct GodexUOverviewMetric: Identifiable {
    let id: String
    let title: String
    let value: String
    let detail: String
    let systemName: String
}
