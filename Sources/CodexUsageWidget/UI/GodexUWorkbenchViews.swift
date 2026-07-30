import SwiftUI

struct GodexUWorkbenchTheme {
    let skin: GodexUSkin

    private var tokens: GodexUSkinVisualTokens {
        skin.visualTokens
    }

    var accent: Color {
        Color(
            red: tokens.accentRed,
            green: tokens.accentGreen,
            blue: tokens.accentBlue
        )
    }

    var secondaryAccent: Color {
        Color(
            red: tokens.secondaryRed,
            green: tokens.secondaryGreen,
            blue: tokens.secondaryBlue
        )
    }

    func chromeFill(
        _ colorScheme: ColorScheme,
        reduceTransparency: Bool
    ) -> Color {
        if reduceTransparency {
            return Color(nsColor: .controlBackgroundColor)
        }
        return accent.opacity(
            colorScheme == .dark
                ? tokens.chromeOpacity * 0.30
                : tokens.chromeOpacity * 0.17
        )
    }

    func selectedFill(_ colorScheme: ColorScheme) -> Color {
        accent.opacity(
            colorScheme == .dark
                ? tokens.selectedOpacity
                : tokens.selectedOpacity * 0.72
        )
    }

    func stroke(_ colorScheme: ColorScheme) -> Color {
        accent.opacity(colorScheme == .dark ? 0.30 : 0.20)
    }
}

struct GodexUWorkbenchHeader: View {
    @ObservedObject var settings: AppSettings

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            GodexUWorkbenchStageControl(
                selection: $settings.workbenchStage,
                skin: settings.workbenchSkin,
                language: language
            )

            GodexUSkinMenu(
                selection: $settings.workbenchSkin,
                language: language
            )
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.chromeFill(
                    colorScheme,
                    reduceTransparency: reduceTransparency
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(theme.stroke(colorScheme), lineWidth: 0.8)
                )
        )
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
                    .foregroundStyle(selection == stage ? .primary : .secondary)
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
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(WidgetPalette.controlFill(colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(WidgetPalette.controlStroke(colorScheme), lineWidth: 0.8)
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
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 9)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(WidgetPalette.controlFill(colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(theme.stroke(colorScheme), lineWidth: 0.8)
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
