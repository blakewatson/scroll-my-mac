# Phase 6: OSK-Aware Click Pass-Through - Research

**Researched:** 2026-02-16
**Domain:** macOS window detection + CGEventTap pass-through for Accessibility Keyboard
**Confidence:** HIGH

## Summary

Phase 6 adds Accessibility Keyboard (OSK) detection to the existing scroll engine so clicks over the OSK pass through instantly without entering the hold-and-decide model. The implementation requires no new frameworks, dependencies, or permissions. A new `WindowExclusionManager` service polls `CGWindowListCopyWindowInfo` on a timer, caches the OSK window bounds as `[CGRect]`, and exposes a fast `isPointExcluded(_:CGPoint) -> Bool` method. This is wired into the existing `shouldPassThroughClick` closure in `AppState.setupServices()` -- the only integration point. ScrollEngine.swift requires zero changes.

Both `CGEvent.location` and `kCGWindowBounds` use CG coordinates (top-left origin, Y down), so the hit test is a direct `CGRect.contains(CGPoint)` with no coordinate conversion. The critical constraint is that `CGWindowListCopyWindowInfo` must NEVER be called inside the event tap callback -- it is a cross-process IPC call that can cause `tapDisabledByTimeout`. The cache-and-check pattern eliminates this risk entirely.

The process name for the Accessibility Keyboard is "Assistive Control" (with space) based on community sources. This is MEDIUM confidence and must be verified empirically at runtime before hardcoding. The first task in this phase should be a diagnostic step that prints all CGWindowList entries to confirm the exact owner name and window properties.

**Primary recommendation:** Create a WindowExclusionManager service (~60 lines) with timer-based polling, wire it into the existing shouldPassThroughClick closure in AppState, and verify the OSK process name empirically before hardcoding.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Boundary behavior
- Use the entire OSK window rectangle for hit-testing (not individual key regions)
- Detect all windows belonging to the OSK process, not just the main keyboard panel
- Edge precision is not critical -- use whatever approach is simplest (no margin needed)
- Always on -- no user-facing setting to toggle OSK pass-through

#### Visual feedback
- No visual indication when pass-through is active over the OSK -- clicks just work naturally
- The overlay dot stays as-is regardless of cursor position relative to OSK
- If OSK detection fails (e.g., process name changes in a macOS update), fall back silently to normal scroll behavior with no user-facing warning

#### Drag transitions
- Click origin determines behavior for the entire drag
- Click starts on OSK -> entire drag is pass-through, even if cursor leaves the OSK
- Click starts outside OSK -> entire drag is scroll, even if cursor enters the OSK
- No mid-drag behavior switching

#### OSK lifecycle
- Auto-detect: continuously check for OSK windows, pass-through activates immediately when OSK appears
- Smart polling: poll less frequently (or stop) when OSK isn't detected, ramp up when it reappears
- OSK only: hardcode for the Accessibility Keyboard, no general window exclusion system
- Keep it simple and focused on this one use case

### Claude's Discretion
- Process name matching strategy (exact vs fuzzy) -- balance reliability and resilience
- Polling interval and smart polling implementation details
- How to integrate with the existing shouldPassThroughClick closure in ScrollEngine

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

## Standard Stack

### Core

| API | Framework | Purpose | Why Standard |
|-----|-----------|---------|--------------|
| `CGWindowListCopyWindowInfo` | CoreGraphics (already linked) | Enumerate on-screen windows to find OSK by owner name and get bounds | NOT deprecated. Returns owner name + bounds WITHOUT Screen Recording permission. Available since macOS 10.5. |
| `kCGWindowOwnerName` | CoreGraphics | Identify the Accessibility Keyboard process | Available without Screen Recording permission (unlike `kCGWindowName`). No extra permissions needed. |
| `kCGWindowBounds` | CoreGraphics | Get window position and size for hit testing | Returns CGRect in CG coordinates (top-left origin) -- same coordinate system as `CGEvent.location`. Direct comparison, no conversion. |
| `Timer` (Foundation) | Foundation (already linked) | Periodic polling of window list to refresh cache | Standard approach for infrequent polling. Already used elsewhere in the app (permission health check, overlay tracking). |

### Supporting

| API | Framework | Purpose | When to Use |
|-----|-----------|---------|-------------|
| `CGRect.contains(_:CGPoint)` | CoreGraphics | Fast hit test against cached bounds | On every mouseDown in the shouldPassThroughClick closure. O(1), nanoseconds. |
| `CGRectMakeWithDictionaryRepresentation` | CoreGraphics | Parse kCGWindowBounds dictionary into CGRect | In the cache refresh method when reading window bounds from CGWindowList. |

