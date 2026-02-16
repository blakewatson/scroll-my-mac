# Technology Stack

**Project:** Scroll My Mac -- OSK-aware click pass-through (milestone addition)
**Researched:** 2026-02-16
**Scope:** Stack ADDITIONS only. See previous STACK.md commit for base stack (Swift, SwiftUI, CGEventTap, etc.)

## New Stack Additions for OSK Detection

### Core APIs

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| `CGWindowListCopyWindowInfo` | CoreGraphics (system framework) | Enumerate on-screen windows to find the Accessibility Keyboard | NOT deprecated (only `CGWindowListCreateImage` was deprecated in macOS 14). Returns window owner name and bounds WITHOUT Screen Recording permission. No new framework dependency needed -- already linked via CoreGraphics. **HIGH confidence** |
| `NSWorkspace` notifications | AppKit (system framework) | Detect when Accessibility Keyboard launches/terminates | `didLaunchApplicationNotification` and `didTerminateApplicationNotification` provide reactive detection. Avoids polling for process existence. Already available via AppKit import. **HIGH confidence** |
| `NSRunningApplication` | AppKit (system framework) | Confirm Accessibility Keyboard process is running | `NSRunningApplication.runningApplications(withBundleIdentifier:)` for initial state check at app launch. Thread-safe. **HIGH confidence** |

### No New Dependencies Required

All required APIs are part of CoreGraphics and AppKit, both already linked by the project. No new SPM packages, frameworks, or entitlements are needed.

## Accessibility Keyboard Identification

### Process Identity (MEDIUM confidence -- verified via AppleScript community sources, needs runtime validation)

| Identifier | Value | Source |
|------------|-------|--------|
| Process name (`kCGWindowOwnerName`) | `"Assistive Control"` (with space) | AppleScript community, System Events inspection |
| Input method bundle ID | `com.apple.inputmethod.AssistiveControl` | `defaults read com.apple.HIToolbox` when keyboard is active |
| Window name (via System Events) | `"Panel"` | AppleScript `window "Panel" of process "Assistive Control"` |
| `kCGWindowLayer` | Likely above normal (>0) | Panel windows float above normal app windows |

**Important:** The exact bundle identifier for `NSRunningApplication.runningApplications(withBundleIdentifier:)` needs runtime verification. Candidates to try in order:

1. `com.apple.inputmethod.AssistiveControl` (most likely -- confirmed in HIToolbox plist)
2. `com.apple.accessibility.AssistiveControl` (Apple accessibility naming convention)
3. Fall back to matching by `kCGWindowOwnerName == "Assistive Control"` via CGWindowList

**Recommendation:** Use `kCGWindowOwnerName` matching as the primary detection method since it is confirmed and does not require knowing the exact bundle ID. Use NSRunningApplication as a secondary/optimization check once the bundle ID is verified at runtime.

## API Details

### CGWindowListCopyWindowInfo -- What We Need

```swift
// Get all on-screen windows (no Screen Recording permission needed for owner name + bounds)
let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    return nil
}

// Find the Accessibility Keyboard window
for window in windowList {
    guard let ownerName = window[kCGWindowOwnerName as String] as? String,
          ownerName == "Assistive Control",
          let boundsDict = window[kCGWindowBounds as String] as? CFDictionary,
          let bounds = CGRect(dictionaryRepresentation: boundsDict)
    else { continue }
    return bounds  // CGRect in screen coordinates (top-left origin)
}
```

### Permission Requirements

| Data | Available WITHOUT Screen Recording? | Needed? |
|------|-------------------------------------|---------|
| `kCGWindowOwnerName` (process name) | YES | YES -- to identify "Assistive Control" |
| `kCGWindowBounds` (position + size) | YES | YES -- for hit testing |
| `kCGWindowOwnerPID` | YES | OPTIONAL -- for PID-based filtering |
| `kCGWindowNumber` (window ID) | YES | NO |
| `kCGWindowName` (window title) | NO (requires Screen Recording) | NO -- not needed |

**No additional permissions beyond existing Accessibility permission.** This is critical -- adding a Screen Recording permission prompt would degrade user experience for an accessibility app.

### Coordinate System Alignment

`kCGWindowBounds` and `CGEvent.location` both use the **same coordinate system**: top-left origin, Y increasing downward. This means:

