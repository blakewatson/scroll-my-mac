# Stack Research

**Domain:** macOS accessibility app (system-wide input interception and transformation)
**Researched:** 2026-02-14
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Swift | 6.2 (Xcode 26) | Application language | First-class Apple platform language. Swift 6.2's "approachable concurrency" with default `@MainActor` isolation simplifies the threading model for a UI+event-tap app. No reason to use anything else for native macOS. **HIGH confidence** |
| SwiftUI | macOS 14+ APIs | GUI (settings window, toggle, hotkey config) | Project requires a simple windowed app, not a menu bar app. SwiftUI's `App` protocol with `WindowGroup` and `Settings` scenes maps directly to requirements. Mature enough on macOS 14+ for a simple preferences-style window. **HIGH confidence** |
| CoreGraphics (CGEventTap) | System framework | System-wide mouse event interception | `CGEvent.tapCreate()` is the only supported API for intercepting AND modifying mouse events system-wide. `NSEvent.addGlobalMonitorForEvents` is listen-only (cannot suppress or transform events). CGEventTap with `.defaultTap` option is required to suppress left-click events and replace them with scroll events. **HIGH confidence** |
| CoreGraphics (CGEvent posting) | System framework | Generating synthetic scroll events | `CGEvent` with `.scrollWheel` type to post synthetic scroll events. This is the standard mechanism for programmatic scrolling. **HIGH confidence** |
| AppKit (NSCursor) | System framework | Cursor state management | `NSCursor.hide()` / `NSCursor.unhide()` for hiding cursor during scroll mode. SwiftUI has no cursor management APIs; must bridge to AppKit. **HIGH confidence** |
| CoreGraphics (CGAssociateMouseAndMouseCursorPosition) | System framework | Lock cursor position during scroll | `CGAssociateMouseAndMouseCursorPosition(false)` disconnects mouse movement from cursor position, preventing the cursor from moving while the user drags to scroll. Pass `true` to reconnect when scroll mode ends. **HIGH confidence** |
| CoreGraphics (CGWarpMouseCursorPosition) | System framework | Restore cursor position | Warps cursor back to the original click position after scroll mode ends, if needed. Does not generate events. **HIGH confidence** |
| CADisplayLink | macOS 14+ | Frame-synchronized inertia animation | Available on macOS since macOS 14 Sonoma. Synchronizes inertia deceleration to the display refresh rate for smooth animation. Replaces the older C-based `CVDisplayLink` API. Use `CADisplayLink` for the inertia/momentum animation loop after the user releases the drag. **MEDIUM confidence** (training data; verify availability on macOS 14 at implementation time) |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | 2.4.0 | User-configurable global hotkey | Use for the "activate scroll mode" hotkey. Provides a SwiftUI `Recorder` view for users to set their preferred shortcut. Wraps Carbon `RegisterEventHotKey` APIs (deprecated but Apple has not provided a replacement; author states Apple will ship new APIs before removing Carbon ones). Sandbox and Mac App Store compatible. macOS 10.15+. **HIGH confidence** |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 26.x | IDE, build system, signing | Required for macOS development. Includes Swift 6.2, macOS Tahoe 26 SDK. Can target macOS 14+ while building with latest SDK. |
| Swift Package Manager | Dependency management | Built into Xcode. Only external dependency is KeyboardShortcuts. No CocoaPods or Carthage needed. SPM is the standard for new Swift projects in 2025+. |
| `xcrun notarytool` | Notarization for distribution | Required for distributing outside the Mac App Store. Submits the signed app to Apple for security checks. |
| `xcrun stapler` | Attach notarization ticket | Staples the notarization ticket to the DMG/ZIP so Gatekeeper can verify offline. |

## Project Setup

This is a native Xcode project (not an SPM-only project). Create via Xcode:

```
Xcode > New Project > macOS > App
- Interface: SwiftUI
- Language: Swift
- Minimum Deployment: macOS 14.0
```

Add KeyboardShortcuts via SPM:
```
File > Add Package Dependencies
URL: https://github.com/sindresorhus/KeyboardShortcuts
Version: 2.4.0 (up to next major)
```

## Key Configuration

### Entitlements (CRITICAL)

This app **must NOT use App Sandbox**. Reason: sandboxed apps cannot get Accessibility permissions, and CGEventTap with `.defaultTap` (active filter mode, required to suppress/modify events) requires the Accessibility permission, not just Input Monitoring.

Required entitlements for distribution:
```xml
<!-- com.apple.security.app-sandbox = FALSE (do not include sandbox entitlement) -->

<!-- Hardened Runtime is required for notarization -->
<!-- No special entitlements needed beyond default hardened runtime -->
```

### Info.plist

