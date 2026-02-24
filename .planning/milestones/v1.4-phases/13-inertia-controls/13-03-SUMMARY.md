---
phase: 13-inertia-controls
plan: 03
subsystem: scrolling
tags: [nsscrollview, momentum, cgscrollevent, velocity-ramp, scroll-phase, native-apps, inertia]

# Dependency graph
requires:
  - phase: 13-inertia-controls-01
    provides: InertiaAnimator intensity-parameterized coasting, ScrollEngine inertia toggle
  - phase: 13-inertia-controls-02
    provides: Momentum toggle and intensity slider in Settings UI
provides:
  - Momentum toggle OFF stops all coasting in native NSScrollView apps (Finder, IA Writer)
  - Intensity slider controls coasting distance in native NSScrollView apps
  - Velocity ramp injection technique for influencing NSScrollView internal momentum
  - Drag-distance progressive scaling to prevent short-drag velocity amplification
  - Quadratic tail acceleration decay formula for sharper web-app deceleration cutoff
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Velocity ramp injection: post intensity-scaled scrollPhaseChanged events before scrollPhaseEnded to control NSScrollView exit velocity"
    - "Drag-distance progressive scaling: attenuate intensity amplification for short drags to prevent sudden jumps"
    - "Separate native vs web-app intensity curves: wider range for native (0.25x-4.0x) because NSScrollView dampens perceived difference"
    - "Quadratic tail acceleration: exp(-t/tau - tailAccel*t^2) for sharp deceleration cutoff without long lingering tail"

key-files:
  created: []
  modified:
    - ScrollMyMac/Services/ScrollEngine.swift
    - ScrollMyMac/Services/InertiaAnimator.swift

key-decisions:
  - "Velocity ramp injection chosen over 4 alternative approaches (momentum cancel, phase-less events, deferred scrollPhaseEnded, extended drag)"
  - "Separate native (0.25x-4.0x) and web-app (0.4x-2.0x) intensity scale ranges to compensate for NSScrollView dampening"
  - "Quadratic tail acceleration (tailAccel=1.5) in decay formula instead of adjusting stop threshold"
  - "Drag-distance progressive scaling with 80pt full-scale threshold to prevent short-drag amplification"
  - "Native scale max set to 4.0x after iterative user testing (tried 3.5x, 5.0x)"

patterns-established:
  - "Velocity ramp injection pattern: inject 3 frames at 8ms intervals with scaled deltas before scrollPhaseEnded"
  - "Two-tier momentum handling: velocity ramp for native apps, InertiaAnimator momentum events for web apps"

requirements-completed: [INRT-01, INRT-03]

# Metrics
duration: ~118min
completed: 2026-02-23
---

# Phase 13 Plan 03: Native Momentum Gap Closure Summary

**Velocity ramp injection to control NSScrollView native momentum, with separate native/web-app intensity curves, quadratic tail acceleration, and drag-distance progressive scaling for short-flick safety**

## Performance

- **Duration:** ~118 min (extensive iterative testing with user across 5 approaches)
- **Started:** 2026-02-23
- **Completed:** 2026-02-23
- **Tasks:** 2 (1 auto + 1 checkpoint:human-verify)
- **Files modified:** 2

## Accomplishments
- Momentum toggle OFF now stops ALL coasting in native NSScrollView apps (Finder, IA Writer) via zero-length momentum cancel sequence
- Intensity slider controls coasting distance in native apps via velocity ramp injection before scrollPhaseEnded
- Web-app deceleration tail shortened via quadratic tail acceleration formula
- Short-drag sudden jumps eliminated via drag-distance progressive scaling on velocity ramp
- All 5 UAT tests passed: momentum OFF in Finder, momentum OFF in IA Writer, intensity slider in native apps, no regression in web apps, default intensity unchanged

## Task Commits

Each task was committed atomically:

1. **Task 1: Suppress NSScrollView native momentum via scroll phase state machine** - `bc89050` (feat)
   - Follow-up fixes during iterative testing:
   - `36944f9` - Phase-less coasting attempt (failed, reverted in next commit)
   - `5a265e7` - Deferred scrollPhaseEnded attempt (failed, reverted in next commit)
   - `9639004` - Extended drag attempt (failed, reverted in next commit)
   - `82c807b` - Velocity ramp injection (working approach)
   - `a39f008` - First tuning pass: wider native range, shorter web-app tail
   - `3508086` - Second tuning pass: push native max, increase stop threshold
   - `c664814` - Quadratic tail acceleration formula
   - `b91fa21` - Drag-distance progressive scaling for short-drag safety
2. **Task 2: Verify native app momentum suppression** - checkpoint approved, all 5 tests passed

## Files Created/Modified
- `ScrollMyMac/Services/ScrollEngine.swift` - Added velocity ramp injection (injectVelocityRamp method), zero-length momentum cancel on inertia-disabled path, drag-distance progressive scaling in handleMouseUp
- `ScrollMyMac/Services/InertiaAnimator.swift` - Added separate native velocity scale (nativeVelocityScaleForIntensity), quadratic tail acceleration decay formula, synchronous first-frame momentum-begin

