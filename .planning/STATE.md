# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-16)

**Core value:** Users can scroll any scrollable area by clicking and dragging with the mouse pointer, with natural inertia -- no scroll wheel or trackpad required.
**Current focus:** Phase 6 — OSK-Aware Click Pass-Through

## Current Position

Phase: 6 of 6 (OSK-Aware Click Pass-Through)
Plan: 1 of 1 in current phase
Status: Phase complete
Last activity: 2026-02-16 — Completed 06-01 WindowExclusionManager

Progress: [############] 100% (v1.0 complete, v1.1 Phase 6 complete)

## Performance Metrics

**Velocity:**
- Total plans completed: 11
- Average duration: 50min
- Total execution time: ~9.3 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-permissions-app-shell | 2 | 59min | 30min |
| 02-core-scroll-mode | 2 | 6h 3min | 3h 2min |
| 03-click-safety | 2 | 4min | 2min |
| 04-inertia | 2 | 8min | 4min |
| 05-settings-polish | 2 | 8min | 4min |
| 06-osk-aware-click-pass-through | 1 | 1h 53min | 1h 53min |

**Recent Trend:**
- Last 5 plans: 2min, 3min, 5min, 5min, 113min
- Trend: Phase 6 took significantly longer due to empirical OSK discovery + 3 critical fixes

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions from Phase 6:

- **OSK process name is "AssistiveControl" (no space)** — verified empirically via CGWindowListCopyWindowInfo
- **AssistiveControl has 3 windows:** 2 full-screen overlays (layers 2996/2997) and 1 keyboard panel (layer 101) — must filter by layer < 1000
- **Timer run loop mode:** Use .common mode to fire during event tracking (default mode doesn't fire during drags)
- **Adaptive polling:** 500ms when OSK detected (tracks repositioning), 2s when not detected (watches for appearance)
- **No coordinate conversion needed** — both CGEvent.location and kCGWindowBounds use CG coordinates (top-left origin)

### Pending Todos

None yet.

### Blockers/Concerns

None — Phase 6 complete. OSK click pass-through verified working.

## Session Continuity

Last session: 2026-02-16
Stopped at: Completed 06-01-PLAN.md — Phase 6 complete
Resume file: .planning/phases/06-osk-aware-click-pass-through/06-01-SUMMARY.md
