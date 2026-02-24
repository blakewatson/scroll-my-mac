import AppKit
import QuartzCore

/// Drives momentum scrolling after a drag release using display-synchronized
/// exponential decay animation.
///
/// Owns a `CADisplayLink` that fires each frame to post momentum scroll events
/// with decaying deltas. The decay follows `amplitude * (1 - exp(-t / tau))`,
/// which is frame-rate independent and robust against dropped frames.
///
/// Not `@Observable` — this is internal to ScrollEngine.
class InertiaAnimator {

    // MARK: - Configuration

    /// Tau range for intensity mapping.
    /// intensity 0.0 -> tauMin (short, gentle coast)
    /// intensity 0.5 -> tauMid (current hardcoded feel)
    /// intensity 1.0 -> tauMax (long iOS-like flick)
    private let tauMin: CFTimeInterval = 0.120
    private let tauMid: CFTimeInterval = 0.400
    private let tauMax: CFTimeInterval = 0.900

    /// Velocity scale range for intensity mapping.
    /// intensity 0.0 -> velocityScaleMin (gentle)
    /// intensity 0.5 -> 1.0 (unchanged from today)
    /// intensity 1.0 -> velocityScaleMax (fast)
    private let velocityScaleMin: CGFloat = 0.4
    private let velocityScaleMid: CGFloat = 1.0
    private let velocityScaleMax: CGFloat = 2.0

    /// Computed tau for the current coasting animation (set per startCoasting call).
    private var tau: CFTimeInterval = 0.400

    // MARK: - Callbacks

    /// Called each frame with (deltaY, deltaX, momentumPhase).
    /// ScrollEngine provides this to post momentum scroll events.
    /// Phase values: 1 = begin, 2 = continue, 3 = end.
    var onMomentumScroll: ((Int32, Int32, Int64) -> Void)?

    /// Called after coasting ends (after the final momentum-end event).
    /// ScrollEngine uses this to post scrollPhaseEnded, which was deferred
    /// to prevent NSScrollView from starting its own internal momentum.
    var onCoastingFinished: (() -> Void)?

    // MARK: - State

    /// Whether inertia animation is currently running.
    private(set) var isCoasting: Bool = false

    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var amplitudeX: CGFloat = 0
    private var amplitudeY: CGFloat = 0
    private var lastPositionX: CGFloat = 0
    private var lastPositionY: CGFloat = 0
    private var lockedAxis: ScrollEngine.Axis?
    private var isFirstFrame: Bool = true
    private var scrollRemainderX: CGFloat = 0
    private var scrollRemainderY: CGFloat = 0

    // MARK: - API

