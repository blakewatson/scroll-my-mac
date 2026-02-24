---
phase: 13-inertia-controls
plan: 01
subsystem: scroll-engine
tags: [inertia, momentum-scrolling, userdefaults, exponential-decay]

# Dependency graph
requires:
  - phase: 04-inertia
    provides: InertiaAnimator with hardcoded tau exponential decay
provides:
  - Parameterized InertiaAnimator with intensity-scaled tau and velocity
  - AppState isInertiaEnabled and inertiaIntensity with UserDefaults persistence
  - ScrollEngine conditional inertia skip when disabled
affects: [13-02 inertia UI controls]

# Tech tracking
tech-stack:
  added: []
  patterns: [two-segment linear interpolation for intensity mapping]

key-files:
  created: []
  modified:
    - ScrollMyMac/Services/InertiaAnimator.swift
    - ScrollMyMac/App/AppState.swift
    - ScrollMyMac/Services/ScrollEngine.swift

key-decisions:
  - "Two-segment linear interpolation for tau and velocity scale (0.0-0.5 and 0.5-1.0 mapped separately)"
  - "Tau range 0.120...0.400...0.900 and velocity scale 0.4x...1.0x...2.0x"

patterns-established:
  - "Intensity-to-tau mapping: two-segment lerp preserving midpoint as current behavior"

requirements-completed: [INRT-01, INRT-03]

# Metrics
duration: 2min
completed: 2026-02-23
---

# Phase 13 Plan 01: Inertia Backend Summary

**Parameterized InertiaAnimator with intensity-scaled tau (0.120-0.900) and velocity (0.4x-2.0x), plus AppState persistence and ScrollEngine inertia toggle**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-23T05:07:05Z
- **Completed:** 2026-02-23T05:09:07Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- InertiaAnimator accepts intensity parameter that scales both coasting duration (tau) and speed (velocity amplitude)
- Intensity 0.5 reproduces exactly the original hardcoded inertia feel
- AppState persists isInertiaEnabled and inertiaIntensity via UserDefaults
- ScrollEngine skips inertia entirely when isInertiaEnabled is false
- Reset to Defaults restores inertia on + intensity 0.5

## Task Commits

Each task was committed atomically:

1. **Task 1: Parameterize InertiaAnimator with intensity multiplier** - `f96e79d` (feat)
2. **Task 2: Add AppState inertia properties and wire through ScrollEngine** - `2569ccd` (feat)

**Plan metadata:** (pending final commit)

## Files Created/Modified
- `ScrollMyMac/Services/InertiaAnimator.swift` - Replaced hardcoded tau with intensity-parameterized two-segment interpolation for both tau and velocity scale
- `ScrollMyMac/App/AppState.swift` - Added isInertiaEnabled and inertiaIntensity properties with UserDefaults persistence, init loading, setupServices wiring, and resetToDefaults
- `ScrollMyMac/Services/ScrollEngine.swift` - Added isInertiaEnabled and inertiaIntensity public properties, conditional inertia skip in handleMouseUp

## Decisions Made
None - followed plan as specified

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Backend is fully wired: intensity parameter flows from AppState through ScrollEngine to InertiaAnimator
- Plan 02 can add SwiftUI controls (Toggle + Slider) that bind directly to AppState.isInertiaEnabled and AppState.inertiaIntensity
- No blockers

## Self-Check: PASSED

All files exist, all commits verified.

---
*Phase: 13-inertia-controls*
*Completed: 2026-02-23*
