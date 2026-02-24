---
phase: 02-core-scroll-mode
plan: 02
subsystem: services
tags: [nspanel, overlay, swiftui, appstate, hotkey, coordination]

# Dependency graph
requires:
  - phase: 02-01
    provides: "ScrollEngine and HotkeyManager with callback-based APIs"
  - phase: 01-permissions-app-shell
    provides: "SafetyTimeoutManager, AppState foundation"
provides:
  - "OverlayManager: NSPanel overlay for visual scroll mode indicator"
  - "IndicatorDotView: SwiftUI circle component for indicator"
  - "AppState service coordination: wires ScrollEngine, HotkeyManager, OverlayManager"
  - "Full end-to-end scroll mode: F6 toggle, drag-to-scroll, visual indicator, UI sync"
affects: [03-click-safety, 04-inertia, 05-settings, future overlay enhancements]

# Tech tracking
tech-stack:
  added: [NSPanel, NSHostingView, CGWindowLevelForKey, NSEvent.mouseLocation]
  patterns: [Service coordination via AppState, callback-based event flow, didSet observers]

key-files:
  created:
    - ScrollMyMac/Services/OverlayManager.swift
    - ScrollMyMac/Views/IndicatorDotView.swift
  modified:
    - ScrollMyMac/App/AppState.swift
    - ScrollMyMac/ScrollMyMacApp.swift
    - ScrollMyMac/Features/Settings/SettingsView.swift
    - ScrollMyMac/Services/ScrollEngine.swift

key-decisions:
  - "Overlay indicator hidden for now due to tracking lag (timer-based polling at 60fps had noticeable delay)"
  - "HotkeyManager changed from keyDown to keyUp to fix on-screen keyboard compatibility"
  - "Horizontal and vertical scroll directions flipped (sign fix) after user testing"
  - "Added click pass-through for app's own windows via shouldPassThroughClick callback"
  - "Added isAccessibilityGranted didSet to auto-start/stop hotkeyManager and show permission warning when revoked"

patterns-established:
  - "Service coordination: AppState owns all services, wires them via callbacks in setupServices()"
  - "Toggle pattern: didSet on isScrollModeActive calls activate/deactivate methods"
  - "Callback chaining: HotkeyManager -> AppState -> ScrollEngine/OverlayManager"

# Metrics
duration: ~6h
completed: 2026-02-15
---

# Phase 2 Plan 02: Overlay Wiring and UI Activation Summary

**Complete end-to-end scroll mode with F6 toggle, drag-to-scroll with axis lock and natural direction, overlay indicator foundation (hidden due to lag), and synced UI toggle**

## Performance

- **Duration:** ~6h (including user testing and iterative refinements)
- **Started:** 2026-02-15T15:02:41Z
- **Completed:** 2026-02-15T18:56:07Z (checkpoint approved)
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- OverlayManager and IndicatorDotView created for visual scroll mode feedback (foundation laid, hidden for now)
- All services wired through AppState with callback-based coordination
- F6 hotkey toggles scroll mode globally (keyUp event for on-screen keyboard compatibility)
- Drag-to-scroll works with natural direction and axis lock after user testing sign corrections
- UI toggle in settings enabled and synced with F6 and scroll mode state
- Safety timeout integrates with real scroll mode activation
- Click pass-through for app's own windows allows settings interaction during scroll mode
- Permission monitoring with auto-start/stop and UI warning when accessibility is revoked

## Task Commits

Each task was committed atomically:

1. **Task 1: Create OverlayManager, IndicatorDotView, and wire all services through AppState** - `2d71727` (feat)
2. **Task 2: Verify end-to-end scroll mode functionality** - Human verification checkpoint (approved)

