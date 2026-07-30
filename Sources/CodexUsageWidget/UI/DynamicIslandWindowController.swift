import AppKit
import SwiftUI

@MainActor
final class DynamicIslandWindowController: NSWindowController {
    private struct ComboDragState {
        let startMouseLocation: NSPoint
        let startFrame: NSRect
    }

    private static let dockDefaultsKey = "dynamicIslandDock"
    private static let sideCenterYDefaultsKey = "dynamicIslandSideCenterY"

    private let systemMonitor: LocalSystemMonitor
    private let placement: DynamicIslandPlacementModel
    private var mode: DynamicIslandMode = .compact
    private var sideCenterY: CGFloat
    private var comboDragGate = DynamicIslandComboDragGate()
    private var comboDragState: ComboDragState?
    private var localMouseEventMonitor: Any?
    private var globalMouseEventMonitor: Any?

    init(
        store: UsageStore,
        settings: AppSettings,
        systemMonitor: LocalSystemMonitor,
        openMainWindow: @escaping () -> Void
    ) {
        self.systemMonitor = systemMonitor
        let initialDock = Self.loadDock()
        self.placement = DynamicIslandPlacementModel(dock: initialDock)
        let screenFrame = Self.currentScreenFrame()
        self.sideCenterY = Self.loadSideCenterY(screenFrame: screenFrame)

        let panel = NSPanel(
            contentRect: DynamicIslandDockResolver.windowRect(
                for: .compact,
                dock: initialDock,
                screenFrame: screenFrame,
                sideCenterY: sideCenterY
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle
        ]

        super.init(window: panel)

        panel.contentView = NSHostingView(
            rootView: DynamicIslandView(
                store: store,
                settings: settings,
                systemMonitor: systemMonitor,
                placement: placement,
                onModeChange: { [weak self] mode in
                    self?.setMode(mode)
                },
                onOpenMainWindow: openMainWindow
            )
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        systemMonitor.start()
        installMouseEventMonitor()
        setMode(mode, animated: false)
        window?.orderFrontRegardless()
    }

    func stop() {
        systemMonitor.stop()
        removeMouseEventMonitor()
        close()
    }

    private func setMode(_ newMode: DynamicIslandMode, animated _: Bool = true) {
        guard let window else { return }
        let targetFrame = DynamicIslandDockResolver.windowRect(
            for: newMode,
            dock: placement.dock,
            screenFrame: Self.currentScreenFrame(),
            sideCenterY: sideCenterY
        )
        guard mode != newMode || !window.frame.equalTo(targetFrame) else { return }

        mode = newMode
        window.setFrame(targetFrame, display: true)
    }

    private func installMouseEventMonitor() {
        guard localMouseEventMonitor == nil, globalMouseEventMonitor == nil else { return }
        let mask = Self.comboMouseEventMask
        localMouseEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: mask
        ) { [weak self] event in
            self?.handleMouseEvent(event, canConsume: true) ?? event
        }
        globalMouseEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: mask
        ) { [weak self] event in
            _ = self?.handleMouseEvent(event, canConsume: false)
        }
    }

    private func removeMouseEventMonitor() {
        if let localMouseEventMonitor {
            NSEvent.removeMonitor(localMouseEventMonitor)
        }
        if let globalMouseEventMonitor {
            NSEvent.removeMonitor(globalMouseEventMonitor)
        }
        localMouseEventMonitor = nil
        globalMouseEventMonitor = nil
    }

    private func handleMouseEvent(_ event: NSEvent, canConsume: Bool) -> NSEvent? {
        guard let window else { return event }
        let wasReady = comboDragGate.isReady
        if let buttonEvent = Self.comboButtonEvent(from: event.type) {
            _ = comboDragGate.apply(buttonEvent)
        }
        let isReady = comboDragGate.isReady

        if isReady {
            let mouseLocation = NSEvent.mouseLocation
            if comboDragState == nil {
                guard window.frame.contains(mouseLocation) else { return event }
                comboDragState = ComboDragState(
                    startMouseLocation: mouseLocation,
                    startFrame: window.frame
                )
            }

            if let comboDragState {
                let deltaX = mouseLocation.x - comboDragState.startMouseLocation.x
                let deltaY = mouseLocation.y - comboDragState.startMouseLocation.y
                window.setFrame(
                    comboDragState.startFrame.offsetBy(dx: deltaX, dy: deltaY),
                    display: true
                )
            }
            return canConsume ? nil : event
        }

        if wasReady || comboDragState != nil {
            finishComboDrag()
            return canConsume ? nil : event
        }

        return event
    }

    private static var comboMouseEventMask: NSEvent.EventTypeMask {
        [
            .leftMouseDown,
            .rightMouseDown,
            .leftMouseDragged,
            .rightMouseDragged,
            .leftMouseUp,
            .rightMouseUp
        ]
    }

    private static func comboButtonEvent(from eventType: NSEvent.EventType) -> DynamicIslandMouseButtonEvent? {
        switch eventType {
        case .leftMouseDown:
            return .leftDown
        case .rightMouseDown:
            return .rightDown
        case .leftMouseUp:
            return .leftUp
        case .rightMouseUp:
            return .rightUp
        default:
            return nil
        }
    }

    private func finishComboDrag() {
        guard let window else { return }
        comboDragState = nil
        let screenFrame = Self.currentScreenFrame()
        let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
        let dock = DynamicIslandDockResolver.nearestDock(
            proposedCenter: center,
            screenFrame: screenFrame
        )

        if dock.isVertical {
            let size = mode.size(for: dock)
            sideCenterY = DynamicIslandDockResolver.clampedSideCenterY(
                center.y,
                size: size,
                screenFrame: screenFrame
            )
        }

        placement.dock = dock
        persistPlacement()
        window.setFrame(
            DynamicIslandDockResolver.windowRect(
                for: mode,
                dock: dock,
                screenFrame: screenFrame,
                sideCenterY: sideCenterY
            ),
            display: true
        )
    }

    private func persistPlacement() {
        UserDefaults.standard.set(placement.dock.rawValue, forKey: Self.dockDefaultsKey)
        UserDefaults.standard.set(Double(sideCenterY), forKey: Self.sideCenterYDefaultsKey)
    }

    private static func loadDock() -> DynamicIslandDock {
        guard let rawValue = UserDefaults.standard.string(forKey: dockDefaultsKey),
              let dock = DynamicIslandDock(rawValue: rawValue) else {
            return .top
        }
        return dock
    }

    private static func loadSideCenterY(screenFrame: CGRect) -> CGFloat {
        let stored = UserDefaults.standard.double(forKey: sideCenterYDefaultsKey)
        guard stored > 0 else { return screenFrame.midY }
        return CGFloat(stored)
    }

    private static func currentScreenFrame() -> CGRect {
        NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }
}
