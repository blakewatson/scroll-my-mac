# Architecture: OSK-Aware Click Pass-Through Integration

**Domain:** macOS accessibility app -- adding on-screen keyboard (OSK) detection to existing ScrollEngine
**Researched:** 2026-02-16
**Confidence:** HIGH (existing codebase well-understood, API choices well-documented)

## Recommended Architecture

### Design Decision: Extend `shouldPassThroughClick`, backed by a new `WindowExclusionManager`

**Do not** put CGWindowListCopyWindowInfo calls inside the event tap callback. **Do not** try to extend the C callback itself. Instead, create a new `WindowExclusionManager` service that caches excluded window regions and expose it through the existing `shouldPassThroughClick` closure pattern.

This approach works because:
1. The `shouldPassThroughClick` closure is already called at exactly the right decision point (top of `handleMouseDown`)
2. The closure runs in Swift-land (inside `handleMouseDown`), not in the C callback directly -- the C callback just dispatches to `engine.handleMouseDown()`
3. Adding another check to the closure in `AppState.setupServices()` is a one-line integration
4. No changes needed to ScrollEngine.swift itself

### System Diagram: New Components

```
EXISTING (unchanged)                     NEW
+------------------+                    +---------------------------+
|   ScrollEngine   |                    |  WindowExclusionManager   |
|                  |                    |                           |
|  shouldPassThru  |<---[closure]-------|  isPointInExcludedWindow  |
|  Click?(CGPoint) |                    |  (_:CGPoint) -> Bool      |
|                  |                    |                           |
|  handleMouseDown |                    |  cachedOSKFrames: [CGRect]|
|  (checks closure |                    |  refreshInterval: 0.5s    |
|   at top)        |                    |  pollTimer: Timer?        |
+------------------+                    +---------------------------+
                                                    |
+------------------+                    Uses: CGWindowListCopyWindowInfo
|    AppState      |                    (on timer, NOT in callback)
|                  |
|  setupServices() |--- wires closure to combine:
|    existing:     |    1. own-window check (existing)
|    own windows   |    2. exclusionManager check (new)
+------------------+
```

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **WindowExclusionManager** (NEW) | Caches OSK/excluded window rects; provides fast point-in-rect check | AppState (owned by), ScrollEngine (via closure) |
| **ScrollEngine** (UNCHANGED) | Mouse event interception, hold-and-decide model | AppState (via shouldPassThroughClick closure) |
| **AppState** (MODIFIED -- setupServices only) | Wires WindowExclusionManager into shouldPassThroughClick | WindowExclusionManager, ScrollEngine |

### Why NOT Other Approaches

**Option rejected: Check inside the C callback function.**
The C callback (`scrollEventCallback`) is a file-level function that receives a raw `UnsafeMutableRawPointer`. Adding OSK detection here would require either (a) making WindowExclusionManager accessible via the userInfo pointer (breaking the clean single-engine-pointer pattern) or (b) using global state. Neither is necessary because the callback already dispatches to `engine.handleMouseDown()` which calls the closure.

**Option rejected: New property on ScrollEngine (e.g., `shouldPassThroughForOSK`).**
This would duplicate the pass-through pattern. The existing `shouldPassThroughClick` closure is the right abstraction -- it answers "should this point be passed through?" regardless of the reason. The caller (AppState) composes multiple reasons into one closure.

**Option rejected: AXObserver for window creation/destruction notifications.**
While technically more "push" than "poll," AXObserver adds significant complexity (background run loop, per-PID observer setup, ordering quirks, need to discover the OSK process PID first). For a window that appears/disappears infrequently (user toggles the Accessibility Keyboard maybe once per session), polling every 500ms is simpler, reliable, and costs nearly nothing.

## New Component: WindowExclusionManager

### Design

```swift
/// Periodically caches the screen rects of on-screen keyboard windows
/// so the event tap can do a fast point-in-rect check without calling
/// CGWindowListCopyWindowInfo on every mouseDown.
class WindowExclusionManager {

    /// Cached rects of excluded windows (CG coordinates, top-left origin).
    private var excludedRects: [CGRect] = []

    /// Process names whose windows should be excluded from scroll interception.
    /// "AssistiveControl" = macOS Accessibility Keyboard
    /// "KeyboardViewer" = macOS Keyboard Viewer
    private let excludedOwnerNames: Set<String> = [
        "AssistiveControl",
        "KeyboardViewer"
    ]

    private var pollTimer: Timer?
    private let refreshInterval: TimeInterval = 0.5

    // MARK: - Public API

    /// Fast check: is this CG point inside any excluded window?
    /// Called from shouldPassThroughClick closure in the event tap path.
    /// Cost: iterate a small array of CGRects (typically 0-1 items). O(n) where n is tiny.
    func isPointExcluded(_ point: CGPoint) -> Bool {
        return excludedRects.contains { $0.contains(point) }
    }

    /// Start polling for excluded windows.
    func startMonitoring() {
        refreshCache() // Immediate first check
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(
            withTimeInterval: refreshInterval,
            repeats: true
        ) { [weak self] _ in
            self?.refreshCache()
        }
    }

    /// Stop polling.
    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        excludedRects = []
    }

    // MARK: - Private

    private func refreshCache() {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            excludedRects = []
            return
        }

        excludedRects = windowList.compactMap { info in
            guard let ownerName = info[kCGWindowOwnerName as String] as? String,
                  excludedOwnerNames.contains(ownerName),
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let y = bounds["Y"],
                  let w = bounds["Width"], let h = bounds["Height"]
                  else { return nil }
            return CGRect(x: x, y: y, width: w, height: h)
        }
    }
}
```

