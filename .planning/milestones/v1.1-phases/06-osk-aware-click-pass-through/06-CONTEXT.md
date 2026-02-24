# Phase 6: OSK-Aware Click Pass-Through - Context

**Gathered:** 2026-02-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Detect the Accessibility Keyboard window and bypass the scroll engine's hold-and-decide logic for clicks over it. Clicks on the OSK pass through instantly so typing is never interrupted by scroll mode. Scrolling behavior outside the OSK is completely unaffected.

</domain>

<decisions>
## Implementation Decisions

### Boundary behavior
- Use the entire OSK window rectangle for hit-testing (not individual key regions)
- Detect all windows belonging to the OSK process, not just the main keyboard panel
- Edge precision is not critical — use whatever approach is simplest (no margin needed)
- Always on — no user-facing setting to toggle OSK pass-through

### Visual feedback
- No visual indication when pass-through is active over the OSK — clicks just work naturally
- The overlay dot stays as-is regardless of cursor position relative to OSK
- If OSK detection fails (e.g., process name changes in a macOS update), fall back silently to normal scroll behavior with no user-facing warning

### Drag transitions
- Click origin determines behavior for the entire drag
- Click starts on OSK → entire drag is pass-through, even if cursor leaves the OSK
- Click starts outside OSK → entire drag is scroll, even if cursor enters the OSK
- No mid-drag behavior switching

### OSK lifecycle
- Auto-detect: continuously check for OSK windows, pass-through activates immediately when OSK appears
- Smart polling: poll less frequently (or stop) when OSK isn't detected, ramp up when it reappears
- OSK only: hardcode for the Accessibility Keyboard, no general window exclusion system
- Keep it simple and focused on this one use case

### Claude's Discretion
- Process name matching strategy (exact vs fuzzy) — balance reliability and resilience
- Polling interval and smart polling implementation details
- How to integrate with the existing shouldPassThroughClick closure in ScrollEngine

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. The key constraint is that typing on the OSK should feel completely uninterrupted, as if scroll mode doesn't exist when clicking on the keyboard.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 06-osk-aware-click-pass-through*
*Context gathered: 2026-02-16*
