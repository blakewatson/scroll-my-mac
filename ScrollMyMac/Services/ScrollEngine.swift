import Cocoa
import Carbon.HIToolbox

/// Intercepts mouse events via CGEventTap and converts click-drag into
/// synthetic pixel-precision scroll wheel events.
///
/// Create once, then call `start()` / `stop()` to enable/disable the tap.
/// The tap is NOT destroyed on stop — it is simply disabled.
@Observable
class ScrollEngine {

    // MARK: - Public State

    /// Whether the engine is currently intercepting mouse events.
    private(set) var isActive: Bool = false

    /// When true, drag direction locks to a single axis after initial movement.
    /// When false, both axes scroll simultaneously (free scroll).
    var useAxisLock: Bool = true

    /// Called with cursor position (CG coordinates) during mouseDown and mouseDragged.
    /// Used by OverlayManager to track the dot to the cursor.
    var onDragPositionChanged: ((CGPoint) -> Void)?

    /// Returns true if clicks at the given CG point should pass through
    /// (not be intercepted). Used to allow clicks on the app's own windows.
    var shouldPassThroughClick: ((CGPoint) -> Bool)?

    /// Called when dragging starts (true) or ends (false).
    var onDragStateChanged: ((Bool) -> Void)?

    /// When true, clicks within the dead zone are replayed as normal clicks.
    /// When false, all clicks become scrolls (legacy behavior).
    var clickThroughEnabled: Bool = true

    // MARK: - Axis

    enum Axis {
        case horizontal
        case vertical
    }

    // MARK: - Private State

    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private(set) var isDragging: Bool = false
    private var passedThroughClick: Bool = false
    private var dragOrigin: CGPoint = .zero
    private var lastDragPoint: CGPoint = .zero
    private var lockedAxis: Axis?
    private var accumulatedDelta: CGPoint = .zero
    private var isFirstDragEvent: Bool = true

    private let axisLockThreshold: CGFloat = 5.0

    // Click-through state
    private var isReplayingClick: Bool = false
    private var pendingMouseDown: Bool = false
    private var pendingClickState: Int64 = 1
    private var pendingMouseDownLocation: CGPoint = .zero
    private var totalMovement: CGFloat = 0.0
    private let clickDeadZone: CGFloat = 8.0

    // MARK: - Lifecycle

