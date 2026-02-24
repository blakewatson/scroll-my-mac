# Phase 4: Inertia - Research

**Researched:** 2026-02-15
**Domain:** Momentum scrolling physics, display-synchronized animation, CGEvent scroll phases
**Confidence:** HIGH

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

- iOS/trackpad-like exponential decay curve -- fast at first, gradually slows to a stop
- Long coast distance -- a fast flick should scroll many screenfuls, covering large distances quickly
- Fixed feel -- one well-tuned curve, no user-adjustable sensitivity slider
- Minimum velocity threshold -- below a speed threshold, scrolling stops cleanly on release (no micro-coasting from slow drags)
- Use recent samples (~50-100ms window of mouse move events) to average out jitter
- Pausing mid-drag (holding still) clears the velocity buffer -- release after a pause produces no inertia
- Inertia direction locks to dominant axis (consistent with drag axis locking)
- Click during inertia: instant stop, click is consumed (not passed through) -- prevents accidental clicks
- New drag during inertia: cancel old inertia immediately, new drag takes over (clean handoff)
- Toggle scroll mode off (F6) during inertia: instant stop, kills inertia immediately
- Edge behavior: defer to native app scroll behavior -- no custom overscroll/bounce handling needed
- Axis lock applies to both drag and inertia (not just inertia)
- Preserve existing axis-lock behavior from current scroll engine and extend it to inertia coasting
- Add a settings toggle for free-scroll (both directions) vs axis-lock mode
- Axis lock is the default; free-scroll is opt-in via settings

### Claude's Discretion

- Maximum velocity cap (whether to cap and where to set it)
- Exact velocity sampling window size and weighting
- Frame synchronization strategy (CVDisplayLink, Timer, etc.)
- Minimum velocity threshold value
- Exact deceleration curve parameters

### Deferred Ideas (OUT OF SCOPE)

None -- discussion stayed within phase scope

</user_constraints>

## Summary

This phase adds momentum/inertia scrolling to the existing drag-to-scroll engine. When the user releases a drag at speed, scrolling continues with exponential deceleration -- matching the feel of iOS/trackpad scrolling. The implementation requires three new capabilities: (1) velocity tracking during drag, (2) a display-synchronized animation loop for the coast phase, and (3) correct CGEvent momentum scroll phase signaling so apps respond naturally to the synthetic momentum events.

