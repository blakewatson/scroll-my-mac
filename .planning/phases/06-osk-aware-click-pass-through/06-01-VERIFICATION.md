---
phase: 06-osk-aware-click-pass-through
verified: 2026-02-16T22:04:45Z
status: passed
score: 5/5 must-haves verified
re_verification: false
---

# Phase 6: OSK-Aware Click Pass-Through Verification Report

**Phase Goal:** Clicks over the Accessibility Keyboard pass through instantly so typing is never interrupted by scroll mode
**Verified:** 2026-02-16T22:04:45Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #   | Truth                                                                      | Status     | Evidence                                                                                                 |
| --- | -------------------------------------------------------------------------- | ---------- | -------------------------------------------------------------------------------------------------------- |
| 1   | Clicks over the Accessibility Keyboard pass through instantly              | ✓ VERIFIED | WindowExclusionManager.isPointExcluded() wired into shouldPassThroughClick closure. Human verified.      |
| 2   | Moving or resizing the Accessibility Keyboard does not break detection     | ✓ VERIFIED | Adaptive polling (500ms when detected) refreshes OSK bounds cache. Human verified repositioning works.   |
| 3   | Scroll mode stays toggled on while clicks pass through over the OSK        | ✓ VERIFIED | Pass-through check in shouldPassThroughClick does not deactivate scroll mode. Human verified.            |
| 4   | Scrolling outside the OSK area is completely unaffected                    | ✓ VERIFIED | Layer filtering (<1000) ensures only OSK panel cached, not full-screen overlays. Human verified.         |
| 5   | Closing the OSK removes the pass-through zone (no stale cache)             | ✓ VERIFIED | refreshCache() clears excludedRects when OSK not found. Human verified no ghost zone after close.        |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact                                              | Expected                                   | Status     | Details                                                                                                    |
| ----------------------------------------------------- | ------------------------------------------ | ---------- | ---------------------------------------------------------------------------------------------------------- |
| `ScrollMyMac/Services/WindowExclusionManager.swift`   | OSK window detection and bounds caching    | ✓ VERIFIED | 94 lines. Contains isPointExcluded, startMonitoring, stopMonitoring, refreshCache, scheduleTimer methods.  |
| `ScrollMyMac/App/AppState.swift`                      | WindowExclusionManager wiring              | ✓ VERIFIED | Property windowExclusionManager instantiated. Wired in shouldPassThroughClick, activate/deactivate calls.  |

**All artifacts pass:**
- **Level 1 (Exists):** Both files exist
- **Level 2 (Substantive):** WindowExclusionManager implements timer-based CGWindowListCopyWindowInfo polling, adaptive rate (500ms active, 2s passive), layer filtering (<1000), CGRect caching. AppState adds second OR condition to shouldPassThroughClick.
- **Level 3 (Wired):** WindowExclusionManager imported and instantiated in AppState. isPointExcluded() called from shouldPassThroughClick. start/stopMonitoring called in activate/deactivateScrollMode.

### Key Link Verification

| From           | To                         | Via                                       | Status     | Details                                                                                          |
| -------------- | -------------------------- | ----------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------ |
| AppState.swift | WindowExclusionManager     | shouldPassThroughClick calls isPointExcluded | ✓ WIRED    | Line 126: `return self.windowExclusionManager.isPointExcluded(cgPoint)`                          |
| AppState.swift | WindowExclusionManager     | activate/deactivate lifecycle             | ✓ WIRED    | Lines 175, 181: startMonitoring() and stopMonitoring() called in activate/deactivateScrollMode() |

**Pattern: Component → Service**
- WindowExclusionManager instantiated as property in AppState (line 67)
- isPointExcluded() read in event tap callback path (line 126)
- start/stopMonitoring() lifecycle tied to scroll mode activation (lines 175, 181)

### Requirements Coverage

| Requirement | Status      | Supporting Truth                                               | Evidence                                                                                           |
| ----------- | ----------- | -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| OSK-01      | ✓ SATISFIED | Truth 1: Clicks pass through instantly                         | shouldPassThroughClick wired to isPointExcluded(). Human verified no hold-and-decide delay on OSK. |
| OSK-02      | ✓ SATISFIED | Truth 2: Periodic polling, never in event tap                  | refreshCache() called by timer. isPointExcluded() only reads cache (no IPC).                       |
| OSK-03      | ✓ SATISFIED | Truth 2: Repositioning tracked                                 | Adaptive polling (500ms active) refreshes bounds. Human verified repositioning works.              |
| OSK-04      | ✓ SATISFIED | Truth 3: Scroll mode stays on during pass-through              | Pass-through returns true without deactivating scroll mode. Human verified.                        |
| OSK-05      | ✓ SATISFIED | Empirical verification documented                              | Process name "AssistiveControl" verified in commit bb3c0d9 and SUMMARY deviations section.         |

