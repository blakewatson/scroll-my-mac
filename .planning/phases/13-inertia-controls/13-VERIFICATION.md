---
phase: 13-inertia-controls
verified: 2026-02-22T00:00:00Z
status: passed
score: 8/8 must-haves verified
re_verification: false
human_verification:
  - test: "Toggle Momentum scrolling OFF, perform a drag-and-release"
    expected: "Scrolling stops immediately with zero coasting"
    why_human: "Runtime behavior — cannot verify absence of animation programmatically from source alone"
  - test: "Toggle Momentum scrolling back ON, perform a drag-and-release"
    expected: "Momentum coasting resumes at the previously set intensity"
    why_human: "Runtime behavior and state preservation across toggle cannot be verified statically"
  - test: "Move Intensity slider to Less, drag-and-release; then move to More, drag-and-release"
    expected: "Less position produces shorter/slower coast; More position produces longer/faster coast"
    why_human: "Perceptual physics behavior — cannot verify scroll feel from source alone"
  - test: "Drag Intensity slider near the center"
    expected: "Slider snaps to exactly 50% and stays there"
    why_human: "UI interaction behavior requires the running app"
  - test: "Set non-default toggle + slider values, quit and relaunch the app"
    expected: "Both settings are restored to the values set before quit"
    why_human: "UserDefaults persistence requires a live app restart to confirm"
  - test: "Click Reset to Defaults"
    expected: "Momentum toggle returns to ON and Intensity slider returns to center (50%)"
    why_human: "UI reset behavior requires the running app"
---

# Phase 13: Inertia Controls Verification Report

**Phase Goal:** Users can tune or completely disable momentum scrolling to match their preference
**Verified:** 2026-02-22
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

All four success criteria map directly to observable truths that can be verified structurally. Runtime behavior items are flagged for human verification. All automated checks pass.

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | When `isInertiaEnabled` is false, releasing a drag produces zero coasting | VERIFIED | `ScrollEngine.handleMouseUp`: `if isInertiaEnabled, let velocity = ...` — inertia block skipped entirely when false (line 368) |
| 2 | When `isInertiaEnabled` is true, releasing a drag produces momentum scrolling | VERIFIED | Same guard: when true, `inertiaAnimator.startCoasting(velocity:axis:intensity:)` is called with full intensity param |
| 3 | Toggling inertia off then back on preserves the intensity value | VERIFIED | `isInertiaEnabled` and `inertiaIntensity` are independent stored properties; toggling one never touches the other |
| 4 | `inertiaIntensity` at 0.5 reproduces exactly the current hardcoded inertia feel | VERIFIED | Two-segment lerp: at t=0.5, tau=0.400 (tauMid), velocityScale=1.0 (velocityScaleMid) — identical to prior hardcoded constants |
| 5 | `inertiaIntensity` at 0.0 produces minimal but nonzero coasting | VERIFIED | At t=0.0, tau=0.120 (tauMin), velocityScale=0.4 — nonzero amplitude means coasting occurs but is short and slow |
| 6 | `inertiaIntensity` at 1.0 produces long iOS-like flick coasting | VERIFIED | At t=1.0, tau=0.900 (tauMax), velocityScale=2.0 — long duration, doubled velocity amplitude |
| 7 | Both `isInertiaEnabled` and `inertiaIntensity` persist across app restarts | VERIFIED | Both properties have `UserDefaults.standard.set(...)` in `didSet`, and init loads them with `object(forKey:) as? Type ?? default` pattern |
| 8 | Inertia toggle defaults to on and intensity defaults to 0.5 on fresh install | VERIFIED | `AppState.init`: `?? true` for `isInertiaEnabled`, `?? 0.5` for `inertiaIntensity` when key absent |

