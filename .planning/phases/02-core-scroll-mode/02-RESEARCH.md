# Phase 2: Core Scroll Mode - Research

**Researched:** 2026-02-15
**Domain:** macOS global event interception (CGEventTap), synthetic scroll events, floating overlay windows
**Confidence:** HIGH

## Summary

Phase 2 requires three distinct technical capabilities: (1) a global hotkey listener for F6 toggle, (2) a CGEventTap that intercepts mouse-down/drag/mouse-up and converts drag deltas into synthetic scroll wheel events, and (3) a floating overlay window (small dot) that tracks the cursor position in real-time. All three rely on Accessibility permissions already granted in Phase 1.

The core mechanism is `CGEvent.tapCreate` with `.defaultTap` option (active filter), which allows intercepting and suppressing left mouse events while scroll mode is active. Drag deltas are converted to `CGEventCreateScrollWheelEvent` calls with `kCGScrollEventUnitPixel` for 1:1 pixel-matched scrolling. The overlay is an `NSPanel` subclass with `ignoresMouseEvents = true` at a high window level.

**Primary recommendation:** Use a single CGEventTap for both hotkey detection (keyDown for F6) and mouse event interception (leftMouseDown, leftMouseDragged, leftMouseUp). Keep the event tap callback thin -- dispatch state changes to main thread, do scroll event posting directly in the callback for low latency.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- Default hotkey: F6 (global, works regardless of focused app)
- User has a custom accessibility keyboard button mapped to F6
- Hotkey system must support modifier combos (Ctrl+Shift+X style) for future customization (Phase 5 UI)
- Floating overlay window: small black dot with white border (matches macOS cursor style)
- Positioned below-right of cursor tip (badge position)
- Overlay follows the cursor in real-time
- 1:1 pixel-matched scroll ratio (content moves exactly as far as mouse drag)
- Natural scroll direction: drag down = content moves down (like touching a phone screen)
- Both vertical and horizontal scrolling supported
- Axis lock as default: detects dominant drag direction and locks to one axis
- Free scroll mode also implemented (both axes simultaneously) -- default to axis lock, setting toggle in Phase 5
- Toggle mode: press F6 to turn on, press again to turn off
- Safety timeout (from Phase 1 SafetyTimeoutManager) auto-disables after inactivity
- UI toggle and F6 always synced -- single source of truth for scroll mode state
- UI toggle is also functional (not display-only)

### Claude's Discretion
- F6 behavior during active drag (simplest implementation)
- Exact dot size and offset distance
- CGEventTap implementation details
- Overlay window level and transparency handling
- Axis lock detection threshold

### Deferred Ideas (OUT OF SCOPE)
- Hotkey customization UI -- Phase 5 (Settings & Polish)
- Axis lock vs free scroll setting toggle -- Phase 5 (Settings & Polish)
- Click-through for small movements -- Phase 3 (Click Safety)
- Inertia/momentum on drag release -- Phase 4 (Inertia)

</user_constraints>

## Standard Stack

### Core (all built into macOS SDK -- no external dependencies)
| Library/Framework | Purpose | Why Standard |
|-------------------|---------|--------------|
| CoreGraphics (CGEvent) | Global event tap, synthetic scroll events | Only way to intercept/suppress system-wide mouse events |
| AppKit (NSPanel) | Floating overlay dot window | Native panel with ignoresMouseEvents, window levels |
| Carbon (HIToolbox) | Virtual key codes (kVK_F6 = 0x61) | Required for CGEvent keyCode matching |

### Supporting
| Framework | Purpose | When to Use |
|-----------|---------|-------------|
| Combine/Observation | State sync between ScrollEngine and UI | AppState is already @Observable |
| SwiftUI | Overlay dot content (circle shape) | Can host SwiftUI view inside NSPanel |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| CGEventTap | NSEvent.addGlobalMonitorForEvents | NSEvent monitors are read-only -- cannot suppress events. CGEventTap is required for active interception. |
| CGEventCreateScrollWheelEvent | Accessibility API scrolling | CGEvent approach is lower-level, more reliable across all apps |
| NSPanel | NSWindow | NSPanel auto-hides when app deactivates unless configured; NSWindow subclass is equally valid. Either works. |

