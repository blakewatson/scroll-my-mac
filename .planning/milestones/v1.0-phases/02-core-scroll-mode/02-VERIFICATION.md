---
phase: 02-core-scroll-mode
verified: 2026-02-15T19:15:00Z
status: gaps_found
score: 4/5 must-haves verified
re_verification: false
gaps:
  - truth: "A visual indicator (cursor change or alternative) shows when scroll mode is active vs inactive"
    status: partial
    reason: "OverlayManager and IndicatorDotView exist and are substantive, but show/hide calls are not wired in AppState (intentionally disabled due to tracking lag)"
    artifacts:
      - path: "ScrollMyMac/Services/OverlayManager.swift"
        issue: "Not called from AppState - show/hide methods exist but are not invoked"
      - path: "ScrollMyMac/Views/IndicatorDotView.swift"
        issue: "Not displayed - overlay manager never shows it"
    missing:
      - "Wire overlayManager.show() in AppState.activateScrollMode()"
      - "Wire overlayManager.hide() in AppState.deactivateScrollMode()"
      - "Alternative: Implement better tracking strategy (event tap callback, CADisplayLink, higher frequency timer)"
      - "Alternative: Different visual indicator (cursor change, menu bar icon, window badge)"
---

# Phase 2: Core Scroll Mode Verification Report

**Phase Goal:** User can toggle scroll mode via hotkey and scroll any area by clicking and dragging

**Verified:** 2026-02-15T19:15:00Z

**Status:** gaps_found

**Re-verification:** No - initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can press a hotkey to toggle scroll mode on and off | ✓ VERIFIED | HotkeyManager detects F6 keyUp (line 40), wired to AppState.toggleScrollMode() (AppState.swift line 55-57), toggles isScrollModeActive (line 77) |
| 2 | In scroll mode, clicking and dragging scrolls the content under the cursor | ✓ VERIFIED | ScrollEngine intercepts mouse events (lines 118-203), converts drag deltas to scroll wheel events (lines 217-231), natural direction implemented (line 159: scrollY = deltaY) |
| 3 | Scrolling works in all directions (up, down, left, right) | ✓ VERIFIED | Axis lock detects and locks to vertical or horizontal (lines 153-155, 172-178), free scroll mode available (useAxisLock flag, line 19), both axes posted during accumulation (lines 183-186) |
| 4 | A visual indicator (cursor change or alternative) shows when scroll mode is active vs inactive | ✗ FAILED (PARTIAL) | OverlayManager exists with show/hide methods (OverlayManager.swift lines 20-53), IndicatorDotView exists (IndicatorDotView.swift lines 3-10), BUT AppState does NOT call show/hide - overlay is intentionally disabled |
| 5 | The on/off toggle in the main window reflects and controls scroll mode state | ✓ VERIFIED | Toggle bound to $appState.isScrollModeActive (SettingsView.swift line 59), didSet observer triggers activate/deactivate (AppState.swift lines 7-15), permission check disables toggle (SettingsView.swift line 60) |

**Score:** 4/5 truths verified (1 partial failure)

### Required Artifacts

#### Plan 02-01 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| ScrollMyMac/Services/ScrollEngine.swift | CGEventTap mouse interception with drag-to-scroll conversion | ✓ VERIFIED | Contains CGEvent.tapCreate (line 72), scrollWheelEvent2Source with .pixel units (line 219-221), leftMouseDown/Dragged/Up handlers (lines 118-203), axis lock (lines 153-155, 207-215), natural scroll direction (line 159), scroll phases (lines 163-169, 229), tapDisabledByTimeout handling (lines 252-260) |
| ScrollMyMac/Services/HotkeyManager.swift | Global F6 hotkey detection via CGEventTap on keyUp | ✓ VERIFIED | Contains kVK_F6 (line 18), CGEventTap on keyUp (line 40), onToggle callback (lines 13, 123), modifier support structure (lines 22, 87-91), tapDisabledByTimeout handling (lines 105-112) |

#### Plan 02-02 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| ScrollMyMac/Services/OverlayManager.swift | Floating NSPanel overlay that tracks cursor position | ⚠️ ORPHANED | Contains NSPanel creation (lines 27-45), show/hide methods (lines 20-53), position tracking (lines 75-106), BUT show/hide NOT called from AppState - code exists but is unused |
| ScrollMyMac/Views/IndicatorDotView.swift | SwiftUI circle view for the indicator dot | ⚠️ ORPHANED | Contains Circle with black fill and white stroke (lines 5-7), 10px frame (line 8), used by OverlayManager (OverlayManager.swift line 40), BUT overlay never shown - component exists but never displayed |
| ScrollMyMac/App/AppState.swift | Updated AppState coordinating scroll engine, hotkey, and overlay | ✓ VERIFIED | Instantiates all services (lines 40-42), setupServices() wires hotkeyManager.onToggle (lines 54-57), isScrollModeActive didSet triggers activate/deactivate (lines 7-15), scrollEngine.start/stop wired (lines 92, 96), shouldPassThroughClick callback implemented (lines 61-69), permission monitoring (lines 17-28) |
| ScrollMyMac/ScrollMyMacApp.swift | App entry point initializing and wiring all services | ✓ VERIFIED | Calls appState.setupServices() on appear (line 18), starts hotkeyManager when permission granted (lines 21-23) |

