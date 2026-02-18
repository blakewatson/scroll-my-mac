---
phase: 12-per-app-exclusion
plan: 01
subsystem: services
tags: [nsworkspace, cgeventtap, nsbezierpath, userdefaults, menu-bar]

# Dependency graph
requires:
  - phase: 10-menu-bar-icon
    provides: MenuBarManager with programmatic NSBezierPath icon
provides:
  - AppExclusionManager service with frontmost-app detection and exclusion list
  - ScrollEngine shouldBypassAllEvents closure for full event passthrough
  - Menu bar slash icon overlay and contextual tooltip
affects: [12-per-app-exclusion plan 02 (settings UI)]

# Tech tracking
tech-stack:
  added: []
  patterns: [NSWorkspace.didActivateApplicationNotification for app-switch detection, callback-based state propagation between services]

key-files:
  created:
    - ScrollMyMac/Services/AppExclusionManager.swift
  modified:
    - ScrollMyMac/Services/ScrollEngine.swift
    - ScrollMyMac/App/AppState.swift
    - ScrollMyMac/Services/MenuBarManager.swift
    - ScrollMyMac.xcodeproj/project.pbxproj

key-decisions:
  - "Stale bundle IDs kept in exclusion list (no harm, user can remove via settings)"
  - "Hotkey toggle works normally in excluded apps (global state vs per-app bypass)"
  - "AppExclusionManager always monitors (not tied to scroll mode) so menu bar icon is correct at activation"

patterns-established:
  - "Per-app exclusion: callback from AppExclusionManager through AppState to ScrollEngine and MenuBarManager"
  - "shouldBypassAllEvents checked in C callback bridge before event type switch"

requirements-completed: [EXCL-01, EXCL-02]

# Metrics
duration: 2min
completed: 2026-02-17
---

# Phase 12 Plan 01: Per-App Exclusion Engine Summary

**AppExclusionManager with NSWorkspace frontmost-app detection, ScrollEngine full-event bypass, and menu bar slash icon overlay**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-18T03:40:10Z
- **Completed:** 2026-02-18T03:42:42Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Created AppExclusionManager that detects frontmost app switches via NSWorkspace notifications and manages a persistent exclusion list
- Added shouldBypassAllEvents closure to ScrollEngine C callback for complete event passthrough when excluded app is frontmost
- Implemented slash icon overlay and contextual tooltip in MenuBarManager with shared applyIconState() method

## Task Commits

Each task was committed atomically:

1. **Task 1: Create AppExclusionManager and wire exclusion bypass** - `56e78e4` (feat)
2. **Task 2: Add slash icon overlay and contextual tooltip** - `cffe1b7` (feat)

## Files Created/Modified
- `ScrollMyMac/Services/AppExclusionManager.swift` - Frontmost app detection, exclusion list management, UserDefaults persistence
- `ScrollMyMac/Services/ScrollEngine.swift` - shouldBypassAllEvents closure checked in C callback bridge
- `ScrollMyMac/App/AppState.swift` - Wires exclusion manager to scroll engine and menu bar, add/remove methods, resetToDefaults
- `ScrollMyMac/Services/MenuBarManager.swift` - Slash icon overlay, contextual tooltip, shared applyIconState method
- `ScrollMyMac.xcodeproj/project.pbxproj` - Added AppExclusionManager.swift to project

## Decisions Made
- Stale bundle IDs kept in exclusion list -- they cause no harm and can be removed from settings UI
- Hotkey and menu bar toggle work normally in excluded apps -- toggle controls global state, exclusion controls per-app bypass
- AppExclusionManager monitoring starts in setupServices() (always running) so menu bar state is correct when scroll mode activates
- Diagonal slash from (3,2) to (15,16) with lineWidth 1.5 for standard macOS "disabled" visual pattern

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added stub updateExclusionState to MenuBarManager for Task 1 compilation**
- **Found during:** Task 1 (AppExclusionManager wiring)
- **Issue:** AppState.setupServices() calls menuBarManager.updateExclusionState() which didn't exist yet (Task 2 work)
- **Fix:** Added minimal stub with stored properties; fully implemented in Task 2
- **Files modified:** ScrollMyMac/Services/MenuBarManager.swift
- **Verification:** Build succeeded after adding stub
- **Committed in:** 56e78e4 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary to compile Task 1 since wiring referenced Task 2's method. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Exclusion engine fully wired and working
- Plan 02 can add settings UI for managing the exclusion list (add/remove apps)
- AppState already exposes addExcludedApp/removeExcludedApp and excludedBundleIDs for UI binding

---
*Phase: 12-per-app-exclusion*
*Completed: 2026-02-17*
