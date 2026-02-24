# Phase 13: Inertia Controls - Context

**Gathered:** 2026-02-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Add settings controls for momentum scrolling: an on/off toggle and an intensity slider. Users can tune how far and fast coasting travels, or disable inertia entirely. This phase also reorganizes the settings view for clarity.

</domain>

<decisions>
## Implementation Decisions

### Slider behavior
- Continuous slider (any value), not discrete stops
- Endpoint labels only ("Less" / "More" or similar) — no dynamic label that changes as you drag
- Slider is disabled (grayed out) when inertia is toggled off — not hidden
- Changes take effect immediately — next scroll drag uses the new intensity

### Settings layout
- Standard SwiftUI Toggle (switch) for the inertia on/off control
- Toggle labeled "Momentum scrolling", slider labeled "Intensity"
- Reorganize the entire settings view as part of this phase — group related settings logically so the growing number of controls stays comprehensible
- Claude has discretion on the grouping/hierarchy — just make it make sense

### Intensity mapping
- At minimum intensity, inertia still coasts slightly — the toggle is for fully off
- At maximum intensity, iOS-like flick behavior — content can travel several screens
- Slider controls both coasting speed AND duration (unified multiplier feel)
- 50% slider position = current hardcoded inertia feel (today's behavior is the midpoint)

### Center detent
- A visual tick mark at the center (50%) position of the slider
- Slider snaps to center when the thumb is near it — makes it easy to return to default intensity without resetting all settings

### Defaults & reset
- Fresh install: inertia on, intensity at 50% (which matches today's feel)
- Toggling inertia off then back on remembers the previous slider position
- "Reset to Defaults" resets inertia settings too (toggle on, slider to 50%)
- Both toggle and slider values persist across app restarts

</decisions>

<specifics>
## Specific Ideas

- 50% intensity must reproduce exactly how inertia feels today — the slider range extends weaker and stronger from that baseline
- Center snap on the slider is important for easy return-to-default without a full settings reset

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 13-inertia-controls*
*Context gathered: 2026-02-22*