**Installation:** No external packages needed. All frameworks are system-provided.

## Architecture Patterns

### Recommended Project Structure
```
ScrollMyMac/
├── App/
│   ├── AppDelegate.swift          # (existing)
│   ├── AppState.swift             # (existing, add scroll mode coordination)
│   └── ScrollMyMacApp.swift       # (existing)
├── Services/
│   ├── SafetyTimeoutManager.swift # (existing)
│   ├── ScrollEngine.swift         # NEW: CGEventTap + scroll logic
│   ├── HotkeyManager.swift        # NEW: Global F6 hotkey detection
│   └── OverlayManager.swift       # NEW: Floating dot window
├── Features/
│   └── Settings/
│       ├── SettingsView.swift      # (existing, enable toggle)
│       └── PermissionSetupView.swift # (existing)
└── Views/
    └── IndicatorDotView.swift      # NEW: SwiftUI circle for overlay
```

### Pattern 1: Event Tap Lifecycle
**What:** CGEventTap must be created, added to a run loop, and properly re-enabled on timeout.
**When to use:** Always -- this is the core mechanism.
**Example:**
```swift
// Source: Apple docs + alt-tab-macos patterns
class ScrollEngine {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isDragging = false
    private var dragOrigin: CGPoint = .zero
    private var lastDragPoint: CGPoint = .zero
    private var lockedAxis: Axis? = nil

    enum Axis { case horizontal, vertical }

    func start() {
        let eventMask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)

        // Callback must be a C function pointer -- use static/global function
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,  // Active filter: can suppress events
            eventsOfInterest: eventMask,
            callback: scrollEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else { return }

        runLoopSource = CFMachPortCreateRunLoopSource(nil, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            if let runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
        isDragging = false
    }
}
```

### Pattern 2: C Callback to Swift Bridge
**What:** CGEventTap requires a C function pointer callback. Use Unmanaged pointer to bridge back to Swift instance.
**When to use:** Always for CGEventTap callbacks.
**Example:**
```swift
// Source: multiple open-source macOS apps (alt-tab-macos, etc.)
private func scrollEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // Handle tap disabled by timeout -- re-enable
    if type == .tapDisabledByTimeout {
        if let userInfo {
            let engine = Unmanaged<ScrollEngine>.fromOpaque(userInfo).takeUnretainedValue()
            if let tap = engine.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let engine = Unmanaged<ScrollEngine>.fromOpaque(userInfo).takeUnretainedValue()

    switch type {
    case .leftMouseDown:
        return engine.handleMouseDown(event: event, proxy: proxy)
    case .leftMouseDragged:
        return engine.handleMouseDragged(event: event, proxy: proxy)
    case .leftMouseUp:
        return engine.handleMouseUp(event: event, proxy: proxy)
    default:
        return Unmanaged.passUnretained(event)
    }
}
```

### Pattern 3: Synthetic Scroll Event Posting
**What:** Convert mouse drag deltas into scroll wheel events with pixel precision.
**When to use:** On each leftMouseDragged event while scroll mode is active.
**Example:**
```swift
// Source: Apple CGEventCreateScrollWheelEvent docs
func handleMouseDragged(event: CGEvent, proxy: CGEventTapProxy) -> Unmanaged<CGEvent>? {
    let currentPoint = event.location
    var deltaX = currentPoint.x - lastDragPoint.x
    var deltaY = currentPoint.y - lastDragPoint.y
    lastDragPoint = currentPoint

    // Natural scrolling: invert deltas (drag down = scroll content down)
    // In CGEvent coordinate space, positive scrollY = scroll up,
    // so for natural direction: negate the mouse delta
    let scrollY = Int32(-deltaY)
    let scrollX = Int32(deltaX)  // horizontal: drag right = scroll right

    // Apply axis lock
    if let axis = lockedAxis {
        switch axis {
        case .vertical:
            // Post vertical-only scroll
            if let scrollEvent = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 1,
                wheel1: scrollY
            ) {
                scrollEvent.post(tap: .cgSessionEventTap)
            }
        case .horizontal:
            if let scrollEvent = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 2,
                wheel1: 0,
                wheel2: scrollX
            ) {
                scrollEvent.post(tap: .cgSessionEventTap)
            }
        }
    }

    return nil  // Suppress the original drag event
}
```