    /// Begins momentum coasting with the given velocity, optional axis lock,
    /// and intensity that scales both coasting duration and speed.
    ///
    /// - Parameters:
    ///   - velocity: Release velocity in points/second (from VelocityTracker).
    ///   - axis: Locked axis from drag phase. Pass nil for free-scroll (both axes).
    ///   - intensity: 0.0...1.0. At 0.5, behavior matches the original hardcoded feel.
    func startCoasting(velocity: CGPoint, axis: ScrollEngine.Axis?, intensity: CGFloat) {
        stopCoasting()

        lockedAxis = axis

        // Clamp intensity to valid range.
        let t = min(max(intensity, 0.0), 1.0)

        // Two-segment linear interpolation for tau:
        // [0.0, 0.5] -> [tauMin, tauMid], [0.5, 1.0] -> [tauMid, tauMax]
        if t <= 0.5 {
            let fraction = t / 0.5
            tau = tauMin + (tauMid - tauMin) * fraction
        } else {
            let fraction = (t - 0.5) / 0.5
            tau = tauMid + (tauMax - tauMid) * fraction
        }

        // Two-segment linear interpolation for velocity scale:
        // [0.0, 0.5] -> [velocityScaleMin, velocityScaleMid], [0.5, 1.0] -> [velocityScaleMid, velocityScaleMax]
        let velocityScale: CGFloat
        if t <= 0.5 {
            let fraction = t / 0.5
            velocityScale = velocityScaleMin + (velocityScaleMid - velocityScaleMin) * fraction
        } else {
            let fraction = (t - 0.5) / 0.5
            velocityScale = velocityScaleMid + (velocityScaleMax - velocityScaleMid) * fraction
        }

        // Compute amplitude (total distance to coast) per axis.
        // amplitude = velocity * velocityScale * tau
        amplitudeX = velocity.x * velocityScale * tau
        amplitudeY = velocity.y * velocityScale * tau

        // Apply axis lock: zero out the non-locked axis.
        if let axis {
            switch axis {
            case .vertical:
                amplitudeX = 0
            case .horizontal:
                amplitudeY = 0
            }
        }

        // If both amplitudes are negligible, don't start.
        guard abs(amplitudeX) >= 0.5 || abs(amplitudeY) >= 0.5 else { return }

        lastPositionX = 0
        lastPositionY = 0
        scrollRemainderX = 0
        scrollRemainderY = 0
        isFirstFrame = true
        startTime = CACurrentMediaTime()
        isCoasting = true

        // Create display link from the main screen.
        guard let screen = NSScreen.main else {
            isCoasting = false
            return
        }

        displayLink = screen.displayLink(
            target: self,
            selector: #selector(displayLinkFired(_:))
        )
        displayLink?.add(to: .main, forMode: .common)
    }

    /// Stops momentum coasting immediately.
    /// Posts a momentum-end event (phase 3), invalidates the display link,
    /// and notifies ScrollEngine to post the deferred scrollPhaseEnded.
    func stopCoasting() {
        guard isCoasting else { return }

        // Post final momentum event with zero deltas and phase 3 (end).
        onMomentumScroll?(0, 0, 3)

        invalidateDisplayLink()
        isCoasting = false

        // Notify ScrollEngine that coasting finished so it can post
        // the deferred scrollPhaseEnded event.
        onCoastingFinished?()
    }

    deinit {
        invalidateDisplayLink()
    }

    // MARK: - Display Link Callback

    @objc private func displayLinkFired(_ link: CADisplayLink) {
        let elapsed = CACurrentMediaTime() - startTime

        // Compute current position from closed-form exponential decay.
        // position(t) = amplitude * (1 - exp(-t / tau))
        let decay = exp(-elapsed / tau)
        let positionX = amplitudeX * (1.0 - decay)
        let positionY = amplitudeY * (1.0 - decay)

        // Delta since last frame.
        let deltaX = positionX - lastPositionX
        let deltaY = positionY - lastPositionY
        lastPositionX = positionX
        lastPositionY = positionY

        // Check stop condition: remaining amplitude is negligible.
        let remainingX = abs(amplitudeX * decay)
        let remainingY = abs(amplitudeY * decay)
        if remainingX < 0.5 && remainingY < 0.5 {
            stopCoasting()
            return
        }

        // Determine momentum phase.
        let momentumPhase: Int64
        if isFirstFrame {
            momentumPhase = 1 // kCGMomentumScrollPhaseBegin
            isFirstFrame = false
        } else {
            momentumPhase = 2 // kCGMomentumScrollPhaseContinue
        }

        // Accumulate fractional remainders so sub-pixel deltas aren't lost.
        scrollRemainderY += deltaY
        scrollRemainderX += deltaX
        let scrollDeltaY = Int32(scrollRemainderY)
        let scrollDeltaX = Int32(scrollRemainderX)
        scrollRemainderY -= CGFloat(scrollDeltaY)
        scrollRemainderX -= CGFloat(scrollDeltaX)

        onMomentumScroll?(scrollDeltaY, scrollDeltaX, momentumPhase)
    }

    // MARK: - Private

    private func invalidateDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
}
