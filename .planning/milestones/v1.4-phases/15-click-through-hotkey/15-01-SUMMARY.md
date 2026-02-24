---
phase: 15-click-through-hotkey
plan: 01
subsystem: ui
tags: [hotkey, settings, HotkeyManager, CGEventTap, UserDefaults]

# Dependency graph
requires:
  - phase: 05-settings-polish
    provides: HotkeyRecorderView component and HotkeyManager service
provides:
  - Click-through hotkey toggle via independent HotkeyManager instance
  - Persistent click-through hotkey key code and modifiers in UserDefaults
  - HotkeyRecorderView in Settings UI for click-through hotkey assignment
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns: [second independent HotkeyManager instance for feature toggle]

key-files:
  created: []
  modified:
    - ScrollMyMac/App/AppState.swift
    - ScrollMyMac/Features/Settings/SettingsView.swift

key-decisions:
  - "Reused existing HotkeyManager class as second instance rather than subclassing or parameterizing"
  - "Click-through hotkey defaults to None (keyCode -1) unlike scroll mode hotkey which defaults to F6"

patterns-established:
  - "Multiple HotkeyManager instances: each feature hotkey gets its own HotkeyManager with independent lifecycle"

requirements-completed: [CTHK-01, CTHK-02, CTHK-03]

# Metrics
duration: 2min
completed: 2026-02-23
---

# Phase 15 Plan 01: Click-Through Hotkey Summary

**Configurable click-through toggle hotkey with independent HotkeyManager, UserDefaults persistence, and key recorder in Settings UI**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-23T06:19:42Z
- **Completed:** 2026-02-23T06:21:23Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Added second HotkeyManager instance for click-through toggle, fully independent of scroll mode hotkey
- Added clickThroughHotkeyKeyCode and clickThroughHotkeyModifiers properties with UserDefaults persistence and didSet wiring
- Added HotkeyRecorderView in Settings Scroll Behavior section for click-through hotkey assignment
- Click-through hotkey starts/stops with accessibility permission changes and resets to None on defaults reset

## Task Commits

Each task was committed atomically:

1. **Task 1: Add click-through HotkeyManager and AppState wiring** - `fded94b` (feat)
2. **Task 2: Add click-through hotkey recorder to Settings UI** - `0772ab2` (feat)

**Plan metadata:** _pending_ (docs: complete plan)

## Files Created/Modified
- `ScrollMyMac/App/AppState.swift` - Added clickThroughHotkeyManager, keyCode/modifiers properties, applyClickThroughHotkeySettings(), wiring in setupServices/isAccessibilityGranted/resetToDefaults
- `ScrollMyMac/Features/Settings/SettingsView.swift` - Added HotkeyRecorderView for click-through hotkey after click-through toggle in Scroll Behavior section

## Decisions Made
- Reused existing HotkeyManager class as a second instance rather than subclassing -- the class is already generic enough for any toggle hotkey
- Click-through hotkey defaults to None (keyCode -1) unlike scroll mode hotkey which defaults to F6, since this is an optional power-user feature

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 15 is the final phase; all planned features are now complete
- The click-through hotkey follows the same patterns as scroll mode hotkey for consistency

## Self-Check: PASSED

- [x] AppState.swift exists and modified
- [x] SettingsView.swift exists and modified
- [x] 15-01-SUMMARY.md created
- [x] Commit fded94b verified
- [x] Commit 0772ab2 verified

---
*Phase: 15-click-through-hotkey*
*Completed: 2026-02-23*
