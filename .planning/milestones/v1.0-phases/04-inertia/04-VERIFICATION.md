---
phase: 04-inertia
verified: 2026-02-15T23:15:00Z
status: human_needed
score: 7/7 must-haves verified
human_verification:
  - test: "Basic inertia momentum"
    expected: "Fast drag then release produces smooth deceleration. Faster drags coast further."
    why_human: "Visual smoothness and momentum feel can't be verified programmatically"
  - test: "Slow drag produces no momentum"
    expected: "Slow drag then release stops immediately, no micro-coasting"
    why_human: "Velocity threshold behavior requires human perception of 'slow' vs 'fast'"
  - test: "Pause detection"
    expected: "Fast drag, pause ~0.5s, release produces no inertia"
    why_human: "Timing and pause perception is subjective"
  - test: "Smoothness and frame sync"
    expected: "Inertia feels smooth — no stuttering, jumping, or visible frame drops"
    why_human: "Visual quality assessment requires human perception"
  - test: "Axis lock during inertia"
    expected: "Diagonal drag locks to one axis, inertia continues in that locked direction"
    why_human: "Visual verification of axis-locked movement"
---

# Phase 04: Inertia Verification Report

**Phase Goal:** Released drags produce natural momentum scrolling that feels like iOS/trackpad
**Verified:** 2026-02-15T23:15:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Releasing a drag at speed produces continued scrolling with gradual deceleration | ✓ VERIFIED | InertiaAnimator implements exponential decay (tau=0.400s), startCoasting() called on mouseUp with velocity |
| 2 | Faster drags produce more momentum; slow drags produce little or no momentum | ✓ VERIFIED | VelocityTracker computes velocity with 50pt/s minimum threshold, 8000pt/s cap; amplitude = velocity * tau |
| 3 | Pausing mid-drag then releasing produces no inertia | ✓ VERIFIED | VelocityTracker uses 80ms window with 5ms minimum span; pause clears velocity samples (returns nil) |
| 4 | Clicking during inertia stops scrolling and passes through the click | ✓ VERIFIED | handleMouseDown() checks isCoasting, calls stopCoasting(), continues processing (no consume/return nil) |
| 5 | Starting a new drag during inertia cancels old inertia and starts a new drag | ✓ VERIFIED | Same as #4 — stopCoasting() called, then normal mouseDown flow enters pending-click or drag state |
| 6 | Toggling scroll mode off (F6) during inertia stops it immediately | ✓ VERIFIED | stop() calls inertiaAnimator.stopCoasting() before disabling tap (line 113) |
| 7 | Inertia direction respects axis lock from the drag phase | ✓ VERIFIED | startCoasting() receives lockedAxis, zeros out non-locked axis amplitude (lines 61-68 InertiaAnimator.swift) |

**Score:** 7/7 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `ScrollMyMac/Services/VelocityTracker.swift` | Ring buffer velocity sampling with time-window averaging | ✓ VERIFIED | 82 lines; struct VelocityTracker with ring buffer (10 samples, 80ms window), computeVelocity() returns CGPoint?, 50pt/s min, 8000pt/s cap |
| `ScrollMyMac/Services/InertiaAnimator.swift` | CADisplayLink-driven exponential decay momentum scrolling | ✓ VERIFIED | 162 lines; class InertiaAnimator with CADisplayLink, exponential decay (tau=0.400s), momentum phase sequence (1/2/3), axis lock support, sub-pixel remainder accumulation |
| `ScrollMyMac/Services/ScrollEngine.swift` | Integration of velocity tracking and inertia into mouse event handlers | ✓ VERIFIED | 436 lines; velocityTracker property, inertiaAnimator property, addSample() at line 239, startCoasting() at line 300, stopCoasting() at lines 113/132/157, reset() at line 393 |

**All artifacts:**
- Exist ✓
- Substantive ✓ (all contain meaningful implementations, no stubs)
- Wired ✓ (integrated into ScrollEngine event handlers)

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| ScrollEngine.swift | VelocityTracker.swift | addSample() on each mouseDragged, computeVelocity() on mouseUp | ✓ WIRED | Line 239: velocityTracker.addSample() in handleMouseDragged; Line 299: velocityTracker.computeVelocity() in handleMouseUp |
| ScrollEngine.swift | InertiaAnimator.swift | startCoasting() on mouseUp with velocity, stopCoasting() on interruption | ✓ WIRED | Lines 300-304: startCoasting() with velocity and lockedAxis; Lines 113/132/157: stopCoasting() on F6/teardown/click-during-inertia |
| InertiaAnimator.swift | CGEvent momentum scroll posting | CADisplayLink callback posts momentum-phase scroll events | ✓ WIRED | Line 152: onMomentumScroll?(scrollDeltaY, scrollDeltaX, momentumPhase); Line 353: scrollWheelEventMomentumPhase field set in postMomentumScrollEvent |

