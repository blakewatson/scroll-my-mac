---
phase: 06-osk-aware-click-pass-through
plan: 01
subsystem: ui
tags: [accessibility, window-management, core-graphics, osk, event-tap]

# Dependency graph
requires:
  - phase: 02-core-scroll-mode
    provides: "ScrollEngine with shouldPassThroughClick closure"
provides:
  - "WindowExclusionManager service for detecting OSK windows via CGWindowListCopyWindowInfo"
  - "OSK click pass-through integration in shouldPassThroughClick closure"
  - "Timer-based window polling with adaptive rate (500ms active, 2s passive)"
  - "Layer-based filtering to exclude full-screen system overlay windows"
affects: [future-window-exclusions, click-safety-enhancements]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Timer-based window polling with adaptive rate based on detection state"
    - "CGRect hit-testing cache for fast event-tap path performance"
    - "Layer filtering (<1000) to distinguish UI windows from system overlays"
    - "RunLoop.main.add with .common mode for event-tracking compatibility"

key-files:
  created:
    - ScrollMyMac/Services/WindowExclusionManager.swift
  modified:
    - ScrollMyMac/App/AppState.swift
    - ScrollMyMac.xcodeproj/project.pbxproj

key-decisions:
  - "Process name is 'AssistiveControl' (no space) — verified empirically"
  - "AssistiveControl has 3 windows: 2 full-screen overlays (layers 2996/2997) and 1 keyboard panel (layer 101)"
  - "Filter windows by layer < 1000 to exclude system overlays and only cache the actual keyboard"
  - "Timer scheduled in .common run loop mode to fire during event tracking"
  - "Adaptive polling: 500ms when OSK detected (tracks repositioning), 2s when not detected (watches for appearance)"
  - "No coordinate conversion needed — both CGEvent.location and kCGWindowBounds use CG coordinates (top-left origin)"

patterns-established:
  - "WindowExclusionManager pattern: Timer polls window list → caches bounds → isPointExcluded() reads cache (no IPC in event-tap path)"
  - "shouldPassThroughClick OR chaining: Check 1 (app windows) || Check 2 (excluded windows)"
  - "Start/stop monitoring lifecycle tied to scroll mode activation/deactivation"

# Metrics
duration: 113min
completed: 2026-02-16
---

# Phase 6 Plan 1: WindowExclusionManager Summary

**Timer-based OSK detection with CGWindowListCopyWindowInfo polling, layer filtering (<1000) to exclude system overlays, and integration into shouldPassThroughClick for instant click pass-through over the Accessibility Keyboard**

## Performance

- **Duration:** 1h 53min
- **Started:** 2026-02-16T20:04:53Z
- **Completed:** 2026-02-16T21:58:17Z
- **Tasks:** 2 (1 auto, 1 human-verify)
- **Files modified:** 3

## Accomplishments
- Created WindowExclusionManager service with timer-based CGWindowList polling and CGRect caching
- Integrated OSK detection into shouldPassThroughClick as second OR condition (preserving existing app-window check)
- Implemented adaptive polling rate (500ms when OSK visible, 2s when hidden) to balance responsiveness and performance
- Discovered and fixed critical layer filtering issue to exclude AssistiveControl's full-screen overlay windows
- Corrected OSK process name to "AssistiveControl" (no space) via empirical verification
- Fixed timer run loop mode to .common for compatibility with event tracking

## Task Commits

Each task was committed atomically:

1. **Task 1: Create WindowExclusionManager and wire into AppState** - `928275e` (feat)
2. **Task 2: Verify OSK click pass-through works end-to-end** - Human verification checkpoint (approved)

**Follow-up fix:** `bb3c0d9` (fix) - Corrected process name, added layer filtering, fixed run loop mode

_Note: The follow-up fix was applied after initial verification revealed OSK was not being detected._

## Files Created/Modified
- `ScrollMyMac/Services/WindowExclusionManager.swift` - New service that polls CGWindowListCopyWindowInfo to detect AssistiveControl windows, filters by layer < 1000 to exclude system overlays, caches OSK panel bounds, and provides isPointExcluded() for fast hit-testing in event-tap path
- `ScrollMyMac/App/AppState.swift` - Wired WindowExclusionManager into shouldPassThroughClick closure as second OR condition (after app-window check), added start/stopMonitoring calls in activate/deactivateScrollMode
- `ScrollMyMac.xcodeproj/project.pbxproj` - Added WindowExclusionManager.swift to build sources

## Decisions Made

**OSK Process Name Discovery:**
- Plan assumed "Assistive Control" (with space) at MEDIUM confidence
- Empirical verification (CGWindowListCopyWindowInfo output) revealed actual name is "AssistiveControl" (no space)
- Rationale: Runtime verification was critical — incorrect process name would cause complete detection failure

**Layer Filtering for System Overlays:**
- AssistiveControl process has 3 windows: 2 full-screen overlays at layers 2996 and 2997, plus 1 keyboard panel at layer 101
- Added layer < 1000 filter to exclude the overlay windows and only cache the actual keyboard
- Rationale: Without filtering, entire screen would be treated as pass-through zone (scroll mode completely disabled)

