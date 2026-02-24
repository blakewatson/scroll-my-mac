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

    /// Called with cursor position (CG coordinates) during mouseDown and mouseDragged.
    /// Used by OverlayManager to track the dot to the cursor.
    var onDragPositionChanged: ((CGPoint) -> Void)?

    /// Returns true if clicks at the given CG point should pass through
    /// (not be intercepted). Used to allow clicks on the app's own windows.
    var shouldPassThroughClick: ((CGPoint) -> Bool)?

    /// Called when dragging starts (true) or ends (false).
    var onDragStateChanged: ((Bool) -> Void)?

    /// When this returns true, ALL mouse events pass through unmodified.
    /// Used by per-app exclusion to completely bypass scroll mode.
    var shouldBypassAllEvents: (() -> Bool)?

    /// When true, clicks within the dead zone are replayed as normal clicks.
    /// When false, all clicks become scrolls (legacy behavior).
    var clickThroughEnabled: Bool = true

    /// When true, holding still in the dead zone for `holdToPassthroughDelay`
    /// seconds replays the click and enters passthrough mode for normal drags.
    var holdToPassthroughEnabled: Bool = false

    /// How long (seconds) to hold still before passthrough activates.
    var holdToPassthroughDelay: TimeInterval = 1.0

    /// When false, releasing a drag produces no coasting — scrolling stops immediately.
    var isInertiaEnabled: Bool = true

    /// Controls inertia coasting speed and duration (0.0 = gentle, 0.5 = default, 1.0 = iOS-like flick).
    var inertiaIntensity: Double = 0.5

    /// When true, scroll direction is inverted (drag down = content moves down, classic scroll bar style).
    /// Default is false (natural: drag down = content moves up, like a touchscreen).
    var isScrollDirectionInverted: Bool = false

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

    // Inertia state
    private var velocityTracker = VelocityTracker()
    private let inertiaAnimator = InertiaAnimator()

    // Click-through state
    private static let replayMarker: Int64 = 0x534D4D // "SMM" — tags synthetic click events
    private var pendingMouseDown: Bool = false
    private var pendingClickState: Int64 = 1
    private var pendingMouseDownLocation: CGPoint = .zero
    private var totalMovement: CGFloat = 0.0
    private let clickDeadZone: CGFloat = 8.0

    // Hold-to-passthrough state
    private var holdTimer: DispatchSourceTimer?
    private var isInPassthroughMode: Bool = false

    // MARK: - Lifecycle

    /// Creates the CGEventTap (if not already created) and enables it.
    func start() {
        // Wire up momentum scroll callback (idempotent).
        inertiaAnimator.onMomentumScroll = { [weak self] wheel1, wheel2, momentumPhase in
            self?.postMomentumScrollEvent(wheel1: wheel1, wheel2: wheel2, momentumPhase: momentumPhase)
        }

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
        // Stop any inertia animation immediately (F6 toggle-off kills inertia).
        inertiaAnimator.stopCoasting()

        // Post scroll-ended if a scroll was in progress, so apps see a clean end.
        if isDragging {
            postScrollEvent(wheel1: 0, wheel2: 0, phase: 4) // kCGScrollPhaseEnded
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        // Reset pending state without replaying (user intent is to toggle off, not click).
        cancelHoldTimer()
        isInPassthroughMode = false
        pendingMouseDown = false
        totalMovement = 0.0
        resetDragState()
        isActive = false
    }

    /// Tears down the event tap completely. Call on app termination.
    func tearDown() {
        // Stop any inertia animation immediately.
        inertiaAnimator.stopCoasting()

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
        // Click during inertia: stop coasting and continue processing the
        // mouseDown normally so the user can immediately start a new scroll
        // (or click through) without needing a second click.
        if inertiaAnimator.isCoasting {
            inertiaAnimator.stopCoasting()
        }

        // Allow replayed clicks to pass through without interception.
        if event.getIntegerValueField(.eventSourceUserData) == ScrollEngine.replayMarker {
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

            // Start hold-to-passthrough timer if enabled and this is a primary click.
            if holdToPassthroughEnabled && event.getIntegerValueField(.mouseEventButtonNumber) == 0 {
                let timer = DispatchSource.makeTimerSource(queue: .main)
                timer.schedule(deadline: .now() + holdToPassthroughDelay)
                timer.setEventHandler { [weak self] in
                    guard let self else { return }
                    self.cancelHoldTimer()
                    self.isInPassthroughMode = true
                    self.pendingMouseDown = false
                    self.replayMouseDown(at: self.pendingMouseDownLocation, clickState: self.pendingClickState)
                }
                timer.resume()
                holdTimer = timer
            }

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

        // In passthrough mode, let drags through unmodified.
        if isInPassthroughMode {
            return Unmanaged.passUnretained(event)
        }

        // Handle pending click-through: check if user has moved beyond dead zone.
        if pendingMouseDown {
            let currentPoint = event.location
            totalMovement = hypot(currentPoint.x - pendingMouseDownLocation.x, currentPoint.y - pendingMouseDownLocation.y)
            if totalMovement > clickDeadZone {
                // Exceeded dead zone — cancel hold timer, transition to scroll mode.
                cancelHoldTimer()
                pendingMouseDown = false
                isDragging = true
                isFirstDragEvent = true
                lockedAxis = nil
                accumulatedDelta = .zero
                lastDragPoint = currentPoint
                onDragStateChanged?(true)
                // Return nil for THIS event — the next mouseDragged will be the
                // first scroll event with a real delta. Falling through here would
                // post a kCGScrollPhaseBegan with zero deltas (lastDragPoint ==
                // currentPoint), which causes WKWebView-based apps (e.g. MarkEdit)
                // to ignore the entire scroll sequence.
                return nil
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

        // Track raw velocity (before axis lock) for inertia on release.
        velocityTracker.addSample(deltaX: deltaX, deltaY: deltaY)

        // Axis lock detection
        if lockedAxis == nil {
            lockedAxis = detectAxis(deltaX: deltaX, deltaY: deltaY)
        }

        // Natural scroll direction: drag down = content moves down (like touching a phone).
        // Drag down = positive deltaY in CG coords. Positive wheel1 = content moves down.
        // When inverted, negate both axes so drag down = content moves up (classic scroll bar).
        let directionMultiplier: CGFloat = isScrollDirectionInverted ? -1.0 : 1.0
        let scrollY = Int32(deltaY * directionMultiplier)
        let scrollX = Int32(deltaX * directionMultiplier)

        // Determine scroll phase
        let phase: Int64
        if isFirstDragEvent {
            phase = 1 // kCGScrollPhaseBegan
            isFirstDragEvent = false
        } else {
            phase = 2 // kCGScrollPhaseChanged
        }

        // Post synthetic scroll event on the locked axis
        if let axis = lockedAxis {
            switch axis {
            case .vertical:
                postScrollEvent(wheel1: scrollY, wheel2: 0, phase: phase)
            case .horizontal:
                postScrollEvent(wheel1: 0, wheel2: scrollX, phase: phase)
            }
        } else {
            // Not yet locked — still accumulating. Post both axes so movement isn't lost.
            postScrollEvent(wheel1: scrollY, wheel2: scrollX, phase: phase)
        }

        return nil // Suppress the original drag event.
    }

    func handleMouseUp(event: CGEvent, proxy: CGEventTapProxy) -> Unmanaged<CGEvent>? {
        // Allow replayed clicks to pass through without interception.
        if event.getIntegerValueField(.eventSourceUserData) == ScrollEngine.replayMarker {
            return Unmanaged.passUnretained(event)
        }

        if passedThroughClick {
            passedThroughClick = false
            return Unmanaged.passUnretained(event)
        }

        // No tracked interaction state — engine never saw the corresponding mouseDown
        // (e.g., race between excluded-app bypass and NSWorkspace notification).
        // Pass through to avoid orphaning the mouseUp in the window server.
        if !pendingMouseDown && !isDragging && !isInPassthroughMode {
            passedThroughClick = false
            return Unmanaged.passUnretained(event)
        }

        // End passthrough mode on mouseUp — no inertia.
        // Post a synthetic mouseUp at .cghidEventTap to match the synthetic
        // mouseDown we posted, so the window server properly pairs them.
        if isInPassthroughMode {
            isInPassthroughMode = false
            cancelHoldTimer()
            replayMouseUp(at: event.location, clickState: pendingClickState)
            return nil // Suppress real mouseUp; synthetic one was posted.
        }

        // Pending click within dead zone — replay as normal click.
        if pendingMouseDown {
            cancelHoldTimer()
            pendingMouseDown = false
            replayClick(at: pendingMouseDownLocation, clickState: pendingClickState)
            return nil // Suppress original mouseUp; synthetic pair was posted.
        }

        if isDragging {
            // Start inertia coasting if enabled and velocity is above threshold.
            if isInertiaEnabled, let velocity = velocityTracker.computeVelocity() {
                let dirMultiplier: CGFloat = isScrollDirectionInverted ? -1.0 : 1.0
                let adjustedVelocity = CGPoint(x: velocity.x * dirMultiplier, y: velocity.y * dirMultiplier)

                // Inject velocity-scaled scroll events BEFORE scrollPhaseEnded
                // to influence NSScrollView's perceived exit velocity.
                // NSScrollView computes its internal momentum from the velocity
                // of recent scrollPhaseChanged events.  By injecting events with
                // intensity-scaled deltas, we control how much native momentum
                // NSScrollView generates.
                let intensityScale = inertiaAnimator.velocityScaleForIntensity(CGFloat(inertiaIntensity))
                injectVelocityRamp(velocity: adjustedVelocity, scale: intensityScale, axis: lockedAxis)

                // Post scroll ended event with zero deltas.
                postScrollEvent(wheel1: 0, wheel2: 0, phase: 4) // kCGScrollPhaseEnded

                // Start InertiaAnimator for web-view apps (which use momentum
                // events directly).  For native NSScrollView apps, the native
                // momentum is already intensity-adjusted via the velocity ramp.
                inertiaAnimator.startCoasting(
                    velocity: adjustedVelocity,
                    axis: lockedAxis,
                    intensity: CGFloat(inertiaIntensity)
                )
            } else {
                // No inertia — post scrollPhaseEnded + momentum cancel so
                // NSScrollView does not start its own internal momentum.
                postScrollEvent(wheel1: 0, wheel2: 0, phase: 4) // kCGScrollPhaseEnded
                postMomentumScrollEvent(wheel1: 0, wheel2: 0, momentumPhase: 1) // begin
                postMomentumScrollEvent(wheel1: 0, wheel2: 0, momentumPhase: 3) // end
            }
        }
        onDragStateChanged?(false)
        resetDragState()
        return nil // Suppress the mouse up while in scroll mode.
    }

    // MARK: - Private Helpers

    /// Injects a short burst of velocity-adjusted scrollPhaseChanged events
    /// to set NSScrollView's perceived exit velocity before scrollPhaseEnded.
    ///
    /// NSScrollView uses the velocity of recent scroll events to compute its
    /// own momentum animation.  By posting a few events with intensity-scaled
    /// deltas (simulating ~16ms frame intervals), we control how much native
    /// momentum NSScrollView generates.
    ///
    /// At intensity 0.5 (default), scale == 1.0, so the injected velocity
    /// matches the actual drag velocity — no change from pre-fix behavior.
    private func injectVelocityRamp(velocity: CGPoint, scale: CGFloat, axis: Axis?) {
        // Simulate 3 frames at ~8ms each (~24ms total) with scaled velocity.
        // The delta per frame = velocity * scale * frameDuration.
        let frameDuration: CGFloat = 0.008 // 8ms per synthetic frame
        let frameCount = 3

        for _ in 0..<frameCount {
            let deltaY = velocity.y * scale * frameDuration
            let deltaX = velocity.x * scale * frameDuration

            let scrollY = Int32(deltaY)
            let scrollX = Int32(deltaX)

            if let axis {
                switch axis {
                case .vertical:
                    postScrollEvent(wheel1: scrollY, wheel2: 0, phase: 2)
                case .horizontal:
                    postScrollEvent(wheel1: 0, wheel2: scrollX, phase: 2)
                }
            } else {
                postScrollEvent(wheel1: scrollY, wheel2: scrollX, phase: 2)
            }
        }
    }

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

    private func postMomentumScrollEvent(wheel1: Int32, wheel2: Int32, momentumPhase: Int64) {
        let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 3,
            wheel1: wheel1,
            wheel2: wheel2,
            wheel3: 0
        )

        guard let scrollEvent else { return }

        // During momentum: scrollPhase = 0 (none), only momentumPhase carries state.
        scrollEvent.setIntegerValueField(.scrollWheelEventScrollPhase, value: 0)
        scrollEvent.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentumPhase)
        scrollEvent.post(tap: .cgSessionEventTap)
    }

    private func replayClick(at position: CGPoint, clickState: Int64) {
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
            return
        }

        // Tag synthetic events so the event tap passes them through.
        // CGEvent.post() is asynchronous — a boolean flag would be cleared
        // before the events reach the callback.
        down.setIntegerValueField(.mouseEventClickState, value: clickState)
        up.setIntegerValueField(.mouseEventClickState, value: clickState)
        down.setIntegerValueField(.eventSourceUserData, value: ScrollEngine.replayMarker)
        up.setIntegerValueField(.eventSourceUserData, value: ScrollEngine.replayMarker)

        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    /// Posts only a synthetic mouseDown (no mouseUp) so the window server
    /// treats it as the start of a drag, enabling window moves and resizes.
    private func replayMouseDown(at position: CGPoint, clickState: Int64) {
        let source = CGEventSource(stateID: .hidSystemState)

        guard let down = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseDown,
            mouseCursorPosition: position,
            mouseButton: .left
        ) else {
            return
        }

        down.setIntegerValueField(.mouseEventClickState, value: clickState)
        down.setIntegerValueField(.eventSourceUserData, value: ScrollEngine.replayMarker)
        down.post(tap: .cghidEventTap)
    }

    /// Posts a synthetic mouseUp at .cghidEventTap to pair with replayMouseDown.
    private func replayMouseUp(at position: CGPoint, clickState: Int64) {
        let source = CGEventSource(stateID: .hidSystemState)

        guard let up = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseUp,
            mouseCursorPosition: position,
            mouseButton: .left
        ) else {
            return
        }

        up.setIntegerValueField(.mouseEventClickState, value: clickState)
        up.setIntegerValueField(.eventSourceUserData, value: ScrollEngine.replayMarker)
        up.post(tap: .cghidEventTap)
    }

    private func cancelHoldTimer() {
        holdTimer?.cancel()
        holdTimer = nil
    }

    private func resetDragState() {
        isDragging = false
        pendingMouseDown = false
        totalMovement = 0.0
        lockedAxis = nil
        accumulatedDelta = .zero
        isFirstDragEvent = true
        velocityTracker.reset()
        cancelHoldTimer()
        isInPassthroughMode = false
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

    // Per-app exclusion: bypass all events when the frontmost app is excluded.
    if engine.shouldBypassAllEvents?() == true {
        return Unmanaged.passUnretained(event)
    }

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