**All v1.1 requirements satisfied.**

### Anti-Patterns Found

No anti-patterns detected in WindowExclusionManager.swift or AppState.swift modifications.

**Checked:**
- TODO/FIXME/PLACEHOLDER comments: None found
- Empty implementations (return null/{}): None found
- Console.log only implementations: None found
- Stub handlers: None found

**Implementation quality:**
- WindowExclusionManager uses proper timer-based polling with adaptive rate
- Layer filtering (<1000) prevents full-screen overlay caching
- Timer scheduled in .common run loop mode for event-tracking compatibility
- No IPC calls in event tap callback path (isPointExcluded reads cache only)
- Proper cleanup in stopMonitoring() (invalidates timer, clears cache, resets detection state)

### Human Verification Performed

User confirmed all 10 verification steps passed:

1. **Rapid OSK clicking** — Keys register as normal clicks with no hold-and-decide delay
2. **OSK repositioning** — Clicks still pass through after moving keyboard to different screen position
3. **Scroll outside OSK** — Dragging in scrollable area works normally
4. **Drag transition (OSK → off)** — Entire drag is pass-through (no scroll initiation)
5. **Drag transition (off → OSK)** — Entire drag is scroll (no pass-through switch)
6. **Close OSK** — No ghost pass-through zone after closing keyboard
7. **Scroll mode toggle state** — Overlay dot stays visible throughout (mode stays on)
8. **App window pass-through** — Settings window still passes through (existing behavior preserved)
9. **Layer filtering** — Scrolling works everywhere outside OSK panel (no full-screen pass-through)
10. **Timer refresh** — OSK repositioning during drag tracked correctly (.common run loop mode)

### Implementation Verification

**WindowExclusionManager.swift (94 lines):**
- Process name: "AssistiveControl" (no space) — verified empirically, documented in commit bb3c0d9
- Polling intervals: 500ms (active), 2s (passive) — adaptive rate based on detection state
- Layer filtering: `layer < 1000` excludes full-screen overlays (layers 2996, 2997), only caches keyboard panel (layer 101)
- Timer run loop mode: `.common` for event-tracking compatibility
- Cache: `excludedRects: [CGRect]` — hit-testing uses `contains { $0.contains(point) }`
- IPC isolation: CGWindowListCopyWindowInfo only called in refreshCache() on timer, never in isPointExcluded()

**AppState.swift modifications:**
- Property: `let windowExclusionManager = WindowExclusionManager()` (line 67)
- shouldPassThroughClick extension: Added second OR condition after app-window check (line 126)
- Lifecycle: startMonitoring() in activateScrollMode() (line 175), stopMonitoring() in deactivateScrollMode() (line 181)
- Coordinate system: CG coordinates passed directly (no NS conversion) — both CGEvent.location and kCGWindowBounds use top-left origin

### Commits Verified

- **928275e** — feat(06-01): add WindowExclusionManager for OSK click pass-through
  - Created WindowExclusionManager.swift
  - Modified AppState.swift (wiring)
  - Modified project.pbxproj (build sources)
  
- **bb3c0d9** — fix(06-01): correct OSK process name and filter overlay windows
  - Fixed process name: "Assistive Control" → "AssistiveControl"
  - Added layer filtering: `layer < 1000`
  - Fixed timer run loop mode: default → .common

**Total files modified:** 3 (WindowExclusionManager.swift, AppState.swift, project.pbxproj)
**Commit integrity:** Both commits exist in git history. No uncommitted changes to key files.

---

## Summary

**All must-haves verified. Phase goal achieved.**

WindowExclusionManager service created with timer-based CGWindowListCopyWindowInfo polling, layer filtering to exclude system overlays, and CGRect caching for fast event-tap path performance. Integrated into shouldPassThroughClick as second OR condition, preserving existing app-window pass-through logic. Lifecycle tied to scroll mode activation/deactivation.

**Human verification passed all 10 steps:** OSK clicks pass through instantly, repositioning tracked, scroll mode stays on, scrolling outside OSK unaffected, closing OSK clears zone, existing app-window pass-through preserved.

**Critical fixes applied during execution:**
- Process name corrected from "Assistive Control" to "AssistiveControl" (empirical verification)
- Layer filtering added to exclude full-screen system overlays (prevents whole-screen pass-through)
- Timer run loop mode fixed to .common (enables refresh during event tracking)

**Next phase readiness:** WindowExclusionManager pattern established and extensible for future window exclusions. All v1.1 OSK compatibility requirements satisfied.

---

_Verified: 2026-02-16T22:04:45Z_  
_Verifier: Claude (gsd-verifier)_
