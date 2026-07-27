import SwiftUI

enum DynamicIslandMode: Equatable {
    case compact
    case peek
    case expanded

    func size(for dock: DynamicIslandDock) -> CGSize {
        if dock.isVertical {
            switch self {
            case .compact:
                return CGSize(width: 54, height: 226)
            case .peek:
                return CGSize(width: 92, height: 438)
            case .expanded:
                return CGSize(width: 300, height: 620)
            }
        }

        return size
    }

    var size: CGSize {
        switch self {
        case .compact:
            return CGSize(width: 226, height: 46)
        case .peek:
            return CGSize(width: 438, height: 92)
        case .expanded:
            return CGSize(width: 620, height: 270)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .compact, .peek:
            return 23
        case .expanded:
            return 24
        }
    }

    func cornerRadius(for dock: DynamicIslandDock) -> CGFloat {
        if dock.isVertical, self != .expanded {
            let size = size(for: dock)
            return min(size.width, size.height) / 2
        }
        return cornerRadius
    }
}

struct DynamicIslandView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var systemMonitor: LocalSystemMonitor
    @ObservedObject var placement: DynamicIslandPlacementModel
    let onModeChange: (DynamicIslandMode) -> Void
    let onOpenMainWindow: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var interaction = DynamicIslandInteractionState()

    private var language: WidgetLanguage { settings.language }
    private var mode: DynamicIslandMode { interaction.mode }
    private var islandSize: CGSize { mode.size(for: placement.dock) }
    private var islandCornerRadius: CGFloat { mode.cornerRadius(for: placement.dock) }

    private var presentation: DynamicIslandPresentation {
        DynamicIslandPresentationBuilder().build(
            DynamicIslandPresentationInput(
                runtimes: store.runtimeSnapshots,
                visibleScopes: settings.visibleRuntimeScopes,
                aggregateTaskBoard: store.multiRuntimeSnapshot.aggregate.taskBoard,
                system: systemMonitor.snapshot,
                language: language,
                now: Date()
            )
        )
    }

    var body: some View {
        islandSurface
            .frame(width: islandSize.width, height: islandSize.height)
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: mode)
            .animation(.spring(response: 0.28, dampingFraction: 0.9), value: placement.dock)
            .onAppear {
                onModeChange(mode)
            }
            .onChange(of: mode) { _, newMode in
                onModeChange(newMode)
            }
            .onHover { hovering in
                if let schedule = interaction.hoverChanged(hovering) {
                    scheduleHoverTransition(schedule)
                }
            }
            .onTapGesture {
                withAnimation {
                    _ = interaction.toggleExpanded()
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("codexU Dynamic Island")
    }

    private var islandSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous)
                .fill(surfaceFill)
                .overlay(
                    RoundedRectangle(cornerRadius: islandCornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.22), lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.14), radius: 18, y: 8)

            switch mode {
            case .compact:
                placement.dock.isVertical ? AnyView(verticalCompactContent) : AnyView(compactContent)
            case .peek:
                placement.dock.isVertical ? AnyView(verticalPeekContent) : AnyView(peekContent)
            case .expanded:
                placement.dock.isVertical ? AnyView(verticalExpandedContent) : AnyView(expandedContent)
            }
        }
        .readableForegroundHierarchy(colorScheme)
    }

    private var surfaceFill: Color {
        if reduceTransparency {
            return colorScheme == .dark ? Color.black.opacity(0.92) : Color.white.opacity(0.92)
        }
        return colorScheme == .dark ? Color.black.opacity(0.72) : Color.white.opacity(0.76)
    }

    private var compactContent: some View {
        HStack(spacing: 10) {
            RuntimeLogoView(scope: .codex, size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(presentation.headline)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                Text(presentation.quotaLine)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            statusDot
        }
        .padding(.horizontal, 12)
    }

    private var verticalCompactContent: some View {
        VStack(spacing: 8) {
            RuntimeLogoView(scope: .codex, size: 24)
            Text("Codex")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .lineLimit(1)
            Text(compactQuotaValue)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
            Text(presentation.totalTodayTokensText)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            statusDot
        }
        .padding(.vertical, 12)
    }

    private var peekContent: some View {
        VStack(spacing: 9) {
            HStack(spacing: 10) {
                compactHeader
                Spacer(minLength: 0)
                Text(presentation.totalTodayTokensText)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                ForEach(presentation.systemMetrics, id: \.id) { metric in
                    metricPill(metric)
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
    }

    private var verticalPeekContent: some View {
        VStack(spacing: 10) {
            verticalCompactHeader
            ForEach(presentation.systemMetrics, id: \.id) { metric in
                verticalMetricPill(metric)
            }
            Spacer(minLength: 0)
            statusDot
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 13)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                compactHeader
                Spacer(minLength: 8)
                Button {
                    onOpenMainWindow()
                } label: {
                    Label(language.text("打开主面板", "Open dashboard"), systemImage: "rectangle.grid.2x2")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Button {
                    withAnimation {
                        _ = interaction.closeExpanded()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                ForEach(presentation.systemMetrics, id: \.id) { metric in
                    metricCard(metric)
                }
            }

            HStack(alignment: .top, spacing: 10) {
                runtimeList
                attentionList
            }
        }
        .padding(14)
    }

    private var verticalExpandedContent: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                verticalCompactHeader
                Spacer(minLength: 6)
                Button {
                    onOpenMainWindow()
                } label: {
                    Image(systemName: "rectangle.grid.2x2")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Button {
                    withAnimation {
                        _ = interaction.closeExpanded()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 8) {
                ForEach(presentation.systemMetrics, id: \.id) { metric in
                    metricCard(metric)
                }
            }

            runtimeList
            attentionList
        }
        .padding(14)
    }

    private var compactHeader: some View {
        HStack(spacing: 9) {
            RuntimeLogoView(scope: .codex, size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(presentation.headline)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                Text(presentation.subheadline)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var verticalCompactHeader: some View {
        HStack(spacing: 8) {
            RuntimeLogoView(scope: .codex, size: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(presentation.headline)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                Text(presentation.subheadline)
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compactQuotaValue: String {
        presentation.headline
            .replacingOccurrences(of: "Codex ", with: "")
            .replacingOccurrences(of: "Codex", with: "--")
    }

    private var statusDot: some View {
        Circle()
            .fill(presentation.attentionTasks.isEmpty ? WidgetPalette.statusSuccess : WidgetPalette.statusWarning)
            .frame(width: 8, height: 8)
    }

    private func metricPill(_ metric: DynamicIslandMetric) -> some View {
        HStack(spacing: 5) {
            Image(systemName: metric.systemName)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(metricTint(metric.severity))
            Text(metric.value)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Capsule(style: .continuous).fill(WidgetPalette.surfaceTrack))
    }

    private func verticalMetricPill(_ metric: DynamicIslandMetric) -> some View {
        VStack(spacing: 4) {
            Image(systemName: metric.systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(metricTint(metric.severity))
            Text(metric.value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Capsule(style: .continuous).fill(WidgetPalette.surfaceTrack))
    }

    private func metricCard(_ metric: DynamicIslandMetric) -> some View {
        HStack(spacing: 8) {
            Image(systemName: metric.systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(metricTint(metric.severity))
            VStack(alignment: .leading, spacing: 1) {
                Text(metric.title)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(metric.value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .cardBackground(cornerRadius: 13, elevated: true)
    }

    private var runtimeList: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(language.text("来源", "Sources"))
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
            ForEach(presentation.runtimeRows) { row in
                HStack(spacing: 7) {
                    RuntimeLogoView(scope: row.scope, size: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.name)
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineLimit(1)
                        Text(row.statusText)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text(row.todayTokensText)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(WidgetPalette.surfaceTrack.opacity(0.56))
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var attentionList: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(language.text("注意", "Attention"))
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
            if presentation.attentionTasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(WidgetPalette.statusSuccess)
                    Text(language.text("暂无需要处理的任务", "No tasks need attention"))
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(WidgetPalette.surfaceTrack.opacity(0.40))
                )
            } else {
                ForEach(presentation.attentionTasks) { task in
                    HStack(alignment: .top, spacing: 7) {
                        RuntimeLogoView(scope: task.source, size: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.system(size: 10.5, weight: .semibold))
                                .lineLimit(2)
                            Text(task.statusText)
                                .font(.system(size: 8.5, weight: .medium))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(WidgetPalette.surfaceTrack.opacity(0.56))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func metricTint(_ severity: DynamicIslandMetricSeverity) -> Color {
        switch severity {
        case .normal:
            return WidgetPalette.statusSuccess
        case .warning:
            return WidgetPalette.statusWarning
        case .danger:
            return WidgetPalette.statusDanger
        case .unknown:
            return WidgetPalette.statusInfo
        }
    }

    private func scheduleHoverTransition(_ schedule: DynamicIslandHoverSchedule) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(schedule.delaySeconds * 1_000_000_000))
            withAnimation {
                _ = interaction.applyPendingHover(token: schedule.token)
            }
        }
    }
}