```xml
<!-- Required: explain why Accessibility permission is needed -->
<key>NSAccessibilityUsageDescription</key>
<string>Scroll My Mac needs Accessibility access to intercept mouse clicks and convert them to scroll events system-wide.</string>
```

### Minimum Deployment Target: macOS 14.0 (Sonoma)

Rationale:
- CADisplayLink is available starting macOS 14 (replaces CVDisplayLink)
- SwiftUI is mature and stable on macOS 14+ for simple window apps
- macOS 14 Sonoma is two versions behind current (macOS 26 Tahoe), providing reasonable coverage
- macOS 13 and earlier are approaching end-of-life for security updates

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| CGEventTap (`.defaultTap`) | `NSEvent.addGlobalMonitorForEvents` | NSEvent global monitors are **listen-only** -- they cannot suppress, modify, or block events. We must suppress left-click during scroll mode and replace it with scroll events. CGEventTap with `.defaultTap` is the only option. |
| Swift/SwiftUI native | Electron / web tech | Massive overhead for a simple utility. Cannot access CGEventTap or Accessibility APIs without native bridges. Not appropriate for a system-level accessibility tool. |
| KeyboardShortcuts library | Raw Carbon `RegisterEventHotKey` | KeyboardShortcuts provides a SwiftUI recorder view, persistence, and conflict detection out of the box. Wrapping Carbon APIs manually is error-prone and provides no UI. |
| KeyboardShortcuts library | HotKey library (soffes/HotKey) | HotKey only supports hard-coded shortcuts, no UI for user configuration. KeyboardShortcuts provides both the registration and a SwiftUI `Recorder` view. |
| KeyboardShortcuts library | CGEventTap for hotkeys | Using a second CGEventTap for hotkey detection is possible but more complex. KeyboardShortcuts handles edge cases (key repeat, modifier-only shortcuts, conflicts) that we would need to re-implement. |
| CADisplayLink | CVDisplayLink | CVDisplayLink is the legacy C-based API. CADisplayLink is available on macOS 14+ and provides the same display-synchronized callback with a cleaner Swift API. Since our minimum target is macOS 14, use CADisplayLink. |
| CADisplayLink | `Timer` / `DispatchSourceTimer` | Timers are not synchronized to the display refresh rate. Inertia animation will appear choppy or waste energy by firing at the wrong cadence. CADisplayLink fires at exactly the right moment for each frame. |
| Unsandboxed + Notarized | Mac App Store (sandboxed) | App Sandbox prevents Accessibility permission grants. CGEventTap with `.defaultTap` requires Accessibility, not just Input Monitoring. Distribute via website with Developer ID signing + notarization. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| App Sandbox entitlement | Sandboxed apps **cannot** receive Accessibility permissions. The system will never show the permission prompt, and the app cannot be manually added in System Settings > Privacy & Security > Accessibility. This is a hard blocker. | Distribute unsandboxed with Hardened Runtime + notarization via Developer ID. |
| `NSEvent.addGlobalMonitorForEvents` | Listen-only. Cannot suppress the original mouse-down event, so the click will pass through to the target app AND trigger scrolling simultaneously. Unusable for our use case. | CGEventTap with `.defaultTap` option. |
| Objective-C | No technical reason to use it for a new project in 2025. Swift has full access to all required C/CoreGraphics APIs. ObjC adds complexity without benefit. | Swift 6.2. |
| Storyboards / XIB | Legacy UI approach. SwiftUI is simpler for a basic preferences window with toggle, hotkey recorder, and minimal settings. | SwiftUI with `App` protocol. |
| `CVDisplayLink` | Legacy C-based API with manual memory management and callback bridging. Harder to use correctly from Swift. | CADisplayLink (macOS 14+). |
| CocoaPods / Carthage | Unnecessary complexity. Only one external dependency (KeyboardShortcuts), which supports SPM. CocoaPods adds a workspace wrapper and Ruby dependency. | Swift Package Manager. |
| Menu bar app (`MenuBarExtra`) | User explicitly prefers a simple window app over a menu bar app. MenuBarExtra also has known SwiftUI issues with Settings windows on macOS Sequoia 15. | Standard `WindowGroup` scene. |

## Stack Patterns

**For the event tap callback:**
- CGEventTap callbacks are C function pointers -- they cannot capture context. Pass `self` (the event manager object) via the `userInfo` parameter as an `UnsafeMutableRawPointer`.
- The callback runs on the thread of the RunLoop it is added to. Add the tap's `CFMachPort` to the main RunLoop for simplicity, since all event processing feeds back into UI state.
- Return `nil` from the callback to suppress an event. Return the (possibly modified) event to let it pass through.

**For Swift 6.2 concurrency:**
- With "approachable concurrency" (default `@MainActor` isolation), most app code runs on the main actor by default. This simplifies the model since CGEventTap callbacks on the main RunLoop and SwiftUI views are all main-thread.
- Mark any background work (if needed) with `@concurrent` or `nonisolated`.
- The CGEventTap callback is a C function pointer, not an async Swift function. It does not participate in Swift concurrency directly. Access shared state through the `userInfo` pointer.

