import Combine
import CoreGraphics

enum DynamicIslandMouseButtonEvent {
    case leftDown
    case rightDown
    case leftUp
    case rightUp
}

struct DynamicIslandComboDragGate: Equatable {
    private var isLeftDown = false
    private var isRightDown = false

    var isReady: Bool { isLeftDown && isRightDown }

    mutating func apply(_ event: DynamicIslandMouseButtonEvent) -> Bool {
        switch event {
        case .leftDown:
            isLeftDown = true
        case .rightDown:
            isRightDown = true
        case .leftUp:
            isLeftDown = false
        case .rightUp:
            isRightDown = false
        }
        return isReady
    }
}

enum DynamicIslandDock: String, Equatable {
    case top
    case left
    case right

    var isVertical: Bool {
        switch self {
        case .top:
            return false
        case .left, .right:
            return true
        }
    }
}

@MainActor
final class DynamicIslandPlacementModel: ObservableObject {
    @Published var dock: DynamicIslandDock

    init(dock: DynamicIslandDock) {
        self.dock = dock
    }
}

enum DynamicIslandDockResolver {
    static let edgeMargin: CGFloat = 10

    static func nearestDock(
        proposedCenter: CGPoint,
        screenFrame: CGRect
    ) -> DynamicIslandDock {
        let distances: [(DynamicIslandDock, CGFloat)] = [
            (.top, screenFrame.maxY - proposedCenter.y),
            (.left, proposedCenter.x - screenFrame.minX),
            (.right, screenFrame.maxX - proposedCenter.x)
        ]
        return distances.min { lhs, rhs in
            lhs.1 < rhs.1
        }?.0 ?? .top
    }

    static func windowRect(
        for mode: DynamicIslandMode,
        dock: DynamicIslandDock,
        screenFrame: CGRect,
        sideCenterY: CGFloat?
    ) -> CGRect {
        let size = mode.size(for: dock)
        switch dock {
        case .top:
            return CGRect(
                x: screenFrame.midX - size.width / 2,
                y: screenFrame.maxY - size.height - edgeMargin,
                width: size.width,
                height: size.height
            )
        case .left:
            return CGRect(
                x: screenFrame.minX + edgeMargin,
                y: clampedSideY(size: size, screenFrame: screenFrame, sideCenterY: sideCenterY),
                width: size.width,
                height: size.height
            )
        case .right:
            return CGRect(
                x: screenFrame.maxX - edgeMargin - size.width,
                y: clampedSideY(size: size, screenFrame: screenFrame, sideCenterY: sideCenterY),
                width: size.width,
                height: size.height
            )
        }
    }

    static func clampedSideCenterY(
        _ proposedCenterY: CGFloat,
        size: CGSize,
        screenFrame: CGRect
    ) -> CGFloat {
        let minimum = screenFrame.minY + edgeMargin + size.height / 2
        let maximum = screenFrame.maxY - edgeMargin - size.height / 2
        guard minimum <= maximum else { return screenFrame.midY }
        return min(max(proposedCenterY, minimum), maximum)
    }

    private static func clampedSideY(
        size: CGSize,
        screenFrame: CGRect,
        sideCenterY: CGFloat?
    ) -> CGFloat {
        let centerY = clampedSideCenterY(
            sideCenterY ?? screenFrame.midY,
            size: size,
            screenFrame: screenFrame
        )
        return centerY - size.height / 2
    }
}
