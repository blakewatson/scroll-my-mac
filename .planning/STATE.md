# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-14)

**Core value:** Users can scroll any scrollable area by clicking and dragging with the mouse pointer, with natural inertia -- no scroll wheel or trackpad required.
**Current focus:** v1.1 OSK Compat — OSK-aware click pass-through

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-02-16 — Milestone v1.1 started

## Performance Metrics

**Velocity:**
- Total plans completed: 9
- Average duration: 1.1h
- Total execution time: ~7.4 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-permissions-app-shell | 2 | 59min | 30min |
| 02-core-scroll-mode | 2 | 6h 3min | 3h 2min |
| 03-click-safety | 2 | 4min | 2min |
| 04-inertia | 2 | 8min | 4min |
| 05-settings-polish | 2 | 8min | 4min |

**Recent Trend:**
- Last 5 plans: 2min, 2min, 3min, 5min, 5min
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
- Inertia tau=0.400s for long coast feel; 80ms velocity window with 50pt/s min, 8000pt/s cap
- Click during inertia stops coasting and passes through immediately (no consume, no double-click needed)
- Momentum events use scrollWheelEventScrollPhase=0, momentumPhase=1/2/3 (separate from scroll phases)
- InertiaAnimator uses callback pattern (onMomentumScroll) for decoupling from ScrollEngine
- Removed free-scroll mode entirely — axis lock always on, too janky for diagonal scrolling
- Sub-pixel remainder accumulation in InertiaAnimator prevents truncation drift during coasting
- OverlayManager uses Timer-based mouse tracking at 60fps for cursor following
- Hotkey modifier flags stored as UInt64 raw value for CGEventFlags/NSEvent.ModifierFlags interop
- keyCode=-1 sentinel convention for "no hotkey set" (stops HotkeyManager)
- Strip .function/.numericPad flags when validating user modifier input
- Launch at login excluded from reset to defaults (system-level setting)
- Removed applicationWillBecomeActive to avoid conflict with silent login launch
- Service init moved to AppState.init for reliable silent launch wiring
- Hotkey keyDown consumed to prevent macOS funk sound on unhandled keys
- SMAppService.mainApp for login item management (no helper app needed)
- getppid()==1 && SMAppService status check for login item launch detection

### Pending Todos

None yet.

### Blockers/Concerns

- Overlay tracking lag needs better strategy (not blocking - feature works without visual indicator). Potential strategies: event tap position callback, CADisplayLink sync, higher frequency polling.

## Session Continuity

Last session: 2026-02-16
Stopped at: Completed 05-02-PLAN.md (Settings consolidation and launch at login) -- ALL PHASES COMPLETE
Resume file: .planning/phases/05-settings-polish/05-02-SUMMARY.md
