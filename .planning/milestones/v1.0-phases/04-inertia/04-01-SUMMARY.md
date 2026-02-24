---
phase: 04-inertia
plan: 01
subsystem: scroll-engine
tags: [inertia, momentum, CADisplayLink, exponential-decay, velocity-tracking]

# Dependency graph
requires:
  - phase: 02-core-scroll-mode
    provides: "ScrollEngine with CGEvent tap, mouse event handlers, axis lock, scroll phase posting"
  - phase: 03-click-safety
    provides: "Hold-and-decide click-through, pending click state, replay mechanism"
provides:
  - "VelocityTracker ring buffer with 80ms window velocity sampling"
  - "InertiaAnimator CADisplayLink-driven exponential decay momentum scrolling"
  - "Momentum scroll event posting with correct phase sequence (1/2/3)"
  - "Click-during-inertia consumption, F6-toggle-off inertia stop"
affects: [04-02, 05-settings]

# Tech tracking
tech-stack:
  added: [CADisplayLink, QuartzCore]
  patterns: [exponential-decay-animation, ring-buffer-velocity-tracking, momentum-scroll-phase-signaling]

key-files:
  created:
    - ScrollMyMac/Services/VelocityTracker.swift
    - ScrollMyMac/Services/InertiaAnimator.swift
  modified:
    - ScrollMyMac/Services/ScrollEngine.swift
    - ScrollMyMac.xcodeproj/project.pbxproj

key-decisions:
  - "tau=0.400s time constant for long coast distance per user requirement"
  - "80ms velocity window with 50pt/s min threshold and 8000pt/s cap"
  - "Click during inertia consumed (return nil) without entering pending-click state"
  - "Momentum events use scrollWheelEventScrollPhase=0 with separate momentumPhase field"

patterns-established:
  - "Callback-based decoupling: InertiaAnimator uses onMomentumScroll closure rather than posting events directly"
  - "Closed-form exponential decay: position = amplitude * (1 - exp(-t/tau)) for frame-rate independence"

# Metrics
duration: 3min
completed: 2026-02-15
---

# Phase 4 Plan 1: Inertia Core Summary

**CADisplayLink-driven exponential decay momentum scrolling with ring buffer velocity tracking and correct CGEvent momentum phase signaling**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-15T22:27:14Z
- **Completed:** 2026-02-15T22:30:11Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- VelocityTracker struct with ring buffer (10 samples, 80ms window) computing points/second velocity with pause detection
- InertiaAnimator class with CADisplayLink frame sync, exponential decay (tau=0.400s), and momentum phase lifecycle (begin/continue/end)
- Full ScrollEngine integration: velocity sampling on drag, inertia start on release, inertia stop on click/toggle/teardown
- Momentum scroll events use correct field separation (scrollPhase=0, momentumPhase=1/2/3) for app compatibility

## Task Commits

Each task was committed atomically:

1. **Task 1: Create VelocityTracker and InertiaAnimator** - `793cffa` (feat)
2. **Task 2: Integrate inertia into ScrollEngine and AppState** - `8956a77` (feat)

**Plan metadata:** (pending) (docs: complete plan)

## Files Created/Modified
- `ScrollMyMac/Services/VelocityTracker.swift` - Ring buffer velocity sampling with time-window averaging, min/max thresholds
- `ScrollMyMac/Services/InertiaAnimator.swift` - CADisplayLink exponential decay animation with momentum scroll event callback
- `ScrollMyMac/Services/ScrollEngine.swift` - Added velocity tracking, inertia start/stop integration, momentum event posting
- `ScrollMyMac.xcodeproj/project.pbxproj` - Added VelocityTracker.swift and InertiaAnimator.swift file references

## Decisions Made
- tau=0.400s (400ms) time constant chosen for "long coast" feel per user requirement -- faster than UIScrollView .normal (500ms) but longer than iOS default (325ms)
- 80ms velocity sampling window (middle of user's 50-100ms range) with 5ms minimum span for pause detection
- Minimum velocity 50pt/s to prevent micro-coasting from slow drags
- Maximum velocity cap at 8000pt/s to prevent extreme flicks
- InertiaAnimator uses callback pattern (onMomentumScroll closure) rather than directly posting CGEvents -- keeps it testable and decoupled
- Click during inertia returns nil immediately without entering pending-click state (clean consumption)
- No AppState changes needed -- scrollEngine.stop() already calls inertiaAnimator.stopCoasting()

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Inertia core complete, ready for Plan 02 (tuning/polish)
- App compiles and all integration points verified by code inspection and successful build
- Behavioral testing requires running the app and performing drag-and-release gestures

---
*Phase: 04-inertia*
*Completed: 2026-02-15*
