# Phase 11: Hold-to-Passthrough - Context

**Gathered:** 2026-02-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Allow users to perform normal drag operations (text selection, window resize) without leaving scroll mode by holding the mouse still within the dead zone for a configurable delay. This is an opt-in feature that coexists with existing click-through behavior. Off by default.

</domain>

<decisions>
## Implementation Decisions

### Hold behavior
- Jitter tolerance reuses the existing dead zone — mouse movement within the dead zone does not reset the hold timer
- Movement beyond the dead zone cancels the hold and initiates scrolling as normal
- Only the primary (left) mouse button triggers hold-to-passthrough
- Default hold delay is 1.5 seconds
- Delay range: 0.25s to 5.0s, adjustable in 0.25s increments

### Passthrough lifecycle
- Passthrough lasts until mouse-up — releasing the button ends passthrough and returns to normal scroll-mode behavior
- No inertia on passthrough drags — mouse-up ends cleanly with no momentum
- Hold-then-release without movement registers as a normal click (passthrough means "act normal")
- Existing click-through behavior (quick click without significant movement) coexists with hold-to-passthrough — both are independent paths to passing through

### Settings presentation
- Hold-to-passthrough toggle and delay stepper grouped under existing scroll-related settings (not a separate section)
- Delay control is a stepper (up/down with 0.25s increments)
- When toggle is off, the delay stepper is visible but grayed out (disabled)
- Off by default

### Claude's Discretion
- Passthrough activation timing (immediate on timer vs on next movement)
- Visual feedback during hold (if any)
- Exact placement within the scrolling settings group
- Internal state machine design

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 11-hold-to-passthrough*
*Context gathered: 2026-02-17*
