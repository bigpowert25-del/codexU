import Foundation

enum AgentTaskEnvelopeState: String, CaseIterable, Codable, Equatable, Identifiable {
    case draft
    case ready

    var id: String { rawValue }
}

struct AgentTaskEnvelope: Identifiable, Codable, Equatable {
    static let maximumIdentifierLength = 96
    static let maximumProjectNameLength = 64
    static let maximumTitleLength = 160
    static let maximumNoteLength = 400
    static let maximumNoteLines = 8
    static let workbenchInboxProjectID = "godexu-inbox"

    let id: UUID
    let originNodeID: String
    let revision: Int
    let sourceTaskID: String
    let sourceRuntime: RuntimeScope
    let projectID: String
    let projectName: String
    let title: String
    let targetNodeID: String
    let targetRuntime: RuntimeScope
    let handoffNote: String
    let state: AgentTaskEnvelopeState
    let createdAt: Date
    let updatedAt: Date

    static func sanitized(
        id: UUID,
        originNodeID: String,
        revision: Int,
        sourceTaskID: String,
        sourceRuntime: RuntimeScope,
        projectID: String,
        projectName: String,
        title: String,
        targetNodeID: String,
        targetRuntime: RuntimeScope,
        handoffNote: String,
        state: AgentTaskEnvelopeState,
        createdAt: Date,
        updatedAt: Date
    ) -> AgentTaskEnvelope? {
        guard revision >= 1,
              updatedAt >= createdAt,
              isSafeIdentifier(originNodeID),
              isSafeIdentifier(sourceTaskID),
              isSafeIdentifier(projectID),
              isSafeIdentifier(targetNodeID)
        else {
            return nil
        }
        let normalizedProjectName = normalizedSingleLine(projectName)
        let normalizedTitle = normalizedSingleLine(title)
        guard !normalizedProjectName.isEmpty, !normalizedTitle.isEmpty else {
            return nil
        }
        return AgentTaskEnvelope(
            id: id,
            originNodeID: originNodeID,
            revision: revision,
            sourceTaskID: sourceTaskID,
            sourceRuntime: sourceRuntime,
            projectID: projectID,
            projectName: String(
                normalizedProjectName.prefix(maximumProjectNameLength)
            ),
            title: String(normalizedTitle.prefix(maximumTitleLength)),
            targetNodeID: targetNodeID,
            targetRuntime: targetRuntime,
            handoffNote: normalizedNote(handoffNote),
            state: state,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    static func localWorkbenchDraft(
        id: UUID,
        originNodeID: String,
        title: String,
        targetNodeID: String,
        targetRuntime: RuntimeScope,
        now: Date
    ) -> AgentTaskEnvelope? {
        sanitized(
            id: id,
            originNodeID: originNodeID,
            revision: 1,
            sourceTaskID: "godexu-draft:\(id.uuidString.lowercased())",
            sourceRuntime: .codex,
            projectID: workbenchInboxProjectID,
            projectName: "GodexU Inbox",
            title: title,
            targetNodeID: targetNodeID,
            targetRuntime: targetRuntime,
            handoffNote: "",
            state: .draft,
            createdAt: now,
            updatedAt: now
        )
    }

    static func isValidStoredEnvelope(_ envelope: AgentTaskEnvelope) -> Bool {
        guard let normalized = sanitized(
            id: envelope.id,
            originNodeID: envelope.originNodeID,
            revision: envelope.revision,
            sourceTaskID: envelope.sourceTaskID,
            sourceRuntime: envelope.sourceRuntime,
            projectID: envelope.projectID,
            projectName: envelope.projectName,
            title: envelope.title,
            targetNodeID: envelope.targetNodeID,
            targetRuntime: envelope.targetRuntime,
            handoffNote: envelope.handoffNote,
            state: envelope.state,
            createdAt: envelope.createdAt,
            updatedAt: envelope.updatedAt
        ) else {
            return false
        }
        return normalized == envelope
    }

    private static func isSafeIdentifier(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= maximumIdentifierLength else {
            return false
        }
        let allowed = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: "._:-")
        )
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func normalizedSingleLine(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func normalizedNote(_ value: String) -> String {
        let lines = value
            .components(separatedBy: .newlines)
            .map { normalizedSingleLine($0) }
            .filter { !$0.isEmpty }
            .prefix(maximumNoteLines)
        return String(lines.joined(separator: "\n").prefix(maximumNoteLength))
    }
}
