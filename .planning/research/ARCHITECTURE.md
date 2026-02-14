# Architecture Research

**Domain:** macOS accessibility/input control app (click-drag scrolling)
**Researched:** 2026-02-14
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
+-----------------------------------------------------------------------+
|                         APPLICATION LAYER                              |
|  +------------------+  +------------------+  +--------------------+    |
|  |   SwiftUI GUI    |  |   MenuBarExtra   |  |   AppState         |    |
|  |   (Settings)     |  |   (Status/Menu)  |  |   (@Observable)    |    |
|  +--------+---------+  +--------+---------+  +----------+---------+    |
|           |                     |                       |              |
+-----------+---------------------+-----------------------+--------------+
|                         COORDINATION LAYER                             |
|  +--------------------------------------------------------------------+|
|  |                     ScrollModeController                           ||
|  |   - Owns mode state (active/inactive)                              ||
|  |   - Coordinates between input and output                           ||
|  |   - Manages cursor changes                                         ||
|  +-----------------------------+--------------------------------------+|
|                                |                                       |
+--------------------------------+---------------------------------------+
|                          INPUT LAYER                                   |
|  +------------------+  +------------------+  +--------------------+    |
|  | HotkeyManager    |  |  EventTapManager |  |  PermissionManager |    |
|  | (Global hotkey)  |  |  (Mouse events)  |  |  (Accessibility)   |    |
|  +--------+---------+  +--------+---------+  +----------+---------+    |
|           |                     |                       |              |
+-----------+---------------------+-----------------------+--------------+
|                          OUTPUT LAYER                                  |
|  +------------------+  +------------------+                            |
|  | ScrollEmitter    |  |  CursorManager   |                            |
|  | (Scroll events)  |  |  (NSCursor)      |                            |
|  +------------------+  +------------------+                            |
+-----------------------------------------------------------------------+
|                          SYSTEM LAYER                                  |
|  +------------------+  +------------------+  +--------------------+    |
|  |  CGEventTap      |  |   CFRunLoop      |  |   TCC Framework    |    |
|  |  (CoreGraphics)  |  |   (Background)   |  |   (Permissions)    |    |
|  +------------------+  +------------------+  +--------------------+    |
+-----------------------------------------------------------------------+
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **AppState** | Application-wide state (mode, settings) | `@Observable` class, single instance |
| **SwiftUI GUI** | Settings UI, onboarding | Standard SwiftUI views |
| **MenuBarExtra** | Status indicator, quick access | SwiftUI `MenuBarExtra` scene |
| **ScrollModeController** | Orchestrates scroll mode lifecycle | Class coordinating input/output managers |
| **HotkeyManager** | Global keyboard shortcut detection | `KeyboardShortcuts` library or CGEventTap |
| **EventTapManager** | Mouse event interception | CGEventTap on background thread |
| **PermissionManager** | Accessibility permission flow | `AXIsProcessTrusted` + UI prompts |
| **ScrollEmitter** | Generate synthetic scroll events | `CGEventCreateScrollWheelEvent` |
| **CursorManager** | System cursor appearance | `NSCursor.push()`/`pop()` |

## Recommended Project Structure

```
ScrollMyMac/
+-- ScrollMyMacApp.swift       # App entry point, MenuBarExtra
+-- App/
|   +-- AppState.swift         # @Observable application state
|   +-- AppDelegate.swift      # NSApplicationDelegate (if needed)
+-- Features/
|   +-- ScrollMode/
|   |   +-- ScrollModeController.swift   # Main coordination logic
|   |   +-- ScrollEmitter.swift          # Scroll event generation
|   |   +-- InertiaEngine.swift          # Momentum/inertia calculations
|   +-- Settings/
|       +-- SettingsView.swift           # SwiftUI settings UI
|       +-- OnboardingView.swift         # Permission onboarding
+-- Services/
|   +-- EventTapManager.swift            # CGEventTap wrapper
|   +-- HotkeyManager.swift              # Global hotkey handling
|   +-- PermissionManager.swift          # Accessibility permission
|   +-- CursorManager.swift              # Cursor state management
+-- Utilities/
|   +-- Extensions/                      # Swift extensions
|   +-- Constants.swift                  # App-wide constants
+-- Resources/
    +-- Assets.xcassets                  # Icons, images
    +-- Info.plist                       # App configuration
```

### Structure Rationale

- **App/:** Entry point and global state. `AppState` is the single source of truth for mode, settings.
- **Features/:** Feature-based organization. Each feature folder contains its controller and related code.
- **Services/:** Low-level system interactions. Reusable across features. Thin wrappers over system APIs.
- **Utilities/:** Shared helpers, extensions, constants.
- **Resources/:** Standard Xcode resources location.

## Architectural Patterns

### Pattern 1: CGEventTap on Background Thread

**What:** Run the event tap on a dedicated background thread with its own CFRunLoop.
**When to use:** Always for mouse/keyboard event interception.
**Trade-offs:** More complex setup, but prevents blocking main thread and ensures responsive event handling.

