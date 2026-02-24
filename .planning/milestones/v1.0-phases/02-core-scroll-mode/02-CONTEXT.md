# Phase 2: Core Scroll Mode - Context

**Gathered:** 2026-02-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Hotkey-toggled scroll mode that converts click-and-drag into scrolling system-wide. User presses F6 to enter scroll mode, then clicks and drags to scroll any scrollable area. A floating dot near the cursor indicates when scroll mode is active. Click safety (pass-through for small movements) and inertia are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Hotkey design
- Default hotkey: F6 (global, works regardless of focused app)
- User has a custom accessibility keyboard button mapped to F6
- Hotkey system must support modifier combos (Ctrl+Shift+X style) for future customization (Phase 5 UI)
- F6 mid-drag behavior: simplest implementation (Claude's discretion)

### Visual indicator
- Floating overlay window: small black dot with white border (matches macOS cursor style)
- Positioned below-right of cursor tip (badge position)
- Overlay follows the cursor in real-time
- Appears when scroll mode is on, disappears when off
- No audio or haptic feedback — visual only

### Scroll feel
- 1:1 pixel-matched scroll ratio (content moves exactly as far as mouse drag)
- Natural scroll direction: drag down = content moves down (like touching a phone screen)
- Both vertical and horizontal scrolling supported
- Axis lock as default: detects dominant drag direction and locks to one axis
- Free scroll mode also implemented (both axes simultaneously) — default to axis lock, setting toggle in Phase 5
- Inertia on release is Phase 4 scope — this phase implements the drag-to-scroll only

### Activation model
- Toggle mode: press F6 to turn on, press again to turn off
- Safety timeout (from Phase 1 SafetyTimeoutManager) auto-disables after inactivity when safety setting is enabled
- UI toggle and F6 always synced — single source of truth for scroll mode state
- UI toggle is also functional (not display-only) — clicking it activates/deactivates scroll mode
- Visual only feedback on toggle (dot appears/disappears)

### Claude's Discretion
- F6 behavior during active drag (simplest implementation)
- Exact dot size and offset distance
- CGEventTap implementation details
- Overlay window level and transparency handling
- Axis lock detection threshold

</decisions>

<specifics>
## Specific Ideas

- Dot should match the macOS cursor aesthetic: black fill, white border — blends with system UI
- The existing SafetyTimeoutManager from Phase 1 handles the auto-off behavior when safety is enabled
- Accessibility keyboard has a custom F6 button ready to go — no special input handling needed

</specifics>

<deferred>
## Deferred Ideas

- Hotkey customization UI — Phase 5 (Settings & Polish)
- Axis lock vs free scroll setting toggle — Phase 5 (Settings & Polish)
- Click-through for small movements — Phase 3 (Click Safety)
- Inertia/momentum on drag release — Phase 4 (Inertia)

</deferred>

---

*Phase: 02-core-scroll-mode*
*Context gathered: 2026-02-15*
