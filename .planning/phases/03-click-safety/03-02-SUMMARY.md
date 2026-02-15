---
phase: 03-click-safety
plan: 02
subsystem: reliability
tags: [accessibility, permission-monitoring, state-cleanup, CGEventTap]

# Dependency graph
requires:
  - phase: 03-click-safety/01
    provides: "Hold-and-decide click-through model with pendingMouseDown state"
  - phase: 02-core-scroll-mode
    provides: "ScrollEngine with event tap, start/stop lifecycle"
provides:
  - "Permission health polling during scroll mode (2s interval)"
  - "Graceful permission revocation handling with UI state update"
  - "Mid-drag scroll-ended event posting on stop() and tearDown()"
  - "Clean mid-toggle state reset without replaying pending clicks"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Timer-based health polling with weak self capture"
    - "Defensive AXIsProcessTrusted check in C callback"

key-files:
  created: []
  modified:
    - ScrollMyMac/App/AppState.swift
    - ScrollMyMac/Services/ScrollEngine.swift

key-decisions:
  - "Permission health poll interval set to 2s (balance between responsiveness and overhead)"
  - "stop() discards pending clicks without replaying (user intent is toggle-off, not click)"
  - "No auto-re-enable of scroll mode after permission re-grant (user must press F6)"
  - "scroll-ended event posted before tap disable in stop() to ensure apps receive clean end"

patterns-established:
  - "Health timer pattern: start on activate, stop on deactivate, invalidate+nil on cleanup"

# Metrics
duration: 2min
completed: 2026-02-15
---

# Phase 3 Plan 2: Permission Health Monitoring Summary

**Permission health polling every 2s with graceful revocation handling and mid-drag scroll-ended cleanup in stop()/tearDown()**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-15T20:57:42Z
- **Completed:** 2026-02-15T20:59:12Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Permission health timer polls AXIsProcessTrusted() every 2s while scroll mode is active
- On permission revocation: scroll mode disabled, accessibility state updated, UI shows warning
- Mid-drag stop()/tearDown() posts kCGScrollPhaseEnded for clean app behavior
- tapDisabledByTimeout handler checks permission before re-enabling event tap

## Task Commits

Each task was committed atomically:

1. **Task 1: Add permission health check polling to AppState** - `752bdc3` (feat)
2. **Task 2: Ensure robust mid-toggle and mid-drag cleanup** - `c95a2c3` (feat)

## Files Created/Modified
- `ScrollMyMac/App/AppState.swift` - Added permissionHealthTimer, start/stop/handlePermissionLost methods, wired into activate/deactivate
- `ScrollMyMac/Services/ScrollEngine.swift` - Added scroll-ended posting in stop()/tearDown(), AXIsProcessTrusted check in tapDisabledByTimeout

## Decisions Made
- Permission health poll interval: 2 seconds (responsive enough for user safety, low overhead)
- No auto-re-enable after permission re-grant (user must manually press F6 -- matches existing recovery flow)
- scroll-ended event posted before disabling tap in stop() so target apps see clean scroll termination
- stop() discards pending clicks without replaying (user toggling off doesn't intend to click)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- xcodebuild required DEVELOPER_DIR override (xcode-select pointed to CommandLineTools) -- used env var workaround

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 3 (Click Safety) is complete -- both plans executed
- All must-have truths satisfied: permission revocation handling, mid-drag cleanup, mid-toggle safety
- Ready for Phase 4 (Inertia) or Phase 5 (Polish)

## Self-Check: PASSED

- FOUND: ScrollMyMac/App/AppState.swift
- FOUND: ScrollMyMac/Services/ScrollEngine.swift
- FOUND: .planning/phases/03-click-safety/03-02-SUMMARY.md
- FOUND: 752bdc3 (Task 1 commit)
- FOUND: c95a2c3 (Task 2 commit)

---
*Phase: 03-click-safety*
*Completed: 2026-02-15*
