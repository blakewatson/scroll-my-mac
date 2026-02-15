# Phase 3: Click Safety - Context

**Gathered:** 2026-02-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Ensure clicks pass through as normal when the user isn't intentionally scrolling, handle modifier keys and right-clicks, support double-click, and gracefully handle Accessibility permission revocation mid-session. Escape key is NOT used for bail-out — F6 is the only toggle. Inertia is Phase 4.

</domain>

<decisions>
## Implementation Decisions

### Click threshold behavior
- Click-through uses a "hold and decide" model: mouse-down is suppressed, movement is tracked
- If mouse-up occurs within ~8px dead zone, replay the click immediately (no delay beyond the hold)
- If movement exceeds ~8px, treat as scroll drag — click is never delivered
- Dead zone is fixed at ~8px (not configurable)
- Click-through is behind a setting (default on) so users can disable it and revert to "all clicks become scrolls" behavior

### Click replay position
- Claude's discretion — use whichever position (mouse-down or mouse-up) has the simplest implementation

### Escape key
- Escape does NOT affect scroll mode at all — removed from success criteria
- F6 (toggle hotkey) is the only way to enable/disable scroll mode
- If scroll mode is toggled off mid-drag, handle simply (Claude's discretion on cleanup)

### Bail-out mechanisms
- Safety timeout (existing from Phase 1) is the primary safety net
- Research whether Accessibility Keyboard clicks can be detected and passed through — if feasible, implement as an additional bail-out (user can always reach the on-screen keyboard to press F6 or interact with the system)
- If Accessibility Keyboard detection isn't feasible, safety timeout alone is sufficient

### Permission loss handling
- If Accessibility permission is revoked, immediately disable scroll mode
- Show status in the app window so user can investigate why scrolling stopped (no disruptive popup needed)
- Auto-recovery vs manual re-enable: Claude's discretion on safest approach
- Mid-drag permission loss behavior: Claude's discretion on safest cleanup

### Right-clicks
- Right-clicks always pass through — never intercepted by scroll mode

### Modifier keys
- Any click with a modifier key held (Cmd, Option, Shift, Ctrl) always passes through as a normal modified click — no scroll detection applied

### Double-clicks
- Double-clicks should work normally in scroll mode — both clicks pass through if within the dead zone

### Feedback
- Click pass-through is seamless and invisible — no visual or audio feedback when a click is replayed

### Claude's Discretion
- Click replay position (mouse-down vs mouse-up location)
- Mid-toggle and mid-drag cleanup behavior
- Permission recovery strategy (auto vs manual)
- Mid-drag permission revocation cleanup
- Accessibility Keyboard detection approach (research first)

</decisions>

<specifics>
## Specific Ideas

- User wants the Accessibility Keyboard (macOS on-screen keyboard) to serve as a bail-out — if clicks on it can be detected and passed through, the user always has a way to interact even when scroll mode captures mouse events
- Click-through setting exists so behavior can be toggled off if it doesn't feel right — this is a safety valve for the feature itself

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-click-safety*
*Context gathered: 2026-02-15*