The core physics are well-understood: iOS uses exponential decay where velocity is multiplied by a constant factor each millisecond (the `decelerationRate`). Position is the integral of this velocity function. Apple's own PastryKit implementation reduces velocity by 0.95 per 16.7ms frame, giving a time constant of ~325ms. For this app's "long coast" requirement, a slower decay rate (closer to UIScrollView's `.normal` rate of 0.998/ms) should be used -- this produces long-distance coasting for fast flicks.

The app targets macOS 14.0+, which means `CADisplayLink` is available natively via `NSScreen.displayLink(target:selector:)`. This is the correct frame synchronization strategy -- it automatically adapts to the display's refresh rate (60Hz, 120Hz ProMotion) and avoids the timing issues of `Timer`-based approaches.

**Primary recommendation:** Implement an `InertiaAnimator` class that owns a `CADisplayLink`, tracks velocity via a ring buffer of recent drag samples, and posts momentum-phase scroll events (`scrollWheelEventMomentumPhase`) with exponentially decaying deltas each frame.

## Standard Stack

### Core

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| `CADisplayLink` via `NSScreen.displayLink(target:selector:)` | macOS 14.0+ | Frame-synchronized animation loop | Apple's recommended replacement for CVDisplayLink; auto-adapts to display refresh rate |
| `CGEvent` scroll wheel API | macOS 10.4+ | Post synthetic momentum scroll events | Already used by ScrollEngine; momentum phase field enables proper inertia signaling |

### Supporting

| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `CFAbsoluteTimeGetCurrent()` or `CACurrentMediaTime()` | High-resolution timestamps for velocity samples | Timestamp each drag event for velocity calculation |
| Ring buffer (custom, ~10 samples) | Store recent drag deltas with timestamps | Velocity averaging over 50-100ms window |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `CADisplayLink` | `Timer(timeInterval: 1/60)` | Timer is not display-synchronized; causes stuttering on ProMotion displays and frame drops under load |
| `CADisplayLink` | `CVDisplayLink` (deprecated) | Works but deprecated in macOS 14; C-based API, harder to use, no reason since deployment target is 14.0 |
| Ring buffer | Full history array | Ring buffer is O(1) memory, trivially bounded; full history wastes memory and requires pruning |

## Architecture Patterns

### Recommended Structure

The inertia system should be a separate class that the ScrollEngine owns and delegates to:

```
ScrollEngine (existing)
├── handles mouse down/drag/up (existing)
├── owns InertiaAnimator (new)
│   ├── VelocityTracker (new, could be nested struct)
│   │   └── ring buffer of (timestamp, deltaX, deltaY) samples
│   ├── CADisplayLink (created on demand)
│   └── posts momentum scroll events during coast
└── coordinates handoff between drag and inertia
```

### Pattern 1: Velocity Tracking via Ring Buffer

**What:** Store the last N drag events (timestamp + delta) in a fixed-size ring buffer. On mouse-up, compute average velocity from samples within the recent time window.

**When to use:** Every `handleMouseDragged` call adds a sample. On `handleMouseUp`, velocity is computed from buffer contents.

**Example:**
```swift
struct VelocitySample {
    let timestamp: CFTimeInterval
    let deltaX: CGFloat
    let deltaY: CGFloat
}

struct VelocityTracker {
    private var samples: [VelocitySample] = []
    private let maxSamples = 10
    private let windowDuration: CFTimeInterval = 0.080 // 80ms

    mutating func addSample(deltaX: CGFloat, deltaY: CGFloat) {
        let now = CACurrentMediaTime()
        samples.append(VelocitySample(timestamp: now, deltaX: deltaX, deltaY: deltaY))
        if samples.count > maxSamples {
            samples.removeFirst()
        }
    }

    mutating func reset() {
        samples.removeAll()
    }

    /// Returns velocity in points/second, or nil if insufficient data.
    func computeVelocity() -> CGPoint? {
        let now = CACurrentMediaTime()
        let cutoff = now - windowDuration
        let recent = samples.filter { $0.timestamp >= cutoff }

        guard recent.count >= 2,
              let first = recent.first,
              let last = recent.last else { return nil }

        let dt = last.timestamp - first.timestamp
        guard dt > 0.001 else { return nil } // Avoid division by near-zero

        let totalDX = recent.reduce(0.0) { $0 + $1.deltaX }
        let totalDY = recent.reduce(0.0) { $0 + $1.deltaY }

        return CGPoint(x: totalDX / dt, y: totalDY / dt)
    }
}
```

### Pattern 2: Exponential Decay Animation

**What:** Each display frame, compute position delta from the closed-form exponential decay equation. This is robust against frame drops -- if a frame is missed, the next frame catches up correctly.

**When to use:** During the inertia coast phase, called by CADisplayLink callback.

**Example:**
```swift
// Closed-form exponential decay (robust against frame drops):
//   position(t) = target - amplitude * e^(-t / tau)
//   velocity(t) = (amplitude / tau) * e^(-t / tau)
//
// Where:
//   amplitude = initialVelocity * tau  (total distance to coast)
//   tau = time constant (controls how long coasting lasts)
//   target = startPosition + amplitude

let tau: CFTimeInterval = 0.325  // 325ms time constant (iOS normal feel)
// For longer coast, use larger tau, e.g. 0.400-0.500

let amplitude = initialVelocity * tau
let elapsed = currentTime - startTime

// Delta since last frame (use position difference, not velocity):
let positionNow = amplitude * (1.0 - exp(-elapsed / tau))
let delta = positionNow - positionAtLastFrame
positionAtLastFrame = positionNow

// Stop when remaining amplitude is negligible
let remaining = amplitude * exp(-elapsed / tau)
if abs(remaining) < 0.5 { // half-pixel threshold
    stopInertia()
}
```

### Pattern 3: Momentum Scroll Phase Signaling

**What:** Post CGEvent scroll events with the `scrollWheelEventMomentumPhase` field set correctly so apps handle momentum events naturally (e.g., rubber-banding, snap-to-content).

**When to use:** During inertia coasting. The scroll phase (`scrollWheelEventScrollPhase`) should be 0 (none) while momentum phase carries the state.

**Example:**
```swift
func postMomentumScrollEvent(deltaY: Int32, deltaX: Int32, momentumPhase: Int64) {
    guard let event = CGEvent(
        scrollWheelEvent2Source: nil,
        units: .pixel,
        wheelCount: 3,
        wheel1: deltaY,
        wheel2: deltaX,
        wheel3: 0
    ) else { return }

    // During momentum: scrollPhase = 0 (none), momentumPhase = active
    event.setIntegerValueField(.scrollWheelEventScrollPhase, value: 0)
    event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentumPhase)
    event.post(tap: .cgSessionEventTap)
}

// Lifecycle:
// Frame 1: momentumPhase = 1 (kCGMomentumScrollPhaseBegin)
// Frame 2..N-1: momentumPhase = 2 (kCGMomentumScrollPhaseContinue)
// Frame N: momentumPhase = 3 (kCGMomentumScrollPhaseEnd)
```

### Anti-Patterns to Avoid

- **Posting momentum events with non-zero scrollWheelEventScrollPhase:** During momentum, the gesture phase must be 0 (none). Having both phases active simultaneously confuses apps.
- **Using Timer instead of CADisplayLink:** Timers fire at imprecise intervals and are not synchronized to the display. This causes visible stuttering, especially on ProMotion displays.
- **Computing velocity from only the last drag event:** Single-sample velocity is extremely noisy. The mouse reports position at variable intervals; one slow report can produce a massive spike. Always average over a time window.
- **Using linear deceleration instead of exponential:** Linear deceleration feels robotic and unnatural. Exponential decay matches human perception of "slowing down naturally."

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Display-synced animation | Custom `Timer(repeating: 1/60)` | `CADisplayLink` via `NSScreen.displayLink` | Timer has no display sync; ProMotion displays need variable frame rates |
| Overscroll/bounce | Custom bounce physics | Nothing -- defer to native apps | User decision: let apps handle their own overscroll behavior |
| Velocity smoothing | Complex Kalman filter or weighted regression | Simple ring buffer with time-window averaging | Sufficient for this use case; more complexity adds no perceptible benefit |

**Key insight:** The physics math itself IS hand-rolled (exponential decay formula), but this is intentional -- it is a simple, well-understood formula. The display synchronization and scroll event posting use system APIs.

## Common Pitfalls

### Pitfall 1: Stale Velocity After Pause-Then-Release

**What goes wrong:** User drags fast, pauses for 500ms, then releases. Inertia fires with the old fast velocity, launching content unexpectedly.
**Why it happens:** Velocity buffer still contains samples from before the pause.
**How to avoid:** Clear or expire samples older than the window duration (80-100ms). If no recent samples remain at mouse-up, velocity is zero -- no inertia.
**Warning signs:** Content flies away after the user clearly stopped moving.

### Pitfall 2: Frame-Rate-Dependent Physics

**What goes wrong:** Inertia feels different on 60Hz vs 120Hz displays, or stutters when frames are dropped.
**Why it happens:** Using per-frame velocity multiplier (v *= 0.95) instead of time-based exponential decay.
**How to avoid:** Use the closed-form position equation `amplitude * (1 - e^(-t/tau))` with real elapsed time. Compute delta as difference between current and previous position. This is frame-rate independent.
**Warning signs:** Scrolling distance differs between MacBook (60Hz) and Studio Display (60Hz) vs ProMotion displays (120Hz).

### Pitfall 3: Scroll Phase Sequence Errors

**What goes wrong:** Apps ignore momentum events, rubber-banding breaks, or scrolling behavior is wrong.
**Why it happens:** Incorrect phase field values. Common mistakes: forgetting to send `kCGScrollPhaseEnded` (value 4) before starting momentum, or setting `scrollWheelEventScrollPhase` during momentum events.
**How to avoid:** Follow the exact sequence: drag ends with `scrollPhase=4, momentumPhase=0` (already done in current code), then momentum starts with `scrollPhase=0, momentumPhase=1`, continues with `scrollPhase=0, momentumPhase=2`, ends with `scrollPhase=0, momentumPhase=3`.
**Warning signs:** Safari ignores momentum events; apps show weird rubber-band behavior.

### Pitfall 4: Click During Inertia Not Consumed

**What goes wrong:** User clicks to stop inertia but the click passes through, activating a link or button.
**Why it happens:** The click arrives at the event tap but the inertia system doesn't know it's coasting, so it falls through to normal click handling.
**How to avoid:** When inertia is active, `handleMouseDown` must check if inertia is coasting. If so: stop inertia, consume the click (return nil), do not enter pending-click or drag state.
**Warning signs:** Clicking during inertia activates elements instead of just stopping the scroll.

### Pitfall 5: CADisplayLink Retain Cycle

**What goes wrong:** `InertiaAnimator` is never deallocated; display link fires forever in the background.
**Why it happens:** `CADisplayLink` retains its target strongly. If `InertiaAnimator` holds the display link and is the target, circular reference.
**How to avoid:** Invalidate the display link when inertia stops. Use a weak proxy target pattern, or ensure `invalidate()` is always called (not just `isPaused`). Set display link to nil after invalidation.
**Warning signs:** CPU usage stays elevated after all scrolling stops.

### Pitfall 6: Axis Lock Lost During Inertia

**What goes wrong:** Drag locks to vertical axis, but inertia scrolls diagonally.
**Why it happens:** The locked axis from the drag phase is not passed to the inertia animator.
**How to avoid:** When starting inertia, pass the `lockedAxis` (or nil for free-scroll) from the drag state to the inertia animator. The animator must respect this lock for all momentum events.
**Warning signs:** Content drifts sideways during inertia when drag was clearly vertical.

## Code Examples

### CADisplayLink Setup on macOS 14+

```swift
// Source: Apple Developer Docs - NSScreen.displayLink(target:selector:)
// Available macOS 14.0+

class InertiaAnimator {
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var lastPosition: CGFloat = 0

    func startCoasting(velocity: CGPoint, axis: ScrollEngine.Axis?) {
        // Create display link from the main screen
        guard let screen = NSScreen.main else { return }
        displayLink = screen.displayLink(
            target: self,
            selector: #selector(displayLinkFired(_:))
        )
        displayLink?.add(to: .main, forMode: .common)
        startTime = CACurrentMediaTime()
        lastPosition = 0
        // ... store velocity, axis, etc.
    }

    @objc private func displayLinkFired(_ link: CADisplayLink) {
        let elapsed = CACurrentMediaTime() - startTime
        // Compute position from exponential decay
        // Post momentum scroll event with delta
        // Check stop condition
    }

    func stopCoasting() {
        displayLink?.invalidate()
        displayLink = nil
        // Post momentum end event
    }
}
```

### Complete Momentum Scroll Event Sequence

```swift
// 1. Drag ends (existing code already posts this):
postScrollEvent(wheel1: 0, wheel2: 0, phase: 4) // scrollPhase = kCGScrollPhaseEnded

// 2. Momentum begins (first frame):
postMomentumEvent(deltaY: d1, deltaX: d2, momentumPhase: 1) // kCGMomentumScrollPhaseBegin

// 3. Momentum continues (subsequent frames):
postMomentumEvent(deltaY: d1, deltaX: d2, momentumPhase: 2) // kCGMomentumScrollPhaseContinue

// 4. Momentum ends (last frame, zero deltas):
postMomentumEvent(deltaY: 0, deltaX: 0, momentumPhase: 3) // kCGMomentumScrollPhaseEnd
```

### Velocity Computation With Pause Detection

```swift
func computeVelocityForInertia() -> CGPoint? {
    let now = CACurrentMediaTime()
    let windowStart = now - 0.080 // 80ms window

    // Filter to recent samples only
    let recent = samples.filter { $0.timestamp >= windowStart }

    // If no recent samples, user paused -- no inertia
    guard recent.count >= 2 else { return nil }

    guard let first = recent.first, let last = recent.last else { return nil }
    let dt = last.timestamp - first.timestamp
    guard dt > 0.005 else { return nil } // need at least 5ms span

    let totalDX = recent.reduce(0.0) { $0 + $1.deltaX }
    let totalDY = recent.reduce(0.0) { $0 + $1.deltaY }

    let vx = totalDX / dt  // points per second
    let vy = totalDY / dt

    // Minimum velocity threshold -- no micro-coasting
    let speed = hypot(vx, vy)
    guard speed > 50.0 else { return nil } // ~50 pt/s minimum (tune this)

    // Optional: cap maximum velocity
    let maxVelocity: CGFloat = 8000.0 // points per second
    if speed > maxVelocity {
        let scale = maxVelocity / speed
        return CGPoint(x: vx * scale, y: vy * scale)
    }

    return CGPoint(x: vx, y: vy)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `CVDisplayLink` (C API) | `CADisplayLink` via `NSScreen.displayLink` | macOS 14 (2023) | Simpler Swift API, auto screen tracking, auto suspend |
| `Timer`-based animation | `CADisplayLink` | Always preferred | Display sync eliminates stuttering |
| Per-frame velocity multiplier (`v *= 0.95`) | Time-based exponential decay (`e^(-t/tau)`) | Best practice | Frame-rate independent; correct on 60Hz and 120Hz |

**Deprecated/outdated:**
- `CVDisplayLink`: Deprecated in macOS 14. The C-based API still works but Apple recommends `NSScreen/NSView/NSWindow.displayLink()` instead.
- `NSTimer` for animation: Never appropriate for display-synchronized animation.

## Discretion Recommendations

These are areas marked as Claude's discretion. Here are researched recommendations:

### Maximum Velocity Cap
**Recommendation:** Cap at 8000 points/second. At 120Hz on a 5K display (~2880 logical points tall), this means a maximum of ~66 pt/frame -- fast enough to scroll through content rapidly but not so fast that everything becomes a blur. Adjust during tuning.

### Velocity Sampling Window
**Recommendation:** 80ms window, up to 10 samples. At typical mouse report rates (125-1000Hz), 80ms captures 10-80 events. Using a ring buffer of 10 keeps memory bounded. 80ms is in the middle of the user's 50-100ms spec and provides good jitter smoothing while remaining responsive.

### Frame Synchronization Strategy
**Recommendation:** Use `CADisplayLink` via `NSScreen.displayLink(target:selector:)`. The app targets macOS 14.0+, making this the clear choice. It is Apple's recommended approach, auto-adapts to display refresh rate, and auto-suspends when the screen is not visible. No reason to use deprecated CVDisplayLink or imprecise Timer.

### Minimum Velocity Threshold
**Recommendation:** Start with 50 points/second. This is approximately 3 pixels of movement across one 60Hz frame -- barely perceptible motion. Below this, the coast would be only 1-2 pixels total, which feels like a glitch rather than intentional momentum. Tune during development.

### Deceleration Curve Parameters
**Recommendation:** Use time constant `tau = 0.400` seconds (400ms). This is slightly longer than iOS's default 325ms, producing the "long coast distance" the user requested. For reference:
- iOS PastryKit: tau = 325ms (moderate coast)
- UIScrollView .normal rate 0.998/ms: tau = ~500ms (very long coast)
- **Recommended: tau = 400ms** (long but not infinite-feeling)

At tau = 400ms, a 2000 pt/s flick coasts ~800 pixels total over ~2.4 seconds (6*tau). A 5000 pt/s flick coasts ~2000 pixels. These feel substantial and match the "many screenfuls" requirement for fast flicks.

The stop condition should be when remaining amplitude drops below 0.5 pixels (half-pixel threshold).

## Open Questions

1. **CADisplayLink on background thread?**
   - What we know: CADisplayLink is typically added to the main RunLoop. The CGEventTap callback runs on the main thread already.
   - What's unclear: Whether posting CGEvents from the main-thread CADisplayLink callback could cause any timing issues with the event tap.
   - Recommendation: Start with main RunLoop. If there are performance issues, investigate running on a dedicated thread.

2. **Momentum phase field behavior in edge cases**
   - What we know: The phase sequence (begin/continue/end) is well documented for trackpad events.
   - What's unclear: Whether all apps correctly handle synthetic momentum events from CGEvent posting, or whether some apps only respond to trackpad-generated momentum.
   - Recommendation: Test with Safari, Chrome, Xcode, and Terminal. If apps don't respond to momentum phase fields, fall back to using `scrollWheelEventScrollPhase` = 2 (changed) during the coast instead.

3. **Interaction between settings toggle (axis-lock vs free-scroll) and existing drag behavior**
   - What we know: The user wants a settings toggle. The current `useAxisLock` property on ScrollEngine already controls this.
   - What's unclear: Whether this should be a new UserDefaults-backed property in AppState or just exposing the existing `useAxisLock` in settings.
   - Recommendation: Add `isAxisLockEnabled` to AppState with UserDefaults persistence, wire to `scrollEngine.useAxisLock`. The UI toggle goes in SettingsView.

## Sources

### Primary (HIGH confidence)
- Apple Developer Docs: `NSScreen.displayLink(target:selector:)` -- macOS 14.0+ availability confirmed
- Apple Developer Docs: `CADisplayLink` -- properties and lifecycle
- Apple Developer Docs: `CGEventField.scrollWheelEventScrollPhase` -- scroll phase field
- Apple Developer Docs: `NSEvent.momentumPhase` -- momentum phase documentation
- Existing codebase: `ScrollEngine.swift` -- current scroll event posting, phase values, axis lock implementation

### Secondary (MEDIUM confidence)
- [Flick list with momentum scrolling - ariya.io](https://ariya.io/2011/10/flick-list-with-its-momentum-scrolling-and-deceleration) -- exponential decay formulas, time constant derivation, PastryKit implementation details
- [Deceleration mechanics of UIScrollView - Ilya Lobanov](https://medium.com/@esskeetit/scrolling-mechanics-of-uiscrollview-142adee1142c) -- UIScrollView decelerationRate values, position/velocity formulas
- [In-process animations with CADisplayLink](https://philz.blog/in-process-animations-and-transitions-with-cadisplaylink-done-right/) -- macOS 14 displayLink deprecation of CVDisplayLink, best practices
- [Low-level scrolling events on macOS (GitHub Gist)](https://gist.github.com/svoisen/5215826) -- scroll event field documentation

### Tertiary (LOW confidence)
- Momentum phase integer constants (0=none, 1=begin, 2=continue, 3=end) -- derived from NSEventPhase documentation and community sources, not directly from CGEvent header documentation. Should be validated empirically by logging real trackpad events.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- CADisplayLink availability confirmed via Apple docs and deployment target (macOS 14.0)
- Architecture: HIGH -- exponential decay physics well-understood; CGEvent scroll API already in use in codebase
- Pitfalls: HIGH -- common issues documented across multiple sources; frame-rate independence is well-established best practice
- Momentum phase constants: MEDIUM -- values consistent across multiple sources but not verified from C headers directly

**Research date:** 2026-02-15
**Valid until:** 2026-03-15 (stable domain; macOS scroll APIs change slowly)
