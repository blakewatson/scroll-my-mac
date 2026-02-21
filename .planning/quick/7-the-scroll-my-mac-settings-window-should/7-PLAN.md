---
phase: quick-7
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - ScrollMyMac/Services/WindowExclusionManager.swift
autonomous: true
requirements: [QUICK-7]

must_haves:
  truths:
    - "Clicking toggles in the settings window works when it is on the primary display"
    - "Clicking toggles in the settings window works when it is on a secondary display"
    - "The click-through setting itself does not affect the ability to interact with the settings window"
  artifacts:
    - path: "ScrollMyMac/Services/WindowExclusionManager.swift"
      provides: "Per-window coordinate conversion using each window's own screen"
      contains: "window.screen"
  key_links:
    - from: "WindowExclusionManager.refreshCache()"
      to: "ScrollEngine.shouldPassThroughClick"
      via: "isPointInAppWindow(_:)"
      pattern: "isPointInAppWindow"
---

<objective>
Fix the settings window click-through on secondary displays.

Purpose: When the user drags the settings window to a secondary display and click-through is disabled, clicks on settings window toggles are incorrectly intercepted by the scroll engine because the CG-coordinate conversion uses the primary screen's height instead of each window's own screen height.

Output: WindowExclusionManager correctly converts AppKit window frames to global CG coordinates regardless of which display the window is on.
</objective>

<execution_context>
@/Users/blakewatson/.claude/get-shit-done/workflows/execute-plan.md
@/Users/blakewatson/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix per-window CG coordinate conversion in WindowExclusionManager</name>
  <files>ScrollMyMac/Services/WindowExclusionManager.swift</files>
  <action>
In `refreshCache()`, the `appWindowRects` block currently uses `NSScreen.main?.frame.height` to flip a single value for all windows. This is wrong for secondary displays because:

1. AppKit window `frame.origin.y` is relative to the global virtual desktop bottom-left (same origin as CG, but Y is flipped).
2. The CG coordinate for a window's top-left corner is: `cgY = totalVirtualDesktopHeight - (frame.origin.y + frame.height)`.
3. But the actual formula that works correctly per-screen is: for a window on screen S, `cgY = S.frame.origin.y + S.frame.height - (frame.origin.y + frame.height - S.frame.origin.y)` ... which simplifies to `cgY = 2 * S.frame.origin.y + S.frame.height - frame.origin.y - frame.height`.

Actually the correct and simplest approach: macOS CG coordinates have Y=0 at the top of the primary screen's top edge. NSScreen coordinates have Y=0 at the bottom of the primary screen. For each NSWindow, the CG top-left Y is computed as:

    let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
    let cgY = primaryScreenHeight - (window.frame.origin.y + window.frame.height)

The key insight: `NSScreen.screens.first` is ALWAYS the primary screen (the one with the menu bar / Y=0 for NSScreen), whereas `NSScreen.main` is the screen currently containing the key window — which changes dynamically. For the coordinate flip, we always need the PRIMARY screen's height (screens.first), not the main screen's height.

The current code uses `NSScreen.main?.frame.height` which is wrong when the key window is on a secondary display.

Change the `appWindowRects` block to:

```swift
if NSApp.isActive, let primaryHeight = NSScreen.screens.first?.frame.height {
    appWindowRects = NSApp.windows.compactMap { window in
        guard window.isVisible, !window.ignoresMouseEvents else { return nil }
        let frame = window.frame
        let cgRect = CGRect(
            x: frame.origin.x,
            y: primaryHeight - frame.origin.y - frame.height,
            width: frame.width,
            height: frame.height
        )
        return cgRect
    }
} else {
    appWindowRects = []
}
```

This is the same formula as before but uses `NSScreen.screens.first?.frame.height` (primary screen height, always correct as the Y-flip baseline) instead of `NSScreen.main?.frame.height` (active screen height, wrong when key window is on secondary display).

Do NOT change any other logic in the file.
  </action>
  <verify>Build the project: Product > Build (or Cmd+B) in Xcode. Build must succeed with no errors or warnings introduced by this change.</verify>
  <done>Build succeeds. When scroll mode is active with click-through disabled, clicking on controls in the settings window passes through the scroll engine correctly regardless of which display the window is on.</done>
</task>

</tasks>

<verification>
1. Build the app (Cmd+B) — no new errors or warnings.
2. Launch the app, enable scroll mode.
3. Disable click-through in settings.
4. Move the settings window to a secondary display.
5. Click on toggles in the settings window — they should respond normally (not be intercepted as scroll drags).
6. Confirm the same works on the primary display too (regression check).
</verification>

<success_criteria>
Settings window controls are interactive on any display regardless of the click-through setting. The scroll engine's `shouldPassThroughClick` correctly identifies points within the settings window on secondary displays.
</success_criteria>

<output>
After completion, create `.planning/quick/7-the-scroll-my-mac-settings-window-should/7-SUMMARY.md`
</output>
