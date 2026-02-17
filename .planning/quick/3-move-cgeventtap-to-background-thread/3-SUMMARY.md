---
phase: quick-3
plan: 01
subsystem: core-scroll-engine
tags: [cgeventtap, threading, cfrunloop, event-tap, background-thread]

# Dependency graph
requires:
  - phase: 06-osk-aware-click-pass-through
    provides: WindowExclusionManager with OSK frame caching
provides:
  - Background-threaded CGEventTap that never blocks on main-thread UI work
  - Cached app window frames for thread-safe click pass-through
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns: [dedicated Thread + CFRunLoop for CGEventTap, cached window frames for thread-safe hit testing]

key-files:
  created: []
  modified:
    - ScrollMyMac/Services/ScrollEngine.swift
    - ScrollMyMac/Services/WindowExclusionManager.swift
    - ScrollMyMac/App/AppState.swift

key-decisions:
  - "No locks needed for drag state — tap is disabled before stop()/tearDown() touch state"
  - "App window frames cached alongside OSK frames in existing timer-based refresh"

patterns-established:
  - "Background event tap: CGEventTap runs on dedicated Thread with CFRunLoop, never main thread"
  - "UI callbacks from event tap: always wrap onDragStateChanged in DispatchQueue.main.async"

requirements-completed: [QUICK-3]

# Metrics
duration: 2min
completed: 2026-02-17
---

# Quick Task 3: Move CGEventTap to Background Thread Summary

**CGEventTap moved to dedicated background thread with cached app window frames for fully thread-safe event processing**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-17T19:15:11Z
- **Completed:** 2026-02-17T19:17:38Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- WindowExclusionManager caches app window frames (CG coordinates) alongside existing OSK frame caching
- shouldPassThroughClick closure makes zero AppKit calls, safe from any thread
- CGEventTap runs on dedicated background thread named "com.blakewatson.ScrollMyMac.EventTap"
- All UI-touching callbacks (onDragStateChanged) dispatch to main thread
- macOS no longer disables the event tap under main-thread UI contention

## Task Commits

Each task was committed atomically:

1. **Task 1: Cache app window frames in WindowExclusionManager** - `93bf3ca` (feat)
2. **Task 2: Move CGEventTap to dedicated background thread** - `a2838da` (feat)

## Files Created/Modified
- `ScrollMyMac/Services/WindowExclusionManager.swift` - Added appWindowRects cache, isPointInAppWindow(), app window frame caching in refreshCache()
- `ScrollMyMac/App/AppState.swift` - Replaced NSApp.windows access with cached WindowExclusionManager lookups
- `ScrollMyMac/Services/ScrollEngine.swift` - Added background Thread + CFRunLoop for event tap, wrapped onDragStateChanged in main-thread dispatch

## Decisions Made
- No locks needed for drag state: the tap is disabled before stop()/tearDown() access shared state, so there is no concurrent access
- App window frames cached in existing timer refresh (0.5s/2.0s intervals) — app windows move rarely so this is sufficient
- OverlayManager.updatePosition already handles thread dispatch internally, no changes needed

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Event tap is now resilient to main-thread contention
- No further changes needed unless additional thread-safety concerns arise

## Self-Check: PASSED

- All 3 modified files exist on disk
- Commit 93bf3ca (Task 1) verified in git log
- Commit a2838da (Task 2) verified in git log
- SUMMARY.md exists at expected path

---
*Phase: quick-3*
*Completed: 2026-02-17*
