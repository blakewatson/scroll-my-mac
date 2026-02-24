# Phase 3: Click Safety - Research

**Researched:** 2026-02-15
**Domain:** CGEvent interception, click replay, modifier detection, accessibility permission monitoring
**Confidence:** HIGH (core patterns verified against Apple docs and existing codebase)

## Summary

Phase 3 transforms the ScrollEngine from "suppress all clicks" to "hold and decide" -- suppressing mouse-down, tracking movement, and either replaying the click (if within dead zone) or treating it as a scroll drag. The core technique is well-established: suppress the original CGEvent by returning `nil` from the tap callback, then post synthetic mouseDown/mouseUp events via `CGEvent.post(tap:)` when the decision is "click."

Right-clicks and modifier-key clicks require expanding the event mask to include `rightMouseDown`/`rightMouseUp` and checking `event.flags` for modifier masks. Both are straightforward additions. Double-click support comes naturally from rapid click-release cycles that stay within the dead zone -- both clicks replay independently, and macOS handles the double-click detection automatically based on timing.

Permission revocation is the trickiest area. When Accessibility permission is revoked, existing CGEventTaps silently stop receiving events -- there is no reliable system notification. The safest approach is periodic polling with `AXIsProcessTrusted()` combined with handling `tapDisabledByTimeout` / `tapDisabledByUserInput` callback types as signals of potential permission loss.

**Primary recommendation:** Implement click-through as a state machine within ScrollEngine's existing `handleMouseDown`/`handleMouseUp` flow, replay clicks by posting synthetic CGEvents to `.cghidEventTap`, and add a periodic permission health check in AppState.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

- Click-through uses a "hold and decide" model: mouse-down is suppressed, movement is tracked
- If mouse-up occurs within ~8px dead zone, replay the click immediately (no delay beyond the hold)
- If movement exceeds ~8px, treat as scroll drag -- click is never delivered
- Dead zone is fixed at ~8px (not configurable)
- Click-through is behind a setting (default on) so users can disable it and revert to "all clicks become scrolls" behavior
- Escape does NOT affect scroll mode at all -- removed from success criteria
- F6 (toggle hotkey) is the only way to enable/disable scroll mode
- Right-clicks always pass through -- never intercepted by scroll mode
- Any click with a modifier key held (Cmd, Option, Shift, Ctrl) always passes through as a normal modified click
- Double-clicks should work normally in scroll mode -- both clicks pass through if within the dead zone
- Click pass-through is seamless and invisible -- no visual or audio feedback
- Safety timeout (existing from Phase 1) is the primary safety net
- If Accessibility permission is revoked, immediately disable scroll mode
- Show status in the app window so user can investigate (no disruptive popup)

### Claude's Discretion

- Click replay position (mouse-down vs mouse-up location)
- Mid-toggle and mid-drag cleanup behavior
- Permission recovery strategy (auto vs manual)
- Mid-drag permission revocation cleanup
- Accessibility Keyboard detection approach (research first)
- If scroll mode is toggled off mid-drag, handle simply

### Deferred Ideas (OUT OF SCOPE)

None -- discussion stayed within phase scope

</user_constraints>

## Standard Stack

### Core

This phase uses no new libraries -- everything is built on the existing CGEvent/CoreGraphics stack already in the codebase.

| API | Purpose | Why Standard |
|-----|---------|--------------|
| `CGEvent(mouseEventSource:mouseType:mouseCursorPosition:mouseButton:)` | Create synthetic click events for replay | Apple's official API for posting mouse events |
| `CGEvent.post(tap: .cghidEventTap)` | Post replayed clicks into the HID event stream | Standard tap location for synthetic input |
| `CGEventFlags` (`.maskShift`, `.maskControl`, `.maskAlternate`, `.maskCommand`) | Detect modifier keys on mouse events | Built-in flags on every CGEvent |
| `AXIsProcessTrusted()` | Poll accessibility permission status | Only reliable API for permission checking |

### Supporting

| API | Purpose | When to Use |
|-----|---------|-------------|
| `CGEvent.setIntegerValueField(.mouseEventClickState, value:)` | Set click count on synthetic events | When replaying clicks to preserve click-state for double-click |
| `event.getIntegerValueField(.mouseEventClickState)` | Read click count from intercepted events | To preserve and forward click count during replay |
| `UserDefaults` | Persist click-through enabled setting | Already used for safety mode setting |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Polling `AXIsProcessTrusted()` | `DistributedNotificationCenter` for `com.apple.accessibility.api` | Notification is unreliable -- not sent when app is removed from list (vs toggled off). Polling is more reliable. |
| Posting to `.cghidEventTap` | Posting to `.cgSessionEventTap` | `.cghidEventTap` is lower in the stack and more reliably recognized as "real" input. Use `.cghidEventTap` for click replay. |