### Key Link Verification

#### Plan 02-01 Key Links

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| ScrollEngine.swift | CGEvent scroll wheel | CGEvent(scrollWheelEvent2Source:) posted on each drag | ✓ WIRED | postScrollEvent() creates and posts scroll events (lines 217-231), called from handleMouseDragged (lines 175, 177, 181, 185) with natural direction deltas |
| HotkeyManager.swift | onToggle callback | Callback closure invoked on F6 press | ✓ WIRED | onToggle property defined (line 13), invoked on main thread when F6 matches (lines 122-124), consumed event (returns nil, line 125) |

#### Plan 02-02 Key Links

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| HotkeyManager | AppState.isScrollModeActive | onToggle callback toggles isScrollModeActive | ✓ WIRED | hotkeyManager.onToggle set to toggleScrollMode (AppState.swift lines 55-57), toggleScrollMode calls isScrollModeActive.toggle() (line 77) |
| AppState.isScrollModeActive | ScrollEngine.start/stop | onChange observer starts or stops the scroll engine | ✓ WIRED | didSet on isScrollModeActive (lines 7-15) calls activateScrollMode (line 10, calls scrollEngine.start line 92) or deactivateScrollMode (line 12, calls scrollEngine.stop line 96) |
| AppState.isScrollModeActive | OverlayManager.show/hide | onChange observer shows or hides the overlay dot | ✗ NOT_WIRED | overlayManager instantiated (line 42) but show/hide methods never called from AppState - activateScrollMode and deactivateScrollMode do NOT call overlay methods |
| ScrollEngine drag events | OverlayManager.updatePosition | Callback from ScrollEngine on each drag event updates dot position | ⚠️ PARTIAL | onDragPositionChanged callback exists on ScrollEngine (line 23), called from handleMouseDragged (line 150), BUT AppState does NOT wire this callback in setupServices - no connection to overlayManager.updatePosition |
| UI toggle | AppState.isScrollModeActive | SwiftUI Toggle binding | ✓ WIRED | Toggle bound to $appState.isScrollModeActive (SettingsView.swift line 59), disabled when permission missing (line 60) |

### Requirements Coverage

| Requirement | Status | Blocking Issue |
|-------------|--------|----------------|
| SCRL-01: User can scroll any scrollable area by clicking and dragging | ✓ SATISFIED | ScrollEngine intercepts clicks (line 118), converts drags to scroll events (lines 138-189), posts to CGSessionEventTap (line 230) |
| SCRL-02: Scrolling works in all directions | ✓ SATISFIED | Axis lock supports vertical (line 175) and horizontal (line 177), free scroll both axes (line 181), accumulation period posts both (line 185) |
| ACTV-01: User can toggle scroll mode on/off via global hotkey | ✓ SATISFIED | F6 hotkey detected (HotkeyManager.swift line 18, 40), toggles scroll mode (AppState.swift lines 55-57, 77), keyUp event for on-screen keyboard compatibility |
| ACTV-02: Visual indicator shows when scroll mode is active | ✗ BLOCKED | Overlay code exists (OverlayManager.swift, IndicatorDotView.swift) but is not wired - show/hide never called, position updates never wired - intentionally disabled per summary due to tracking lag |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| AppState.swift | 42 | Unused service: overlayManager instantiated but never used | ⚠️ Warning | Dead code - OverlayManager exists but show/hide methods never called, onDragPositionChanged callback never wired |
| OverlayManager.swift | 20-106 | Orphaned implementation: complete overlay tracking system unused | ℹ️ Info | Code is complete and functional but intentionally disabled - not a stub, just deferred activation |

### Human Verification Required

#### 1. F6 Hotkey Toggle

**Test:** Press F6, verify scroll mode activates. Press F6 again, verify it deactivates.

**Expected:** 
- First F6 press: isScrollModeActive becomes true, ScrollEngine starts
- Second F6 press: isScrollModeActive becomes false, ScrollEngine stops
- Toggle in settings window reflects state changes
- Works regardless of which app has focus

**Why human:** Global hotkey detection requires actual key press and focus verification across apps.

#### 2. Drag-to-Scroll with Natural Direction

