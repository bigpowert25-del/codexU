import SwiftUI

struct ProjectWorkspacePanel: View {
    let taskBoard: TaskBoard?
    let usageBoard: ProjectBoard?
    let language: WidgetLanguage

    @EnvironmentObject private var envelopeStore: AgentTaskEnvelopeStore
    @State private var selectedProjectID: String?

    private var workspaces: [AgentProjectWorkspace] {
        AgentProjectWorkspaceBuilder.make(
            taskBoard: taskBoard,
            envelopes: envelopeStore.envelopes
        )
    }

    private var selectedWorkspace: AgentProjectWorkspace? {
        workspaces.first { $0.id == selectedProjectID } ?? workspaces.first
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            projectSidebar
                .frame(width: 220)
            projectDetail
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minHeight: 300, alignment: .topLeading)
        .onAppear {
            selectFirstProjectIfNeeded()
        }
        .onChange(of: workspaces.map(\.id)) { _, _ in
            selectFirstProjectIfNeeded()
        }
    }

    private var projectSidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    language.text("项目", "Projects"),
                    systemImage: "folder.fill"
                )
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                Spacer()
                Text("\(workspaces.count)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if workspaces.isEmpty {
                ProjectWorkspaceEmptyState(
                    title: language.text("暂无项目", "No projects"),
                    detail: language.text(
                        "任务出现后会按项目自动归类。",
                        "Tasks are grouped into projects when they appear."
                    )
                )
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 6) {
                        ForEach(workspaces) { workspace in
                            Button {
                                selectedProjectID = workspace.id
                            } label: {
                                ProjectWorkspaceSidebarRow(
                                    workspace: workspace,
                                    isSelected: selectedWorkspace?.id == workspace.id,
                                    language: language
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: projectPanelCornerRadius, style: .continuous)
                .fill(WidgetPalette.surfaceTrack.opacity(0.46))
        )
    }

    @ViewBuilder
    private var projectDetail: some View {
        if let workspace = selectedWorkspace {
            ProjectWorkspaceDetail(
                workspace: workspace,
                usage: usageForWorkspace(workspace),
                language: language
            )
        } else {
            ProjectWorkspaceEmptyState(
                title: language.text("选择项目", "Select a project"),
                detail: language.text(
                    "从左侧选择一个项目查看跨 Agent 任务。",
                    "Choose a project to inspect its cross-Agent tasks."
                )
            )
            .frame(maxWidth: .infinity, minHeight: 300)
        }
    }

    private func selectFirstProjectIfNeeded() {
        guard !workspaces.isEmpty else {
            selectedProjectID = nil
            return
        }
        if !workspaces.contains(where: { $0.id == selectedProjectID }) {
            selectedProjectID = workspaces.first?.id
        }
    }

    private func usageForWorkspace(
        _ workspace: AgentProjectWorkspace
    ) -> ProjectUsage? {
        let candidates = (usageBoard?.recentProjects ?? [])
            + (usageBoard?.allProjects ?? [])
        return candidates.first {
            $0.name.localizedCaseInsensitiveCompare(workspace.identity.name)
                == .orderedSame
        }
    }
}