## Architecture Patterns

### Pattern 1: Hold-and-Decide State Machine

**What:** Instead of immediately consuming or passing mouse-down, suppress it and enter a "pending" state. Track movement. On mouse-up, decide: replay click or end scroll.

**When to use:** When the same physical gesture (click) must map to two different outcomes (click vs scroll) based on subsequent movement.

**Implementation approach in ScrollEngine:**

```swift
// New state for the hold-and-decide model
private var pendingMouseDown: Bool = false
private var pendingMouseDownEvent: CGEvent?  // Store for replay
private var pendingMouseDownLocation: CGPoint = .zero
private var totalMovement: CGFloat = 0.0
private let clickDeadZone: CGFloat = 8.0

func handleMouseDown(event: CGEvent, proxy: CGEventTapProxy) -> Unmanaged<CGEvent>? {
    let location = event.location

    // Pass through: app's own windows
    if shouldPassThroughClick?(location) == true {
        passedThroughClick = true
        return Unmanaged.passUnretained(event)
    }

    // Pass through: right-clicks handled separately (not in left-mouse mask)
    // Pass through: modifier keys held
    let modifierMask: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
    if !event.flags.intersection(modifierMask).isEmpty {
        passedThroughClick = true
        return Unmanaged.passUnretained(event)
    }

    // If click-through disabled, go straight to scroll mode (old behavior)
    if !clickThroughEnabled {
        // ... existing scroll-start logic
        return nil
    }

    // Hold and decide: suppress mouse-down, start tracking
    pendingMouseDown = true
    pendingMouseDownLocation = location
    pendingMouseDownEvent = event.copy()  // Keep a copy for replay
    totalMovement = 0.0
    dragOrigin = location
    lastDragPoint = location
    return nil  // Suppress original
}
```

### Pattern 2: Click Replay via Synthetic CGEvents

**What:** When deciding "this was a click," post synthetic mouseDown + mouseUp events at the click position.

**Key details:**
- Use `CGEvent(mouseEventSource:mouseType:mouseCursorPosition:mouseButton:)` to create events
- Post to `.cghidEventTap` (not `.cgSessionEventTap`) for reliable delivery
- Preserve `mouseEventClickState` from the original event for double-click support
- Must set a flag to prevent the replayed click from being re-intercepted by our own event tap

```swift
func replayClick(at position: CGPoint, clickState: Int64 = 1) {
    // Set flag so our own tap passes these through
    isReplayingClick = true

    let source = CGEventSource(stateID: .hidSystemState)

    let mouseDown = CGEvent(
        mouseEventSource: source,
        mouseType: .leftMouseDown,
        mouseCursorPosition: position,
        mouseButton: .left
    )
    mouseDown?.setIntegerValueField(.mouseEventClickState, value: clickState)

    let mouseUp = CGEvent(
        mouseEventSource: source,
        mouseType: .leftMouseUp,
        mouseCursorPosition: position,
        mouseButton: .left
    )
    mouseUp?.setIntegerValueField(.mouseEventClickState, value: clickState)

    mouseDown?.post(tap: .cghidEventTap)
    mouseUp?.post(tap: .cghidEventTap)

    // Reset flag after a short delay or in the next event cycle
    isReplayingClick = false
}
```

### Pattern 3: Self-Event Detection (Preventing Replay Loop)

**What:** When we post synthetic clicks, our own event tap will see them. We need a way to pass them through without re-intercepting.

**Options (recommend Option A):**

**Option A -- Flag-based:** Set `isReplayingClick = true` before posting, check it in `handleMouseDown`, pass through if true. Simple and reliable since events are processed synchronously on the same thread.

**Option B -- eventSourceUserData:** Set a custom value on the synthetic event via `event.setIntegerValueField(.eventSourceUserData, value: magicNumber)` and check for it in the callback. More robust but more code.

**Recommendation:** Option A is sufficient. The event tap callback runs on the same run loop, so the flag will be checked before any other event can arrive. If testing reveals timing issues, upgrade to Option B.

### Pattern 4: Permission Health Check

**What:** Periodically poll `AXIsProcessTrusted()` to detect permission revocation.

**When to use:** While scroll mode is active, as a safety net.