**Test:** 
1. Activate scroll mode (F6 or UI toggle)
2. Open Safari with a long webpage
3. Click and drag downward - content should move DOWN
4. Click and drag upward - content should move UP
5. Click and drag right - content should move RIGHT (if horizontal scroll available)
6. Click and drag left - content should move LEFT (if horizontal scroll available)

**Expected:** Natural scroll direction (like iOS/trackpad) - drag direction matches content movement direction.

**Why human:** Visual verification of scroll direction requires observing actual content movement.

#### 3. Axis Lock Behavior

**Test:**
1. Activate scroll mode
2. In Safari, start dragging primarily downward - should lock to vertical axis, horizontal movement ignored
3. Release, start new drag primarily rightward - should lock to horizontal axis, vertical movement ignored
4. Test ambiguous initial movement - should accumulate until 5px threshold, then lock to dominant axis

**Expected:** Each drag gesture locks to one axis after ~5px accumulated movement. New drags re-detect axis.

**Why human:** Requires observing axis lock engagement during active drag gestures.

#### 4. UI Toggle Sync

**Test:**
1. Click toggle in settings to ON - scroll mode should activate
2. Press F6 - toggle should reflect OFF
3. Press F6 again - toggle should reflect ON
4. Click toggle to OFF - scroll mode should deactivate

**Expected:** Toggle and F6 control the same state, both update the UI.

**Why human:** Requires verifying UI sync across both control methods.

#### 5. Safety Timeout Integration

**Test:**
1. Enable "Safety timeout" in settings
2. Activate scroll mode (F6 or toggle)
3. Don't move mouse for 10 seconds
4. Verify scroll mode deactivates, notification appears
5. Verify toggle reflects OFF state

**Expected:** Auto-deactivation after 10s idle, notification shown, toggle synced.

**Why human:** Requires waiting and observing timeout behavior.

#### 6. Permission Revocation Graceful Degradation

**Test:**
1. With scroll mode active, revoke Accessibility permission in System Settings
2. Verify scroll mode deactivates
3. Verify warning appears in settings window
4. Verify F6 no longer toggles scroll mode
5. Re-grant permission, verify F6 works again

**Expected:** Graceful degradation when permission revoked, auto-recovery when re-granted.

**Why human:** Requires System Settings interaction and permission state changes.

#### 7. Click Pass-Through for App Windows

**Test:**
1. Activate scroll mode
2. Click the settings toggle while scroll mode is active
3. Verify click passes through (toggle responds)
4. Click in Safari while scroll mode active
5. Verify click is suppressed (no navigation, just scroll mode drag)

**Expected:** Clicks on app's own windows pass through, clicks elsewhere are intercepted.

**Why human:** Requires testing click behavior across different windows.

#### 8. On-Screen Keyboard Compatibility

**Test:**
1. Open macOS on-screen keyboard (System Settings > Accessibility > Keyboard > Accessibility Keyboard)
2. Click F6 on the on-screen keyboard
3. Verify scroll mode toggles
4. Verify on-screen keyboard key doesn't get stuck in pressed state

**Expected:** F6 via on-screen keyboard works, no stuck keys (keyUp implementation).

**Why human:** Requires on-screen keyboard setup and interaction testing.

### Gaps Summary

**Visual Indicator Not Displayed**

The overlay indicator system is complete and substantive but is not wired into AppState. The OverlayManager and IndicatorDotView exist with full implementations including:
- NSPanel-based floating window (OverlayManager.swift lines 27-45)
- Black circle with white border (IndicatorDotView.swift lines 5-8)
- Position tracking via timer polling (OverlayManager.swift lines 57-69)
- Show/hide methods (lines 20-53)

However, AppState does NOT:
- Call overlayManager.show() in activateScrollMode()
- Call overlayManager.hide() in deactivateScrollMode()
- Wire scrollEngine.onDragPositionChanged to overlayManager.updatePosition()

**Root Cause:** Per 02-02-SUMMARY.md, the overlay was intentionally disabled due to noticeable tracking lag (timer-based polling at 60fps had ~16ms delay, dot visibly trailing cursor). The summary states: "User approved hiding overlay, approved overall scroll mode functionality."

**Impact:** Success criterion #4 from ROADMAP.md is not met. The visual indicator does not show when scroll mode is active. This is a KNOWN gap acknowledged by the user, with the code retained for future enhancement.

**Options to Close Gap:**
1. Wire existing overlay (quick fix, but lag remains)
2. Implement event tap position callback (requires coordination, cleaner architecture)
3. Use CADisplayLink for vsync-synchronized tracking (higher complexity)
4. Higher frequency timer (CPU intensive, may not eliminate lag)
5. Different visual indicator (cursor change, menu bar icon, window badge)

---

_Verified: 2026-02-15T19:15:00Z_
_Verifier: Claude (gsd-verifier)_