### Not Needed

| API | Why Not |
|-----|---------|
| `kCGWindowName` | Requires Screen Recording permission. Not needed -- owner name is sufficient. |
| `ScreenCaptureKit / SCShareableContent` | Requires Screen Recording permission. Async API. Overkill for bounds queries. |
| `AXObserver` | Adds complexity (PID tracking, run loop, observer lifecycle). Timer polling is sufficient since OSK moves rarely. |
| `NSWorkspace` notifications | Could optimize by detecting OSK launch/termination, but smart polling achieves the same result with less code. |
| `NSRunningApplication` | Could check if OSK process is running, but CGWindowList already tells us this (no matching windows = not running). |

**No new dependencies.** All APIs are part of CoreGraphics and Foundation, both already linked.

## Architecture Patterns

### Component Diagram

```
EXISTING (unchanged)                     NEW
+------------------+                    +---------------------------+
|   ScrollEngine   |                    |  WindowExclusionManager   |
|                  |                    |                           |
|  shouldPassThru  |<---[closure]-------|  isPointExcluded          |
|  Click?(CGPoint) |                    |  (_:CGPoint) -> Bool      |
|                  |                    |                           |
|  handleMouseDown |                    |  excludedRects: [CGRect]  |
|  (checks closure |                    |  pollTimer: Timer?        |
|   at top)        |                    |  oskDetected: Bool        |
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

### Files Changed vs Created

| File | Action | What Changes |
|------|--------|-------------|
| `Services/WindowExclusionManager.swift` | **CREATE** | New service class (~60-80 lines) |
| `App/AppState.swift` | **MODIFY** | Add property, extend shouldPassThroughClick closure, add start/stop in activate/deactivate |
| `Services/ScrollEngine.swift` | **UNCHANGED** | No changes needed |

### Pattern 1: Cache-and-Check for IPC-Heavy APIs
**What:** Pre-cache results from expensive system calls on a timer; read the cache in performance-sensitive paths.
**When:** Any time you need data from a cross-process IPC call in the event tap callback path.
**Why:** The event tap callback must return quickly. CGWindowListCopyWindowInfo involves IPC to the Window Server (0.5-2ms). Caching separates the cost from the critical path.

### Pattern 2: Compose Exclusion Reasons in the Closure
**What:** The `shouldPassThroughClick` closure in AppState composes multiple independent pass-through reasons into a single check using short-circuit OR logic.
**When:** Adding new pass-through conditions.
**Why:** ScrollEngine stays generic. New exclusion reasons never require changes to ScrollEngine.

```swift
scrollEngine.shouldPassThroughClick = { [weak self] cgPoint in
    guard let self else { return false }
    // Check 1: App's own windows (existing, NS coordinates)
    if self.isClickOnOwnWindow(cgPoint) { return true }
    // Check 2: Excluded windows like OSK (new, CG coordinates)
    return self.windowExclusionManager.isPointExcluded(cgPoint)
}
```

### Pattern 3: Smart Polling (Monitor Only When Active + Adaptive Rate)
**What:** Start/stop the polling timer with scroll mode. When OSK is not detected, poll slowly (every 2-5s). When OSK is detected, poll faster (every 500ms) to track repositioning.
**When:** For any polling-based service where the target may or may not be present.
**Why:** No cost when scroll mode is off. Minimal cost when OSK is absent. Responsive when OSK is in use.

**Recommended intervals:**
- Scroll mode OFF: no polling at all (timer stopped)
- Scroll mode ON, OSK not detected: poll every 2 seconds
- Scroll mode ON, OSK detected: poll every 500ms

### Pattern 4: Drag-Origin-Determines-Behavior
**What:** The `passedThroughClick` flag in ScrollEngine already implements this. Once mouseDown is passed through (returns the event), all subsequent mouseDragged and mouseUp events for that click sequence also pass through.
**When:** Always -- this is the existing ScrollEngine behavior.
**Why:** Prevents jarring mid-drag behavior switching. Already implemented, no work needed.

### Anti-Patterns to Avoid

- **CGWindowListCopyWindowInfo in the event tap callback:** IPC call that can cause tapDisabledByTimeout. Always cache outside the callback.
- **Using kCGWindowName for identification:** Requires Screen Recording permission. Use kCGWindowOwnerName instead.
- **Global/static state for the cache:** Breaks the existing architecture pattern. Flow data through the shouldPassThroughClick closure.
- **Replacing the entire shouldPassThroughClick closure:** Must extend with an additional OR condition. Keep the existing app-window check intact.
- **Retaining stale cache when OSK is closed:** Set excludedRects to empty array when no matching windows found. Do not retain last-known bounds.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| kCGWindowBounds dict -> CGRect | Manual X/Y/Width/Height extraction | `CGRectMakeWithDictionaryRepresentation` (or `CGRect(dictionaryRepresentation:)`) | Handles all edge cases, nil safety, type conversion |
| Coordinate conversion for hit test | CG-to-NS conversion for OSK check | Direct CG-to-CG comparison | Both CGEvent.location and kCGWindowBounds are CG coordinates. No conversion needed. |
| Drag pass-through continuity | Custom flag to track "started on OSK" | Existing `passedThroughClick` flag in ScrollEngine | Already implemented. When shouldPassThroughClick returns true for mouseDown, all subsequent drag/up events pass through automatically. |

**Key insight:** The existing ScrollEngine architecture already handles the hard parts (pass-through continuity, modifier pass-through, replay marker tagging). The new code only needs to answer one question: "Is this CGPoint inside an OSK window?"

## Common Pitfalls

### Pitfall 1: CGWindowListCopyWindowInfo in Event Tap Path
**What goes wrong:** Calling CGWindowListCopyWindowInfo on every mouseDown causes the event tap callback to block for 5-50ms+. macOS sends `tapDisabledByTimeout` and silently disables scroll mode.
**Why it happens:** Developers underestimate the IPC cost because it "works fine" in isolation but breaks under event tap timing constraints.
**How to avoid:** Never call CGWindowListCopyWindowInfo inside handleMouseDown or the C callback. Cache on a timer, read the cache in the callback.
**Warning signs:** Scroll mode randomly stops working. `tapDisabledByTimeout` events in Console.app. Works in testing (few windows) but fails in real usage.

### Pitfall 2: Wrong Process Name
**What goes wrong:** Detection never finds the OSK because the hardcoded process name is wrong (e.g., "AssistiveControl" instead of "Assistive Control").
**Why it happens:** The process name is from community sources, not Apple documentation. Apple could also change it between macOS versions.
**How to avoid:** First task must be empirical verification -- open the Accessibility Keyboard and print all CGWindowList entries to confirm the exact `kCGWindowOwnerName` string.
**Warning signs:** OSK clicks always get intercepted even though the manager is running.

### Pitfall 3: Stale Cache After OSK Closes/Minimizes
**What goes wrong:** OSK is closed or minimized but cached bounds persist, creating a "dead zone" where clicks always pass through.
**Why it happens:** Cache not cleared when CGWindowListCopyWindowInfo returns no matching windows.
**How to avoid:** Always set excludedRects to empty array when poll finds no matching windows. Use `.optionOnScreenOnly` flag to exclude minimized windows.
**Warning signs:** Clicks pass through in an area where the OSK used to be but is no longer visible.

### Pitfall 4: Breaking Existing App-Window Pass-Through
**What goes wrong:** The settings panel click pass-through stops working after modifying the shouldPassThroughClick closure.
**Why it happens:** Restructuring the closure changes evaluation order or drops the existing NSApp.windows check.
**How to avoid:** Keep the existing check untouched. Add OSK check as a second, independent OR condition. Test existing pass-through behavior before and after.
**Warning signs:** Settings panel clicks get intercepted by scroll mode.

### Pitfall 5: Coordinate System Mismatch
**What goes wrong:** Hit test compares CG coordinates with NS coordinates, producing vertically-flipped results.
**Why it happens:** The existing app-window check converts CG to NS (because NSWindow.frame is NS coordinates). Developer might accidentally apply the same conversion to OSK bounds (which are already CG coordinates).
**How to avoid:** Keep the OSK check entirely in CG coordinate space. Do NOT reuse the NS conversion from the app-window check.
**Warning signs:** Pass-through works at a position vertically mirrored from the actual OSK location.

## Code Examples

### WindowExclusionManager Core Structure

```swift
// Source: Synthesized from prior research (.planning/research/ARCHITECTURE.md)
class WindowExclusionManager {
    private var excludedRects: [CGRect] = []
    private var pollTimer: Timer?
    private var oskDetected: Bool = false