```swift
// Direct hit test -- no coordinate conversion needed!
let cursorPosition = event.location  // CGEvent location: top-left origin
let oskBounds: CGRect = ...          // kCGWindowBounds: top-left origin
let isOverOSK = oskBounds.contains(cursorPosition)
```

This is a significant simplification. The existing `shouldPassThroughClick` closure converts CG coordinates to NS coordinates (bottom-left origin) to check NSWindow frames. For OSK detection, we skip that conversion entirely since both APIs use the same coordinate space.

## Performance Strategy

### The Problem

`CGWindowListCopyWindowInfo` is a system call that crosses process boundaries to query the window server. Calling it on EVERY mouseDown is wasteful, especially since the Accessibility Keyboard window position changes infrequently (only when the user manually repositions it).

### Recommended Approach: Cache + Invalidate

| Strategy | When | Cost |
|----------|------|------|
| **Cache OSK bounds on app activation** | `NSWorkspace.didLaunchApplicationNotification` for "Assistive Control" | One-time ~1ms call |
| **Invalidate cache on termination** | `NSWorkspace.didTerminateApplicationNotification` for "Assistive Control" | Free |
| **Refresh cache periodically** | Timer every 2-5 seconds while OSK is known to be running | ~1ms per refresh |
| **Hit test from cache** | Every mouseDown in ScrollEngine callback | ~0 cost (CGRect.contains is a few nanoseconds) |

### Expected Performance

| Operation | Estimated Cost | Frequency |
|-----------|---------------|-----------|
| `CGWindowListCopyWindowInfo` (full call) | 0.5-2ms depending on window count | Every 2-5 seconds (cached) |
| `CGRect.contains(CGPoint)` | <1 microsecond | Every mouseDown |
| `NSRunningApplication.runningApplications(withBundleIdentifier:)` | <0.1ms | On notification events |

The mouseDown event tap callback budget is roughly 100ms before macOS disables the tap (`tapDisabledByTimeout`). A cached CGRect.contains check adds effectively zero latency. Even an uncached `CGWindowListCopyWindowInfo` at ~2ms worst case would be safe, but caching is still the right approach for cleanliness.

### Why NOT Alternative Approaches

| Alternative | Why Not |
|-------------|---------|
| **ScreenCaptureKit (`SCShareableContent`)** | Requires Screen Recording permission. Async API (returns via completion handler). Overkill for reading window bounds. Designed for screen capture, not window geometry queries. |
| **AXUIElement** | Could query the OSK window via Accessibility APIs, but more complex to set up. Requires knowing the PID first, then traversing the element tree. `CGWindowListCopyWindowInfo` gives bounds directly in one call. |
| **`CGWindowListCreateImage` for hit testing** | Deprecated in macOS 14, unavailable in macOS 15. Also captures pixel data which is absurdly expensive for a bounds check. |
| **Polling `CGWindowListCopyWindowInfo` on every mouseDown** | Works but wasteful. System call on every click adds unnecessary latency and window server load. Cache-based approach is strictly better. |

## Integration Points

### Existing Hook: `shouldPassThroughClick`

The ScrollEngine already has a `shouldPassThroughClick: ((CGPoint) -> Bool)?` closure called on every mouseDown. Currently it checks if the cursor is over the app's own windows:

```swift
// Current implementation in AppState.setupServices()
scrollEngine.shouldPassThroughClick = { cgPoint in
    guard let screenHeight = NSScreen.main?.frame.height else { return false }
    let nsPoint = NSPoint(x: cgPoint.x, y: screenHeight - cgPoint.y)
    return NSApp.windows.contains { window in
        window.isVisible && !window.ignoresMouseEvents && window.frame.contains(nsPoint)
    }
}
```

**Extend this closure** to also check the cached OSK bounds:

```swift
scrollEngine.shouldPassThroughClick = { [weak self] cgPoint in
    // Check 1: App's own windows (existing logic, uses NS coordinates)
    guard let screenHeight = NSScreen.main?.frame.height else { return false }
    let nsPoint = NSPoint(x: cgPoint.x, y: screenHeight - cgPoint.y)
    let isOverOwnWindow = NSApp.windows.contains { window in
        window.isVisible && !window.ignoresMouseEvents && window.frame.contains(nsPoint)
    }
    if isOverOwnWindow { return true }

    // Check 2: Accessibility Keyboard (uses CG coordinates directly)
    if let oskBounds = self?.oskDetector?.cachedBounds {
        return oskBounds.contains(cgPoint)
    }
    return false
}
```

