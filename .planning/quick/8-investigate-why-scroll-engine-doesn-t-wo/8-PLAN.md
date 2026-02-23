---
phase: quick-8
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - ScrollMyMac/Services/ScrollEngine.swift
autonomous: false
requirements: [QUICK-8]

must_haves:
  truths:
    - "Root cause of WKWebView scroll failure is verified (not just hypothesized)"
    - "Findings are documented with clear explanation of why it happens"
    - "A fix is implemented if feasible, or a known-limitation is documented if not"
  artifacts:
    - path: ".planning/quick/8-investigate-why-scroll-engine-doesn-t-wo/8-SUMMARY.md"
      provides: "Investigation findings, root cause, and resolution"
  key_links:
    - from: "ScrollEngine.postScrollEvent"
      to: "WKWebView event routing"
      via: "CGEvent scroll wheel posted at .cgSessionEventTap"
      pattern: "scrollEvent.post\\(tap: .cgSessionEventTap\\)"
---

<objective>
Investigate why ScrollMyMac's scroll engine does not work on MarkEdit (a WKWebView + CodeMirror 6 editor) when click-through is enabled, verify the root cause, and implement a fix if feasible.

Purpose: MarkEdit is a popular macOS text editor. Understanding and resolving this WKWebView incompatibility improves ScrollMyMac's compatibility with a class of hybrid native+web apps.
Output: Documented root cause analysis, and either a code fix or a documented known limitation.
</objective>

<execution_context>
@/Users/blake/.claude/get-shit-done/workflows/execute-plan.md
@/Users/blake/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@ScrollMyMac/Services/ScrollEngine.swift
@ScrollMyMac/Services/WindowExclusionManager.swift
@ScrollMyMac/Services/AppExclusionManager.swift
@ScrollMyMac/App/AppState.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Verify root cause and explore fix approaches</name>
  <files>ScrollMyMac/Services/ScrollEngine.swift</files>
  <action>
The hypothesis: WKWebView-based apps (like MarkEdit) don't process synthetic scroll wheel events when their window isn't key/focused. Click-through mode suppresses the original mouseDown (line 223 of ScrollEngine.swift returns nil), so the target window never becomes key. The scroll events ARE posted via .cgSessionEventTap but WKWebView's internal event routing requires responder-chain focus to convert native scroll events into JavaScript DOM wheel events.

Investigation steps:
1. Examine the scroll event posting path. Currently `postScrollEvent` posts at `.cgSessionEventTap` with no target window specified. CGEvents posted this way go to "the window under the pointer" per macOS event routing -- but WKWebView may need the window to be the key window for its internal WebProcess to pick up the events.

2. Research whether we can make the target window key BEFORE posting scroll events, without disrupting the click-through UX. The key insight: when entering scroll mode (user drags past dead zone, line 251-261 in handleMouseDragged), we could post a synthetic mouseDown+mouseUp at the drag origin to make the window key, then immediately start scrolling. This "focus then scroll" approach would:
   - Make the target window key (WKWebView gets responder chain)
   - NOT disrupt scroll UX (scroll starts from the drag, not the click)
   - Side effect: brings the background window to focus (which may actually be desirable -- the user IS interacting with it)