    // Target process name -- verify empirically before hardcoding
    private let targetOwnerName = "Assistive Control"

    // Smart polling intervals
    private let activeInterval: TimeInterval = 0.5   // OSK detected
    private let passiveInterval: TimeInterval = 2.0   // OSK not detected

    func isPointExcluded(_ point: CGPoint) -> Bool {
        return excludedRects.contains { $0.contains(point) }
    }

    func startMonitoring() {
        refreshCache()
        scheduleTimer()
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        excludedRects = []
        oskDetected = false
    }

    private func refreshCache() {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            excludedRects = []
            updatePollingRate(oskFound: false)
            return
        }

        excludedRects = windowList.compactMap { info in
            guard let ownerName = info[kCGWindowOwnerName as String] as? String,
                  ownerName == targetOwnerName,
                  let boundsDict = info[kCGWindowBounds as String] as? CFDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict)
            else { return nil }
            return bounds
        }

        updatePollingRate(oskFound: !excludedRects.isEmpty)
    }

    private func updatePollingRate(oskFound: Bool) {
        guard oskFound != oskDetected else { return }
        oskDetected = oskFound
        scheduleTimer()
    }

    private func scheduleTimer() {
        pollTimer?.invalidate()
        let interval = oskDetected ? activeInterval : passiveInterval
        pollTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            self?.refreshCache()
        }
    }
}
```

### AppState Integration

```swift
// Source: Synthesized from existing AppState.swift + research
// In AppState:
let windowExclusionManager = WindowExclusionManager()  // Add as property