### Key Design Decisions

**Polling at 0.5s, not per-event:** `CGWindowListCopyWindowInfo` is an IPC call to the Window Server. Calling it on every mouseDown would add latency to the event tap path and risk timeout-based tap disabling. Polling at 500ms means the cache is at most 500ms stale -- acceptable because the OSK does not move frequently, and a half-second delay before recognizing a newly-opened OSK is imperceptible.

**Owner name matching, not window name:** `kCGWindowOwnerName` (process name) does NOT require Screen Recording permission. `kCGWindowName` DOES require Screen Recording permission on macOS 10.15+. Since we only need to identify which process owns the window, owner name is sufficient and avoids an unnecessary permission requirement.

**Set of owner names:** The `excludedOwnerNames` set is easily extensible. If users report other on-screen keyboards or floating palettes that need pass-through, adding a name is a one-line change. Could later be exposed as a user preference.

**CG coordinate system:** `CGWindowListCopyWindowInfo` returns bounds in CG coordinates (top-left origin), which is the same coordinate system used by `CGEvent.location` in the event tap. No coordinate conversion needed -- this is a direct `CGRect.contains(CGPoint)` check.

## Integration with Existing Code

### AppState.setupServices() -- The Only Wiring Change

```swift
// In AppState:
let windowExclusionManager = WindowExclusionManager()  // Add as property

// In setupServices():
scrollEngine.shouldPassThroughClick = { [weak self] cgPoint in
    guard let self else { return false }

    // Check 1: App's own windows (existing logic)
    guard let screenHeight = NSScreen.main?.frame.height else { return false }
    let nsPoint = NSPoint(x: cgPoint.x, y: screenHeight - cgPoint.y)
    let isOwnWindow = NSApp.windows.contains { window in
        window.isVisible && !window.ignoresMouseEvents && window.frame.contains(nsPoint)
    }
    if isOwnWindow { return true }

    // Check 2: Excluded windows (OSK, etc.) -- NEW
    return windowExclusionManager.isPointExcluded(cgPoint)
}
```

### Lifecycle Integration

Start/stop monitoring tied to scroll mode activation:

```swift
// In activateScrollMode():
windowExclusionManager.startMonitoring()

// In deactivateScrollMode():
windowExclusionManager.stopMonitoring()
```

This means the timer only runs while scroll mode is active. No background cost when scroll mode is off.

### Data Flow: mouseDown with OSK Check

```
User clicks while scroll mode active
    |
    v
[C callback: scrollEventCallback]
    |
    v
[engine.handleMouseDown(event:proxy:)]
    |
    v
[shouldPassThroughClick?(location)]  <-- closure in AppState
    |                                     |
    |-- Check 1: own windows?             |-- NSApp.windows iteration
    |-- Check 2: excluded windows?        |-- windowExclusionManager.isPointExcluded()
    |                                          (reads cached [CGRect], no IPC)
    v
if true -> return event (pass through, user clicks the OSK)
if false -> enter hold-and-decide (existing scroll logic)
```

## Files Changed vs Created

| File | Action | What Changes |
|------|--------|-------------|
| `Services/WindowExclusionManager.swift` | **CREATE** | New service class (~60 lines) |
| `App/AppState.swift` | **MODIFY** | Add property, wire into setupServices(), add start/stop in activate/deactivate |
| `Services/ScrollEngine.swift` | **UNCHANGED** | No changes needed |

## Patterns to Follow

### Pattern 1: Cache-and-Check for IPC-Heavy APIs

**What:** Pre-cache results from expensive system calls on a timer; read the cache in performance-sensitive paths.
**When:** Any time you need data from a cross-process IPC call (like Window Server queries) in the event tap path.
**Why:** The event tap callback must return quickly (typically under 1ms). CGWindowListCopyWindowInfo involves IPC to the Window Server and can take 5-50ms+ depending on window count. Caching separates the cost from the critical path.

### Pattern 2: Compose Exclusion Reasons in the Closure

