# Phase 4: Inertia - Context

**Gathered:** 2026-02-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Released drags produce natural momentum scrolling with gradual deceleration. Faster drags produce more momentum; slow drags produce little or no momentum. Inertia scrolling feels smooth and frame-synchronized. This phase adds momentum behavior to the existing drag-to-scroll engine — it does not change drag behavior, click safety, or hotkey mechanics.

</domain>

<decisions>
## Implementation Decisions

### Deceleration feel
- iOS/trackpad-like exponential decay curve — fast at first, gradually slows to a stop
- Long coast distance — a fast flick should scroll many screenfuls, covering large distances quickly
- Fixed feel — one well-tuned curve, no user-adjustable sensitivity slider
- Minimum velocity threshold — below a speed threshold, scrolling stops cleanly on release (no micro-coasting from slow drags)

### Velocity capture
- Use recent samples (~50-100ms window of mouse move events) to average out jitter
- Pausing mid-drag (holding still) clears the velocity buffer — release after a pause produces no inertia
- Inertia direction locks to dominant axis (consistent with drag axis locking)

### Interruption behavior
- Click during inertia: instant stop, click is consumed (not passed through) — prevents accidental clicks
- New drag during inertia: cancel old inertia immediately, new drag takes over (clean handoff)
- Toggle scroll mode off (F6) during inertia: instant stop, kills inertia immediately
- Edge behavior: defer to native app scroll behavior — no custom overscroll/bounce handling needed

### Direction constraints
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

</decisions>

<specifics>
## Specific Ideas

- Current axis-lock behavior during drag already feels right — preserve and extend to inertia
- Native overscroll bounce in some apps is fine as-is — the app should not try to replicate or suppress it

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-inertia*
*Context gathered: 2026-02-15*