**Example:**
```swift
class EventTapManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var backgroundThread: Thread?

    func start() {
        backgroundThread = Thread { [weak self] in
            self?.setupEventTap()
            CFRunLoopRun() // Blocks until stopped
        }
        backgroundThread?.start()
    }

    private func setupEventTap() {
        let eventMask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) |
                                      (1 << CGEventType.leftMouseUp.rawValue) |
                                      (1 << CGEventType.leftMouseDragged.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap = eventTap else { return }

        runLoopSource = CFMachPortCreateRunLoopSource(nil, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
}

private func eventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // Process event, return nil to swallow, return event to pass through
    guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()
    // Dispatch to main thread for UI updates if needed
    return manager.handleEvent(type: type, event: event)
}
```

### Pattern 2: State-Driven Mode Toggle

**What:** Use `@Observable` for mode state, components react to state changes.
**When to use:** For coordinating scroll mode activation across UI and services.
**Trade-offs:** Clean separation, but requires careful thread safety when updating from event callbacks.

**Example:**
```swift
@Observable
class AppState {
    var isScrollModeActive: Bool = false
    var scrollSpeed: Double = 1.0
    var useInertia: Bool = true

    // Derived state
    var statusText: String {
        isScrollModeActive ? "Scroll Mode Active" : "Ready"
    }
}

// In controller
func toggleScrollMode() {
    DispatchQueue.main.async {
        self.appState.isScrollModeActive.toggle()
    }

    if appState.isScrollModeActive {
        cursorManager.pushScrollCursor()
        eventTapManager.startCapturing()
    } else {
        cursorManager.popCursor()
        eventTapManager.stopCapturing()
    }
}
```

### Pattern 3: Coordinator Pattern for Mode Lifecycle

**What:** A controller class coordinates the lifecycle of scroll mode across multiple services.
**When to use:** When multiple components must act together (cursor, event tap, scroll emission).
**Trade-offs:** Additional abstraction, but centralizes complex coordination logic.

**Example:**
```swift
class ScrollModeController {
    private let appState: AppState
    private let eventTapManager: EventTapManager
    private let scrollEmitter: ScrollEmitter
    private let cursorManager: CursorManager
    private let hotkeyManager: HotkeyManager

    private var dragStartLocation: CGPoint?
    private var lastDragLocation: CGPoint?

    init(appState: AppState) {
        self.appState = appState
        self.eventTapManager = EventTapManager()
        self.scrollEmitter = ScrollEmitter()
        self.cursorManager = CursorManager()
        self.hotkeyManager = HotkeyManager()

        setupBindings()
    }

    private func setupBindings() {
        hotkeyManager.onHotkeyPressed = { [weak self] in
            self?.activate()
        }
        hotkeyManager.onHotkeyReleased = { [weak self] in
            self?.deactivate()
        }
        eventTapManager.onMouseEvent = { [weak self] event in
            self?.handleMouseEvent(event)
        }
    }

    func activate() {
        appState.isScrollModeActive = true
        cursorManager.pushScrollCursor()
        eventTapManager.startCapturing()
    }

    func deactivate() {
        // Check for click-through (no movement)
        if shouldPassThroughClick() {
            scrollEmitter.simulateClick(at: dragStartLocation)
        }

        appState.isScrollModeActive = false
        cursorManager.popCursor()
        eventTapManager.stopCapturing()

        if appState.useInertia {
            scrollEmitter.applyInertia(velocity: calculateVelocity())
        }
    }
}
```

## Data Flow

### Event Processing Flow

```
[User presses hotkey]
    |
    v
[HotkeyManager] ---(onHotkeyPressed)---> [ScrollModeController]
    |                                            |
    |                                            v
    |                                    [Activate mode]
    |                                            |
    +--------------------------------------------+
    |                    |                       |
    v                    v                       v
[AppState]        [CursorManager]        [EventTapManager]
(isScrollModeActive=true)  (push cursor)    (start capturing)
    |
    v
[SwiftUI Views react to state change]


[User drags mouse while holding click]
    |
    v
[CGEventTap callback] ---(raw CGEvent)---> [EventTapManager]
    |
    v
[EventTapManager.onMouseEvent] ---(processed event)---> [ScrollModeController]
    |
    v
[Calculate delta from last position]
    |
    v
[ScrollEmitter.emitScroll(deltaX, deltaY)]
    |
    v
[CGEventCreateScrollWheelEvent] ---> [System receives scroll event]
```

### State Flow

```
[AppState (@Observable)]
         |
         +---(isScrollModeActive)---> [MenuBarExtra icon/label]
         |
         +---(isScrollModeActive)---> [SettingsView toggle display]
         |
         +---(scrollSpeed)---------> [ScrollEmitter multiplier]
         |
         +---(useInertia)----------> [ScrollModeController deactivation logic]
```

### Key Data Flows