### Pattern 4: Floating Overlay Dot
**What:** NSPanel that displays a small dot near the cursor, ignores mouse events.
**When to use:** When scroll mode is active.
**Example:**
```swift
// Source: NSPanel docs, NSWindow.Level ordering
class OverlayManager {
    private var overlayWindow: NSPanel?

    func show() {
        let dotSize: CGFloat = 12
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: dotSize, height: dotSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver + 1  // Above most windows, below cursor
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Host SwiftUI dot view
        panel.contentView = NSHostingView(rootView: IndicatorDotView())

        overlayWindow = panel
        updatePosition()
        panel.orderFrontRegardless()
    }

    func updatePosition() {
        guard let panel = overlayWindow else { return }
        let mouseLocation = NSEvent.mouseLocation
        // Offset: below-right of cursor tip
        let offset: CGFloat = 16
        // NSScreen coordinates: origin at bottom-left
        panel.setFrameOrigin(NSPoint(
            x: mouseLocation.x + offset,
            y: mouseLocation.y - offset - panel.frame.height
        ))
    }

    func hide() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
    }
}
```

### Anti-Patterns to Avoid
- **Running event tap on main thread with heavy processing:** Keep the CGEventTap callback extremely fast. Do NOT perform UI updates directly in the callback. Post scroll events there (fast), but dispatch UI state changes to main thread.
- **Using NSEvent.addGlobalMonitorForEvents for interception:** This is read-only -- you cannot suppress events. Must use CGEventTap with `.defaultTap` option.
- **Creating a new CGEvent tap per scroll mode toggle:** Create the tap once, enable/disable it. Tap creation is expensive; toggling is cheap.
- **Forgetting to handle tapDisabledByTimeout:** macOS will silently disable your event tap if the callback takes too long. You MUST handle this event type and re-enable the tap.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Global event interception | Custom polling/timer approach | CGEvent.tapCreate with .defaultTap | Only supported mechanism for suppressing system events |
| Synthetic scroll events | NSEvent-based scrolling or Accessibility API | CGEventCreateScrollWheelEvent with kCGScrollEventUnitPixel | Direct pixel-level control, works in all apps |
| Window-level overlay | SwiftUI-only overlay | NSPanel with ignoresMouseEvents | SwiftUI has no API for system-level floating windows |
| Key code constants | Hardcoded integers | Carbon.HIToolbox kVK_F6 (0x61) | Self-documenting, matches Apple headers |

**Key insight:** This phase is almost entirely AppKit/CoreGraphics territory. SwiftUI is used only for the dot shape rendering and the settings UI. The event interception and overlay management are pure AppKit.

## Common Pitfalls

### Pitfall 1: Event Tap Disabled by Timeout
**What goes wrong:** macOS silently disables the event tap if the callback takes too long (~200ms). All mouse events pass through unintercepted.
**Why it happens:** System protection against misbehaving event taps blocking input.
**How to avoid:** Handle `CGEventType.tapDisabledByTimeout` in the callback and call `CGEvent.tapEnable(tap:enable:)` to re-enable. Keep callback execution under 50ms.
**Warning signs:** Scroll mode suddenly stops working; clicks pass through to apps.

### Pitfall 2: Coordinate System Mismatch
**What goes wrong:** Overlay dot appears at wrong position or scroll direction is inverted.
**Why it happens:** CGEvent uses top-left origin (y increases downward). NSScreen uses bottom-left origin (y increases upward). NSEvent.mouseLocation uses screen coordinates (bottom-left origin).
**How to avoid:** Be explicit about which coordinate system each API uses. CGEvent.location is top-left; NSEvent.mouseLocation is bottom-left. Convert as needed.
**Warning signs:** Dot tracks horizontally but is vertically inverted; scrolling feels backwards.

### Pitfall 3: Natural Scroll Direction Confusion
**What goes wrong:** "Drag down = content moves up" instead of "drag down = content moves down."
**Why it happens:** The sign convention for CGEvent scroll deltas: positive wheel1 = scroll up (content moves down in old convention). The user wants natural direction where drag-down = content-down.
**How to avoid:** For natural scrolling: `scrollY = Int32(-deltaY)` where deltaY is the mouse movement delta. Mouse moves down (positive deltaY in CG coords) -> negative scroll value -> content scrolls down visually.
**Warning signs:** Test by dragging down -- content should follow your drag like a touchscreen.