```swift
// In AppState or a dedicated PermissionHealthMonitor
private var permissionCheckTimer: Timer?

func startPermissionMonitoring() {
    permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
        if !AXIsProcessTrusted() {
            self?.handlePermissionLost()
        }
    }
}

func handlePermissionLost() {
    permissionCheckTimer?.invalidate()
    isScrollModeActive = false
    isAccessibilityGranted = false
    // UI already shows warning banner when isAccessibilityGranted is false
}
```

### Anti-Patterns to Avoid

- **Re-intercepting replayed clicks:** Always check for the replay flag before suppressing a mouseDown. Without this, replayed clicks get swallowed.
- **Storing CGEvent references long-term:** CGEvents are CF types. The event passed to the callback is only valid during the callback. Call `.copy()` if you need to store it for later replay.
- **Blocking in the event tap callback:** The callback must return quickly. Any delay causes `tapDisabledByTimeout`. Never do async work or sleep in the callback.
- **Relying on DistributedNotificationCenter for permission changes:** The `com.apple.accessibility.api` notification is not sent in all cases (e.g., when the app is removed from the list rather than toggled off). Polling is more reliable.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Double-click detection | Custom double-click timer | Preserve `mouseEventClickState` from original event and set it on replayed events | macOS tracks click count internally; replaying with correct clickState lets the system handle double/triple click |
| Click distance calculation | Complex distance formula | `hypot(dx, dy)` | Standard math function, already available in Foundation |
| Permission change notification | Custom file watcher on TCC.db | Periodic `AXIsProcessTrusted()` polling | TCC database is private/protected; polling the public API is the only supported approach |

## Common Pitfalls

### Pitfall 1: Replayed Click Re-intercepted by Own Event Tap

**What goes wrong:** You post a synthetic mouseDown to replay a click, but your own CGEventTap intercepts it again, creating an infinite loop or swallowing the click.

**Why it happens:** The tap is at `.cgSessionEventTap` with `.headInsertEventTap`, so it sees all events including synthetic ones.

**How to avoid:** Use a flag (`isReplayingClick`) that is set before posting and checked at the top of `handleMouseDown`. Since the event tap callback executes synchronously on the same run loop, the flag is reliable.

**Warning signs:** Clicks never arrive at the target app; or app hangs from infinite recursion.

### Pitfall 2: Lost mouseEventClickState Breaks Double-Click

**What goes wrong:** Double-clicking in scroll mode only registers as two single clicks -- no double-click behavior (e.g., text selection).

**Why it happens:** The replayed synthetic events have `clickState = 1` by default. macOS uses this field to determine click multiplicity.

**How to avoid:** Read `mouseEventClickState` from the original intercepted mouseDown event and set the same value on the replayed event.

**Warning signs:** Double-clicking to select a word no longer works while scroll mode is active.

### Pitfall 3: Permission Revocation Silently Disables Event Tap

**What goes wrong:** User revokes Accessibility permission in System Settings. The event tap silently stops receiving events. Scroll mode appears "on" but nothing works. Worse: mouse events may be stuck in a suppressed state.

**Why it happens:** macOS does not send a reliable notification when permissions are revoked. The tap is not destroyed -- it just stops receiving callbacks.

**How to avoid:** Poll `AXIsProcessTrusted()` every 2 seconds while scroll mode is active. On the callback side, handle `tapDisabledByTimeout` and `tapDisabledByUserInput` as potential signals of permission loss (re-enable the tap, but also check `AXIsProcessTrusted()`).

**Warning signs:** Scroll mode toggle shows "on" but mouse behaves normally (no scrolling, no interception).

### Pitfall 4: CGEvent.copy() Required for Deferred Use

**What goes wrong:** Storing the `CGEvent` pointer from the callback for later replay results in a crash or garbage data.

**Why it happens:** The CGEvent passed to the callback is only valid for the duration of the callback. After the callback returns, the system may reuse or deallocate the memory.

**How to avoid:** Call `event.copy()` to create an owned copy if you need to store the event for later replay.

**Warning signs:** Crashes in `replayClick` or corrupted event data.

### Pitfall 5: Modifier Check Must Use Intersection, Not Contains

**What goes wrong:** Using `event.flags.contains(.maskCommand)` fails because `event.flags` contains additional bits beyond the modifier masks (e.g., device-dependent flags).

**Why it happens:** `CGEventFlags` includes bits for both modifier keys and other state. A simple `.contains()` check on the raw value may not work as expected.

