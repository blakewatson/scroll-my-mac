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

    // MARK: - Axis

    enum Axis {
        case horizontal
        case vertical
    }

    // MARK: - Private State

    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var isDragging: Bool = false
    private var dragOrigin: CGPoint = .zero
    private var lastDragPoint: CGPoint = .zero
    private var lockedAxis: Axis?
    private var accumulatedDelta: CGPoint = .zero
    private var isFirstDragEvent: Bool = true

    private let axisLockThreshold: CGFloat = 5.0

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
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        resetDragState()
        isActive = false
    }

    /// Tears down the event tap completely. Call on app termination.
    func tearDown() {
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
        let location = event.location
        dragOrigin = location
        lastDragPoint = location
        isDragging = true
        lockedAxis = nil
        accumulatedDelta = .zero
        isFirstDragEvent = true
        return nil // Suppress the click while in scroll mode.
    }

    func handleMouseDragged(event: CGEvent, proxy: CGEventTapProxy) -> Unmanaged<CGEvent>? {
        guard isDragging else {
            return Unmanaged.passUnretained(event)
        }

        let currentPoint = event.location
        let deltaX = currentPoint.x - lastDragPoint.x
        let deltaY = currentPoint.y - lastDragPoint.y
        lastDragPoint = currentPoint

        // Axis lock detection
        if useAxisLock && lockedAxis == nil {
            lockedAxis = detectAxis(deltaX: deltaX, deltaY: deltaY)
        }

        // Natural scroll direction: drag down (positive deltaY) = content moves down
        // In CG scroll space, positive wheel1 = scroll up, so negate.
        let scrollY = Int32(-deltaY)
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
        if isDragging {
            // Post scroll ended event with zero deltas.
            postScrollEvent(wheel1: 0, wheel2: 0, phase: 4) // kCGScrollPhaseEnded
        }
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

    private func resetDragState() {
        isDragging = false
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

    // Handle tap disabled by timeout — re-enable.
    if type == .tapDisabledByTimeout {
        if let userInfo {
            let engine = Unmanaged<ScrollEngine>.fromOpaque(userInfo).takeUnretainedValue()
            if let tap = engine.eventTap {
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
