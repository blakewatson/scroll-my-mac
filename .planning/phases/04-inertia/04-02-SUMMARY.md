---
phase: 04-inertia
plan: 02
subsystem: ui, input
tags: [axis-lock, settings, inertia, user-testing, SwiftUI]

# Dependency graph
requires:
  - phase: 04-01
    provides: "InertiaAnimator, VelocityTracker, momentum scroll events"
provides:
  - "Always-on axis lock (no toggle needed)"
  - "Click-during-inertia passes through immediately"
  - "Sub-pixel remainder accumulation for smooth inertia"
  - "User-verified inertia feel and behavior"
affects: [05-polish]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Always-on axis lock — simpler than user-configurable toggle"
    - "Click during inertia: stop + passthrough (no consume)"

key-files:
  created: []
  modified:
    - ScrollMyMac/App/AppState.swift
    - ScrollMyMac/Features/Settings/SettingsView.swift
    - ScrollMyMac/Services/ScrollEngine.swift
    - ScrollMyMac/Services/InertiaAnimator.swift
    - ScrollMyMac/ScrollMyMacApp.swift
    - ScrollMyMac/Services/HotkeyManager.swift
    - ScrollMyMac/Services/OverlayManager.swift

key-decisions:
  - "Removed free-scroll mode entirely — axis lock always on, too janky for users"
  - "Click during inertia passes through immediately instead of being consumed"
  - "Kept sub-pixel remainder accumulation for smooth inertia coasting"

patterns-established:
  - "Axis lock is always on — no setting, no branching code paths"
  - "Inertia interruption should be zero-friction (no double-click needed)"

# Metrics
duration: 5min
completed: 2026-02-15
---

# Phase 4 Plan 2: Axis Lock Settings and Inertia Verification Summary

**Always-on axis lock after removing free-scroll mode, with click-during-inertia passthrough and user-verified momentum feel**

## Performance

- **Duration:** ~5 min (summary/finalization only; user testing session separate)
- **Started:** 2026-02-15
- **Completed:** 2026-02-15
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- Added then removed axis-lock settings toggle after user testing revealed free-scroll was too janky
- Simplified ScrollEngine by removing all free-scroll branching code
- Click during inertia now stops coasting and immediately processes the click (no second click needed)
- Sub-pixel remainder accumulation added to InertiaAnimator for smooth coasting
- User approved inertia feel: deceleration curve, coast distance, and smoothness
- Fixed auxiliary issues found during testing: HotkeyManager keyUp, OverlayManager tracking, conditional hotkey start

## Task Commits

Each task was committed atomically:

1. **Task 1: Add axis-lock settings toggle** - `2d00de6` (feat)
2. **Task 2: Verify inertia behavior** - APPROVED with deviations, changes committed as `807a0db` (fix)

## Files Created/Modified
- `ScrollMyMac/App/AppState.swift` - Removed isAxisLockEnabled property and UserDefaults persistence
- `ScrollMyMac/Features/Settings/SettingsView.swift` - Removed axis lock toggle from UI
- `ScrollMyMac/Services/ScrollEngine.swift` - Removed useAxisLock, free-scroll code paths, cursor freeze; click-during-inertia passthrough
- `ScrollMyMac/Services/InertiaAnimator.swift` - Added sub-pixel remainder accumulation for smooth coasting
- `ScrollMyMac/ScrollMyMacApp.swift` - Guard hotkeyManager.start() on accessibility permission
- `ScrollMyMac/Services/HotkeyManager.swift` - Changed keyDown to keyUp for on-screen keyboard compatibility
- `ScrollMyMac/Services/OverlayManager.swift` - Added mouse tracking timer for cursor following

## Decisions Made
- **Removed free-scroll mode:** User found diagonal free-scroll too janky and not worth the complexity. Axis lock is always on — no setting needed. This simplifies ScrollEngine significantly.
- **Removed cursor freeze (CGAssociateMouseAndMouseCursorPosition):** Was added to fix Finder column-switching in free-scroll, but caused worse UX (stuck cursor). Removed along with free-scroll.
- **Click during inertia passthrough:** Previously consumed the click (required double-click to start new scroll). Now stops coasting and processes mouseDown normally for zero-friction interaction.
- **Kept sub-pixel remainder:** Although deviation notes said it was "removed," it was actually kept in InertiaAnimator for correctness — prevents truncation drift during inertia frames.

## Deviations from Plan

### User-Requested Changes (Post-Verification)

**1. [Rule 1 - Simplification] Removed free-scroll mode entirely**
- **Found during:** Task 2 (user verification)
- **Issue:** Free-scroll diagonal scrolling felt janky and wasn't worth the complexity
- **Fix:** Removed isAxisLockEnabled from AppState, useAxisLock from ScrollEngine, toggle from SettingsView. Axis lock is now always on.
- **Files modified:** AppState.swift, SettingsView.swift, ScrollEngine.swift
- **Committed in:** 807a0db

**2. [Rule 1 - Bug] Removed cursor freeze mechanism**
- **Found during:** Task 2 (user verification)
- **Issue:** CGAssociateMouseAndMouseCursorPosition caused stuck cursor and difficulty scrolling right
- **Fix:** Removed along with free-scroll code paths
- **Files modified:** ScrollEngine.swift
- **Committed in:** 807a0db

**3. [Rule 1 - Bug] Click during inertia no longer consumed**
- **Found during:** Task 2 (user verification)
- **Issue:** Clicking during inertia consumed the click, requiring a second click to start a new scroll
- **Fix:** stopCoasting() call kept, but removed resetDragState()/return nil — mouseDown processing continues normally
- **Files modified:** ScrollEngine.swift
- **Committed in:** 807a0db

**4. [Rule 2 - Enhancement] Sub-pixel remainder accumulation**
- **Found during:** Task 2 (user verification)
- **Issue:** Int32 truncation during inertia frames caused drift
- **Fix:** Added scrollRemainderX/Y to InertiaAnimator to accumulate fractional pixels between frames
- **Files modified:** InertiaAnimator.swift
- **Committed in:** 807a0db

**5. [Rule 3 - Auxiliary fixes] HotkeyManager, OverlayManager, app startup**
- **Found during:** Task 2 (user verification)
- **Issue:** Multiple small issues found during testing: keyDown vs keyUp for on-screen keyboard, overlay not following cursor, unconditional hotkey start
- **Fix:** HotkeyManager uses keyUp; OverlayManager adds mouse tracking timer; ScrollMyMacApp guards hotkeyManager.start() on permission
- **Files modified:** HotkeyManager.swift, OverlayManager.swift, ScrollMyMacApp.swift
- **Committed in:** 807a0db

---

**Total deviations:** 5 (3 user-requested simplifications, 1 enhancement, 1 auxiliary fix batch)
**Impact on plan:** Net reduction in complexity. Free-scroll removal eliminated ~20 lines of branching code. All changes improve UX based on real user testing.

## Issues Encountered
None beyond the deviations documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 4 (Inertia) is complete: velocity tracking, exponential decay, momentum events, always-on axis lock, user-verified feel
- Ready for Phase 5 (Polish): overlay improvements, any remaining UX refinements
- Overlay tracking lag noted as concern (timer-based at 60fps added in OverlayManager, needs evaluation)

---
*Phase: 04-inertia*
*Completed: 2026-02-15*