3. Implement the fix: In `handleMouseDragged`, when transitioning from pendingMouseDown to isDragging (the dead zone exceeded path, around line 251), post a quick synthetic mouseDown+mouseUp pair to the drag origin BEFORE starting scroll events. This activates the window. Use the existing `replayClick` helper or a similar mechanism, but ensure the events are tagged with the replayMarker so our own event tap passes them through.

   Specifically, add a call like:
   ```swift
   // Activate the target window so WKWebView-based apps receive scroll events.
   // Without this, apps using WKWebView (MarkEdit, etc.) ignore scroll events
   // posted to unfocused windows because WKWebView requires responder-chain
   // focus to route native scroll events to its web content.
   replayClick(at: pendingMouseDownLocation, clickState: pendingClickState)
   ```

   Place this BEFORE the scroll-began event is posted (before `isDragging = true` and the subsequent scroll event posting).

   IMPORTANT CONSIDERATION: This replay click will cause the window to come to the foreground. This changes click-through behavior from "scroll without focusing" to "focus then scroll". This is actually reasonable UX -- if you're scrolling a window, you're interacting with it. But it IS a behavior change for ALL apps, not just WKWebView ones.

   ALTERNATIVE: If we want to ONLY activate for WKWebView apps, we'd need to detect them. We could use CGWindowListCopyWindowInfo to check if the target window's owner uses WKWebView, but that's not detectable from window info alone. Bundle ID detection would be brittle.

   RECOMMENDATION: The simplest and most correct approach is to activate the target window when entering scroll mode. This fixes WKWebView apps AND is arguably better UX for all apps (you're scrolling it, so it makes sense for it to be focused). If the user reports this as a regression for other workflows, we can make it configurable later.

   However -- there's a subtlety. The replayClick posts both mouseDown and mouseUp. The mouseDown will make the window key, but it might also trigger unintended actions (e.g., clicking a button in the target window). A safer approach: instead of replaying a full click, use NSRunningApplication.activate() or post the events at the window title bar area. But NSRunningApplication.activate() brings the ENTIRE app forward (all windows), which is heavier than needed.

   SAFEST FIX: Post just a mouseDown+mouseUp pair at the original click location. This is exactly what a normal click would do -- it focuses the window and clicks at that spot. Since the user clicked there anyway (they just moved past the dead zone), activating at that point is the natural behavior. The click may trigger UI elements at that location, but this is the same as what happens when click-through is disabled or when the user clicks without dragging.

   Actually, re-reading the code more carefully: when `clickThroughEnabled` is true and the user drags past the dead zone, the original click is SUPPRESSED and scroll mode starts. The click is never delivered. If we now deliver it, that changes behavior -- the click target gets activated AND clicked. This could trigger buttons, links, etc.

   REVISED SAFEST FIX: Use `CGEvent.post` with a mouseDown immediately followed by mouseUp at the click location, but ONLY post the mouseDown (no mouseUp initially) -- no wait, that leaves a dangling mouseDown.

   ACTUALLY SIMPLEST AND SAFEST: We don't need to click. We just need to make the window key. We can do this by finding the window under the cursor using `CGWindowListCopyWindowInfo` to get the owning PID, then using NSRunningApplication(processIdentifier:) to activate that app. This makes the window key WITHOUT clicking anything.

   Implementation in ScrollEngine.swift -- add a private method:
   ```swift
   private func activateWindowUnderCursor(at point: CGPoint) {
       // Get the window list to find which window is under the cursor
       guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return }

       for info in windowList {
           guard let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                 let bounds = CGRect(dictionaryRepresentation: boundsDict),
                 bounds.contains(point),
                 let pid = info[kCGWindowOwnerPID as String] as? pid_t else { continue }

           // Don't activate our own app
           if pid == ProcessInfo.processInfo.processIdentifier { return }

           // Activate the owning app (makes its window key)
           if let app = NSRunningApplication(processIdentifier: pid) {
               app.activate()
           }
           return
       }
   }
   ```

   Call this in `handleMouseDragged` when transitioning from dead zone to scroll mode (line ~251), right before setting `isDragging = true`.

   NOTE: `NSRunningApplication.activate()` activates the app but may bring ALL its windows forward. On macOS, `activate()` makes the app frontmost. This is reasonable -- the user is interacting with that app's window.

   EDGE CASE: If the user is scrolling a background window intentionally without wanting to bring it forward (e.g., reading a reference window while typing in another), this activation would be disruptive. To mitigate: use `activate(options: [])` with no options, which brings the app forward. Or we could use the lower-level `_SLPSSetFrontProcessWithOptions` but that's private API.

   DECISION FOR IMPLEMENTATION: Go with `NSRunningApplication.activate()` in the dead-zone-exceeded transition. This fixes WKWebView apps. Document the behavior change. If users report it as a regression, we can add a "focus window on scroll" toggle in settings later.
  </action>
  <verify>
    Build succeeds: `cd /Users/blake/Dropbox/Projects/scroll-my-mac && xcodebuild -scheme ScrollMyMac -configuration Debug build 2>&1 | tail -5`
  </verify>
  <done>
    ScrollEngine.swift contains an activateWindowUnderCursor method that is called when transitioning from the click-through dead zone into scroll mode. The code compiles without errors.
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 2: Verify fix with MarkEdit and other apps</name>
  <what-built>
    Added window activation when entering scroll mode from click-through dead zone. When you click on an unfocused window and drag past the dead zone to scroll, the target window is now activated (brought to focus) before scroll events are posted. This ensures WKWebView-based apps like MarkEdit receive the scroll events properly.
  </what-built>
  <how-to-verify>
    1. Build and run ScrollMyMac from Xcode
    2. Enable scroll mode (F6)
    3. Open MarkEdit with some scrollable content
    4. Click on another app's window so MarkEdit is in the background (not focused)
    5. Click on the MarkEdit window and drag down -- it should now scroll the content
    6. Verify: The MarkEdit window comes to focus when you start scrolling (this is the new behavior)
    7. Test with a normal (non-WKWebView) app like Finder or TextEdit to ensure scrolling still works and the window activation doesn't cause issues
    8. Test that click-through still works: click on an unfocused window without dragging -- it should still pass through as a normal click (no change to existing behavior)
    9. Test that scrolling a FOCUSED window still works normally (no regression)

    If MarkEdit scrolls correctly: approved
    If there are issues with the activation approach: describe what went wrong
  </how-to-verify>
  <resume-signal>Type "approved" if MarkEdit scrolling works, or describe any issues observed</resume-signal>
</task>

</tasks>

<verification>
- ScrollMyMac builds without errors
- MarkEdit scrolls when click-through scroll is used on its unfocused window
- Normal apps continue to scroll correctly
- Click-through (click without drag) still works as before
</verification>

<success_criteria>
- Root cause verified: WKWebView apps don't process scroll events when window isn't key
- Fix implemented: target window is activated when entering scroll mode from click-through
- Fix verified by user testing with MarkEdit
- Or: documented as known limitation if fix approach causes unacceptable side effects
</success_criteria>

<output>
After completion, create `.planning/quick/8-investigate-why-scroll-engine-doesn-t-wo/8-SUMMARY.md`
</output>