**Score:** 8/8 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `ScrollMyMac/Services/InertiaAnimator.swift` | Parameterized tau for intensity control | VERIFIED | `func startCoasting(velocity:axis:intensity:)` present at line 67; two-segment lerp for both tau (0.120–0.900) and velocity scale (0.4x–2.0x) fully implemented |
| `ScrollMyMac/App/AppState.swift` | `isInertiaEnabled` and `inertiaIntensity` with UserDefaults persistence | VERIFIED | Both properties with `didSet` UserDefaults save at lines 90–102; init loads both at lines 137–138; `resetToDefaults` restores both at lines 244–245; `setupServices` syncs both at lines 176–177 |
| `ScrollMyMac/Services/ScrollEngine.swift` | Inertia skip path when disabled, intensity passed to animator | VERIFIED | `isInertiaEnabled: Bool = true` and `inertiaIntensity: Double = 0.5` at lines 44–47; conditional guard in `handleMouseUp` at line 368 |
| `ScrollMyMac/Features/Settings/SettingsView.swift` | Momentum scrolling toggle and Intensity slider in reorganized settings | VERIFIED | Toggle at line 103, slider at lines 108–131 within `LabeledContent("Intensity")`; disabled modifier at line 132; center snap at line 116; center tick mark background at lines 120–126 |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `AppState.swift` | `ScrollEngine.swift` | `scrollEngine.isInertiaEnabled` in `didSet` | VERIFIED | Line 93: `scrollEngine.isInertiaEnabled = isInertiaEnabled`; also synced at init via `setupServices` line 176 |
| `AppState.swift` | `ScrollEngine.swift` | `scrollEngine.inertiaIntensity` in `didSet` | VERIFIED | Line 100: `scrollEngine.inertiaIntensity = inertiaIntensity`; also synced at init via `setupServices` line 177 |
| `ScrollEngine.swift` | `InertiaAnimator.swift` | `startCoasting` call with `intensity` parameter | VERIFIED | Lines 369–373: `inertiaAnimator.startCoasting(velocity: velocity, axis: lockedAxis, intensity: CGFloat(inertiaIntensity))` |
| `SettingsView.swift` | `AppState.swift` | `$appState.isInertiaEnabled` binding | VERIFIED | Line 103: `Toggle("Momentum scrolling", isOn: $appState.isInertiaEnabled)` |
| `SettingsView.swift` | `AppState.swift` | `$appState.inertiaIntensity` binding | VERIFIED | Line 113: `Slider(value: $appState.inertiaIntensity, in: 0...1)` |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| INRT-01 | 13-01, 13-02 | User can toggle inertia on/off in settings (enabled by default) | SATISFIED | Toggle in SettingsView binds to `AppState.isInertiaEnabled`; default `true` in `init` |
| INRT-02 | 13-02 | User can adjust inertia intensity via a slider (weaker/stronger) | SATISFIED | `LabeledContent("Intensity")` slider with Less/More labels, 0–1 range, center snap; bound to `AppState.inertiaIntensity` |
| INRT-03 | 13-01 | When inertia is disabled, releasing a drag stops immediately | SATISFIED | `ScrollEngine.handleMouseUp`: `if isInertiaEnabled, let velocity = ...` guard completely skips coasting when false |

All three INRT requirement IDs from both plans are accounted for. No orphaned requirements.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `SettingsView.swift` | 115 | Stale comment says `within 0.05` but code checks `< 0.025` | Info | Comment mismatch only; the code is correct (0.025 matches the fix commit intent). No functional impact. |

No stubs, placeholders, empty implementations, or TODO/FIXME/HACK markers found in any phase 13 files.

### Human Verification Required

The following items cannot be confirmed from source code alone and require running the app:

#### 1. Inertia disable stops scrolling immediately

**Test:** With scroll mode active, toggle "Momentum scrolling" OFF in Settings. Perform a drag and release.
**Expected:** Scrolling stops at the exact moment the mouse button is released — no coasting or continued movement.
**Why human:** The absence of animation is a runtime observable behavior, not a compile-time property.

#### 2. Inertia re-enable resumes coasting at preserved intensity

**Test:** With "Momentum scrolling" OFF, drag the Intensity slider to a non-center position. Toggle momentum back ON. Perform a drag-and-release.
**Expected:** Coasting occurs and the slider has not moved from the set position.
**Why human:** Requires observing that the intensity value survives the toggle cycle and produces perceptibly different coasting.

#### 3. Intensity slider produces perceptibly different coasting

**Test:** Set slider to leftmost (Less). Scroll and release. Then set to rightmost (More). Scroll and release.
**Expected:** Less position produces noticeably shorter, slower coast. More position produces noticeably longer, faster coast.
**Why human:** Coasting feel is perceptual — requires running the app and subjective comparison.

#### 4. Center detent snap

**Test:** Drag the Intensity slider slowly from either end toward the center.
**Expected:** When within ~2.5% of center, the slider thumb snaps and locks to exactly 50%.
**Why human:** Snap behavior is a runtime UI interaction.

#### 5. Persistence across app restart

**Test:** Set "Momentum scrolling" to OFF and Intensity slider to approximately 75%. Quit the app completely. Relaunch.
**Expected:** The toggle remains OFF and the slider position remains near 75%.
**Why human:** UserDefaults persistence requires a full app lifecycle to confirm.

#### 6. Reset to Defaults restores both settings

**Test:** With non-default values set for both controls, click "Reset to Defaults".
**Expected:** Momentum scrolling toggle returns to ON; Intensity slider returns to center position (50%).
**Why human:** UI reset behavior requires the running app to observe.

### Gaps Summary

No gaps. All structural verification passed. The phase backend (Plan 01) and UI (Plan 02) are fully implemented and wired. The four success criteria are satisfied by the codebase:

1. **Toggle off stops scrolling immediately** — `ScrollEngine.handleMouseUp` uses `if isInertiaEnabled, let velocity` as a single guard, so when disabled the coasting block is never entered.
2. **Toggle on restores coasting** — The same guard allows coasting when `isInertiaEnabled` is true; `inertiaIntensity` is independent and unaffected by toggling.
3. **Intensity slider controls coasting feel** — Two-segment linear interpolation in `InertiaAnimator` scales both tau (0.120–0.900s) and velocity amplitude (0.4x–2.0x).
4. **Defaults on fresh install** — `isInertiaEnabled` defaults to `true` and `inertiaIntensity` defaults to `0.5` via nil-coalescing in `AppState.init`.

---

_Verified: 2026-02-22_
_Verifier: Claude (gsd-verifier)_