### Pitfall 4: Overlay Window Receives Mouse Events
**What goes wrong:** The overlay dot intercepts clicks/drags, breaking scroll functionality.
**Why it happens:** Forgot to set `ignoresMouseEvents = true` on the panel.
**How to avoid:** Always set `panel.ignoresMouseEvents = true`. Test by clicking directly on the dot.
**Warning signs:** Clicking near cursor doesn't start a scroll drag.

### Pitfall 5: Event Tap Not Created (nil return)
**What goes wrong:** `CGEvent.tapCreate` returns nil. No events are intercepted.
**Why it happens:** Accessibility permission not granted, or the app is sandboxed.
**How to avoid:** The app already has sandbox disabled (`com.apple.security.app-sandbox = false`) and requests accessibility in Phase 1. Check `AXIsProcessTrusted()` before creating taps. Show user-facing error if tap creation fails.
**Warning signs:** Toggle appears to activate but nothing happens.

### Pitfall 6: Axis Lock Never Releases
**What goes wrong:** User starts dragging vertically, axis locks, and then can never scroll horizontally without lifting the mouse.
**Why it happens:** Axis lock is set once per drag and never reset until mouseUp.
**How to avoid:** This is actually the desired behavior per the spec (lock per drag gesture). Ensure axis resets on mouseUp. Clear axis lock state when drag ends.
**Warning signs:** None -- this is correct behavior. But verify it feels right.

## Code Examples

### Global Hotkey Detection for F6
```swift
// Source: Carbon HIToolbox + CGEvent docs
import Carbon.HIToolbox

// kVK_F6 = 0x61 (97 decimal)
// In the CGEventTap callback, or using a separate keyDown tap:

func handleKeyDown(event: CGEvent) -> Bool {
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    if keyCode == Int64(kVK_F6) {
        // Check no modifiers pressed (plain F6)
        // For future: also check modifier combos
        toggleScrollMode()
        return true  // Consume the event
    }
    return false  // Pass through
}
```

### Axis Lock Detection
```swift
// Recommended: lock after first N pixels of movement to determine dominant axis
private let axisLockThreshold: CGFloat = 5.0  // pixels of movement before locking
private var accumulatedDelta: CGPoint = .zero

func detectAxis(deltaX: CGFloat, deltaY: CGFloat) -> Axis? {
    accumulatedDelta.x += abs(deltaX)
    accumulatedDelta.y += abs(deltaY)

    let total = accumulatedDelta.x + accumulatedDelta.y
    guard total >= axisLockThreshold else { return nil }  // Not enough movement yet

    return accumulatedDelta.y >= accumulatedDelta.x ? .vertical : .horizontal
}
```

### Indicator Dot SwiftUI View
```swift
// Simple circle matching macOS cursor aesthetic
struct IndicatorDotView: View {
    var body: some View {
        Circle()
            .fill(Color.black)
            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            .frame(width: 10, height: 10)
    }
}
```

