import SwiftUI

enum AgentNodePollingPolicy {
    static let interval: TimeInterval = 120
    static let tolerance: TimeInterval = 24
}

struct AgentNodeRefreshGate {
    private var isRefreshing = false
    private var hasPendingRefresh = false

    mutating func request(queueIfBusy: Bool) -> Bool {
        guard !isRefreshing else {
            if queueIfBusy {
                hasPendingRefresh = true
            }
            return false
        }
        isRefreshing = true
        return true
    }

    mutating func complete() -> Bool {
        guard isRefreshing else { return false }
        isRefreshing = false
        let shouldRefreshAgain = hasPendingRefresh
        hasPendingRefresh = false
        return shouldRefreshAgain
    }

    mutating func reset() {
        isRefreshing = false
        hasPendingRefresh = false
    }
}

final class AgentNodeStore: ObservableObject {
    @Published private(set) var snapshots: [AgentNodeSnapshot] = []

    private let reader: AgentNodeReader
    private var codexRuntime: RuntimeUsageSnapshot?
    private var refreshTimer: Timer?
    private var refreshGate = AgentNodeRefreshGate()
    private var generation = 0

    init(reader: AgentNodeReader = AgentNodeReader()) {
        self.reader = reader
    }

    func start(codexRuntime: RuntimeUsageSnapshot?) {
        self.codexRuntime = codexRuntime
        generation += 1
        refresh(queueIfBusy: false)

        refreshTimer?.invalidate()
        let timer = Timer(
            timeInterval: AgentNodePollingPolicy.interval,
            repeats: true
        ) { [weak self] _ in
            self?.refresh(queueIfBusy: false)
        }
        timer.tolerance = AgentNodePollingPolicy.tolerance
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    func stop() {
        generation += 1
        refreshTimer?.invalidate()
        refreshTimer = nil
        refreshGate.reset()
    }

    func updateLocalCodex(_ runtime: RuntimeUsageSnapshot?) {
        guard runtime != codexRuntime else { return }
        codexRuntime = runtime
        refresh(queueIfBusy: true)
    }

    private func refresh(queueIfBusy: Bool) {
        guard refreshGate.request(queueIfBusy: queueIfBusy) else { return }
        let reader = reader
        let runtime = codexRuntime
        let refreshGeneration = generation

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let nextSnapshots = reader.load(codexRuntime: runtime, now: Date())
            DispatchQueue.main.async {
                guard let self, self.generation == refreshGeneration else { return }
                self.snapshots = nextSnapshots
                if self.refreshGate.complete() {
                    self.refresh(queueIfBusy: false)
                }
            }
        }
    }
}

enum AgentNodePresentationTone: Equatable {
    case success
    case warning
    case danger
    case info
    case neutral
}

struct AgentNodePresentation: Identifiable, Equatable {
    let id: String
    let runtime: RuntimeScope
    let title: String
    let subtitle: String
    let statusText: String
    let lastSeenText: String
    let capabilityText: String
    let systemName: String
    let tone: AgentNodePresentationTone
    let accessibilityText: String
    let isCached: Bool

    static func make(
        _ snapshot: AgentNodeSnapshot,
        language: WidgetLanguage,
        now: Date
    ) -> AgentNodePresentation {
        let status: (text: String, symbol: String, tone: AgentNodePresentationTone)
        switch snapshot.health {
        case .available:
            status = (
                language.text("可用", "Available"),
                "checkmark.circle.fill",
                .success
            )
        case .degraded:
            status = (
                language.text("需关注", "Needs attention"),
                "exclamationmark.triangle.fill",
                .warning
            )
        case .offline:
            status = (
                language.text("已离线", "Offline"),
                "stop.circle.fill",
                .neutral
            )
        case .unreachable:
            status = (
                language.text("无法连接", "Unreachable"),
                "wifi.slash",
                .danger
            )
        case .stale:
            status = (
                cachedStatusText(snapshot.detailCode, language: language),
                "clock.arrow.circlepath",
                .info
            )
        }

        let location = snapshot.descriptor.location == .local
            ? language.text("本机", "Local")
            : language.text("远端", "Remote")
        let lastSeen = relativeNodeTime(
            snapshot.lastSeenAt,
            now: now,
            language: language
        )
        let capabilityText = language.text(
            "\(snapshot.descriptor.capabilities.count) 项能力",
            "\(snapshot.descriptor.capabilities.count) capabilities"
        )
        let subtitle = "\(snapshot.descriptor.deviceName) · \(location)"
        return AgentNodePresentation(
            id: snapshot.id,
            runtime: snapshot.descriptor.runtime,
            title: snapshot.descriptor.displayName,
            subtitle: subtitle,
            statusText: status.text,
            lastSeenText: lastSeen,
            capabilityText: capabilityText,
            systemName: status.symbol,
            tone: status.tone,
            accessibilityText: [
                snapshot.descriptor.displayName,
                subtitle,
                status.text,
                lastSeen,
                capabilityText
            ].joined(separator: "，"),
            isCached: snapshot.isFromCache
        )
    }
}