**Timer Run Loop Mode:**
- Changed from default run loop mode to .common mode
- Rationale: Default mode doesn't fire during event tracking (e.g., while dragging), causing stale cache and missed OSK repositioning

**Adaptive Polling Rate:**
- 500ms when OSK detected (tracks repositioning), 2s when not detected (watches for appearance)
- Rationale: Balance between responsiveness (detecting OSK moves) and performance (not polling continuously when OSK is hidden)

**No Coordinate Conversion:**
- Both CGEvent.location and kCGWindowBounds use CG coordinates (top-left origin)
- No NS coordinate conversion applied to OSK bounds
- Rationale: Coordinate system mismatch would offset hit-testing rectangles, causing pass-through to fail

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected OSK process name from "Assistive Control" to "AssistiveControl"**
- **Found during:** Task 2 (human verification checkpoint)
- **Issue:** Initial implementation used "Assistive Control" (with space) as specified in plan. Human verification revealed OSK clicks were not passing through. Diagnostic output showed actual process name is "AssistiveControl" (no space).
- **Fix:** Changed targetOwnerName constant from "Assistive Control" to "AssistiveControl"
- **Files modified:** ScrollMyMac/Services/WindowExclusionManager.swift
- **Verification:** Rebuilt and re-verified with Accessibility Keyboard — detection now works
- **Committed in:** bb3c0d9 (follow-up fix commit)

**2. [Rule 1 - Bug] Added layer filtering to exclude full-screen system overlay windows**
- **Found during:** Task 2 (human verification checkpoint) after fixing process name
- **Issue:** AssistiveControl process has 3 windows: 2 full-screen overlays (layers 2996, 2997) and 1 keyboard panel (layer 101). Without filtering, all 3 windows were cached, causing the entire screen to be treated as pass-through zone (scroll mode disabled everywhere).
- **Fix:** Added `layer < 1000` filter in refreshCache() compactMap to exclude high-layer system overlays and only cache the actual keyboard panel
- **Files modified:** ScrollMyMac/Services/WindowExclusionManager.swift
- **Verification:** Re-verified with Accessibility Keyboard — scrolling works outside OSK, clicks pass through on OSK, scroll mode stays active
- **Committed in:** bb3c0d9 (follow-up fix commit)

**3. [Rule 1 - Bug] Fixed timer run loop mode for event tracking compatibility**
- **Found during:** Task 2 (human verification checkpoint)
- **Issue:** Timer was scheduled in default run loop mode, which doesn't fire during event tracking (e.g., while dragging). This caused OSK bounds cache to become stale if user moved the keyboard during a drag operation.
- **Fix:** Changed RunLoop.main.add() to use .common mode instead of default mode
- **Files modified:** ScrollMyMac/Services/WindowExclusionManager.swift
- **Verification:** Timer now fires during event tracking, keeping cache fresh during drag operations
- **Committed in:** bb3c0d9 (follow-up fix commit)

---

**Total deviations:** 3 auto-fixed (3 bugs discovered during human verification)
**Impact on plan:** All auto-fixes were critical for correctness. The plan's MEDIUM confidence on process name proved prescient — empirical verification was essential. Layer filtering was not anticipated in plan but was necessary to distinguish keyboard panel from system overlays. Run loop mode fix ensures cache freshness during drag operations. No scope creep.

## Issues Encountered

**OSK Process Name Uncertainty:**
- Plan specified "Assistive Control" with MEDIUM confidence and required empirical verification
- Verification revealed actual name is "AssistiveControl" (no space)
- Resolution: Updated targetOwnerName constant and documented as key decision for future reference

**AssistiveControl Multiple Windows:**
- Initial detection cached ALL AssistiveControl windows (including 2 full-screen overlays)
- This caused entire screen to be treated as pass-through zone, completely disabling scroll mode
- Resolution: Added layer < 1000 filter to distinguish keyboard panel (layer 101) from system overlays (layers 2996, 2997)

**Timer Run Loop Mode:**
- Default run loop mode doesn't fire during event tracking
- Could cause stale cache if OSK repositioned during drag
- Resolution: Schedule timer in .common mode for event-tracking compatibility

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

WindowExclusionManager pattern established and working correctly:
- OSK clicks pass through instantly with no hold-and-decide delay
- Scrolling outside OSK works normally
- Scroll mode stays toggled on during OSK pass-through
- OSK repositioning tracked via adaptive polling
- Closing OSK clears pass-through zone (no ghost detection)
- Existing app-window pass-through preserved

The WindowExclusionManager pattern is extensible for future window exclusions (e.g., other system UI panels, screen sharing controls, etc.).

**Potential Future Enhancements:**
- Generalize targetOwnerName to support multiple process names (e.g., array of exclusion rules)
- Add window title filtering for finer-grained exclusion control
- Consider notification-based detection (NSWorkspace) instead of polling for better performance

---
*Phase: 06-osk-aware-click-pass-through*
*Completed: 2026-02-16*

## Self-Check: PASSED

All claimed files exist:
- ScrollMyMac/Services/WindowExclusionManager.swift
- ScrollMyMac/App/AppState.swift
- .planning/phases/06-osk-aware-click-pass-through/06-01-SUMMARY.md

All claimed commits exist:
- 928275e (feat: Task 1)
- bb3c0d9 (fix: Follow-up fix)