## Files Created/Modified
- `ScrollMyMac/Services/OverlayManager.swift` - NSPanel-based floating overlay with cursor tracking (hidden for now)
- `ScrollMyMac/Views/IndicatorDotView.swift` - SwiftUI circle indicator (black fill, white border, 10px)
- `ScrollMyMac/App/AppState.swift` - Service coordination hub, wires ScrollEngine/HotkeyManager/OverlayManager via callbacks
- `ScrollMyMac/ScrollMyMacApp.swift` - App entry point, calls setupServices() and starts hotkeyManager
- `ScrollMyMac/Features/Settings/SettingsView.swift` - Enabled UI toggle, removed disabled state and placeholder text, added permission re-grant polling
- `ScrollMyMac/Services/ScrollEngine.swift` - Added onDragPositionChanged callback, shouldPassThroughClick callback, sign corrections for scroll direction
- `ScrollMyMac.xcodeproj/project.pbxproj` - Added OverlayManager.swift and IndicatorDotView.swift to project

## Decisions Made
- **Overlay indicator hidden for now:** Timer-based cursor tracking at 60fps had noticeable lag. OverlayManager code retained for future strategy change (event tap position callback or higher frequency polling)
- **HotkeyManager keyDown -> keyUp:** Original keyDown implementation caused on-screen keyboard to get stuck when scroll mode activated (keyDown + scroll mode suppressed mouseUp). Changed to keyUp for compatibility.
- **Scroll direction sign fixes:** User testing revealed both horizontal and vertical scroll directions were inverted. Applied sign corrections in ScrollEngine.
- **Click pass-through for app windows:** Added `shouldPassThroughClick` callback to ScrollEngine so clicks on the app's own windows (settings toggle) pass through during scroll mode.
- **Permission monitoring:** Added didSet observer on `isAccessibilityGranted` to auto-start/stop hotkeyManager and update UI warning when permission is revoked at runtime.
- **Settings permission polling:** When onboarding completed but permission missing, SettingsView polls every second for re-grant.

## Deviations from Plan

### Auto-fixed Issues During Checkpoint Verification

**1. [Rule 1 - Bug] Fixed horizontal scroll direction (sign flip)**
- **Found during:** Task 2 (user verification testing)
- **Issue:** Horizontal scrolling was inverted (drag right scrolled left instead of right)
- **Fix:** Flipped sign in ScrollEngine horizontal scroll event creation
- **Files modified:** ScrollMyMac/Services/ScrollEngine.swift
- **Verification:** User confirmed natural horizontal scrolling works
- **Committed in:** Part of iterative checkpoint refinement

**2. [Rule 1 - Bug] Fixed vertical scroll direction (sign flip)**
- **Found during:** Task 2 (user verification testing)
- **Issue:** Vertical scrolling was inverted (drag down scrolled up instead of down)
- **Fix:** Flipped sign in ScrollEngine vertical scroll event creation
- **Files modified:** ScrollMyMac/Services/ScrollEngine.swift
- **Verification:** User confirmed natural vertical scrolling works
- **Committed in:** Part of iterative checkpoint refinement

**3. [Rule 1 - Bug] Changed HotkeyManager from keyDown to keyUp**
- **Found during:** Task 2 (user verification testing with on-screen keyboard)
- **Issue:** keyDown + scroll mode activation suppressed mouseUp event, leaving on-screen keyboard stuck in pressed state
- **Fix:** Changed HotkeyManager to trigger on keyUp instead of keyDown
- **Files modified:** ScrollMyMac/Services/HotkeyManager.swift
- **Verification:** On-screen keyboard no longer gets stuck, toggle still responsive
- **Committed in:** Part of iterative checkpoint refinement

**4. [Rule 2 - Missing Critical] Added click pass-through for app's own windows**
- **Found during:** Task 2 (user verification testing)
- **Issue:** User couldn't click the settings toggle while scroll mode was active (ScrollEngine intercepts all clicks)
- **Fix:** Added `shouldPassThroughClick` callback to ScrollEngine, implemented in AppState to allow clicks on app's own windows
- **Files modified:** ScrollMyMac/Services/ScrollEngine.swift, ScrollMyMac/App/AppState.swift
- **Verification:** User can click settings toggle during scroll mode
- **Committed in:** Part of iterative checkpoint refinement

