# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-22)

**Core value:** Users can scroll any scrollable area by clicking and dragging with the mouse pointer, with natural inertia -- no scroll wheel or trackpad required.
**Current focus:** Phase 15 — Click-Through Hotkey (v1.1)

## Current Position

Phase: 15 of 15 (Click-Through Hotkey)
Plan: 1 of 1
Status: Phase 15 complete
Last activity: 2026-02-23 — Completed 15-01 click-through hotkey

Progress: [████████████████████████] 100% (15/15 phases)

## Performance Metrics

**Velocity:**
- Total plans completed: 22
- Average duration: 30min
- Total execution time: ~10 hours

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
| 13-inertia-controls | 2 | 17min | 9min |
| 14-scroll-direction | 1 | 2min | 2min |
| 15-click-through-hotkey | 1 | 2min | 2min |

**Recent Trend:**
- Last 5 plans: 15min, 2min, 15min, 2min, 2min
- Trend: Stable

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
- Phases 13-15 are independent -- can be executed in any order
- Inertia controls build on existing InertiaAnimator from Phase 4
- Click-through hotkey reuses existing KeyRecorderView from Phase 5
- Two-segment linear interpolation for intensity-to-tau mapping (0.120...0.400...0.900)
- Velocity scale range 0.4x...1.0x...2.0x matches tau segments
- Settings reorganized into 6 sections: Scroll Mode, Scroll Behavior, Safety, General, Excluded Apps, Reset
- LabeledContent for slider Form alignment, background-based tick mark, 0.025 snap threshold
- Direction inversion applied at ScrollEngine level, not in InertiaAnimator -- keeps animator generic
- Default scroll direction is natural (false) -- matches touchscreen mental model
- Click-through hotkey uses second HotkeyManager instance, defaults to None (keyCode -1)

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

Last session: 2026-02-23
Stopped at: Completed 15-01-PLAN.md (Phase 15 complete -- all phases done)
Resume file: --