// In setupServices() -- extend the existing closure:
scrollEngine.shouldPassThroughClick = { [weak self] cgPoint in
    guard let self else { return false }

    // Check 1: App's own windows (existing logic, unchanged)
    guard let screenHeight = NSScreen.main?.frame.height else { return false }
    let nsPoint = NSPoint(x: cgPoint.x, y: screenHeight - cgPoint.y)
    let isOwnWindow = NSApp.windows.contains { window in
        window.isVisible && !window.ignoresMouseEvents && window.frame.contains(nsPoint)
    }
    if isOwnWindow { return true }

    // Check 2: OSK / excluded windows (new, CG coordinates -- no conversion)
    return self.windowExclusionManager.isPointExcluded(cgPoint)
}

// In activateScrollMode():
windowExclusionManager.startMonitoring()

// In deactivateScrollMode():
windowExclusionManager.stopMonitoring()
```

### Empirical Process Name Verification

```swift
// Run this diagnostic to discover the exact OSK process name.
// Open the Accessibility Keyboard first, then call this.
func printAllWindows() {
    guard let windowList = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
    ) as? [[String: Any]] else {
        print("Failed to get window list")
        return
    }

    for window in windowList {
        let ownerName = window[kCGWindowOwnerName as String] as? String ?? "(nil)"
        let ownerPID = window[kCGWindowOwnerPID as String] as? Int ?? -1
        let layer = window[kCGWindowLayer as String] as? Int ?? -1
        let boundsDict = window[kCGWindowBounds as String] as? CFDictionary
        let bounds = boundsDict.flatMap { CGRect(dictionaryRepresentation: $0) }
        print("Owner: \(ownerName) | PID: \(ownerPID) | Layer: \(layer) | Bounds: \(bounds?.debugDescription ?? "nil")")
    }
}
```

### Parsing kCGWindowBounds Correctly

```swift
// Source: Apple CoreGraphics documentation
// Use CGRect(dictionaryRepresentation:) -- do NOT manually extract X/Y/Width/Height
guard let boundsDict = windowInfo[kCGWindowBounds as String] as? CFDictionary,
      let bounds = CGRect(dictionaryRepresentation: boundsDict)
else { return nil }
// bounds is now in CG coordinates (top-left origin) -- same as CGEvent.location
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `CGWindowListCreateImage` for window detection | `CGWindowListCopyWindowInfo` for metadata only | macOS 14 (image capture deprecated) | Info query is NOT deprecated, only image capture |
| `kCGWindowName` for identification | `kCGWindowOwnerName` for identification | macOS 10.15 Catalina | Window name requires Screen Recording permission; owner name does not |

**Deprecated/outdated:**
- `CGWindowListCreateImage`: Deprecated in macOS 14, unavailable in macOS 15. Not needed -- we only query metadata.
- `kCGWindowName` without Screen Recording: No longer available without permission since macOS 10.15. Use `kCGWindowOwnerName` instead.

## Discretion Recommendations

### Process Name Matching Strategy
**Recommendation: Use exact string match.**
- Match `kCGWindowOwnerName` exactly against the verified process name string
- Do NOT use fuzzy/contains matching -- risks false positives with other processes
- If the exact name changes in a future macOS update, the detection silently falls back to normal scroll behavior (per user decision), which is the safest failure mode
- Store the target name as a single constant for easy updating