private struct ProjectWorkspaceSidebarRow: View {
    let workspace: AgentProjectWorkspace
    let isSelected: Bool
    let language: WidgetLanguage
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isSelected ? WidgetPalette.brandSecondary : .secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 3) {
                Text(workspace.identity.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text(language.text(
                    "\(workspace.tasks.count) 任务 · \(workspace.envelopes.count) 交接",
                    "\(workspace.tasks.count) tasks · \(workspace.envelopes.count) handoffs"
                ))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: projectRowCornerRadius, style: .continuous)
                .fill(isSelected
                    ? WidgetPalette.controlSelectedFill(colorScheme)
                    : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

private struct ProjectWorkspaceDetail: View {
    let workspace: AgentProjectWorkspace
    let usage: ProjectUsage?
    let language: WidgetLanguage
    @EnvironmentObject private var nodeStore: AgentNodeStore
    @EnvironmentObject private var identityStore: AgentIdentityProfileStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workspace.identity.name)
                        .font(.system(size: 14, weight: .semibold))
                    HStack(spacing: 5) {
                        ForEach(workspace.runtimes) { runtime in
                            TaskSourceBadge(source: runtime)
                        }
                    }
                }
                Spacer(minLength: 8)
                if let usage {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(TokenFormatter.format(usage.tokens))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text(language.text("本机上下文", "Local context"))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            HStack(spacing: 6) {
                ProjectWorkspaceMetric(
                    title: language.text("进行中", "Active"),
                    value: "\(workspace.tasks.filter { $0.kind == .active }.count)"
                )
                ProjectWorkspaceMetric(
                    title: language.text("完成", "Done"),
                    value: "\(workspace.tasks.filter { $0.kind == .done }.count)"
                )
                ProjectWorkspaceMetric(
                    title: "Agent",
                    value: "\(workspace.runtimes.count)"
                )
                ProjectWorkspaceMetric(
                    title: language.text("交接", "Handoffs"),
                    value: "\(workspace.envelopes.count)"
                )
            }

            if workspace.tasks.isEmpty {
                ProjectWorkspaceEmptyState(
                    title: language.text("暂无活动任务", "No active tasks"),
                    detail: language.text(
                        "这个项目目前只有本地交接草稿。",
                        "This project currently contains local handoff drafts only."
                    )
                )
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 7) {
                        ForEach(workspace.tasks) { task in
                            ProjectWorkspaceTaskRow(item: task, language: language)
                        }
                    }
                }
                .frame(maxHeight: 206)
            }

            if !workspace.envelopes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(language.text("本地交接", "Local handoffs"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(workspace.envelopes.prefix(3)) { envelope in
                        ProjectHandoffOverviewRow(
                            envelope: envelope,
                            target: nodeStore.snapshots.first {
                                $0.id == envelope.targetNodeID
                            },
                            identityStore: identityStore,
                            language: language
                        )
                    }
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: projectPanelCornerRadius, style: .continuous)
                .fill(WidgetPalette.surfaceTrack.opacity(0.28))
        )
    }
}

private struct ProjectWorkspaceMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: projectRowCornerRadius, style: .continuous)
                .fill(WidgetPalette.surfaceTrack.opacity(0.48))
        )
    }
}

private struct ProjectHandoffOverviewRow: View {
    let envelope: AgentTaskEnvelope
    let target: AgentNodeSnapshot?
    @ObservedObject var identityStore: AgentIdentityProfileStore
    let language: WidgetLanguage

    private var identity: AgentIdentityPresentation? {
        guard let target else { return nil }
        return AgentIdentityPresentation.make(
            profile: identityStore.profile(
                nodeID: target.id,
                runtime: target.descriptor.runtime,
                now: envelope.updatedAt
            ),
            language: language
        )
    }

    var body: some View {
        HStack(spacing: 7) {
            RuntimeLogoView(scope: envelope.targetRuntime, size: 17)
            VStack(alignment: .leading, spacing: 2) {
                Text(envelope.title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                Text(targetSummary)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 5)
            VStack(alignment: .trailing, spacing: 2) {
                Text(stateText)
                    .font(.system(size: 9, weight: .semibold))
                Text(language.text("仅本机 · 未投递", "Local only · Not delivered"))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: projectRowCornerRadius, style: .continuous)
                .fill(WidgetPalette.surfaceTrack.opacity(0.55))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                [
                    envelope.title,
                    targetSummary,
                    stateText,
                    language.text("仅保存在本机，尚未投递", "Stored locally, not delivered")
                ]
                .joined(separator: "，")
                .prefix(260)
            )
        )
    }

    private var targetSummary: String {
        guard let target else {
            return language.text(
                "\(envelope.targetRuntime.displayName) · 节点不可用",
                "\(envelope.targetRuntime.displayName) · Node unavailable"
            )
        }
        guard let identity else { return target.descriptor.displayName }
        return "\(target.descriptor.displayName) · \(identity.roleName) · \(identity.policyCode)"
    }

    private var stateText: String {
        switch envelope.state {
        case .draft:
            return language.text("草稿", "Draft")
        case .ready:
            return language.text("本机就绪", "Locally ready")
        }
    }
}

private struct ProjectWorkspaceTaskRow: View {
    let item: TaskItem
    let language: WidgetLanguage
    @State private var isShowingDetail = false

    var body: some View {
        Button {
            isShowingDetail = true
        } label: {
            HStack(spacing: 8) {
                RuntimeLogoView(scope: item.source, size: 18)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Text(item.code)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                TaskChip(text: item.chip, kind: item.kind)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .cardBackground(cornerRadius: projectRowCornerRadius, elevated: true)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isShowingDetail) {
            TaskDetailView(item: item, language: language)
        }
    }
}

private let projectPanelCornerRadius: CGFloat = 10
private let projectRowCornerRadius: CGFloat = 8

private struct ProjectWorkspaceEmptyState: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
            Text(detail)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }
}
