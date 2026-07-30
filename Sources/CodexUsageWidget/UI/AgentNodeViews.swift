import SwiftUI

struct AgentIdentityPresentation: Equatable {
    let roleName: String
    let responsibility: String
    let policyCode: String
    let policyName: String
    let policyDescription: String
    let safetyNotice: String
    let accessibilityText: String

    static func make(
        profile: AgentIdentityProfile,
        language: WidgetLanguage
    ) -> AgentIdentityPresentation {
        let defaults = AgentIdentityProfile.defaultProfile(
            nodeID: profile.nodeID,
            runtime: profile.runtime,
            now: profile.updatedAt
        )
        let usesDefaultIdentity = profile.roleName == defaults.roleName
            && profile.responsibility == defaults.responsibility
        let localizedDefault = defaultIdentity(
            runtime: profile.runtime,
            language: language
        )
        let roleName = usesDefaultIdentity
            ? localizedDefault.roleName
            : profile.roleName
        let responsibility = usesDefaultIdentity
            ? localizedDefault.responsibility
            : profile.responsibility
        let policy = policyText(profile.policyLevel, language: language)
        let safetyNotice = language.text(
            "本阶段只保存本机策略，不会授权任务投递、修复或其他远端动作。",
            "This phase stores local policy only and does not grant task delivery, repair, or other remote actions."
        )
        let accessibility = [
            roleName,
            responsibility,
            "\(policy.code) \(policy.name)",
            policy.description,
            safetyNotice
        ]
            .filter { !$0.isEmpty }
            .joined(separator: "，")
        return AgentIdentityPresentation(
            roleName: roleName,
            responsibility: responsibility,
            policyCode: policy.code,
            policyName: policy.name,
            policyDescription: policy.description,
            safetyNotice: safetyNotice,
            accessibilityText: String(accessibility.prefix(320))
        )
    }

    private static func defaultIdentity(
        runtime: RuntimeScope,
        language: WidgetLanguage
    ) -> (roleName: String, responsibility: String) {
        switch runtime {
        case .codex:
            return (
                language.text("开发执行", "Build & execute"),
                language.text(
                    "研究、实现、验证与交付成果",
                    "Research, implement, verify, and deliver"
                )
            )
        case .openClaw:
            return (
                language.text("协调调度", "Coordinate"),
                language.text(
                    "连续理解、任务编排与跨端状态协调",
                    "Maintain context, orchestrate work, and coordinate nodes"
                )
            )
        case .claudeCode:
            return (
                language.text("代码协作", "Code collaboration"),
                language.text(
                    "本机代码会话与实现协作",
                    "Collaborate on local coding sessions and implementation"
                )
            )
        case .hermes:
            return (
                language.text("分析复核", "Analyze & review"),
                language.text(
                    "独立分析、研究与结果复核",
                    "Analyze independently, research, and review results"
                )
            )
        }
    }

    private static func policyText(
        _ level: AgentPolicyLevel,
        language: WidgetLanguage
    ) -> (code: String, name: String, description: String) {
        switch level {
        case .guarded:
            return (
                "A",
                language.text("保守", "Guarded"),
                language.text(
                    "只观察、分析和给出建议，不执行外部动作。",
                    "Observe, analyze, and advise without external actions."
                )
            )
        case .collaborative:
            return (
                "B",
                language.text("协作", "Collaborative"),
                language.text(
                    "可以准备任务和交接草稿；实际投递仍需后续协议与确认。",
                    "May prepare work and handoff drafts; actual delivery still needs the later protocol and confirmation."
                )
            )
        case .flexible:
            return (
                "C",
                language.text("灵活", "Flexible"),
                language.text(
                    "为后续自定义规则预留；当前不会自动获得额外权限。",
                    "Reserved for later custom rules; it grants no additional permission now."
                )
            )
        }
    }
}

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
    let identity: AgentIdentityPresentation

    static func make(
        _ snapshot: AgentNodeSnapshot,
        language: WidgetLanguage,
        now: Date
    ) -> AgentNodePresentation {
        make(
            snapshot,
            profile: AgentIdentityProfile.defaultProfile(
                nodeID: snapshot.id,
                runtime: snapshot.descriptor.runtime,
                now: now
            ),
            language: language,
            now: now
        )
    }

    static func make(
        _ snapshot: AgentNodeSnapshot,
        profile: AgentIdentityProfile,
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
                unreachableStatusText(snapshot.detailCode, language: language),
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
        let identity = AgentIdentityPresentation.make(
            profile: profile,
            language: language
        )
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
                capabilityText,
                identity.accessibilityText
            ].joined(separator: "，"),
            isCached: snapshot.isFromCache,
            identity: identity
        )
    }
}