**What:** The `shouldPassThroughClick` closure in AppState composes multiple independent reasons for pass-through (own windows, OSK windows, future reasons) into a single check.
**When:** Adding new pass-through conditions to ScrollEngine.
**Why:** ScrollEngine stays generic -- it just asks "should I pass through?" without knowing why. New exclusion reasons never require changes to ScrollEngine.

### Pattern 3: Monitor Only When Active

**What:** Start/stop the WindowExclusionManager timer when scroll mode activates/deactivates.
**When:** Any polling-based service.
**Why:** No point polling for OSK windows when scroll mode is off. Reduces energy impact.

## Anti-Patterns to Avoid

### Anti-Pattern 1: CGWindowListCopyWindowInfo in the Event Tap Path

**What:** Calling CGWindowListCopyWindowInfo directly inside handleMouseDown or the C callback.
**Why bad:** IPC call to Window Server. Can take 5-50ms+. If the event tap callback takes too long, macOS disables the tap entirely (`tapDisabledByTimeout`). Even if it doesn't time out, it adds perceptible latency to every click.
**Instead:** Cache on a timer, read the cache in the callback.

### Anti-Pattern 2: Requiring Screen Recording Permission

**What:** Using `kCGWindowName` to identify the OSK window.
**Why bad:** `kCGWindowName` requires Screen Recording permission on macOS 10.15+. The app currently only needs Accessibility permission. Adding a second permission prompt degrades the user experience significantly.
**Instead:** Use `kCGWindowOwnerName` (process name), which is available without Screen Recording permission.

### Anti-Pattern 3: Global/Static State for the Cache

**What:** Using a file-level or static variable for the excluded rects so the C callback can access them directly.
**Why bad:** Breaks the existing architecture pattern where the C callback only accesses the ScrollEngine instance via userInfo. Introduces hidden coupling and makes testing harder.
**Instead:** Flow the data through the existing shouldPassThroughClick closure.

## Scalability Considerations

| Concern | Current (1 OSK) | Future (multiple exclusions) |
|---------|-----------------|------------------------------|
| Cache size | 0-1 rects | Add user-configurable exclusion list; still < 20 rects |
| Poll frequency | 500ms is fine | Could reduce to 1s if many windows to scan |
| Owner name matching | Hardcoded set | Could load from UserDefaults for user customization |
| Coordinate systems | CG-only, no conversion needed | Stays CG-only as long as we use CGWindowList + CGEvent |

## Build Order for This Milestone

1. **Step 1: WindowExclusionManager** -- Create the service with caching logic. Test independently that it detects the Accessibility Keyboard when open.
2. **Step 2: AppState wiring** -- Add the manager as a property, wire into `shouldPassThroughClick` closure, add start/stop to activate/deactivate.
3. **Step 3: Manual verification** -- Open Accessibility Keyboard, activate scroll mode, verify clicks on OSK keys pass through and clicks elsewhere scroll.
4. **Step 4 (optional): Settings UI** -- If desired, add a toggle for "Pass through clicks on on-screen keyboards" or a way to add custom excluded app names.

**Rationale:** Step 1 is fully independent with no dependency on existing code changes. Step 2 is a small, focused edit to AppState. This ordering means Step 1 can be tested in isolation before touching existing working code.

## Open Questions

- **Exact process names on current macOS:** The owner name for the Accessibility Keyboard is reported as "AssistiveControl" in community sources, but this should be verified on the target macOS version by opening the keyboard and inspecting CGWindowListCopyWindowInfo output. LOW confidence on exact names -- verify empirically.
- **Keyboard Viewer vs Accessibility Keyboard:** These may be separate processes ("KeyboardViewer" vs "AssistiveControl"). Both should likely be excluded. Verify which the user actually needs.
- **Third-party on-screen keyboards:** Users of apps like Karabiner-Elements virtual keyboard or third-party OSKs may need additional owner names. Consider making this configurable in a future phase.

## Sources

- [Apple Developer: CGWindowListCopyWindowInfo](https://developer.apple.com/documentation/coregraphics/1455137-cgwindowlistcopywindowinfo)
- [Apple Developer: CGEvent.tapCreate](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:))
- [Apple Developer Forums: kCGWindowName requires Screen Recording permission (macOS 10.15+)](https://developer.apple.com/forums/thread/126860)
- [Apple Developer: AXObserverAddNotification](https://developer.apple.com/documentation/applicationservices/1462089-axobserveraddnotification)
- [Apple Support: Accessibility Keyboard](https://support.apple.com/guide/mac-help/use-the-accessibility-keyboard-mchlc74c1c9f/mac)
- [PyGetWindow: CGWindowList hit-testing pattern](https://github.com/asweigart/PyGetWindow/blob/master/src/pygetwindow/_pygetwindow_macos.py)

---
*Architecture research for: Scroll My Mac -- OSK-aware click pass-through integration*
*Researched: 2026-02-16*
