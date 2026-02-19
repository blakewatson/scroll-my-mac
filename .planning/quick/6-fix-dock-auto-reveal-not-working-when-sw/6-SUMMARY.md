---
phase: quick-6
plan: 6
subsystem: ui
tags: [cgeventtap, scroll-engine, mouse-events, window-server, dock]

# Dependency graph
requires:
  - phase: 12-per-app-exclusion
    provides: shouldBypassAllEvents closure and excluded-app NSWorkspace notification path
provides:
  - handleMouseUp guard that passes through events when no interaction state is tracked
affects: [scroll-engine, per-app-exclusion]

# Tech tracking
tech-stack:
  added: []
  patterns: [guard-against-orphaned-events, no-tracked-state-passthrough]

key-files:
  created: []
  modified:
    - ScrollMyMac/Services/ScrollEngine.swift

key-decisions:
  - "Pass through mouseUp when engine has no tracked state (pendingMouseDown, isDragging, isInPassthroughMode all false) to prevent window server orphan"

patterns-established:
  - "Orphaned event guard: when event tap intercepts a mouseUp with no record of the corresponding mouseDown, pass it through rather than suppress"

requirements-completed: [QUICK-6]

# Metrics
duration: 1min
completed: 2026-02-19
---

# Quick Task 6: Fix Dock Auto-Reveal Not Working When Switching Apps Summary

**Race-condition fix in handleMouseUp: passes through mouseUp events when engine has no tracked interaction state, preventing window server orphan that blocked Dock auto-reveal**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-02-19T16:44:41Z
- **Completed:** 2026-02-19T16:45:30Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Fixed race condition between per-app exclusion bypass (background thread) and NSWorkspace app-switch notification (main thread)
- Added guard in handleMouseUp that returns `Unmanaged.passUnretained(event)` when `!pendingMouseDown && !isDragging && !isInPassthroughMode`
- Prevents window server from believing a left mouse button is still held after clicking from an excluded app to a non-excluded app window

## Task Commits

Each task was committed atomically:

1. **Task 1: Guard against orphaned mouseUp suppression in handleMouseUp** - `35137e0` (fix)

## Files Created/Modified
- `ScrollMyMac/Services/ScrollEngine.swift` - Added early-return guard in handleMouseUp for no-tracked-state case

## Decisions Made
- Include `passedThroughClick = false` in the guard branch to clean up any stale value, mirroring the existing passedThroughClick branch pattern

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

All quick tasks complete. No blockers.

---
*Phase: quick-6*
*Completed: 2026-02-19*