**How to avoid:** Use `.intersection()` with a mask of all modifier flags and check `.isEmpty`: `!event.flags.intersection([.maskShift, .maskControl, .maskAlternate, .maskCommand]).isEmpty`

**Warning signs:** Modifier-clicks are still being intercepted despite holding Cmd/Shift/etc.

## Code Examples

### Click Replay with Double-Click Support

```swift
/// Posts synthetic mouseDown + mouseUp to replay a suppressed click.
/// Must be called with isReplayingClick = true to prevent re-interception.
func replayClick(at position: CGPoint, originalClickState: Int64) {
    let source = CGEventSource(stateID: .hidSystemState)

    guard let down = CGEvent(
        mouseEventSource: source,
        mouseType: .leftMouseDown,
        mouseCursorPosition: position,
        mouseButton: .left
    ), let up = CGEvent(
        mouseEventSource: source,
        mouseType: .leftMouseUp,
        mouseCursorPosition: position,
        mouseButton: .left
    ) else { return }

    down.setIntegerValueField(.mouseEventClickState, value: originalClickState)
    up.setIntegerValueField(.mouseEventClickState, value: originalClickState)

    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
}
```

### Modifier Key Detection

```swift
/// Returns true if any modifier key is held during this mouse event.
func hasModifierKeys(_ event: CGEvent) -> Bool {
    let modifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
    return !event.flags.intersection(modifiers).isEmpty
}
```

### Movement Tracking for Dead Zone

```swift
/// Accumulate total movement distance from drag origin.
/// Called in handleMouseDragged when pendingMouseDown is true.
func updateMovementTracking(currentPoint: CGPoint) {
    let dx = currentPoint.x - pendingMouseDownLocation.x
    let dy = currentPoint.y - pendingMouseDownLocation.y
    totalMovement = hypot(dx, dy)
}

/// Check if movement has exceeded the click dead zone.
var hasExceededDeadZone: Bool {
    totalMovement > clickDeadZone
}
```

### Enhanced Event Tap Callback (Right-Click Pass-Through)

Right-clicks are handled by simply NOT including `rightMouseDown`/`rightMouseUp` in the event mask. The current event mask only includes `leftMouseDown`, `leftMouseDragged`, and `leftMouseUp` -- right-clicks already pass through because the tap never sees them. No code change needed for right-click pass-through.

### Permission Health Check Integration