**For checking Accessibility permissions:**
- Call `AXIsProcessTrusted()` at app launch to check if the app has Accessibility permission.
- Call `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeRetainedValue(): true])` to prompt the user if not trusted.
- Poll `AXIsProcessTrusted()` periodically (e.g., every 1-2 seconds) after prompting, since the user must toggle the permission in System Settings and macOS does not send a callback when permission is granted.

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|-----------------|-------|
| Swift 6.2 | Xcode 26+ | Xcode 26 is current stable. Swift 6.2 is included. |
| SwiftUI (macOS 14+ APIs) | macOS 14.0 Sonoma through macOS 26 Tahoe | `WindowGroup`, `Settings`, `@AppStorage` all available on macOS 14+. |
| CGEventTap | macOS 10.4+ | Stable API, unchanged for years. Works on all modern macOS. |
| CADisplayLink | macOS 14.0+ | New to macOS in Sonoma. Not available on macOS 13 or earlier. |
| KeyboardShortcuts 2.4.0 | macOS 10.15+ | Requires macOS Catalina minimum. Well within our macOS 14 target. |
| Hardened Runtime | macOS 10.14+ | Required for notarization. No issues with our target. |
| AXIsProcessTrusted | macOS 10.9+ | Long-stable API. |

## Sources

- [Apple Developer: CGEvent.tapCreate](https://developer.apple.com/documentation/coregraphics/cgevent/1454426-tapcreate) -- CGEventTap function signature and parameters (HIGH confidence)
- [Apple Developer: CGAssociateMouseAndMouseCursorPosition](https://developer.apple.com/documentation/coregraphics/cgassociatemouseandmousecursorposition(_:)) -- cursor locking API (HIGH confidence)
- [Apple Developer: CGWarpMouseCursorPosition](https://developer.apple.com/documentation/coregraphics/1456387-cgwarpmousecursorposition) -- cursor repositioning (HIGH confidence)
- [Apple Developer: NSCursor.hide()](https://developer.apple.com/documentation/appkit/nscursor/hide()) -- cursor visibility (HIGH confidence)
- [Apple Developer: CADisplayLink](https://developer.apple.com/documentation/quartzcore/cadisplaylink) -- display-synchronized timer (HIGH confidence)
- [Apple Developer: Accessibility permission](https://developer.apple.com/documentation/accessibility) -- TCC framework (HIGH confidence)
- [Apple Developer Forums: Accessibility permission in sandboxed app](https://developer.apple.com/forums/thread/707680) -- confirms sandboxed apps cannot get Accessibility permission (HIGH confidence)
- [KeyboardShortcuts GitHub](https://github.com/sindresorhus/KeyboardShortcuts) -- v2.4.0, macOS 10.15+, SwiftUI support confirmed (HIGH confidence)
- [emreyolcu/drag-scroll](https://github.com/emreyolcu/drag-scroll) -- reference implementation of drag-to-scroll in C using CGEventTap, macOS 10.9-14.0 (MEDIUM confidence, useful as architecture reference)
- [Drag to Scroll by sargunv](https://code.sargunv.dev/drag-to-scroll/) -- another reference implementation, middle-click based (MEDIUM confidence)
- [Apple Developer: Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) -- notarization requirements (HIGH confidence)
- [Apple Developer: Signing with Developer ID](https://developer.apple.com/developer-id/) -- distribution outside App Store (HIGH confidence)
- [jano.dev: Accessibility Permission in macOS](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html) -- AXIsProcessTrusted usage patterns (MEDIUM confidence)
- [Swift 6.2 Released](https://www.swift.org/blog/swift-6.2-released/) -- approachable concurrency, default MainActor (HIGH confidence)
- [Avanderlee: Approachable Concurrency in Swift 6.2](https://www.avanderlee.com/concurrency/approachable-concurrency-in-swift-6-2-a-clear-guide/) -- practical guide to Swift 6.2 concurrency model (MEDIUM confidence)
- [SwiftUI for Mac 2025 - TrozWare](https://troz.net/post/2025/swiftui-mac-2025/) -- SwiftUI maturity assessment on macOS (MEDIUM confidence)
- [Apple Developer: macOS Tahoe 26 Release Notes](https://developer.apple.com/documentation/macos-release-notes/macos-26-release-notes) -- current macOS version (HIGH confidence)
- [Apple Developer: Xcode 26 Release Notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-26-release-notes) -- current Xcode, Swift 6.2 (HIGH confidence)

---
*Stack research for: macOS accessibility app (system-wide click-and-drag scrolling)*
*Researched: 2026-02-14*
