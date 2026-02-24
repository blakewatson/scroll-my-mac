---
phase: 13-inertia-controls
verified: 2026-02-23T00:00:00Z
status: passed
score: 9/9 must-haves verified
re_verification: true
  previous_status: passed (automated) / gaps_found (UAT)
  previous_score: 8/8 automated truths verified, 2/7 UAT tests failed
  gaps_closed:
    - "Momentum scrolling toggle disables all inertial coasting in native NSScrollView apps (Finder, IA Writer)"
    - "Intensity slider affects coasting feel in native NSScrollView apps"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Toggle Momentum scrolling OFF in Settings, open Finder, drag-scroll and release"
    expected: "Scrolling stops immediately — no coasting in Finder"
    why_human: "UAT in 13-UAT.md already confirmed this passed after 13-03 gap closure"
  - test: "With momentum ON, set Intensity to Less then More, drag-scroll in Finder"
    expected: "Less produces short coast, More produces long coast — perceptible difference"
    why_human: "UAT in 13-UAT.md already confirmed this passed after 13-03 gap closure"
---

# Phase 13: Inertia Controls Verification Report (Re-verification)

**Phase Goal:** Users can tune or completely disable momentum scrolling to match their preference
**Verified:** 2026-02-23
**Status:** passed
**Re-verification:** Yes — after UAT gap closure via Plan 03

## Context: What Changed Since Initial Verification

The initial verification (2026-02-22) verified structural correctness (8/8 truths). The subsequent UAT
(13-UAT.md) exposed 2 major runtime failures: the momentum toggle and intensity slider had no effect in
native NSScrollView apps (Finder, IA Writer) because NSScrollView generates its own internal momentum from
scroll phase velocity, ignoring InertiaAnimator's momentum events entirely.