### Cursor Tracking for Overlay
```swift
// Use CGEvent mouse position from the event tap callback for lowest latency
// In the drag handler, update overlay position:
func updateOverlayPosition(from event: CGEvent) {
    let cgPoint = event.location  // Top-left coordinate system
    // Convert to NSScreen coordinates (bottom-left origin)
    guard let screenHeight = NSScreen.main?.frame.height else { return }
    let screenPoint = NSPoint(
        x: cgPoint.x + 16,  // offset right
        y: screenHeight - cgPoint.y - 16 - 10  // offset down, flip Y, subtract dot height
    )
    DispatchQueue.main.async { [weak self] in
        self?.overlayWindow?.setFrameOrigin(screenPoint)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NSEvent global monitors | CGEventTap (still current) | Always for interception | NSEvent monitors are read-only; CGEventTap required for suppression |
| IOKit HID for input | CGEvent.tapCreate | macOS 10.4+ | Higher-level, better supported |
| registerHotKey (Carbon) | CGEventTap keyDown or NSEvent.addGlobalMonitor | Ongoing migration | Carbon RegisterEventHotKey still works but deprecated direction |

**Deprecated/outdated:**
- `RegisterEventHotKey` (Carbon): Still functional but Carbon is legacy. CGEventTap keyDown detection works and aligns with the mouse event tap already needed.

## Discretion Recommendations

### F6 During Active Drag
**Recommendation:** Ignore F6 while `isDragging == true`. Simplest implementation -- prevents confusing state where scroll mode deactivates mid-drag. F6 only toggles when no drag is in progress.

### Dot Size and Offset
**Recommendation:** 10px diameter dot, offset 16px right and 16px down from cursor tip. This places it clearly visible as a "badge" without obscuring the click point. The 1.5px white border on black fill matches macOS cursor aesthetic.

### Overlay Window Level
**Recommendation:** Use `NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)) - 1)` or `.screenSaver + 1` (level ~102). This keeps the dot above all normal windows and full-screen apps but below the actual cursor. Avoid `.cursorWindow` level (2,147,483,630) as that could interfere with the system cursor.

### Axis Lock Threshold
**Recommendation:** 5 pixels of accumulated movement before locking. This is enough to determine intent without noticeable delay. Accumulate absolute deltas for both axes during the initial unlocked movement, then lock to whichever axis has more accumulated movement.

## Open Questions

1. **Run loop thread for event tap**
   - What we know: The event tap callback runs on whatever run loop the source is added to. Main run loop is simplest. Background thread reduces main thread blocking.
   - What's unclear: Whether main run loop latency is acceptable for smooth scrolling.
   - Recommendation: Start with main run loop (simpler). If scrolling feels laggy, move tap to a dedicated background thread's run loop (like alt-tab-macos does). The callback itself should be fast enough for main thread.

2. **Multi-monitor coordinate handling**
   - What we know: CGEvent coordinates span the full virtual screen space. NSScreen.screens provides per-display frames.
   - What's unclear: Whether the overlay dot position calculation handles multi-monitor setups correctly without explicit handling.
   - Recommendation: Use `NSEvent.mouseLocation` for overlay positioning (already in screen coordinates). Test on multi-monitor if available.

3. **Scroll phase events**
   - What we know: Modern macOS apps may expect scroll phase events (began/changed/ended) for smooth scrolling behavior.
   - What's unclear: Whether omitting scroll phase fields causes issues in some apps.
   - Recommendation: Set `scrollWheelEventScrollPhase` on synthetic events. Use `.began` on first drag event, `.changed` on subsequent, `.ended` on mouseUp. This mimics trackpad behavior and should work best across apps.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: CGEventTapCreate, CGEventCreateScrollWheelEvent, NSPanel, NSWindow.Level
- Apple Developer Documentation: CGEventType.tapDisabledByTimeout
- Apple Developer Documentation: CGEventField.scrollWheelEventFixedPtDeltaAxis1
- Carbon HIToolbox Events.h: kVK_F6 = 0x61

### Secondary (MEDIUM confidence)
- [alt-tab-macos KeyboardEvents.swift](https://github.com/lwouis/alt-tab-macos/blob/master/src/logic/events/KeyboardEvents.swift) -- real-world CGEventTap patterns
- [NSWindow level ordering](https://jameshfisher.com/2020/08/03/what-is-the-order-of-nswindow-levels/) -- complete numeric level reference
- [Low-level scrolling events on macOS](https://gist.github.com/svoisen/5215826) -- scroll event field documentation
- [CGEventTap gist](https://gist.github.com/osnr/23eb05b4e0bcd335c06361c4fabadd6f) -- callback bridge pattern

### Tertiary (LOW confidence)
- Scroll phase behavior across different apps (needs testing; no authoritative source on which apps require phases)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- CGEventTap is the only viable approach; well-documented Apple API
- Architecture: HIGH -- patterns are well-established in macOS ecosystem (alt-tab, Karabiner, etc.)
- Pitfalls: HIGH -- tap timeout, coordinate systems, and event suppression are well-documented issues
- Scroll phases: MEDIUM -- best practice to include, but unclear if strictly necessary

**Research date:** 2026-02-15
**Valid until:** 2026-03-15 (stable APIs, unlikely to change)
