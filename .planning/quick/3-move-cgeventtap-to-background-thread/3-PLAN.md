---
phase: quick-3
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - ScrollMyMac/Services/WindowExclusionManager.swift
  - ScrollMyMac/Services/ScrollEngine.swift
  - ScrollMyMac/App/AppState.swift
  - ScrollMyMac/Services/OverlayManager.swift
autonomous: true
requirements: [QUICK-3]
must_haves:
  truths:
    - "CGEventTap callback fires on a dedicated background thread, never the main thread"
    - "shouldPassThroughClick never accesses NSApp.windows or any AppKit API from the callback"
    - "macOS no longer disables the event tap under main-thread UI contention"
    - "Scrolling, click-through, inertia, and overlay dot all continue to work correctly"
  artifacts:
    - path: "ScrollMyMac/Services/ScrollEngine.swift"
      provides: "Background-threaded event tap with thread-safe state"
    - path: "ScrollMyMac/Services/WindowExclusionManager.swift"
      provides: "Cached app window frames alongside existing OSK frame caching"
    - path: "ScrollMyMac/App/AppState.swift"
      provides: "Updated wiring that uses cached frames instead of NSApp.windows"
  key_links:
    - from: "ScrollEngine.swift"
      to: "background thread run loop"
      via: "dedicated Thread + CFRunLoop"
      pattern: "CFRunLoopAddSource.*tapRunLoop"
    - from: "AppState.swift shouldPassThroughClick"
      to: "WindowExclusionManager cached app frames"
      via: "isPointInAppWindow check"
      pattern: "isPointInAppWindow|appWindowRects"
    - from: "ScrollEngine callback"
      to: "OverlayManager.updatePosition"
      via: "DispatchQueue.main.async in onDragPositionChanged"
      pattern: "DispatchQueue\\.main\\.async"
---

<objective>
Move the CGEventTap to a dedicated background thread so macOS never disables it due to main-thread contention. Cache the app's own window frames so the shouldPassThroughClick closure never touches NSApp.windows from the callback thread. Ensure all callbacks that touch AppKit (overlay, drag state) dispatch to main thread.

Purpose: Fixes sporadic issue where macOS disables the event tap because the callback is blocked by main-thread UI work, causing mouseDown events to leak through and trigger text selection or drag-and-drop instead of scrolling.

Output: Updated ScrollEngine.swift, WindowExclusionManager.swift, AppState.swift, OverlayManager.swift
</objective>

<execution_context>
@/Users/blakewatson/.claude/get-shit-done/workflows/execute-plan.md
@/Users/blakewatson/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@ScrollMyMac/Services/ScrollEngine.swift
@ScrollMyMac/Services/WindowExclusionManager.swift
@ScrollMyMac/App/AppState.swift
@ScrollMyMac/Services/OverlayManager.swift
@ScrollMyMac/Services/InertiaAnimator.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Cache app window frames in WindowExclusionManager</name>
  <files>
    ScrollMyMac/Services/WindowExclusionManager.swift
    ScrollMyMac/App/AppState.swift
  </files>
  <action>
Extend WindowExclusionManager to also cache the app's own window frames, so the event-tap callback never needs to call NSApp.windows.

In WindowExclusionManager.swift:

1. Add a new private property `appWindowRects: [CGRect] = []` alongside the existing `excludedRects`.

2. Add a public method `isPointInAppWindow(_ point: CGPoint) -> Bool` that checks the cached `appWindowRects` array. This mirrors the existing `isPointExcluded(_:)` pattern.

3. In `refreshCache()` (which already runs on main thread via Timer), add a second pass that caches the app's own visible, mouse-interactive window frames. Use `NSApp.windows` here (safe because refreshCache runs on main thread). For each window where `window.isVisible && !window.ignoresMouseEvents`, convert the NSWindow frame (bottom-left origin) to CG coordinates (top-left origin) using the screen height, and store in `appWindowRects`. This replaces the coordinate conversion that was previously done per-click in AppState.

4. In `stopMonitoring()`, also clear `appWindowRects = []`.

In AppState.swift:

5. Replace the `shouldPassThroughClick` closure body. Remove the `NSApp.windows` access and `NSScreen.main` lookup. Instead:
   - Check 1: `self.windowExclusionManager.isPointInAppWindow(cgPoint)` (cached app window frames, CG coordinates)
   - Check 2: `self.windowExclusionManager.isPointExcluded(cgPoint)` (existing OSK check, unchanged)
   - Both checks are pure array lookups with no AppKit calls, safe from any thread.

Note: The existing 0.5s/2.0s polling intervals for OSK are fine for app windows too -- the app's own windows move rarely (settings panel). The refresh already happens on a timer, so app window positions stay current.
  </action>
  <verify>
Build the project with Cmd+B (or `xcodebuild build`). Confirm no compile errors. Verify that `shouldPassThroughClick` in AppState.swift contains zero references to `NSApp.windows`, `NSScreen`, or `NSPoint` -- it should only call methods on `windowExclusionManager`.
  </verify>
  <done>
shouldPassThroughClick closure is fully thread-safe: it only reads cached CGRect arrays via WindowExclusionManager methods. No AppKit API is called from the closure. The cache is refreshed on the main thread timer alongside the existing OSK cache refresh.
  </done>
</task>

