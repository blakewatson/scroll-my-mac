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

    /// Time constant for exponential decay. Larger = longer coast.
    /// 0.400s produces a long, iOS-like coast for fast flicks.
    private let tau: CFTimeInterval = 0.400

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

    // MARK: - API

    /// Begins momentum coasting with the given velocity and optional axis lock.
    ///
    /// - Parameters:
    ///   - velocity: Release velocity in points/second (from VelocityTracker).
    ///   - axis: Locked axis from drag phase. Pass nil for free-scroll (both axes).
    func startCoasting(velocity: CGPoint, axis: ScrollEngine.Axis?) {
        stopCoasting()

        lockedAxis = axis

        // Compute amplitude (total distance to coast) per axis.
        // amplitude = velocity * tau
        amplitudeX = velocity.x * tau
        amplitudeY = velocity.y * tau

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

        // Convert to Int32 for scroll event posting.
        let scrollDeltaY = Int32(deltaY)
        let scrollDeltaX = Int32(deltaX)

        onMomentumScroll?(scrollDeltaY, scrollDeltaX, momentumPhase)
    }

    // MARK: - Private

    private func invalidateDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
}