    /// Creates the CGEventTap (if not already created) and enables it.
    func start() {
        guard eventTap == nil else {
            // Tap already exists — just re-enable.
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            isActive = true
            return
        }

        let eventMask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: scrollEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else {
            print("[ScrollEngine] ERROR: Failed to create CGEventTap. Check Accessibility permissions.")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(nil, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        isActive = true
    }

    /// Disables the event tap and resets drag state.
    /// The tap is NOT destroyed — call `start()` to re-enable.
    func stop() {
        // Post scroll-ended if a scroll was in progress, so apps see a clean end.
        if isDragging {
            postScrollEvent(wheel1: 0, wheel2: 0, phase: 4) // kCGScrollPhaseEnded
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        // Reset pending state without replaying (user intent is to toggle off, not click).
        pendingMouseDown = false
        totalMovement = 0.0
        resetDragState()
        isActive = false
    }

    /// Tears down the event tap completely. Call on app termination.
    func tearDown() {
        // Post scroll-ended if a scroll was in progress, so apps see a clean end.
        if isDragging {
            postScrollEvent(wheel1: 0, wheel2: 0, phase: 4) // kCGScrollPhaseEnded
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
        resetDragState()
        isActive = false
    }

    // MARK: - Mouse Event Handlers

    func handleMouseDown(event: CGEvent, proxy: CGEventTapProxy) -> Unmanaged<CGEvent>? {
        // Allow replayed clicks to pass through without interception.
        if isReplayingClick {
            return Unmanaged.passUnretained(event)
        }

        let location = event.location

        // Allow clicks on the app's own windows to pass through.
        if shouldPassThroughClick?(location) == true {
            passedThroughClick = true
            return Unmanaged.passUnretained(event)
        }

        // Modifier-key clicks always pass through immediately.
        let modifierMask: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
        if !event.flags.intersection(modifierMask).isEmpty {
            passedThroughClick = true
            return Unmanaged.passUnretained(event)
        }

        passedThroughClick = false

        if clickThroughEnabled {
            // Hold-and-decide: suppress click, wait to see if user drags.
            pendingMouseDown = true
            pendingMouseDownLocation = location
            pendingClickState = event.getIntegerValueField(.mouseEventClickState)
            totalMovement = 0.0
            dragOrigin = location
            lastDragPoint = location
            return nil // Suppress original event until we decide.
        } else {
            // Legacy behavior: all clicks become scroll starts.
            dragOrigin = location
            lastDragPoint = location
            isDragging = true
            lockedAxis = nil
            accumulatedDelta = .zero
            isFirstDragEvent = true
            onDragStateChanged?(true)
            return nil
        }
    }

    func handleMouseDragged(event: CGEvent, proxy: CGEventTapProxy) -> Unmanaged<CGEvent>? {
        if passedThroughClick {
            return Unmanaged.passUnretained(event)
        }

        // Handle pending click-through: check if user has moved beyond dead zone.
        if pendingMouseDown {
            let currentPoint = event.location
            totalMovement = hypot(currentPoint.x - pendingMouseDownLocation.x, currentPoint.y - pendingMouseDownLocation.y)
            if totalMovement > clickDeadZone {
                // Exceeded dead zone — transition to scroll mode.
                pendingMouseDown = false
                isDragging = true
                isFirstDragEvent = true
                lockedAxis = nil
                accumulatedDelta = .zero
                lastDragPoint = currentPoint
                onDragStateChanged?(true)
                // Fall through to process this drag event as the first scroll event.
            } else {
                return nil // Still in dead zone, suppress drag.
            }
        }

        guard isDragging else {
            return Unmanaged.passUnretained(event)
        }

        let currentPoint = event.location
        let deltaX = currentPoint.x - lastDragPoint.x
        let deltaY = currentPoint.y - lastDragPoint.y
        lastDragPoint = currentPoint
        onDragPositionChanged?(currentPoint)

        // Axis lock detection
        if useAxisLock && lockedAxis == nil {
            lockedAxis = detectAxis(deltaX: deltaX, deltaY: deltaY)
        }

        // Natural scroll direction: drag down = content moves down (like touching a phone).
        // Drag down = positive deltaY in CG coords. Positive wheel1 = content moves down.
        let scrollY = Int32(deltaY)
        let scrollX = Int32(deltaX)

        // Determine scroll phase
        let phase: Int64
        if isFirstDragEvent {
            phase = 1 // kCGScrollPhaseBegan
            isFirstDragEvent = false
        } else {
            phase = 2 // kCGScrollPhaseChanged
        }

        // Post synthetic scroll event based on axis lock state
        if useAxisLock, let axis = lockedAxis {
            switch axis {
            case .vertical:
                postScrollEvent(wheel1: scrollY, wheel2: 0, phase: phase)
            case .horizontal:
                postScrollEvent(wheel1: 0, wheel2: scrollX, phase: phase)
            }
        } else if !useAxisLock {
            // Free scroll: both axes
            postScrollEvent(wheel1: scrollY, wheel2: scrollX, phase: phase)
        } else {
            // Axis lock is on but not yet locked — still accumulating.
            // Post both axes during the detection period so movement isn't lost.
            postScrollEvent(wheel1: scrollY, wheel2: scrollX, phase: phase)
        }

        return nil // Suppress the original drag event.
    }

    func handleMouseUp(event: CGEvent, proxy: CGEventTapProxy) -> Unmanaged<CGEvent>? {
        // Allow replayed clicks to pass through without interception.
        if isReplayingClick {
            return Unmanaged.passUnretained(event)
        }

        if passedThroughClick {
            passedThroughClick = false
            return Unmanaged.passUnretained(event)
        }

        // Pending click within dead zone — replay as normal click.
        if pendingMouseDown {
            pendingMouseDown = false
            replayClick(at: pendingMouseDownLocation, clickState: pendingClickState)
            return nil // Suppress original mouseUp; synthetic pair was posted.
        }

        if isDragging {
            // Post scroll ended event with zero deltas.
            postScrollEvent(wheel1: 0, wheel2: 0, phase: 4) // kCGScrollPhaseEnded
        }
        onDragStateChanged?(false)
        resetDragState()
        return nil // Suppress the mouse up while in scroll mode.
    }

    // MARK: - Private Helpers

    private func detectAxis(deltaX: CGFloat, deltaY: CGFloat) -> Axis? {
        accumulatedDelta.x += abs(deltaX)
        accumulatedDelta.y += abs(deltaY)

        let total = accumulatedDelta.x + accumulatedDelta.y
        guard total >= axisLockThreshold else { return nil }

        return accumulatedDelta.y >= accumulatedDelta.x ? .vertical : .horizontal
    }

    private func postScrollEvent(wheel1: Int32, wheel2: Int32, phase: Int64) {
        let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 3,
            wheel1: wheel1,
            wheel2: wheel2,
            wheel3: 0
        )

        guard let scrollEvent else { return }

        scrollEvent.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase)
        scrollEvent.post(tap: .cgSessionEventTap)
    }

    private func replayClick(at position: CGPoint, clickState: Int64) {
        isReplayingClick = true

        let source = CGEventSource(stateID: .hidSystemState)

        guard let down = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseDown,
            mouseCursorPosition: position,
            mouseButton: .left
        ), let up = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseUp,
            mouseCursorPosition: position,
            mouseButton: .left
        ) else {
            isReplayingClick = false
            return
        }

        down.setIntegerValueField(.mouseEventClickState, value: clickState)
        up.setIntegerValueField(.mouseEventClickState, value: clickState)

        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)

        isReplayingClick = false
    }

    private func resetDragState() {
        isDragging = false
        pendingMouseDown = false
        totalMovement = 0.0
        lockedAxis = nil
        accumulatedDelta = .zero
        isFirstDragEvent = true
    }
}

// MARK: - C Callback Bridge

/// File-level function required by CGEventTap (C function pointer).
private func scrollEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    // Handle tap disabled by timeout — re-enable if we still have permission.
    if type == .tapDisabledByTimeout {
        if let userInfo {
            let engine = Unmanaged<ScrollEngine>.fromOpaque(userInfo).takeUnretainedValue()
            // Only re-enable if we still have Accessibility permission.
            if AXIsProcessTrusted(), let tap = engine.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let engine = Unmanaged<ScrollEngine>.fromOpaque(userInfo).takeUnretainedValue()

    switch type {
    case .leftMouseDown:
        return engine.handleMouseDown(event: event, proxy: proxy)
    case .leftMouseDragged:
        return engine.handleMouseDragged(event: event, proxy: proxy)
    case .leftMouseUp:
        return engine.handleMouseUp(event: event, proxy: proxy)
    default:
        return Unmanaged.passUnretained(event)
    }
}
