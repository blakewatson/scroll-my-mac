---
phase: 10-menu-bar-icon
plan: 01
subsystem: ui
tags: [NSStatusItem, menu-bar, AppKit, NSBezierPath, template-image]

# Dependency graph
requires:
  - phase: 01-permissions-app-shell
    provides: AppState service architecture and settings window
provides:
  - Menu bar status item with scroll mode toggle
  - Right-click context menu with Settings and Quit
  - Settings toggle to show/hide menu bar icon
  - Programmatic mouse icon drawn via NSBezierPath
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns: [programmatic-template-image, NSStatusItem-left-right-click]

key-files:
  created:
    - ScrollMyMac/Services/MenuBarManager.swift
  modified:
    - ScrollMyMac/App/AppState.swift
    - ScrollMyMac/Features/Settings/SettingsView.swift
    - ScrollMyMac.xcodeproj/project.pbxproj

key-decisions:
  - "Programmatic NSBezierPath icon instead of PDF asset — avoids asset catalog complexity"
  - "MenuBarManager is plain class (not @Observable) — pure AppKit, no SwiftUI observation needed"

patterns-established:
  - "Menu bar icon: programmatic template image via NSBezierPath for macOS light/dark auto-coloring"
  - "Left/right click distinction via sendAction(on:) and NSApp.currentEvent type check"

requirements-completed: [MBAR-01, MBAR-02, MBAR-03, MBAR-04]

# Metrics
duration: 2min
completed: 2026-02-17
---

# Phase 10 Plan 01: Menu Bar Icon Summary

**NSStatusItem with programmatic mouse icon, left-click scroll toggle, right-click context menu, and settings visibility control**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-18T00:51:12Z
- **Completed:** 2026-02-18T00:53:08Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Menu bar icon with programmatic mouse outline drawn via NSBezierPath (template image for auto light/dark)
- Left-click toggles scroll mode, right-click shows context menu with Settings... and Quit
- Icon opacity reflects scroll mode state (1.0 active, 0.4 inactive)
- Settings toggle to show/hide the menu bar icon with UserDefaults persistence

## Task Commits

Each task was committed atomically:

1. **Task 1: Create MenuBarManager service with custom icon and wire into AppState** - `76b8e25` (feat)
2. **Task 2: Add menu bar icon toggle to settings UI** - `2ae9e2c` (feat)

## Files Created/Modified
- `ScrollMyMac/Services/MenuBarManager.swift` - NSStatusItem management with show/hide, left/right click handling, programmatic icon
- `ScrollMyMac/App/AppState.swift` - Added isMenuBarIconEnabled property, menuBarManager service, wiring in setupServices
- `ScrollMyMac/Features/Settings/SettingsView.swift` - Added "Show menu bar icon" toggle in General section
- `ScrollMyMac.xcodeproj/project.pbxproj` - Added MenuBarManager.swift to build sources

## Decisions Made
- Used programmatic NSBezierPath icon instead of PDF asset to avoid asset catalog complexity
- MenuBarManager is a plain class (not @Observable) since it is pure AppKit with no SwiftUI observation needed
- Used `popUp(positioning:at:in:)` for right-click context menu display

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Menu bar icon feature complete and ready for use
- Independent of phases 11 and 12 which can proceed in any order

## Self-Check: PASSED

- FOUND: ScrollMyMac/Services/MenuBarManager.swift
- FOUND: commit 76b8e25
- FOUND: commit 2ae9e2c
- FOUND: 10-01-SUMMARY.md

---
*Phase: 10-menu-bar-icon*
*Completed: 2026-02-17*
