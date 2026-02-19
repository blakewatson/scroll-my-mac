---
phase: quick-6
plan: 6
type: execute
wave: 1
depends_on: []
files_modified:
  - ScrollMyMac/Services/ScrollEngine.swift
autonomous: true
requirements: [QUICK-6]

must_haves:
  truths:
    - "After clicking an excluded app window then clicking a non-excluded window, moving the mouse to the bottom screen edge reveals the Dock"
    - "The fix does not break normal scrolling, click-through, or hold-to-passthrough behavior"
  artifacts:
    - path: "ScrollMyMac/Services/ScrollEngine.swift"
      provides: "handleMouseUp guard against orphaned mouseUp suppression"
      contains: "pass through mouseUp when no state is tracked"
  key_links:
    - from: "ScrollEngine.handleMouseUp"
      to: "window server"
      via: "returning Unmanaged.passUnretained(event) when engine has no tracked state"
      pattern: "!pendingMouseDown && !isDragging && !isInPassthroughMode && !passedThroughClick"
---

<objective>
Fix a race condition in the ScrollEngine's handleMouseUp method that causes orphaned mouseDown events to leave the window server thinking a button is still held, preventing Dock auto-reveal.

Purpose: When the user clicks from an excluded app to a non-excluded app, the NSWorkspace notification updating `isFrontmostExcluded` fires on the main thread asynchronously. The event tap runs on a background thread. This creates a window where the mouseDown event for the non-excluded window click is bypassed (excluded app still frontmost per stale state) but the corresponding mouseUp is intercepted (notification has now fired). The engine's handleMouseUp finds no tracked state and returns nil — suppressing the mouseUp. The window server never sees the mouseUp, believes a button press is still in progress, and suppresses Dock auto-reveal until a subsequent click resets everything.

Output: Modified ScrollEngine.swift with a guard in handleMouseUp that passes through the event when no state is being tracked by the engine.
</objective>

<execution_context>
@/Users/blakewatson/.claude/get-shit-done/workflows/execute-plan.md
@/Users/blakewatson/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/STATE.md
@ScrollMyMac/Services/ScrollEngine.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Guard against orphaned mouseUp suppression in handleMouseUp</name>
  <files>ScrollMyMac/Services/ScrollEngine.swift</files>
  <action>
In `handleMouseUp`, after the `passedThroughClick` branch and before the `isInPassthroughMode` branch, add a check: if the engine has no tracked interaction state — meaning `pendingMouseDown == false` AND `isDragging == false` AND `isInPassthroughMode == false` — pass the event through instead of suppressing it.

The current code at the bottom of handleMouseUp always returns `nil` (suppresses) even when the engine has no tracked state. This is the race condition entry point.

The fix: add an early return that passes through the event when the engine has no record of the corresponding mouseDown. Place this check after the `passedThroughClick` block and before the `isInPassthroughMode` block (since isInPassthroughMode needs its own handling):

```swift
// No tracked interaction state — engine never saw the corresponding mouseDown
// (e.g., race between excluded-app bypass and NSWorkspace notification).
// Pass through to avoid orphaning the mouseUp in the window server.
if !pendingMouseDown && !isDragging && !isInPassthroughMode {
    passedThroughClick = false
    return Unmanaged.passUnretained(event)
}
```

This guard must come AFTER the `passedThroughClick` branch (line ~321) and BEFORE the `isInPassthroughMode` branch (line ~327). The `passedThroughClick = false` reset is included to clean up any stale value.

Do NOT move or modify the replay marker check at the top of the function (that stays first). Do NOT change any other branches.

Build and verify: `xcodebuild -project ScrollMyMac.xcodeproj -scheme ScrollMyMac -configuration Debug build 2>&1 | tail -5`
  </action>
  <verify>
    1. `xcodebuild -project /Users/blakewatson/Dropbox/Projects/scroll-my-mac/ScrollMyMac.xcodeproj -scheme ScrollMyMac -configuration Debug build 2>&1 | tail -10` — must show "BUILD SUCCEEDED"
    2. Review the modified handleMouseUp to confirm: replay marker check first, passedThroughClick branch second, new guard third, isInPassthroughMode branch fourth, pendingMouseDown branch fifth, isDragging branch last.
  </verify>
  <done>
    Build succeeds. handleMouseUp passes through mouseUp events when the engine has no tracked mouseDown state, preventing the window server from seeing an orphaned button press. All other branches unchanged.
  </done>
</task>

</tasks>

<verification>
After the fix:
- User clicks excluded app, then clicks non-excluded app window → moves mouse to bottom screen edge → Dock auto-reveals (no second click required)
- Normal scroll mode: click-drag still scrolls, click-without-drag still replays as click
- Hold-to-passthrough: still works when enabled
- No regressions in click-through or inertia behavior
</verification>

<success_criteria>
Dock auto-reveals on mouse proximity after switching from excluded to non-excluded app window, without requiring a second click. Build succeeds with no errors.
</success_criteria>

<output>
After completion, create `.planning/quick/6-fix-dock-auto-reveal-not-working-when-sw/6-SUMMARY.md`
</output>
