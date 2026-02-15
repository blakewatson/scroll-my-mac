# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-14)

**Core value:** Users can scroll any scrollable area by clicking and dragging with the mouse pointer, with natural inertia -- no scroll wheel or trackpad required.
**Current focus:** Phase 3 in progress — click-through with hold-and-decide dead zone detection

## Current Position

Phase: 3 of 5 (Click Safety) -- COMPLETE
Plan: 2 of 2 in current phase
Status: Phase Complete
Last activity: 2026-02-15 -- Completed 03-02-PLAN.md (Permission health monitoring and mid-drag cleanup)

Progress: [██████░░░░] 60%

## Performance Metrics

**Velocity:**
- Total plans completed: 6
- Average duration: 1.5h
- Total execution time: 7.1 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-permissions-app-shell | 2 | 59min | 30min |
| 02-core-scroll-mode | 2 | 6h 3min | 3h 2min |
| 03-click-safety | 2 | 4min | 2min |

**Recent Trend:**
- Last 5 plans: 3min, 56min, 3min, 2min, 2min
- Trend: Fast execution on well-specified plans

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Used manually-crafted pbxproj for Xcode project (most reliable from CLI)
- Safety mode toggle changed from @ObservationIgnored to didSet persistence for SwiftUI reactivity
- Dual permission buttons: system prompt (AXIsProcessTrustedWithOptions) + deep link fallback
- SafetyTimeoutManager uses Timer polling (0.5s) rather than event tap for Phase 1 simplicity
- Safety notification uses ZStack overlay with ultraThinMaterial and 3s auto-dismiss
- Used fileprivate for eventTap so file-level C callback can re-enable on timeout
- CGEvent scrollWheelEvent2 requires wheelCount 3 with all params in Swift API
- Scroll phases set via setIntegerValueField for trackpad-like behavior across apps
- tearDown() separate from stop() for clean app termination vs toggle
- Overlay indicator hidden for now due to tracking lag (timer-based polling at 60fps had noticeable delay)
- HotkeyManager changed from keyDown to keyUp to fix on-screen keyboard compatibility
- Horizontal and vertical scroll directions flipped (sign fix) after user testing
- Added click pass-through for app's own windows via shouldPassThroughClick callback
- Added isAccessibilityGranted didSet to auto-start/stop hotkeyManager and show permission warning when revoked
- 8px dead zone threshold for click vs drag discrimination in hold-and-decide model
- Click replayed at original mouseDown position (matches user intent)
- Synchronous isReplayingClick flag prevents re-entry (same run loop)
- stop() discards pending clicks without replaying
- Permission health poll every 2s during scroll mode (Timer-based)
- No auto-re-enable scroll mode after permission re-grant (user presses F6)
- stop()/tearDown() post kCGScrollPhaseEnded if mid-drag for clean app behavior

### Pending Todos

None yet.

### Blockers/Concerns

- Overlay tracking lag needs better strategy (not blocking - feature works without visual indicator). Potential strategies: event tap position callback, CADisplayLink sync, higher frequency polling.

## Session Continuity

Last session: 2026-02-15
Stopped at: Completed 03-02-PLAN.md (Phase 3 complete)
Resume file: .planning/phases/03-click-safety/03-02-SUMMARY.md
