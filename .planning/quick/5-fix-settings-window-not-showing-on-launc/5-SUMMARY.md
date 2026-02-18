---
phase: quick-5
plan: 1
subsystem: ui
tags: [swiftui, window-lifecycle, nsstatusitem, appkit]

requires:
  - phase: 10-menu-bar-icon
    provides: MenuBarManager with show/hide/applyIconState
  - phase: 11-hold-to-passthrough
    provides: AppDelegate window management

provides:
  - Single-window settings lifecycle (no duplicate windows)
  - Menu bar icon state restoration on toggle

affects: []

tech-stack:
  added: []
  patterns:
    - "SwiftUI Window (not WindowGroup) for single-window apps"
    - "Deferred window setup via DispatchQueue.main.async for SwiftUI timing"

key-files:
  created: []
  modified:
    - ScrollMyMac/ScrollMyMacApp.swift
    - ScrollMyMac/App/AppDelegate.swift
    - ScrollMyMac/Services/MenuBarManager.swift

key-decisions:
  - "Replaced WindowGroup with Window scene to prevent duplicate window creation"
  - "Deferred applicationDidFinishLaunching window setup to next run loop to handle SwiftUI timing"

patterns-established:
  - "Window scene for single-window apps: prevents SwiftUI from creating extra instances on dock reopen"

requirements-completed: [FIX-WINDOW-LAUNCH, FIX-WINDOW-DOUBLE, FIX-MENUBAR-RESTORE]

duration: 1min
completed: 2026-02-18
---

# Quick Task 5: Fix Settings Window Not Showing on Launch Summary

**Single Window scene replaces WindowGroup to fix launch visibility, dock-click duplicates, and menu bar icon restoration**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-18T05:08:43Z
- **Completed:** 2026-02-18T05:09:27Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Replaced WindowGroup with Window scene to prevent duplicate settings windows on dock click
- Deferred window setup in applicationDidFinishLaunching to fix SwiftUI timing issue where window was nil
- Added applyIconState() call in MenuBarManager.show() to restore correct icon state after toggle

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix settings window lifecycle (launch + dock click)** - `86ffaa8` (fix)
2. **Task 2: Fix menu bar icon toggle restore** - `857e246` (fix)

## Files Created/Modified
- `ScrollMyMac/ScrollMyMacApp.swift` - Changed WindowGroup to Window("Scroll My Mac", id: "settings")
- `ScrollMyMac/App/AppDelegate.swift` - Deferred window setup to next run loop, explicit show on normal launch
- `ScrollMyMac/Services/MenuBarManager.swift` - Added applyIconState() at end of show()

## Decisions Made
- Replaced WindowGroup with Window scene -- Window is designed for single-instance windows (preferences/settings) and prevents SwiftUI from creating new instances on dock reopen
- Deferred applicationDidFinishLaunching window setup via DispatchQueue.main.async to handle cases where SwiftUI has not yet created the Window scene

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Self-Check: PASSED

All files exist, all commits verified (86ffaa8, 857e246).

---
*Quick Task: 5*
*Completed: 2026-02-18*