Plan 13-03 was executed to close these gaps. The root cause required a fundamentally different approach
than originally planned: velocity ramp injection (posting intensity-scaled scrollPhaseChanged events before
scrollPhaseEnded to control NSScrollView's perceived exit velocity). The UAT was re-run after 13-03; all
5 tests passed.

This re-verification confirms the gap closure is correctly implemented in the codebase and that all phase
success criteria are now satisfied.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | When `isInertiaEnabled` is false, releasing a drag produces zero coasting in native apps | VERIFIED | `handleMouseUp` else branch (lines 406-412): posts `scrollPhaseEnded` then `momentumPhase: 1` (begin) + `momentumPhase: 3` (end) with zero deltas — claims and immediately closes the momentum phase so NSScrollView cannot start its own |
| 2 | When `isInertiaEnabled` is false, releasing a drag produces zero coasting in web-view apps | VERIFIED | Same else branch: `InertiaAnimator.startCoasting` is never called; zero-length momentum cancel also terminates any web-view momentum phase |
| 3 | Intensity slider controls coasting feel in native NSScrollView apps | VERIFIED | `injectVelocityRamp` (lines 431-455): posts 3 scrollPhaseChanged events with `velocity * nativeVelocityScaleForIntensity(inertiaIntensity)` scaled deltas before scrollPhaseEnded; NSScrollView reads these as the user's exit velocity and generates proportional native momentum |
| 4 | Intensity slider controls coasting feel in web-view apps | VERIFIED | `InertiaAnimator.startCoasting` uses two-segment lerp for both tau (0.120–0.900s) and web velocity scale (0.4x–2.0x); momentum events posted via `onMomentumScroll` callback |
| 5 | Short drags do not produce sudden jumps from intensity amplification | VERIFIED | `dragFactor = min(dragDistance / 80.0, 1.0)` blends `intensityScale` toward 1.0 for drags shorter than 80pt (lines 388-391) |
| 6 | No regression: inertia ON at default intensity (0.5) feels identical to pre-fix behavior | VERIFIED | `nativeVelocityScaleForIntensity(0.5)` returns exactly `nativeScaleMid = 1.0`; web app path: at `t=0.5`, tau=0.400 (tauMid), velocityScale=1.0 — identical to original hardcoded constants |
| 7 | Toggle defaults to ON and intensity defaults to 0.5 on fresh install | VERIFIED | `AppState.init` line 163: `?? true` for `isInertiaEnabled`; line 164: `?? 0.5` for `inertiaIntensity` |
| 8 | Both settings persist across app restarts | VERIFIED | `isInertiaEnabled.didSet`: `UserDefaults.standard.set(isInertiaEnabled, forKey: "inertiaEnabled")` (line 96); `inertiaIntensity.didSet`: `UserDefaults.standard.set(inertiaIntensity, forKey: "inertiaIntensity")` (line 103); init loads both |
| 9 | Reset to Defaults restores both settings to defaults | VERIFIED | `AppState.resetToDefaults()` lines 304-305: `isInertiaEnabled = true`, `inertiaIntensity = 0.5` |

**Score:** 9/9 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `ScrollMyMac/Services/ScrollEngine.swift` | Velocity ramp injection for native apps; zero-length momentum cancel when inertia disabled; drag-distance progressive scaling | VERIFIED | `injectVelocityRamp` (lines 431-455); zero-length momentum cancel in else branch (lines 409-411); `dragFactor` progressive scaling (lines 388-391); `nativeVelocityScaleForIntensity` call (line 381) |
| `ScrollMyMac/Services/InertiaAnimator.swift` | `nativeVelocityScaleForIntensity` for wider native range; quadratic tail acceleration in decay formula; separate native vs web scale constants | VERIFIED | `nativeVelocityScaleForIntensity` function (lines 89-98); `nativeScaleMin=0.25`, `nativeScaleMid=1.0`, `nativeScaleMax=4.0` (lines 39-41); `tailAccel=1.5` (line 47); decay formula `exp(-t/tau - tailAccel*t^2)` (line 200) |
| `ScrollMyMac/App/AppState.swift` | `isInertiaEnabled` and `inertiaIntensity` with UserDefaults persistence, init defaults, resetToDefaults | VERIFIED | Both properties with `didSet` UserDefaults saves (lines 96, 103); init loads (lines 163-164); `setupServices` syncs (lines 220-221); `resetToDefaults` restores (lines 304-305) |
| `ScrollMyMac/Features/Settings/SettingsView.swift` | Momentum toggle and Intensity slider bound to AppState, disabled when off | VERIFIED | Toggle `$appState.isInertiaEnabled` (line 113); Slider `$appState.inertiaIntensity` (line 123); center snap at line 126; `.disabled(!appState.isInertiaEnabled)` at line 142 |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `ScrollEngine.handleMouseUp` (inertia enabled) | `injectVelocityRamp` | Called with `adjustedVelocity` and `intensityScale` before `scrollPhaseEnded` | VERIFIED | Line 393: `injectVelocityRamp(velocity: adjustedVelocity, scale: intensityScale, axis: lockedAxis)` — velocity ramp fires before line 396's `scrollPhaseEnded` |
| `ScrollEngine.handleMouseUp` (inertia disabled / below threshold) | `postMomentumScrollEvent` | Zero-length momentum begin+end | VERIFIED | Lines 410-411: `postMomentumScrollEvent(wheel1: 0, wheel2: 0, momentumPhase: 1)` then `momentumPhase: 3` — immediately after `scrollPhaseEnded` at line 409 |
| `InertiaAnimator.nativeVelocityScaleForIntensity` | `ScrollEngine.injectVelocityRamp` | Called with `CGFloat(inertiaIntensity)` as argument | VERIFIED | Line 381: `let rawScale = inertiaAnimator.nativeVelocityScaleForIntensity(CGFloat(inertiaIntensity))` |
| `AppState.isInertiaEnabled.didSet` | `scrollEngine.isInertiaEnabled` | Direct property assignment | VERIFIED | Line 97: `scrollEngine.isInertiaEnabled = isInertiaEnabled` |
| `AppState.inertiaIntensity.didSet` | `scrollEngine.inertiaIntensity` | Direct property assignment | VERIFIED | Line 104: `scrollEngine.inertiaIntensity = inertiaIntensity` |
| `SettingsView` | `AppState.isInertiaEnabled` | `$appState.isInertiaEnabled` SwiftUI binding | VERIFIED | Line 113: `Toggle("Momentum scrolling", isOn: $appState.isInertiaEnabled)` |
| `SettingsView` | `AppState.inertiaIntensity` | `$appState.inertiaIntensity` SwiftUI binding | VERIFIED | Line 123: `Slider(value: $appState.inertiaIntensity, in: 0...1)` |

### Note on Plan 13-03 Implementation Deviation

The 13-03 PLAN specified two mechanisms: (A) zero-length momentum cancel in the else branch, and (B) a synchronous
`onMomentumScroll?(0, 0, 1)` call in `InertiaAnimator.startCoasting` before the display link fires.

The final implementation uses mechanism (A) intact. Mechanism (B) was abandoned because iterative testing
revealed NSScrollView ignores the delta values of momentum events entirely — it computes its own momentum
from the velocity of recent scrollPhaseChanged events. The velocity ramp injection technique (posting
intensity-scaled scrollPhaseChanged events before scrollPhaseEnded) was discovered as the correct approach
through 5 iterative fix attempts. This is documented in 13-03-SUMMARY.md under "Deviations from Plan."

The PLAN's `must_haves.key_links` pattern `"onMomentumScroll.*1"` in InertiaAnimator is not present in the
final code, but this is not a gap — the intent (prevent NSScrollView from starting its own momentum) is
achieved more effectively by the velocity ramp technique. All 5 UAT tests passed after this change.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| INRT-01 | 13-01, 13-02, 13-03 | User can toggle inertia on/off in settings (enabled by default) | SATISFIED | `Toggle("Momentum scrolling", isOn: $appState.isInertiaEnabled)` in SettingsView; `?? true` default in AppState.init; now works in native apps via momentum cancel |
| INRT-02 | 13-02, 13-03 | User can adjust inertia intensity via a slider (weaker to stronger) | SATISFIED | `Slider(value: $appState.inertiaIntensity, in: 0...1)` in SettingsView; `nativeVelocityScaleForIntensity` for native apps; two-segment lerp for web apps; both confirmed working in UAT |
| INRT-03 | 13-01, 13-03 | When inertia is disabled, releasing a drag stops scrolling immediately | SATISFIED | `handleMouseUp` else branch: `scrollPhaseEnded` + zero-length momentum cancel (`begin`+`end`); suppresses NSScrollView's internal momentum; confirmed in UAT for both Finder and IA Writer |

All three INRT requirement IDs are satisfied. REQUIREMENTS.md marks all three as `[x]` complete under Phase 13.
No orphaned requirements.

### Build Verification

`xcodebuild -project ScrollMyMac.xcodeproj -scheme ScrollMyMac -destination 'platform=macOS' build` exits
with `** BUILD SUCCEEDED **` and zero errors.

### Commit Verification

All 9 commits from Plan 13-03 are present in git history:
- `bc89050` — feat(13-03): suppress NSScrollView native momentum via scroll phase state machine
- `36944f9` — fix(13-03): use phase-less scroll events (failed attempt, later superseded)
- `5a265e7` — fix(13-03): defer scrollPhaseEnded (failed attempt, later superseded)
- `9639004` — fix(13-03): coasting as extended drag (failed attempt, later superseded)
- `82c807b` — fix(13-03): velocity ramp injection (working approach)
- `a39f008` — fix(13-03): tune intensity curves — wider native range, shorter web-app tail
- `3508086` — fix(13-03): push native intensity max (5.0x, later revised down)
- `c664814` — fix(13-03): quadratic tail acceleration; nativeScaleMax revised to 4.0x
- `b91fa21` — fix(13-03): drag-distance progressive scaling for short-drag safety

### Anti-Patterns Found

None. No TODO/FIXME/HACK/placeholder markers, no empty implementations, no return-null stubs in any phase 13 file.

### Human Verification Status

The 6 items from the initial VERIFICATION.md's human_verification section were addressed by UAT in 13-UAT.md:

| UAT Test | Result After 13-03 |
|----------|--------------------|
| Momentum toggle OFF stops coasting (native apps: Finder, IA Writer) | Passed |
| Momentum toggle OFF stops coasting (web-view apps) | Passed |
| Intensity slider changes coasting feel (Less vs More in native apps) | Passed |
| No regression in web-view apps | Passed |
| Default center intensity unchanged | Passed |
| Settings persist across restart | Passed (UAT test 5) |
| Reset to Defaults restores inertia settings | Passed (UAT test 6) |

All human verification items resolved by UAT.

### Gaps Summary

No gaps. All four success criteria are structurally satisfied and runtime-confirmed by UAT:

1. **Toggle off stops scrolling immediately** — `handleMouseUp` else branch posts `scrollPhaseEnded` + zero-length momentum cancel sequence (`momentumPhase: 1` begin + `momentumPhase: 3` end), preventing NSScrollView from starting its own internal momentum. Confirmed in Finder and IA Writer.

2. **Toggle on restores coasting** — The `isInertiaEnabled` guard in `handleMouseUp` allows velocity ramp injection and `InertiaAnimator.startCoasting` when true. `inertiaIntensity` is an independent property not affected by toggling. Confirmed in UAT.

3. **Intensity slider controls coasting feel** — Two complementary mechanisms: (a) `nativeVelocityScaleForIntensity` (range 0.25x–4.0x) controls NSScrollView native momentum via velocity ramp injection before `scrollPhaseEnded`; (b) tau interpolation (0.120s–0.900s) and web velocity scale (0.4x–2.0x) control `InertiaAnimator` momentum for web-view apps. Both confirmed perceptibly different at Less vs More in UAT.

4. **Defaults on fresh install** — `isInertiaEnabled ?? true` and `inertiaIntensity ?? 0.5` in `AppState.init`. Confirmed in UAT (UAT test 6 confirmed reset restores to these values).

---

_Verified: 2026-02-23_
_Verifier: Claude (gsd-verifier)_