### Polling Interval and Smart Polling
**Recommendation: Two-tier adaptive polling.**
- Scroll mode OFF: no timer at all (zero overhead)
- Scroll mode ON + OSK not detected: poll every 2 seconds (low overhead, catches OSK appearing)
- Scroll mode ON + OSK detected: poll every 500ms (responsive to repositioning)
- Switch tiers when OSK presence changes (detected/not detected)
- Immediate first poll on startMonitoring() so detection is instant when scroll mode activates

### Integration with shouldPassThroughClick
**Recommendation: Extend the existing closure with an OR condition.**
- Keep the existing NSApp.windows check as-is (Check 1)
- Add windowExclusionManager.isPointExcluded() as Check 2
- Short-circuit: if Check 1 is true, skip Check 2
- No changes to ScrollEngine.swift -- the closure composition happens entirely in AppState.setupServices()

## Open Questions

1. **Exact process name on current macOS**
   - What we know: Community sources report "Assistive Control" (with space). Input method ID is `com.apple.inputmethod.AssistiveControl`.
   - What's unclear: Whether `kCGWindowOwnerName` returns "Assistive Control" or "AssistiveControl" (no space) or something else entirely.
   - Recommendation: First implementation task must be empirical verification with the diagnostic code above. Do NOT hardcode until verified.

2. **Multiple windows from the same process**
   - What we know: AssistiveControl may own multiple windows (keyboard panel, toolbar, resize handles, custom panels from Panel Editor).
   - What's unclear: How many windows appear and whether all should be excluded.
   - Recommendation: Per user decision, detect ALL windows belonging to the OSK process. The compactMap in refreshCache already handles this -- it collects all matching windows.

3. **Keyboard Viewer vs Accessibility Keyboard**
   - What we know: These are likely separate processes ("KeyboardViewerServer" vs "Assistive Control").
   - What's unclear: Whether the user needs Keyboard Viewer pass-through too.
   - Recommendation: Per user decision, hardcode for Accessibility Keyboard only. Keyboard Viewer support can be added later by adding its owner name to the match set.

## Sources

### Primary (HIGH confidence)
- **Existing codebase** -- ScrollEngine.swift (shouldPassThroughClick pattern, handleMouseDown flow, passedThroughClick flag), AppState.swift (setupServices wiring, activate/deactivate lifecycle)
- **Prior research** -- `.planning/research/ARCHITECTURE.md`, `STACK.md`, `PITFALLS.md`, `FEATURES.md` (comprehensive investigation already completed 2026-02-16)
- [Apple Developer: CGWindowListCopyWindowInfo](https://developer.apple.com/documentation/coregraphics/1455137-cgwindowlistcopywindowinfo) -- API not deprecated, returns owner name + bounds without Screen Recording
- [Apple Developer Forums: kCGWindowName requires Screen Recording](https://developer.apple.com/forums/thread/126860) -- confirms only window name is gated

### Secondary (MEDIUM confidence)
- [Ryan Thomson: Screen Recording Permissions in Catalina](https://www.ryanthomson.net/articles/screen-recording-permissions-catalina-mess/) -- confirms which CGWindowList fields need Screen Recording
- [alt-tab-macos](https://github.com/lwouis/alt-tab-macos/issues/45) -- CGWindowListCopyWindowInfo performance characteristics
- [Nonstrict: ScreenCaptureKit on Sonoma](https://nonstrict.eu/blog/2023/a-look-at-screencapturekit-on-macos-sonoma/) -- confirms CGWindowListCopyWindowInfo not deprecated

### Tertiary (LOW confidence -- needs runtime validation)
- AppleScript community references -- process name "Assistive Control" with window "Panel". Must verify empirically.
- Input method bundle ID `com.apple.inputmethod.AssistiveControl` -- from `defaults read com.apple.HIToolbox`

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all APIs well-documented, available without additional permissions, not deprecated
- Architecture: HIGH -- extends existing proven pattern (shouldPassThroughClick), minimal code changes, prior research thoroughly validated the approach
- Pitfalls: HIGH -- all pitfalls have clear prevention strategies, most critical one (no IPC in callback) is a simple architectural constraint
- Process identification: MEDIUM -- name needs runtime verification before hardcoding

**Research date:** 2026-02-16
**Valid until:** 2026-03-16 (stable APIs, macOS system frameworks)