**All key links:** ✓ WIRED

### Anti-Patterns Found

None detected.

**Checks performed:**
- TODO/FIXME/placeholder comments: None found
- Empty implementations (return null/{}): None found
- Console.log-only implementations: Not applicable (Swift)
- Stub patterns: None found

### Phase Scope Changes

**Axis lock toggle removed (deliberate simplification):**
- Plan 04-02 initially added axis lock settings toggle
- User testing revealed free-scroll mode was too janky and not worth complexity
- Decision: axis lock always on, removed toggle completely
- Files affected: AppState.swift (removed isAxisLockEnabled), SettingsView.swift (removed toggle), ScrollEngine.swift (removed useAxisLock branching)
- Impact: Net reduction in complexity (~20 lines of branching code removed)
- Committed in: 807a0db

**Click-during-inertia behavior changed (UX improvement):**
- Original plan: consume click (return nil), requiring second click to start new scroll
- User feedback: too much friction, should be zero-friction interaction
- New behavior: stop coasting, pass through click immediately for normal processing
- Files affected: ScrollEngine.swift handleMouseDown()
- Impact: Improved UX, removed resetDragState()/return nil after stopCoasting()
- Committed in: 807a0db

These are not gaps — they are deliberate improvements based on user testing.

### Human Verification Required

All automated checks pass, but the following aspects require human testing:

#### 1. Basic Inertia Momentum

**Test:** In a long scrollable page (e.g., Safari on Wikipedia article), click-drag quickly downward then release.

**Expected:** Content should continue scrolling with gradual deceleration, slowing to a smooth stop. Faster drags should coast further.

**Why human:** Visual smoothness and momentum feel can't be verified programmatically. The tau constant (0.400s) and exponential decay curve need subjective assessment.

#### 2. No Micro-Coasting

**Test:** Drag very slowly, then release.

**Expected:** There should be no visible momentum — scrolling stops on release.

**Why human:** The 50pt/s velocity threshold is designed to prevent micro-coasting from slow drags. This requires human perception of "slow" vs "fast" movement.

#### 3. Pause Detection

**Test:** Drag fast, then hold still for ~0.5s, then release.

**Expected:** No inertia should occur (the pause cleared velocity).

**Why human:** The 80ms window and 5ms minimum span settings need validation. Timing perception is subjective.

#### 4. Click to Stop Inertia (Passthrough)

**Test:** Do a fast drag to trigger inertia, then click while content is still coasting.

**Expected:** Scrolling stops instantly. The click should immediately process normally (can start new scroll or click through).

**Why human:** Zero-friction interaction requires human assessment. The change from "consume click" to "passthrough" needs UX validation.

#### 5. F6 During Inertia

**Test:** Trigger inertia, then press F6.

**Expected:** Inertia stops immediately and scroll mode turns off.

**Why human:** Real-time interruption behavior and mode-switching coordination.

#### 6. Smoothness and Frame Synchronization

**Test:** Trigger fast inertia and watch the scrolling animation carefully.

**Expected:** Inertia should feel smooth — no stuttering, jumping, or visible frame drops. The deceleration curve should feel natural (fast at first, gradually slowing).

**Why human:** CADisplayLink frame synchronization and visual quality can only be assessed by human perception. The closed-form exponential decay formula is frame-rate independent, but smoothness requires validation.

#### 7. Axis Lock During Inertia

**Test:** Drag diagonally. Observe the locked axis and inertia direction.

**Expected:** Scrolling should lock to one axis (vertical or horizontal). Inertia should continue in that same locked direction.

**Why human:** Visual verification of axis-locked movement and consistency between drag phase and inertia phase.

#### 8. Sub-pixel Remainder Accumulation

**Test:** Trigger slow-ish inertia (just above 50pt/s threshold) and watch for drift or jerkiness.

**Expected:** Smooth continuous motion even at low speeds. No truncation-induced drift.

**Why human:** The sub-pixel remainder accumulation (scrollRemainderX/Y) prevents truncation drift. Visual assessment needed to confirm smooth low-velocity coasting.

---

**Status Summary:** All automated verification passed. Phase 04 goal achieved in codebase. Awaiting human testing to confirm subjective quality (smoothness, feel, timing).

---

_Verified: 2026-02-15T23:15:00Z_
_Verifier: Claude (gsd-verifier)_