struct AgentNodeStatusSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var profileStore: AgentIdentityProfileStore
    @State private var selectedSnapshot: AgentNodeSnapshot?

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
                    ForEach(Array(snapshots.prefix(4))) { snapshot in
                        Button {
                            selectedSnapshot = snapshot
                        } label: {
                            AgentNodeStatusTile(
                                presentation: presentation(for: snapshot),
                                colorScheme: colorScheme
                            )
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .help(
                            language.text(
                                "查看和设置 Agent 身份",
                                "View and configure Agent identity"
                            )
                        )
                    }
                }
            }
        }
        .padding(12)
        .sectionBackground()
        .accessibilityElement(children: .contain)
        .sheet(item: $selectedSnapshot) { snapshot in
            AgentIdentityDetailView(
                snapshot: snapshot,
                profileStore: profileStore,
                language: language
            )
        }
    }

    private func presentation(
        for snapshot: AgentNodeSnapshot
    ) -> AgentNodePresentation {
        let now = Date()
        return AgentNodePresentation.make(
            snapshot,
            profile: profileStore.profile(
                nodeID: snapshot.id,
                runtime: snapshot.descriptor.runtime,
                now: now
            ),
            language: language,
            now: now
        )
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

            HStack(spacing: 5) {
                Text(presentation.identity.roleName)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                Text(presentation.identity.policyCode)
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 17, minHeight: 17)
                    .background(
                        Circle()
                            .fill(WidgetPalette.surfaceTrack)
                    )
                Image(systemName: "chevron.right")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(minHeight: 82, alignment: .topLeading)
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

struct AgentIdentityDetailView: View {
    let snapshot: AgentNodeSnapshot
    @ObservedObject var profileStore: AgentIdentityProfileStore
    let language: WidgetLanguage

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var roleName: String
    @State private var responsibility: String
    @State private var policyLevel: AgentPolicyLevel
    @State private var saveError: String?

    init(
        snapshot: AgentNodeSnapshot,
        profileStore: AgentIdentityProfileStore,
        language: WidgetLanguage
    ) {
        self.snapshot = snapshot
        self.profileStore = profileStore
        self.language = language
        let profile = profileStore.profile(
            nodeID: snapshot.id,
            runtime: snapshot.descriptor.runtime,
            now: Date()
        )
        let presentation = AgentIdentityPresentation.make(
            profile: profile,
            language: language
        )
        _roleName = State(initialValue: presentation.roleName)
        _responsibility = State(initialValue: presentation.responsibility)
        _policyLevel = State(initialValue: profile.policyLevel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 14)

            Divider()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    identityEditor
                    policyEditor
                    capabilitySection
                    safetyNotice
                    if let saveError {
                        Label(saveError, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(WidgetPalette.statusDanger)
                    }
                }
                .padding(20)
            }

            Divider()

            footer
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .frame(width: 540)
        .frame(minHeight: 520, maxHeight: 680)
        .background(WidgetPalette.windowScrim(colorScheme))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 11) {
            RuntimeLogoView(scope: snapshot.descriptor.runtime, size: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.descriptor.displayName)
                    .font(.system(size: 17, weight: .semibold))
                Text(
                    "\(snapshot.descriptor.deviceName) · "
                        + (snapshot.descriptor.location == .local
                            ? language.text("本机", "Local")
                            : language.text("远端", "Remote"))
                )
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                Label(
                    nodePresentation.statusText,
                    systemImage: nodePresentation.systemName
                )
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(nodeTint)
            }
            Spacer(minLength: 12)
            Text(
                language.text(
                    "Agent 身份",
                    "Agent identity"
                )
            )
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(language.text("关闭", "Close"))
        }
    }

    private var identityEditor: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(language.text("身份与职责", "Identity and responsibility"))
                .font(.system(size: 12, weight: .semibold))

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(language.text("角色名称", "Role name"))
                    Spacer()
                    Text("\(roleName.count)/\(AgentIdentityProfile.maximumRoleNameLength)")
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
                .font(.system(size: 9.5, weight: .medium))
                TextField(
                    language.text("例如：分析复核", "For example: Analyze & review"),
                    text: $roleName
                )
                .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(language.text("职责摘要", "Responsibility"))
                    Spacer()
                    Text(
                        "\(responsibility.count)/"
                            + "\(AgentIdentityProfile.maximumResponsibilityLength)"
                    )
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                }
                .font(.system(size: 9.5, weight: .medium))
                TextEditor(text: $responsibility)
                    .font(.system(size: 11, weight: .medium))
                    .scrollContentBackground(.hidden)
                    .padding(7)
                    .frame(minHeight: 76)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(WidgetPalette.controlFill(colorScheme))
                            .overlay(
                                RoundedRectangle(
                                    cornerRadius: 8,
                                    style: .continuous
                                )
                                .strokeBorder(
                                    WidgetPalette.controlStroke(colorScheme),
                                    lineWidth: 0.8
                                )
                            )
                    )
            }
        }
        .padding(13)
        .cardBackground(cornerRadius: 11)
    }

    private var policyEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(language.text("策略档位", "Policy level"))
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(
                    "\(identityPresentation.policyCode) "
                        + identityPresentation.policyName
                )
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            }

            Picker("", selection: $policyLevel) {
                ForEach(AgentPolicyLevel.allCases) { level in
                    Text(level.rawValue.uppercased()).tag(level)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            Text(identityPresentation.policyDescription)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .cardBackground(cornerRadius: 11)
    }

    private var capabilitySection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(language.text("节点能力", "Node capabilities"))
                .font(.system(size: 12, weight: .semibold))
            HStack(spacing: 7) {
                ForEach(snapshot.descriptor.capabilities, id: \.self) { capability in
                    Text(capabilityTitle(capability))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(WidgetPalette.surfaceTrack)
                        )
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(13)
        .cardBackground(cornerRadius: 11)
    }

    private var safetyNotice: some View {
        Label(
            identityPresentation.safetyNotice,
            systemImage: "lock.shield"
        )
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 2)
    }

    private var footer: some View {
        HStack(spacing: 9) {
            Button(language.text("恢复默认", "Reset")) {
                resetProfile()
            }
            .buttonStyle(.bordered)
            Spacer()
            Button(language.text("取消", "Cancel")) {
                dismiss()
            }
            .buttonStyle(.bordered)
            Button(language.text("保存", "Save")) {
                saveProfile()
            }
            .buttonStyle(.borderedProminent)
            .disabled(roleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var identityPresentation: AgentIdentityPresentation {
        let draft = AgentIdentityProfile(
            nodeID: snapshot.id,
            runtime: snapshot.descriptor.runtime,
            roleName: roleName,
            responsibility: responsibility,
            policyLevel: policyLevel,
            updatedAt: Date()
        )
        return AgentIdentityPresentation.make(
            profile: draft,
            language: language
        )
    }

    private var nodePresentation: AgentNodePresentation {
        AgentNodePresentation.make(
            snapshot,
            profile: profileStore.profile(
                nodeID: snapshot.id,
                runtime: snapshot.descriptor.runtime,
                now: Date()
            ),
            language: language,
            now: Date()
        )
    }

    private var nodeTint: Color {
        switch nodePresentation.tone {
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

    private func saveProfile() {
        guard let profile = AgentIdentityProfile.sanitized(
            nodeID: snapshot.id,
            runtime: snapshot.descriptor.runtime,
            roleName: roleName,
            responsibility: responsibility,
            policyLevel: policyLevel,
            updatedAt: Date()
        ) else {
            saveError = language.text(
                "请输入有效的角色名称。",
                "Enter a valid role name."
            )
            return
        }
        do {
            try profileStore.save(profile)
            saveError = nil
            dismiss()
        } catch {
            saveError = language.text(
                "无法保存本机 Agent 身份。",
                "The local Agent identity could not be saved."
            )
        }
    }

    private func resetProfile() {
        do {
            try profileStore.reset(nodeID: snapshot.id)
            let profile = profileStore.profile(
                nodeID: snapshot.id,
                runtime: snapshot.descriptor.runtime,
                now: Date()
            )
            let presentation = AgentIdentityPresentation.make(
                profile: profile,
                language: language
            )
            roleName = presentation.roleName
            responsibility = presentation.responsibility
            policyLevel = .guarded
            saveError = nil
        } catch {
            saveError = language.text(
                "无法恢复默认身份。",
                "The default identity could not be restored."
            )
        }
    }

    private func capabilityTitle(_ capability: String) -> String {
        switch capability {
        case "coding":
            return language.text("开发", "Coding")
        case "local-usage":
            return language.text("本机用量", "Local usage")
        case "task-observation":
            return language.text("任务观察", "Task observation")
        case "orchestration":
            return language.text("编排", "Orchestration")
        case "memory":
            return language.text("记忆", "Memory")
        case "task-routing":
            return language.text("任务路由", "Task routing")
        case "local-sessions":
            return language.text("本机会话", "Local sessions")
        case "analysis":
            return language.text("分析", "Analysis")
        case "review":
            return language.text("复核", "Review")
        case "research":
            return language.text("研究", "Research")
        default:
            return capability
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
    case "live-probe-local-network":
        return language.text("缓存 · 允许局域网", "Cached · allow local network")
    case "live-probe-connection-closed":
        return language.text("缓存 · 连接被关闭", "Cached · connection closed")
    case "live-probe-name-resolution":
        return language.text("缓存 · 节点地址无效", "Cached · invalid node address")
    case "live-probe-process-launch":
        return language.text("缓存 · SSH 无法启动", "Cached · SSH could not start")
    case "live-probe-transport-no-detail":
        return language.text("缓存 · SSH 未响应", "Cached · SSH did not respond")
    case "live-probe-transport":
        return language.text("缓存 · 连接失败", "Cached · connection failed")
    case "live-probe-protocol":
        return language.text("缓存 · 数据异常", "Cached · invalid response")
    default:
        return language.text("缓存状态", "Cached state")
    }
}

private func unreachableStatusText(
    _ detailCode: String,
    language: WidgetLanguage
) -> String {
    if detailCode == "probe-local-network" {
        return language.text("允许局域网", "Allow local network")
    }
    if detailCode == "probe-name-resolution" {
        return language.text("节点地址无效", "Invalid node address")
    }
    if detailCode == "probe-connection-closed" {
        return language.text("连接被关闭", "Connection closed")
    }
    if detailCode == "probe-process-launch" {
        return language.text("SSH 无法启动", "SSH could not start")
    }
    if detailCode == "probe-transport-no-detail" {
        return language.text("SSH 未响应", "SSH did not respond")
    }
    return language.text("无法连接", "Unreachable")
}