### New Component: `OSKDetector`

A lightweight service class that:
1. Observes NSWorkspace notifications for "Assistive Control" process launch/termination
2. Caches the OSK window bounds via `CGWindowListCopyWindowInfo`
3. Refreshes bounds on a timer (handles user repositioning the keyboard)
4. Exposes `cachedBounds: CGRect?` (nil when OSK is not visible)

This service would be owned by `AppState` alongside `ScrollEngine`, `HotkeyManager`, and `OverlayManager`.

## Deprecation and Future-Proofing

| API | Status | Risk |
|-----|--------|------|
| `CGWindowListCopyWindowInfo` | NOT deprecated (as of macOS 15 Sequoia) | LOW -- Apple has only deprecated the image capture sibling, not the info query. Even if deprecated later, it would go through a multi-year deprecation cycle. |
| `kCGWindowBounds` / `kCGWindowOwnerName` | Stable, no deprecation signals | LOW |
| `NSWorkspace` notifications | Stable since macOS 10.6 | NONE |
| `NSRunningApplication` | Stable since macOS 10.6 | NONE |

If Apple eventually deprecates `CGWindowListCopyWindowInfo`, the migration path would be `SCShareableContent` from ScreenCaptureKit. However, that API currently requires Screen Recording permission, which would be a user experience regression. Cross that bridge if/when it comes.

## Version Compatibility

All new APIs are available on the project's minimum deployment target (macOS 14.0 Sonoma) and earlier:

| API | Available Since |
|-----|-----------------|
| `CGWindowListCopyWindowInfo` | macOS 10.5 |
| `kCGWindowBounds` | macOS 10.5 |
| `kCGWindowOwnerName` | macOS 10.5 |
| `NSWorkspace.didLaunchApplicationNotification` | macOS 10.6 |
| `NSRunningApplication` | macOS 10.6 |

No deployment target changes required.

## Sources

- [Apple Developer: CGWindowListCopyWindowInfo](https://developer.apple.com/documentation/coregraphics/1455137-cgwindowlistcopywindowinfo) -- API reference, NOT deprecated (HIGH confidence)
- [Apple Developer: NSRunningApplication](https://developer.apple.com/documentation/appkit/nsrunningapplication) -- running app detection (HIGH confidence)
- [Apple Developer: NSWorkspace notifications](https://developer.apple.com/documentation/appkit/nsworkspace/runningapplications) -- app launch/quit observation (HIGH confidence)
- [Ryan Thomson: Screen Recording Permissions in Catalina](https://www.ryanthomson.net/articles/screen-recording-permissions-catalina-mess/) -- confirms kCGWindowOwnerName and kCGWindowBounds available without Screen Recording (HIGH confidence)
- [Apple Developer Forums: window name not available in 10.15](https://developer.apple.com/forums/thread/126860) -- confirms only kCGWindowName gated by Screen Recording (HIGH confidence)
- [AppleAyuda: AssistiveControl AppleScript](https://www.appleayuda.com/pregunta/96306/acceso-directo-para-alternar-keyboardviewer-con-applescript-en-big-sur) -- process name "Assistive Control", input method ID `com.apple.inputmethod.AssistiveControl` (MEDIUM confidence -- community source)
- [Nonstrict: ScreenCaptureKit on macOS Sonoma](https://nonstrict.eu/blog/2023/a-look-at-screencapturekit-on-macos-sonoma/) -- confirms CGWindowListCopyWindowInfo not deprecated, only CGWindowListCreateImage (HIGH confidence)
- [Entonos: Which CGRect was that?](https://entonos.com/2021/05/20/which-cgrect-was-that/) -- kCGWindowBounds coordinate system (top-left origin) (MEDIUM confidence)
- [Krizka: Converting kCGWindowBounds and NSWindow frame](https://www.krizka.net/2010/04/20/converting-between-kcgwindowbounds-and-nswindowframe/) -- coordinate system details (MEDIUM confidence)
- [GitHub: MacWindowsLister](https://github.com/allenlinli/MacWindowsLister) -- CGWindowList Swift usage example (MEDIUM confidence)

---
*Stack additions research for: OSK-aware click pass-through*
*Researched: 2026-02-16*
