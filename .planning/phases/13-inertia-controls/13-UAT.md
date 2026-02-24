---
status: resolved
phase: 13-inertia-controls
source: [13-01-SUMMARY.md, 13-02-SUMMARY.md]
started: 2026-02-23T06:00:00Z
updated: 2026-02-24T00:00:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Momentum Scrolling Toggle
expected: In Settings, "Momentum scrolling" toggle in Scroll Behavior section. OFF = no inertial coasting after releasing scroll. ON = momentum coasting resumes.
result: issue
reported: "Toggling off momentum scrolling works for certain views, especially apps that have web views. But it seems that native apps like the Finder or IA Writer don't respect the momentum scrolling disabled setting. they seem to be providing their own internal momentum."
severity: major

### 2. Intensity Slider Visible and Responsive
expected: Below the momentum toggle, an "Intensity" slider appears with "Less" and "More" endpoint labels. Slider is interactive when momentum is ON, and grayed out / disabled when momentum is OFF.
result: pass

### 3. Center Detent Snap
expected: Dragging the intensity slider near the center snaps to the midpoint (0.5). A small tick mark is visible at the center of the slider track indicating the default position.
result: pass

### 4. Intensity Affects Coasting Feel
expected: With momentum ON, setting intensity to "Less" (far left) produces short, slow coasting. Setting to "More" (far right) produces long, fast coasting. Center feels like the original default.
result: issue
reported: "The intensity slider does affect the coasting feel in apps that respect it, which seems to be apps that have web views. That said, native apps seem to ignore this setting entirely."
severity: major

### 5. Settings Persist Across Restart
expected: Set momentum OFF or change intensity to a non-default value, quit and relaunch the app. The toggle and slider reflect the saved values — not reset to defaults.
result: pass

### 6. Reset to Defaults Restores Inertia
expected: After changing momentum/intensity settings, clicking "Reset to Defaults" restores momentum ON and intensity slider to center (0.5).
result: pass

### 7. Settings Section Organization
expected: Settings window shows logically grouped sections: Scroll Mode, Scroll Behavior (containing momentum toggle + intensity slider), Safety, General, Excluded Apps, Reset.
result: pass

## Summary

total: 7
passed: 5
issues: 2
pending: 0
skipped: 0

## Gaps

- truth: "Momentum scrolling toggle disables all inertial coasting when OFF"
  status: resolved
  reason: "User reported: Toggling off momentum scrolling works for certain views, especially apps that have web views. But it seems that native apps like the Finder or IA Writer don't respect the momentum scrolling disabled setting. they seem to be providing their own internal momentum."
  severity: major
  test: 1
  root_cause: "NSScrollView has built-in momentum scrolling triggered by the scroll phase state machine (began->changed->ended). When ScrollEngine posts scrollPhaseEnded on mouse-up, NSScrollView interprets this as user finished scrolling and initiates its own internal momentum. Disabling our InertiaAnimator does not suppress NSScrollView's native momentum. Need to post a zero-length momentum sequence (momentumPhase begin+end with zero deltas) after scrollPhaseEnded when inertia is disabled."
  artifacts:
    - path: "ScrollMyMac/Services/ScrollEngine.swift"
      issue: "handleMouseUp() posts scrollPhaseEnded but no momentum-cancel to suppress NSScrollView's internal momentum"
    - path: "ScrollMyMac/Services/InertiaAnimator.swift"
      issue: "~16ms gap between scrollPhaseEnded and first momentum-begin allows NSScrollView to start its own momentum"
  missing:
    - "Post zero-length momentum sequence (begin+end, zero deltas) when inertia disabled"
    - "Fire first momentum-begin synchronously (no CADisplayLink gap) when inertia enabled"
  debug_session: ".planning/debug/native-momentum-bypass.md"

- truth: "Intensity slider affects coasting feel across all apps"
  status: resolved
  reason: "User reported: The intensity slider does affect the coasting feel in apps that respect it, which seems to be apps that have web views. That said, native apps seem to ignore this setting entirely."
  severity: major
  test: 4
  root_cause: "Same root cause as Test 1. NSScrollView generates its own momentum independently of InertiaAnimator. Our intensity-scaled momentum events compete with NSScrollView's internal momentum. Fix: ensure our momentum events arrive before NSScrollView starts its own, so NSScrollView defers to incoming momentum rather than generating its own."
  artifacts:
    - path: "ScrollMyMac/Services/ScrollEngine.swift"
      issue: "handleMouseUp() posts scrollPhaseEnded but no momentum-cancel to suppress NSScrollView's internal momentum"
    - path: "ScrollMyMac/Services/InertiaAnimator.swift"
      issue: "CADisplayLink delay allows NSScrollView to start its own momentum before our first momentum event"
  missing:
    - "Fire first momentum-begin synchronously after scrollPhaseEnded (eliminate 16ms gap)"
    - "NSScrollView should defer to incoming momentum events once it sees momentumPhase begin"
  debug_session: ".planning/debug/native-momentum-bypass.md"