<task type="auto">
  <name>Task 2: Move CGEventTap to dedicated background thread</name>
  <files>
    ScrollMyMac/Services/ScrollEngine.swift
    ScrollMyMac/Services/OverlayManager.swift
  </files>
  <action>
Move the CGEventTap's run loop source to a dedicated background thread so the callback never competes with main-thread UI work.

In ScrollEngine.swift:

1. Add a private property `tapThread: Thread?` and a private property `tapRunLoop: CFRunLoop?` to hold the background thread and its run loop reference.

2. In `start()`, after creating the CGEventTap (the `CGEvent.tapCreate` call stays the same), instead of adding the run loop source to `CFRunLoopGetCurrent()`, create a new `Thread` with a closure that:
   a. Sets `Thread.current.name = "com.blakewatson.ScrollMyMac.EventTap"`
   b. Stores `CFRunLoopGetCurrent()` into `self.tapRunLoop`
   c. Calls `CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)`
   d. Calls `CGEvent.tapEnable(tap: eventTap, enable: true)`
   e. Calls `CFRunLoopRun()` to keep the thread alive
   Store the thread in `tapThread` and call `tapThread?.start()`.

3. In the re-enable path of `start()` (where `eventTap` already exists), the `CGEvent.tapEnable` call is fine from any thread -- no change needed.

4. In `stop()`, the `CGEvent.tapEnable(tap:enable:false)` call is safe from any thread. No change needed for the disable. The `resetDragState()` and state changes are fine because `stop()` is always called from the main thread and the tap is disabled first.

5. In `tearDown()`, after disabling the tap, call `CFRunLoopStop(tapRunLoop)` to exit the background thread's run loop, then set `tapThread = nil` and `tapRunLoop = nil`. Remove the `CFRunLoopRemoveSource(CFRunLoopGetCurrent(), ...)` call since the source is on the background run loop (stopping the run loop cleans up).

6. The callback itself (`scrollEventCallback` and `handleMouseDown/Dragged/Up`) runs on the background thread. The state it mutates (`isDragging`, `pendingMouseDown`, `lastDragPoint`, etc.) is ONLY accessed from the callback thread during active scrolling, so no lock is needed -- the tap is disabled before `stop()`/`tearDown()` touch this state.

7. For callbacks that touch UI:
   - `onDragPositionChanged` calls `OverlayManager.updatePosition(cgPoint:)` which already handles thread dispatch (has `if Thread.isMainThread` check). No change needed.
   - `onDragStateChanged` is called from `handleMouseDown` and `handleMouseUp`. Wrap these calls: `DispatchQueue.main.async { [weak self] in self?.onDragStateChanged?(true/false) }`. This is important because `onDragStateChanged` triggers AppState's overlay show/hide.
   - `shouldPassThroughClick` -- after Task 1, this only reads cached arrays, safe from any thread. No dispatch needed.

8. For `isActive` (an `@Observable` property read by SwiftUI): it is set in `start()`/`stop()`/`tearDown()` which are called from the main thread. No change needed.

9. The `tapDisabledByTimeout` handler in `scrollEventCallback` calls `CGEvent.tapEnable` which is thread-safe. No change needed.

10. `postScrollEvent` and `postMomentumScrollEvent` call `CGEvent.post()` which is thread-safe. No change needed.

11. `replayClick` calls `CGEvent.post()` which is thread-safe. No change needed.

In OverlayManager.swift: No changes needed -- `updatePosition(cgPoint:)` already dispatches to main thread when called off-main.
  </action>
  <verify>
Build the project with Cmd+B (or `xcodebuild build`). Confirm no compile errors. Run the app, activate scroll mode with F6, verify:
1. Scrolling works (click-drag in any app scrolls content)
2. Click-through works (short clicks pass through)
3. Inertia works (fast drag and release causes momentum scroll)
4. Overlay dot tracks cursor during drag
5. Clicking on the app's own settings window passes through
6. Toggling scroll mode off/on works cleanly
7. Under UI load (e.g., opening settings, resizing windows), the event tap is NOT disabled by macOS
  </verify>
  <done>
CGEventTap runs on a dedicated background thread named "com.blakewatson.ScrollMyMac.EventTap". The callback never blocks on main-thread work. All UI-touching callbacks dispatch to main thread. macOS no longer disables the tap under contention. All existing functionality (scrolling, click-through, inertia, overlay, pass-through) works correctly.
  </done>
</task>

</tasks>

<verification>
1. Build succeeds with zero errors and zero warnings related to thread safety
2. Scroll mode activates and deactivates cleanly via hotkey
3. Click-drag scrolling works in Safari, Finder, and other apps
4. Click-through (short clicks) still registers as normal clicks
5. Inertia momentum scrolling works after fast drag release
6. Overlay indicator dot follows cursor during scroll
7. Clicks on app's own windows (settings) pass through correctly
8. OSK exclusion still works if Accessibility Keyboard is enabled
9. No console errors about event tap being disabled by timeout during normal use
</verification>

<success_criteria>
The CGEventTap callback runs entirely on a background thread. The shouldPassThroughClick closure makes zero AppKit calls. macOS does not disable the event tap under main-thread UI contention. All existing scrolling, click-through, inertia, and overlay functionality works correctly.
</success_criteria>

<output>
After completion, create `.planning/quick/3-move-cgeventtap-to-background-thread/3-01-SUMMARY.md`
</output>