## Decisions Made
- **Velocity ramp injection over alternatives:** Tried 4 other approaches first. Phase-less events lost window binding and rubber-banding. Deferred scrollPhaseEnded still let NSScrollView compute its own momentum. Extended drag followed cursor to other windows and lacked boundary awareness. Velocity ramp works WITH NSScrollView's momentum by controlling the perceived exit velocity.
- **Separate native vs web-app scale ranges:** NSScrollView applies its own momentum curve on top of the perceived velocity, dampening the difference. Native range (0.25x-4.0x) is wider than web-app range (0.4x-2.0x) to compensate.
- **Quadratic tail acceleration over stop threshold:** User preferred changing the deceleration formula rather than adjusting the stop threshold. Formula `exp(-t/tau - 1.5*t^2)` produces a sharp tail cutoff while preserving smooth early feel.
- **Drag-distance progressive scaling at 80pt:** Short drags get attenuated intensity (closer to 1.0x neutral), long drags get full effect. 80pt threshold chosen as the point where a drag feels "intentional" for momentum.
- **Native scale max at 4.0x:** Tested 3.5x (too subtle), 5.0x (too extreme), settled on 4.0x as the right maximum.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] NSScrollView ignores momentum event deltas**
- **Found during:** Task 1 initial implementation
- **Issue:** Plan assumed posting momentum events with scaled deltas would control native coasting. NSScrollView computes its own momentum from the velocity of recent scrollPhaseChanged events, completely ignoring momentum event delta values.
- **Fix:** Invented velocity ramp injection technique: post 3 intensity-scaled scrollPhaseChanged events before scrollPhaseEnded to set NSScrollView's perceived exit velocity
- **Files modified:** ScrollEngine.swift, InertiaAnimator.swift
- **Committed in:** `82c807b`

**2. [Rule 1 - Bug] Phase-less events lose window binding and rubber-banding**
- **Found during:** Task 1 first fix attempt
- **Issue:** Phase-less scroll events (phase=0, momentumPhase=0) follow cursor to other windows and produce no bounce-back at boundaries
- **Fix:** Abandoned phase-less approach, reverted to momentum-phase events for web apps and velocity ramp for native apps
- **Files modified:** ScrollEngine.swift, InertiaAnimator.swift
- **Committed in:** `5a265e7` (reverted phase-less, tried next approach)

**3. [Rule 1 - Bug] Extended drag events follow cursor to other windows**
- **Found during:** Task 1 third fix attempt
- **Issue:** scrollPhaseChanged events target whatever window is under the cursor, not the originally-scrolled window. Also no boundary awareness during extended drag.
- **Fix:** Abandoned extended drag approach, moved to velocity ramp injection
- **Files modified:** ScrollEngine.swift
- **Committed in:** `82c807b` (final working approach)

**4. [Rule 1 - Bug] Web-app deceleration tail too long**
- **Found during:** Task 2 checkpoint testing
- **Issue:** Pure exponential decay `exp(-t/tau)` produces a long lingering tail at low velocities
- **Fix:** Added quadratic tail acceleration: `exp(-t/tau - tailAccel*t^2)` with tailAccel=1.5
- **Files modified:** InertiaAnimator.swift
- **Committed in:** `c664814`

**5. [Rule 1 - Bug] Short drags produce sudden jumps**
- **Found during:** Task 2 checkpoint testing
- **Issue:** Quick small mouse movements produce high velocity that gets amplified by intensity scale, causing sudden jumps on release
- **Fix:** Drag-distance progressive scaling: blend intensity scale toward 1.0 for drags shorter than 80pt
- **Files modified:** ScrollEngine.swift
- **Committed in:** `b91fa21`

---

**Total deviations:** 5 auto-fixed (5 bugs discovered during iterative testing)
**Impact on plan:** The core approach in the plan (momentum cancel + synchronous first frame) was necessary but insufficient -- NSScrollView ignores momentum event deltas for native apps. The velocity ramp injection technique was the key innovation. All deviations were essential for correctness. No scope creep.

## Issues Encountered
- The plan's approach of posting momentum events with intensity-scaled deltas only works for web-view apps (which consume momentum events directly). Native NSScrollView apps required a fundamentally different technique (velocity ramp injection) that was discovered through iterative testing of 5 approaches.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 13 is fully complete: all 3 plans done (backend parameterization, UI controls, native app gap closure)
- v1.4 milestone is now complete: Phase 13 (inertia controls), Phase 14 (scroll direction), Phase 15 (click-through hotkey) all done
- No blockers

## Self-Check: PASSED

All files exist (ScrollEngine.swift, InertiaAnimator.swift, 13-03-SUMMARY.md). All 9 commits verified (bc89050, 36944f9, 5a265e7, 9639004, 82c807b, a39f008, 3508086, c664814, b91fa21).

---
*Phase: 13-inertia-controls*
*Completed: 2026-02-23*
