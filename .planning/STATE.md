# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-24)

**Core value:** Users can scroll any scrollable area by clicking and dragging with the mouse pointer, with natural inertia -- no scroll wheel or trackpad required.
**Current focus:** Planning next milestone

## Current Position

Phase: v1.4 complete — all 15 phases shipped
Plan: All plans complete
Status: v1.4 milestone archived — ready for next milestone
Last activity: 2026-02-24 — Archived v1.4 milestone

Progress: v1.0-v1.4 shipped (15 phases, 23 plans)

## Performance Metrics

**Velocity:**
- Total plans completed: 23
- Average duration: 33min
- Total execution time: ~12 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-permissions-app-shell | 2 | 59min | 30min |
| 02-core-scroll-mode | 2 | 6h 3min | 3h 2min |
| 03-click-safety | 2 | 4min | 2min |
| 04-inertia | 2 | 8min | 4min |
| 05-settings-polish | 2 | 8min | 4min |
| 06-osk-aware-click-pass-through | 1 | 1h 53min | 1h 53min |
| 07-app-icon | 1 | 12min | 12min |
| 08-code-signing-notarization | 1 | 30min | 30min |
| 09-release-documentation | 1 | 1min | 1min |
| 10-menu-bar-icon | 1 | 2min | 2min |
| 11-hold-to-passthrough | 1 | 2min | 2min |
| 12-per-app-exclusion | 2 | 17min | 9min |
| 13-inertia-controls | 3 | 135min | 45min |
| 14-scroll-direction | 1 | 2min | 2min |
| 15-click-through-hotkey | 1 | 2min | 2min |

**Recent Trend:**
- Last 5 plans: 2min, 15min, 2min, 2min, 118min
- Trend: Variable (gap closure plan required extensive iterative testing)

*Updated after each plan completion*
| Phase 13 P03 | 118min | 2 tasks | 2 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
v1.4 decisions archived — see .planning/milestones/v1.4-ROADMAP.md for full history.

### Pending Todos

None yet.

### Blockers/Concerns

None.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 1 | Add MIT license and update README accordingly | 2026-02-17 | a8fb027 | [1-add-mit-license-and-update-readme-accord](./quick/1-add-mit-license-and-update-readme-accord/) |
| 2 | Add safety timeout note to README | 2026-02-16 | db7a8b9 | [2-add-safety-timeout-note-to-readme](./quick/2-add-safety-timeout-note-to-readme/) |
| 3 | Move CGEventTap to background thread | 2026-02-17 | a2838da | [3-move-cgeventtap-to-background-thread](./quick/3-move-cgeventtap-to-background-thread/) |
| 4 | Change hold-to-passthrough wording in settings window | 2026-02-18 | 3ef52e2 | [4-change-hold-to-passthrough-wording-in-se](./quick/4-change-hold-to-passthrough-wording-in-se/) |
| 5 | Fix settings window not showing on launch and appearing twice on dock click, and fix menu bar icon toggle not restoring icon | 2026-02-18 | 27da4b8 | [5-fix-settings-window-not-showing-on-launc](./quick/5-fix-settings-window-not-showing-on-launc/) |
| 6 | Fix Dock auto-reveal not working when switching from excluded app to non-excluded app | 2026-02-19 | 35137e0 | [6-fix-dock-auto-reveal-not-working-when-sw](./quick/6-fix-dock-auto-reveal-not-working-when-sw/) |
| 7 | Fix settings window click-through on secondary displays | 2026-02-21 | 7c8ec9a | [7-the-scroll-my-mac-settings-window-should](./quick/7-the-scroll-my-mac-settings-window-should/) |
| 8 | Fix scroll engine on WKWebView-based apps (MarkEdit) | 2026-02-23 | 970a4a5 | [8-investigate-why-scroll-engine-doesn-t-wo](./quick/8-investigate-why-scroll-engine-doesn-t-wo/) |

## Session Continuity

Last session: 2026-02-24
Stopped at: v1.4 milestone archived
Resume file: --
