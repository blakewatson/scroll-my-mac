---
phase: 03-click-safety
plan: 01
subsystem: input-handling
tags: [cgevent, click-through, dead-zone, event-tap, swiftui]

# Dependency graph
requires:
  - phase: 02-core-scroll-mode
    provides: ScrollEngine with CGEventTap mouse interception
provides:
  - Hold-and-decide click-through with dead zone detection
  - Click replay via synthetic CGEvent mouseDown/mouseUp
  - Modifier-key and double-click pass-through
  - User-facing click-through toggle in Settings
affects: [03-click-safety]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Hold-and-decide pattern: suppress mouseDown, decide on drag vs click based on movement threshold"
    - "Click replay via CGEvent post with isReplayingClick re-entry guard"
    - "Modifier key detection using CGEventFlags.intersection (not contains)"

key-files:
  created: []
  modified:
    - ScrollMyMac/Services/ScrollEngine.swift
    - ScrollMyMac/App/AppState.swift
    - ScrollMyMac/Features/Settings/SettingsView.swift

key-decisions:
  - "8px dead zone threshold for click vs drag discrimination"
  - "Replay click at original mouseDown position (not mouseUp position)"
  - "Synchronous isReplayingClick flag works because event tap callback runs on same run loop"
  - "stop() discards pending click without replaying (user intent is to toggle off)"

patterns-established:
  - "Hold-and-decide: pendingMouseDown state with dead zone check before committing to scroll or click"
  - "Click replay: synthetic mouseDown+mouseUp pair posted via .cghidEventTap with clickState preserved"

# Metrics
duration: 2min
completed: 2026-02-15
---

# Phase 3 Plan 1: Click-Through Summary

**Hold-and-decide click-through with 8px dead zone, modifier pass-through, double-click support, and Settings toggle**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-15T20:53:15Z
- **Completed:** 2026-02-15T20:55:28Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- ScrollEngine now uses hold-and-decide model: clicks within 8px dead zone are replayed as normal clicks, drags beyond 8px trigger scrolling
- Modifier-key clicks (Cmd, Shift, Option, Ctrl) always pass through immediately without interception
- Double-click support via preserved mouseEventClickState on synthetic events
- Click-through toggle added to Settings UI with UserDefaults persistence (default: on)

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement hold-and-decide click-through in ScrollEngine** - `3647cf7` (feat)
2. **Task 2: Add click-through setting to AppState and Settings UI** - `ccf667a` (feat)

## Files Created/Modified
- `ScrollMyMac/Services/ScrollEngine.swift` - Hold-and-decide state machine with dead zone detection, click replay, modifier pass-through, and re-entry guard
- `ScrollMyMac/App/AppState.swift` - isClickThroughEnabled property with UserDefaults persistence and ScrollEngine wiring
- `ScrollMyMac/Features/Settings/SettingsView.swift` - Click-through toggle in Scroll Mode section with help text

## Decisions Made
- 8px dead zone threshold balances click accuracy with intentional drag detection
- Click replayed at original mouseDown position (matches user intent for clicking buttons/links)
- isReplayingClick flag is synchronous (not DispatchQueue-deferred) because CGEvent tap callback and post happen on same run loop
- stop() discards pending clicks silently rather than replaying (user toggled off, so clicking wasn't their intent)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Click-through feature complete and ready for manual verification
- Plan 03-02 (verification and edge cases) can proceed
- Right-clicks already pass through (event mask only includes left mouse events)

## Self-Check: PASSED

All files verified present. All commit hashes verified in git log.

---
*Phase: 03-click-safety*
*Completed: 2026-02-15*