```swift
// In AppState, start when scroll mode activates
func activateScrollMode() {
    guard AXIsProcessTrusted() else { ... }
    scrollEngine.start()
    startPermissionHealthCheck()
}

func deactivateScrollMode() {
    scrollEngine.stop()
    stopPermissionHealthCheck()
}

private var permissionHealthTimer: Timer?

func startPermissionHealthCheck() {
    permissionHealthTimer?.invalidate()
    permissionHealthTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
        guard let self else { return }
        if !AXIsProcessTrusted() {
            self.isScrollModeActive = false
            self.isAccessibilityGranted = false
        }
    }
}

func stopPermissionHealthCheck() {
    permissionHealthTimer?.invalidate()
    permissionHealthTimer = nil
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `kAXTrustedCheckOptionPrompt` for permission checking | `AXIsProcessTrusted()` for checking + `AXIsProcessTrustedWithOptions` only for prompting | Long-standing | Separating check from prompt avoids unwanted dialogs |
| `DistributedNotificationCenter` for permission changes | Polling `AXIsProcessTrusted()` | macOS Ventura+ unreliable notifications | Polling is the only reliable method |

## Discretion Recommendations

### Click Replay Position: Use Mouse-Down Location

**Recommendation:** Replay the click at the mouse-down position (where the user intended to click), not the mouse-up position.

**Rationale:** The user's intent is expressed by where they pressed down. If they moved slightly (within 8px) and released, the mouse-down position is what they were aiming at. This also matches normal macOS click behavior where the target is determined by mouse-down.

### Mid-Toggle Cleanup: Reset and Pass Through

**Recommendation:** If scroll mode is toggled off via F6 while in a pending-click or mid-drag state:
1. Reset all drag/pending state
2. If there was a pending (suppressed) mouse-down, do NOT replay it -- the user's intent was to toggle off, not click
3. Post a scroll-ended event if a scroll was in progress

### Permission Recovery: Auto-Recovery with Re-Check

**Recommendation:** Use auto-recovery. The existing `PermissionManager.startPolling()` already polls for permission re-grant. When permission is restored:
1. Set `isAccessibilityGranted = true`
2. Re-enable the hotkey manager
3. Do NOT automatically re-enable scroll mode -- let the user press F6

This is already partially implemented in the existing `SettingsView` / `PermissionManager` flow.

### Mid-Drag Permission Revocation Cleanup

**Recommendation:** When `AXIsProcessTrusted()` returns false during the health check:
1. Call `scrollEngine.stop()` which resets drag state
2. Set `isScrollModeActive = false`
3. The event tap will silently stop working anyway
4. No special cleanup needed for the mouse cursor -- macOS will resume normal mouse handling once the tap stops intercepting

### Accessibility Keyboard Detection

**Research finding:** There is no reliable public API to distinguish Accessibility Keyboard (on-screen keyboard) clicks from physical mouse clicks at the CGEvent level. The `eventSourceUserData` field could theoretically differ, but Apple does not document what values the Accessibility Keyboard sets, and it is LOW confidence that this is detectable.

**Recommendation:** Do not implement Accessibility Keyboard detection. The safety timeout (existing) and F6 hotkey (which works via keyboard -- physical or on-screen) are sufficient bail-out mechanisms. The on-screen keyboard can be used to press F6 to toggle off scroll mode even when mouse clicks are being intercepted.

## Open Questions

1. **Event tap callback thread safety for `isReplayingClick` flag**
   - What we know: The event tap callback runs on the run loop where the source was added (main run loop in this app). Setting a flag before `CGEvent.post()` and checking it in the callback should be synchronous.
   - What's unclear: Whether `CGEvent.post(tap: .cghidEventTap)` delivers the event synchronously through the tap callback before returning, or whether it queues for the next run loop iteration.
   - Recommendation: Test with flag approach first. If replay clicks are still intercepted, switch to `eventSourceUserData` approach (set a magic number on synthetic events, check in callback).

2. **`event.copy()` behavior for CGEvent in Swift**
   - What we know: CGEvent is a CF type bridged to Swift. The `copy()` method should create an independent copy.
   - What's unclear: Whether `event.copy()` returns `CGEvent` or `Any` in Swift's bridging, and whether the copy is deep enough to preserve all fields.
   - Recommendation: Verify at implementation time. If `copy()` doesn't work cleanly, create a new CGEvent and manually copy position + clickState fields.

## Sources

### Primary (HIGH confidence)
- [CGEventFlags - Apple Developer Documentation](https://developer.apple.com/documentation/coregraphics/cgeventflags) - Modifier key flag constants
- [CGEventType - Apple Developer Documentation](https://developer.apple.com/documentation/coregraphics/cgeventtype) - Event types including tapDisabledByTimeout/tapDisabledByUserInput
- [AXIsProcessTrusted() - Apple Developer Documentation](https://developer.apple.com/documentation/applicationservices/1460720-axisprocesstrusted) - Permission check API
- Existing codebase: ScrollEngine.swift, AppState.swift, HotkeyManager.swift -- verified current implementation patterns

### Secondary (MEDIUM confidence)
- [Apple Developer Forums - Emulate double click](https://developer.apple.com/forums/thread/685901) - mouseEventClickState usage for double-click
- [Apple Developer Forums - Emulate mouse click](https://developer.apple.com/forums/thread/685618) - CGEvent click posting patterns
- [Apple Developer Forums - Determining Accessibility permission](https://developer.apple.com/forums/thread/744440) - Permission detection strategies
- [Accessibility Permission in macOS - jano.dev](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html) - Permission handling overview

### Tertiary (LOW confidence)
- [Apple Developer Forums - macOS application hangs if accessibility changed](https://developer.apple.com/forums/thread/735204) - Behavior on permission revocation (incomplete information)
- Accessibility Keyboard event source differentiation -- no reliable documentation found

## Metadata

**Confidence breakdown:**
- Click replay mechanism: HIGH -- well-documented CGEvent APIs, multiple sources confirm pattern
- Modifier key detection: HIGH -- CGEventFlags is official API, straightforward
- Right-click pass-through: HIGH -- already works (not in event mask), no code change needed
- Double-click support: HIGH -- mouseEventClickState is documented and confirmed by multiple developers
- Permission revocation detection: MEDIUM -- polling works but edge cases around timing are uncertain
- Accessibility Keyboard detection: LOW -- no reliable API found, recommend skipping
- Self-event detection (replay loop prevention): MEDIUM -- flag approach should work but threading details unclear

**Research date:** 2026-02-15
**Valid until:** 2026-03-15 (stable APIs, not fast-moving)