struct AgentNodeStatusSection: View {
    @Environment(\.colorScheme) private var colorScheme

    let snapshots: [AgentNodeSnapshot]
    let language: WidgetLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionTitle(
                title: language.text("Agent 节点", "Agent nodes"),
                detail: summaryText
            )

            if snapshots.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(language.text("正在读取节点状态", "Reading node status"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(height: 62)
                .padding(.horizontal, 12)
            } else {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(presentations.prefix(4)) { presentation in
                        AgentNodeStatusTile(
                            presentation: presentation,
                            colorScheme: colorScheme
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(12)
        .sectionBackground()
        .accessibilityElement(children: .contain)
    }

    private var presentations: [AgentNodePresentation] {
        let now = Date()
        return snapshots.map {
            AgentNodePresentation.make($0, language: language, now: now)
        }
    }

    private var summaryText: String {
        let available = snapshots.filter { $0.health == .available }.count
        return language.text(
            "\(available)/\(snapshots.count) 可用",
            "\(available)/\(snapshots.count) available"
        )
    }
}

private struct AgentNodeStatusTile: View {
    let presentation: AgentNodePresentation
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                RuntimeLogoView(scope: presentation.runtime, size: 20)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(presentation.title)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(presentation.subtitle)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 4)
                Image(systemName: presentation.systemName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }

            HStack(spacing: 5) {
                Text(presentation.statusText)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(presentation.lastSeenText)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(presentation.capabilityText)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(minHeight: 76, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(WidgetPalette.controlFill(colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(
                            WidgetPalette.controlStroke(colorScheme),
                            lineWidth: 0.8
                        )
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityText)
    }

    private var tint: Color {
        switch presentation.tone {
        case .success:
            return WidgetPalette.statusSuccess
        case .warning:
            return WidgetPalette.statusWarning
        case .danger:
            return WidgetPalette.statusDanger
        case .info:
            return WidgetPalette.statusInfo
        case .neutral:
            return WidgetPalette.statusNeutral
        }
    }
}

private func relativeNodeTime(
    _ date: Date?,
    now: Date,
    language: WidgetLanguage
) -> String {
    guard let date else {
        return language.text("未见", "Never seen")
    }
    let interval = max(0, now.timeIntervalSince(date))
    if interval < 60 {
        return language.text("刚刚", "Just now")
    }
    if interval < 60 * 60 {
        let minutes = max(1, Int(interval / 60))
        return language.text("\(minutes) 分钟前", "\(minutes)m ago")
    }
    if interval < 24 * 60 * 60 {
        let hours = max(1, Int(interval / (60 * 60)))
        return language.text("\(hours) 小时前", "\(hours)h ago")
    }
    let days = max(1, Int(interval / (24 * 60 * 60)))
    return language.text("\(days) 天前", "\(days)d ago")
}

private func cachedStatusText(
    _ detailCode: String,
    language: WidgetLanguage
) -> String {
    switch detailCode {
    case "live-probe-timeout":
        return language.text("缓存 · 连接超时", "Cached · timed out")
    case "live-probe-authentication":
        return language.text("缓存 · 需要授权", "Cached · authorization needed")
    case "live-probe-host-key":
        return language.text("缓存 · 主机验证", "Cached · verify host")
    case "live-probe-transport":
        return language.text("缓存 · 连接失败", "Cached · connection failed")
    case "live-probe-protocol":
        return language.text("缓存 · 数据异常", "Cached · invalid response")
    default:
        return language.text("缓存状态", "Cached state")
    }
}