**5. [Rule 2 - Missing Critical] Added isAccessibilityGranted didSet for permission monitoring**
- **Found during:** Task 2 (consideration of runtime permission revocation)
- **Issue:** If user revokes accessibility permission while app is running, hotkeyManager would continue running but not work, creating confusing state
- **Fix:** Added didSet observer on isAccessibilityGranted to auto-stop hotkeyManager when permission revoked, auto-start when re-granted, update UI warning
- **Files modified:** ScrollMyMac/App/AppState.swift
- **Verification:** Permission revocation shows warning, re-grant restarts functionality
- **Committed in:** Part of iterative checkpoint refinement

**6. [Rule 2 - Missing Critical] Added permission re-grant polling in SettingsView**
- **Found during:** Task 2 (user flow testing when permission denied then granted)
- **Issue:** When user completes onboarding but permission is missing, UI shows warning but doesn't update when they grant it in System Settings
- **Fix:** Added timer-based polling (1s interval) in SettingsView to detect permission re-grant
- **Files modified:** ScrollMyMac/Features/Settings/SettingsView.swift
- **Verification:** UI updates automatically when permission granted
- **Committed in:** Part of iterative checkpoint refinement

**7. [Rule 4 - Architectural Decision] Hide overlay indicator due to tracking lag**
- **Found during:** Task 2 (user verification testing)
- **Issue:** Timer-based cursor tracking at 60fps had noticeable lag (dot trailing cursor by ~16ms)
- **Decision:** Hide overlay for now (OverlayManager.show() commented out), retain code for future strategy change
- **Options considered:** Event tap position callback (requires coordination), higher frequency timer (CPU intensive), CADisplayLink (complex)
- **Resolution:** User approved hiding overlay, approved overall scroll mode functionality
- **Files modified:** ScrollMyMac/App/AppState.swift (commented overlayManager.show())
- **Verification:** Scroll mode works without visual indicator, axis lock and natural direction confirmed working
- **Committed in:** Part of iterative checkpoint refinement

---

**Total deviations:** 7 (5 bugs/missing critical auto-fixed, 1 architectural decision deferred, 1 feature hidden)
**Impact on plan:** All fixes essential for correct behavior and user experience. Overlay hidden pending better tracking strategy. No scope creep beyond critical usability.

## Issues Encountered
- **Overlay tracking lag:** Initial timer-based implementation at 60fps had visible lag. Rather than over-engineer a solution prematurely, hid the overlay and retained code for future improvement (potential strategies: event tap callback, CADisplayLink sync, higher frequency).
- **On-screen keyboard stuck:** keyDown event + scroll mode activation suppressed mouseUp, fixed by changing to keyUp.
- **Inverted scroll directions:** Both axes had wrong signs, fixed through user testing feedback.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Core scroll mode fully functional: F6 toggle, drag-to-scroll with axis lock and natural direction, UI sync, safety timeout integration
- Overlay foundation in place (hidden due to lag, ready for future enhancement)
- Permission monitoring ensures graceful degradation if accessibility revoked
- Ready for Phase 3 (click pass-through safety) - basic pass-through for app windows already implemented
- Ready for Phase 4 (inertia/momentum) - clean drag events ready for physics layer
- Settings UI reactive and accessible

**Blockers/Concerns:**
- Overlay tracking lag needs better strategy (not blocking - feature works without visual indicator)
- Current click pass-through only works for app's own windows (intentional - full click-through is Phase 3)

---
*Phase: 02-core-scroll-mode*
*Completed: 2026-02-15*

## Self-Check: PASSED

- OverlayManager.swift: FOUND
- IndicatorDotView.swift: FOUND
- AppState.swift: FOUND
- ScrollMyMacApp.swift: FOUND
- SettingsView.swift: FOUND
- Commit 2d71727: FOUND
