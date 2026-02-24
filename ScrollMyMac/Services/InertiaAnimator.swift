import AppKit
import QuartzCore

/// Drives momentum scrolling after a drag release using display-synchronized
/// exponential decay animation with quadratic tail acceleration.
///
/// Owns a `CADisplayLink` that fires each frame to post momentum scroll events
/// with decaying deltas. The decay follows
/// `amplitude * (1 - exp(-t/tau - tailAccel*t^2))`, which is frame-rate
/// independent and has a sharp tail cutoff instead of lingering at low velocity.
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

    /// Velocity scale range for InertiaAnimator momentum events (web apps).
    /// intensity 0.0 -> velocityScaleMin (gentle)
    /// intensity 0.5 -> 1.0 (unchanged from today)
    /// intensity 1.0 -> velocityScaleMax (fast)
    private let velocityScaleMin: CGFloat = 0.4
    private let velocityScaleMid: CGFloat = 1.0
    private let velocityScaleMax: CGFloat = 2.0

    /// Velocity scale range for native app velocity ramp injection.
    /// Wider range than web apps because NSScrollView applies its own
    /// momentum curve on top, dampening the perceived difference.
    /// intensity 0.0 -> nativeScaleMin (shorter coast)
    /// intensity 0.5 -> 1.0 (unchanged from pre-fix behavior)
    /// intensity 1.0 -> nativeScaleMax (much longer coast)
    private let nativeScaleMin: CGFloat = 0.25
    private let nativeScaleMid: CGFloat = 1.0
    private let nativeScaleMax: CGFloat = 4.0

    /// Quadratic tail-acceleration coefficient.  Added to the exponential
    /// decay exponent as `-tailAccel * t^2`, causing deceleration to
    /// intensify sharply at the tail end while preserving smooth early feel.
    /// Higher values = sharper cutoff.  0.0 = pure exponential (long tail).
    private let tailAccel: CFTimeInterval = 1.5

    /// Stop threshold: remaining amplitude below this is considered negligible.
    private let stopThreshold: CGFloat = 0.5

    /// Computed tau for the current coasting animation (set per startCoasting call).
    private var tau: CFTimeInterval = 0.400

    // MARK: - Callback

    /// Called each frame with (deltaY, deltaX, momentumPhase).
    /// ScrollEngine provides this to post momentum scroll events.
    /// Phase values: 1 = begin, 2 = continue, 3 = end.
    var onMomentumScroll: ((Int32, Int32, Int64) -> Void)?

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

    /// Computes the native-app velocity scale factor for a given intensity.
    ///
    /// Two-segment linear interpolation using the wider native range:
    /// [0.0, 0.5] -> [nativeScaleMin, 1.0], [0.5, 1.0] -> [1.0, nativeScaleMax]
    ///
    /// Used by ScrollEngine to inject velocity-adjusted scroll events before
    /// scrollPhaseEnded so that NSScrollView's native momentum reflects the
    /// intensity setting.  The wider range compensates for NSScrollView's own
    /// momentum curve dampening the perceived difference.
    func nativeVelocityScaleForIntensity(_ intensity: CGFloat) -> CGFloat {
        let t = min(max(intensity, 0.0), 1.0)
        if t <= 0.5 {
            let fraction = t / 0.5
            return nativeScaleMin + (nativeScaleMid - nativeScaleMin) * fraction
        } else {
            let fraction = (t - 0.5) / 0.5
            return nativeScaleMid + (nativeScaleMax - nativeScaleMid) * fraction
        }
    }

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

        // Web-app velocity scale (InertiaAnimator's own momentum events).
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
    /// Posts a momentum-end event (phase 3) and invalidates the display link.
    func stopCoasting() {
        guard isCoasting else { return }

        // Post final momentum event with zero deltas and phase 3 (end).
        onMomentumScroll?(0, 0, 3)

        invalidateDisplayLink()
        isCoasting = false
    }

    deinit {
        invalidateDisplayLink()
    }

    // MARK: - Display Link Callback

    @objc private func displayLinkFired(_ link: CADisplayLink) {
        let elapsed = CACurrentMediaTime() - startTime

        // Compute current position from exponential decay with quadratic
        // tail acceleration: decay = exp(-t/tau - tailAccel * t^2).
        // The linear term (-t/tau) controls the main deceleration feel.
        // The quadratic term (-tailAccel * t^2) intensifies at large t,
        // causing the tail to drop off sharply instead of lingering.
        let decay = exp(-elapsed / tau - tailAccel * elapsed * elapsed)
        let positionX = amplitudeX * (1.0 - decay)
        let positionY = amplitudeY * (1.0 - decay)

        // Delta since last frame.
        let deltaX = positionX - lastPositionX
        let deltaY = positionY - lastPositionY
        lastPositionX = positionX
        lastPositionY = positionY

        // Check stop condition: remaining amplitude is negligible.
        // Higher threshold cuts the deceleration tail shorter.
        let remainingX = abs(amplitudeX * decay)
        let remainingY = abs(amplitudeY * decay)
        if remainingX < stopThreshold && remainingY < stopThreshold {
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
