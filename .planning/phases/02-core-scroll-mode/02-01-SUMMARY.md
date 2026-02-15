---
phase: 02-core-scroll-mode
plan: 01
subsystem: services
tags: [cgeventtap, scrollwheel, hotkey, cocoa, carbon, swift]

# Dependency graph
requires:
  - phase: 01-permissions-app-shell
    provides: "Accessibility permission flow, app shell, SafetyTimeoutManager"
provides:
  - "ScrollEngine: CGEventTap mouse interception with drag-to-scroll conversion"
  - "HotkeyManager: Global F6 hotkey detection via CGEventTap on keyDown"
affects: [02-02-PLAN (wiring to AppState), 03-click-safety, 04-inertia, 05-settings]

# Tech tracking
tech-stack:
  added: [CoreGraphics CGEventTap, Carbon.HIToolbox kVK_F6]
  patterns: [C callback bridge via Unmanaged pointer, file-level callback functions, fileprivate tap access]

key-files:
  created:
    - ScrollMyMac/Services/ScrollEngine.swift
    - ScrollMyMac/Services/HotkeyManager.swift
  modified:
    - ScrollMyMac.xcodeproj/project.pbxproj

key-decisions:
  - "Used fileprivate for eventTap so file-level C callback can re-enable on timeout"
  - "CGEvent scrollWheelEvent2 with wheelCount 3 (all params required by Swift API)"
  - "Scroll phases set via setIntegerValueField for trackpad-like behavior across apps"
  - "tearDown() method separate from stop() for clean app termination vs toggle"

patterns-established:
  - "C callback bridge: file-level function + Unmanaged.passUnretained(self) for CGEventTap userInfo"
  - "Event tap lifecycle: create once, enable/disable on toggle, tearDown on quit"
  - "Axis lock: accumulate abs deltas, lock after 5px threshold, reset on mouseUp"

# Metrics
duration: 3min
completed: 2026-02-15
---

# Phase 2 Plan 01: Core Event Tap Services Summary

**ScrollEngine drag-to-scroll via CGEventTap with axis lock and natural direction, plus HotkeyManager F6 global hotkey detection**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-15T14:55:35Z
- **Completed:** 2026-02-15T14:58:13Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- ScrollEngine intercepts leftMouseDown/Dragged/Up and converts drag deltas to synthetic pixel-precision scroll wheel events
- Natural scroll direction implemented (drag down = content moves down) with axis lock after 5px threshold
- Scroll phase tracking (began/changed/ended) for smooth behavior across apps
- HotkeyManager detects F6 globally via CGEventTap keyDown with modifier combo support structure for Phase 5
- Both services handle tapDisabledByTimeout by re-enabling

## Task Commits

Each task was committed atomically:

1. **Task 1: Create ScrollEngine with CGEventTap mouse interception and drag-to-scroll** - `ea89784` (feat)
2. **Task 2: Create HotkeyManager with global F6 detection via CGEventTap** - `8be6193` (feat)

## Files Created/Modified
- `ScrollMyMac/Services/ScrollEngine.swift` - CGEventTap mouse interception, drag-to-scroll conversion with axis lock, natural direction, scroll phases
- `ScrollMyMac/Services/HotkeyManager.swift` - Global F6 hotkey detection via CGEventTap keyDown, callback-based toggle, modifier support
- `ScrollMyMac.xcodeproj/project.pbxproj` - Added both new files to Xcode project (PBXFileReference, PBXBuildFile, PBXGroup, PBXSourcesBuildPhase)

## Decisions Made
- Used `fileprivate` access for `eventTap` property so the file-level C callback function can access it for timeout re-enabling
- Used `wheelCount: 3` with all parameters for CGEvent scrollWheelEvent2 (Swift API requires all wheel params)
- Added `tearDown()` method separate from `stop()` -- stop disables the tap, tearDown destroys it (for app quit)
- Scroll phases set via `setIntegerValueField(.scrollWheelEventScrollPhase)` for trackpad-like behavior

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed CGEvent scrollWheelEvent2 API signature**
- **Found during:** Task 1 (ScrollEngine build verification)
- **Issue:** CGEvent(scrollWheelEvent2Source:) requires wheel3 parameter -- Swift compiler error with only wheel1/wheel2
- **Fix:** Changed to wheelCount: 3 with wheel3: 0 for all scroll events
- **Files modified:** ScrollMyMac/Services/ScrollEngine.swift
- **Verification:** Build succeeded
- **Committed in:** ea89784 (Task 1 commit)

**2. [Rule 1 - Bug] Fixed eventTap access level for C callback**
- **Found during:** Task 1 (ScrollEngine build verification)
- **Issue:** `private var eventTap` inaccessible from file-level callback function needed for tapDisabledByTimeout re-enabling
- **Fix:** Changed to `fileprivate var eventTap` so the callback in the same file can access it
- **Files modified:** ScrollMyMac/Services/ScrollEngine.swift
- **Verification:** Build succeeded
- **Committed in:** ea89784 (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (2 bugs)
**Impact on plan:** Both fixes required for compilation. No scope creep.

## Issues Encountered
None beyond the compile fixes documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- ScrollEngine and HotkeyManager are self-contained services with callback-based APIs
- Ready for Plan 02 to wire them into AppState for toggle coordination
- Neither service is started yet -- Plan 02 will handle lifecycle integration

---
*Phase: 02-core-scroll-mode*
*Completed: 2026-02-15*

## Self-Check: PASSED

- ScrollEngine.swift: FOUND
- HotkeyManager.swift: FOUND
- Commit ea89784: FOUND
- Commit 8be6193: FOUND
- CGEvent.tapCreate in ScrollEngine: FOUND
- scrollWheelEvent2Source in ScrollEngine: FOUND
- kVK_F6 in HotkeyManager: FOUND
- tapDisabledByTimeout in both: FOUND