1. **Hotkey to Mode Activation:** HotkeyManager detects key press -> notifies ScrollModeController -> updates AppState -> UI reacts
2. **Mouse Movement to Scroll:** EventTapManager captures drag -> calculates delta -> ScrollEmitter creates scroll event -> system scrolls
3. **Settings to Behavior:** SettingsView updates AppState -> services read current values when needed
4. **Click-through Detection:** Track mouse movement during drag; if no movement, pass click to underlying app on release

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Single user (this app) | Monolith is perfect. All components in one process. |
| Multiple features | Feature-based folders. Services remain reusable. |
| Plugin system | Consider protocol-based services for extensibility. |

### Performance Priorities

1. **First priority:** Event tap callback efficiency. Must be extremely fast; any delay affects all input.
2. **Second priority:** Main thread responsiveness. UI updates must not block; dispatch from event callback.
3. **Third priority:** Inertia smoothness. Timer-based animation should use CADisplayLink or similar.

## Anti-Patterns

### Anti-Pattern 1: Processing on Event Tap Thread

**What people do:** Perform heavy computation or I/O in the CGEventTap callback.
**Why it's wrong:** The callback blocks all system input. Even small delays cause noticeable lag.
**Do this instead:** In callback, capture minimal data, dispatch heavy work to another queue, return immediately.

### Anti-Pattern 2: Storing State in Multiple Places

**What people do:** Keep `isScrollModeActive` in AppState AND EventTapManager AND CursorManager.
**Why it's wrong:** State gets out of sync. Bugs where cursor shows scroll but events aren't captured.
**Do this instead:** Single source of truth in AppState. Components query or observe AppState.

### Anti-Pattern 3: Forgetting to Release Event Tap

**What people do:** Create event tap but never call `CGEvent.tapEnable(tap:enable:false)` or release resources.
**Why it's wrong:** Resource leak. If app crashes, event tap may persist and cause issues.
**Do this instead:** Proper cleanup in deinit. Use defer or RAII patterns. Handle app termination.

### Anti-Pattern 4: Blocking Main Thread for Permissions

**What people do:** Call `AXIsProcessTrustedWithOptions` on main thread and wait for user response.
**Why it's wrong:** This doesn't actually block (it's async), but failing to handle the async nature leads to race conditions.
**Do this instead:** Check permission, show UI if needed, poll or observe for permission grant.

## Integration Points

### System Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| **CGEventTap** | Create on background thread, add to CFRunLoop | Requires Accessibility permission |
| **NSCursor** | Push/pop on main thread only | Must be called from main thread |
| **CGEventCreateScrollWheelEvent** | Can be called from any thread | Use `.line` units for compatibility |
| **Accessibility (TCC)** | `AXIsProcessTrustedWithOptions` | Check before creating event tap |
| **UserDefaults** | Standard @AppStorage | For persisting settings |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| EventTapManager <-> ScrollModeController | Closure callbacks | Events dispatched to main thread |
| AppState <-> Views | @Observable binding | Automatic SwiftUI updates |
| ScrollModeController <-> Services | Direct method calls | Controller owns service instances |
| HotkeyManager <-> Controller | Closure callbacks | Key events trigger mode changes |

## Build Order Implications

Based on dependencies, recommended build order:

1. **Phase 1: Foundation**
   - AppState (other components depend on it)
   - PermissionManager (needed before event taps work)
   - Basic SwiftUI shell with MenuBarExtra

2. **Phase 2: Input Layer**
   - EventTapManager (core functionality)
   - HotkeyManager (activation mechanism)
   - Test: Can detect hotkey, can capture mouse events

3. **Phase 3: Output Layer**
   - ScrollEmitter (converts movement to scroll)
   - CursorManager (visual feedback)
   - Test: Dragging produces scroll, cursor changes

4. **Phase 4: Coordination**
   - ScrollModeController (ties everything together)
   - Click-through detection
   - Test: Full flow works end-to-end

5. **Phase 5: Polish**
   - InertiaEngine (optional smooth scrolling)
   - SettingsView (customization)
   - OnboardingView (permission guidance)

**Rationale:** Build from bottom up (system services first), then coordinate. Test each layer before building on it.

## Sources

- [Apple Developer: CGEvent.tapCreate](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:))
- [Apple Developer: NSCursor](https://developer.apple.com/documentation/appkit/nscursor)
- [Apple Developer: MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)
- [Apple Developer: Run Loops](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/RunLoopManagement/RunLoopManagement.html)
- [GitHub: drag-scroll (reference implementation)](https://github.com/emreyolcu/drag-scroll)
- [GitHub: alt-tab-macos (event handling patterns)](https://github.com/lwouis/alt-tab-macos)
- [GitHub: KeyboardShortcuts (hotkey library)](https://github.com/sindresorhus/KeyboardShortcuts)
- [Low-level scrolling events on Mac OS X](https://gist.github.com/svoisen/5215826)
- [CGEventSupervisor (event tap patterns)](https://gist.github.com/stephancasas/fd27ebcd2a0e36f3e3f00109d70abcdc)
- [Sarunw: Menu Bar App with SwiftUI](https://sarunw.com/posts/swiftui-menu-bar-app/)
- [Nil Coalescing: Build macOS Menu Bar Utility](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/)

---
*Architecture research for: Scroll My Mac - macOS accessibility input control app*
*Researched: 2026-02-14*
