import QuartzCore

/// A single velocity sample recorded during a drag event.
struct VelocitySample {
    let timestamp: CFTimeInterval
    let deltaX: CGFloat
    let deltaY: CGFloat
}

/// Tracks mouse drag velocity using a ring buffer of recent samples.
///
/// Feed drag deltas via `addSample(deltaX:deltaY:)` on each mouseDragged event.
/// On mouseUp, call `computeVelocity()` to get the release velocity in points/second.
/// Returns nil if the drag was too slow, too brief, or the user paused before releasing.
struct VelocityTracker {

    // MARK: - Configuration

    private let maxSamples = 10
    private let windowDuration: CFTimeInterval = 0.080 // 80ms
    private let minTimeSpan: CFTimeInterval = 0.005     // 5ms minimum for pause detection
    private let minSpeed: CGFloat = 50.0                // points/second
    private let maxSpeed: CGFloat = 8000.0              // points/second cap

    // MARK: - State

    private var samples: [VelocitySample] = []

    // MARK: - API

    /// Records a drag delta sample with the current timestamp.
    mutating func addSample(deltaX: CGFloat, deltaY: CGFloat) {
        let now = CACurrentMediaTime()
        samples.append(VelocitySample(timestamp: now, deltaX: deltaX, deltaY: deltaY))
        if samples.count > maxSamples {
            samples.removeFirst()
        }
    }

    /// Clears all stored samples.
    mutating func reset() {
        samples.removeAll()
    }

    /// Computes the average velocity from recent samples within the time window.
    ///
    /// Returns nil if:
    /// - Fewer than 2 samples in the window (insufficient data)
    /// - Time span < 5ms (user paused before releasing)
    /// - Speed below 50 pt/s threshold (no micro-coasting)
    ///
    /// Caps velocity at 8000 pt/s to prevent extreme flicks.
    func computeVelocity() -> CGPoint? {
        let now = CACurrentMediaTime()
        let cutoff = now - windowDuration
        let recent = samples.filter { $0.timestamp >= cutoff }

        guard recent.count >= 2,
              let first = recent.first,
              let last = recent.last else { return nil }

        let dt = last.timestamp - first.timestamp
        guard dt >= minTimeSpan else { return nil }

        let totalDX = recent.reduce(0.0) { $0 + $1.deltaX }
        let totalDY = recent.reduce(0.0) { $0 + $1.deltaY }

        let vx = totalDX / dt
        let vy = totalDY / dt

        let speed = hypot(vx, vy)
        guard speed >= minSpeed else { return nil }

        // Cap at maximum velocity
        if speed > maxSpeed {
            let scale = maxSpeed / speed
            return CGPoint(x: vx * scale, y: vy * scale)
        }

        return CGPoint(x: vx, y: vy)
    }
}
