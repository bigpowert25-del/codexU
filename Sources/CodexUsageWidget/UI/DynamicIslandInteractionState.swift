import Foundation

struct DynamicIslandHoverSchedule: Equatable {
    let token: Int
    let delaySeconds: TimeInterval
}

struct DynamicIslandInteractionState: Equatable {
    static let hoverEnterDelaySeconds: TimeInterval = 0.18
    static let hoverExitDelaySeconds: TimeInterval = 0.36

    private(set) var mode: DynamicIslandMode = .compact
    private(set) var isPinnedExpanded = false

    private var pendingHoverMode: DynamicIslandMode?
    private var pendingHoverToken = 0

    mutating func hoverChanged(_ hovering: Bool) -> DynamicIslandHoverSchedule? {
        guard !isPinnedExpanded else {
            cancelPendingHover()
            return nil
        }

        let targetMode: DynamicIslandMode = hovering ? .peek : .compact
        guard targetMode != mode else {
            cancelPendingHover()
            return nil
        }

        pendingHoverToken += 1
        pendingHoverMode = targetMode
        return DynamicIslandHoverSchedule(
            token: pendingHoverToken,
            delaySeconds: hovering ? Self.hoverEnterDelaySeconds : Self.hoverExitDelaySeconds
        )
    }

    mutating func applyPendingHover(token: Int) -> Bool {
        guard token == pendingHoverToken,
              let targetMode = pendingHoverMode,
              !isPinnedExpanded else {
            return false
        }

        pendingHoverMode = nil
        guard mode != targetMode else { return false }
        mode = targetMode
        return true
    }

    mutating func toggleExpanded() -> Bool {
        cancelPendingHover()
        isPinnedExpanded.toggle()
        let targetMode: DynamicIslandMode = isPinnedExpanded ? .expanded : .peek
        guard mode != targetMode else { return false }
        mode = targetMode
        return true
    }

    mutating func closeExpanded() -> Bool {
        cancelPendingHover()
        isPinnedExpanded = false
        guard mode != .compact else { return false }
        mode = .compact
        return true
    }

    private mutating func cancelPendingHover() {
        pendingHoverToken += 1
        pendingHoverMode = nil
    }
}
