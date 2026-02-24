# Phase 1: Permissions & App Shell - Research

**Researched:** 2026-02-14
**Domain:** macOS Accessibility permissions, SwiftUI app shell, window lifecycle
**Confidence:** HIGH

## Summary

Phase 1 establishes the Xcode project, implements the Accessibility permission detection and onboarding flow, and creates the settings window shell. The core technical challenges are: (1) creating an unsandboxed SwiftUI app that stays running when the window is closed, (2) detecting and polling for Accessibility permission state, (3) guiding the user to System Settings and handling the post-grant flow, and (4) implementing the safety timeout mechanism.

The key architectural insight is that `AXIsProcessTrusted()` can detect permission grants without requiring an app restart -- polling every 1 second and then creating the event tap on grant is a proven pattern (used by UnnaturalScrollWheels, drag-scroll, and others). The window lifecycle requires `WindowGroup` with an `NSApplicationDelegateAdaptor` to prevent quit-on-close and handle dock icon reopening.

**Primary recommendation:** Use `WindowGroup` + `NSApplicationDelegateAdaptor` for the app shell. Poll `AXIsProcessTrusted()` every 1 second during onboarding. Use `NSApp.hide(nil)` on window close instead of actual close to preserve window state. Implement safety timeout as a simple `Timer` that monitors mouse position.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### App window & identity
- Dock app only -- no menu bar icon
- Single window that serves as the settings interface
- Native macOS visual style -- standard window chrome, system fonts, default SwiftUI controls
- Closing the settings window does NOT quit the app -- app continues running headlessly with Dock icon
- Reopening the window from the Dock shows settings again

#### Toggle & status display
- On/off toggle for scroll mode included as a regular settings row (not prominently placed)
- Toggle is part of the settings list alongside other options, no special treatment
- Permission status shown only during initial setup flow, not persistently in settings
- Phase 1 settings content is Claude's discretion -- at minimum: toggle and whatever makes sense for the shell

#### Safety mode
- Safety timeout: if no mouse movement for 10 seconds while scroll mode is active, scroll mode auto-deactivates
- Brief notification shown on safety deactivation (e.g., "Scroll mode deactivated (safety timeout)")
- Safety mode is on by default
- Safety mode can be toggled off in settings once user trusts the tool
- This is in addition to the hotkey toggle (same key on/off) -- belt and suspenders

### Claude's Discretion
- Exact settings window layout and content for Phase 1
- Permission flow UI details (tone, steps, visual treatment)
- Notification style for safety timeout
- How to handle app relaunch after permission grant

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

## Standard Stack

### Core

| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| Swift | 6.2 (Xcode 26) | Application language | First-class Apple platform language with approachable concurrency. **HIGH confidence** |
| SwiftUI | macOS 14+ | Settings window UI | `WindowGroup` + `App` protocol for simple single-window app. Mature on macOS 14+. **HIGH confidence** |
| ApplicationServices | System framework | `AXIsProcessTrusted()` / `AXIsProcessTrustedWithOptions()` | Only API for checking Accessibility permission state. **HIGH confidence** |
| AppKit (NSApplication) | System framework | Window lifecycle, dock icon handling | `NSApplicationDelegateAdaptor` for `applicationShouldTerminateAfterLastWindowClosed`, `applicationShouldHandleReopen`. **HIGH confidence** |
| Foundation (Timer) | System framework | Safety timeout polling, permission polling | Standard timer for periodic checks. **HIGH confidence** |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| UserDefaults / @AppStorage | System | Persist safety mode toggle, first-launch state | Store simple boolean/string settings. **HIGH confidence** |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `WindowGroup` | `Window` (single instance) | `Window` quits app when closed -- incompatible with user requirement that closing window keeps app running. Must use `WindowGroup`. |
| `NSApp.hide(nil)` on close | Actually closing the window | Hiding preserves window state and position. True close requires recreating window state. Hide is simpler and matches user expectation. |
| Polling `AXIsProcessTrusted()` | `DistributedNotificationCenter` | Notification is unreliable -- not sent when app is removed from accessibility list. Polling every 1s is proven pattern (UnnaturalScrollWheels). |
| In-app toast for safety notification | `UNUserNotificationCenter` | System notifications require separate permission and are heavyweight. A simple overlay/toast within the app is sufficient for this case. |

**No external dependencies needed for Phase 1.** All functionality uses system frameworks.

## Architecture Patterns

### Recommended Project Structure (Phase 1)

```
ScrollMyMac/
+-- ScrollMyMacApp.swift          # @main App with WindowGroup, NSApplicationDelegateAdaptor
+-- App/
|   +-- AppDelegate.swift         # NSApplicationDelegate for window lifecycle
|   +-- AppState.swift            # @Observable: permission state, scroll mode toggle, safety mode
+-- Features/
|   +-- Settings/
|   |   +-- SettingsView.swift    # Main settings window content
|   |   +-- PermissionSetupView.swift  # First-launch permission guidance
+-- Services/
|   +-- PermissionManager.swift   # AXIsProcessTrusted polling, System Settings deep link
|   +-- SafetyTimeoutManager.swift # 10-second no-movement auto-deactivation
+-- Resources/
    +-- Assets.xcassets            # App icon
    +-- Info.plist                 # NSAccessibilityUsageDescription
```

### Pattern 1: WindowGroup with Close Prevention

**What:** Use `WindowGroup` for the main window, but intercept close to hide instead of terminate.
**When to use:** Always -- this is the core app shell pattern for "close doesn't quit."
**Why:** User requirement: closing the settings window keeps the app running with Dock icon. Clicking the Dock icon reopens settings.

```swift
@main
struct ScrollMyMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            SettingsView()
        }
        .commands {
            // Remove "New Window" menu item -- single window app
            CommandGroup(replacing: .newItem) { }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false  // Keep app running when window closes
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApp.windows.first {
            window.delegate = self
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.hide(nil)  // Hide instead of close -- preserves window state
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Reopen window when dock icon is clicked and no windows visible
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }
}
```

**Source:** [Apple: applicationShouldTerminateAfterLastWindowClosed](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/1428381-applicationshouldterminateafterl), [Blue Lemon Bits: Restoring macOS window](https://bluelemonbits.com/2022/12/29/restoring-macos-window-after-close-swiftui-windowsgroup/)

### Pattern 2: Accessibility Permission Polling

**What:** Check `AXIsProcessTrusted()` on launch. If not granted, show setup flow and poll every 1 second until granted. No restart needed.
**When to use:** Always on first launch or when permission is not yet granted.
**Why:** Proven pattern from UnnaturalScrollWheels and drag-scroll. macOS does NOT require app restart for accessibility permission to take effect for `AXIsProcessTrusted()` -- the function returns the live state.

```swift
import ApplicationServices

@Observable
class PermissionManager {
    var isAccessibilityGranted: Bool = false
    private var pollTimer: Timer?

    init() {
        checkPermission()
    }

    func checkPermission() {
        isAccessibilityGranted = AXIsProcessTrusted()
    }

    func requestPermission() {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        AXIsProcessTrustedWithOptions(options)
    }

    func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkPermission()
            if self?.isAccessibilityGranted == true {
                self?.stopPolling()
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

**Source:** [jano.dev: Accessibility Permission in macOS](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html), [UnnaturalScrollWheels Permission Management](https://deepwiki.com/ther0n/UnnaturalScrollWheels/6-permission-management), [Apple: AXIsProcessTrustedWithOptions](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions)

### Pattern 3: Safety Timeout Manager

**What:** Monitor mouse position every 0.5 seconds. If no movement for 10 seconds while scroll mode is active, auto-deactivate and show brief notification.
**When to use:** When safety mode is enabled (default: on) and scroll mode is active.
**Why:** User-requested safety mechanism -- belt and suspenders alongside the hotkey toggle. Prevents "stuck in scroll mode" scenario.

```swift
@Observable
class SafetyTimeoutManager {
    var isEnabled: Bool = true  // Default on, persisted via @AppStorage
    private var checkTimer: Timer?
    private var lastMousePosition: CGPoint = .zero
    private var lastMovementTime: Date = Date()
    private let timeoutInterval: TimeInterval = 10.0

    func startMonitoring() {
        lastMousePosition = NSEvent.mouseLocation
        lastMovementTime = Date()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkMouseMovement()
        }
    }

    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    private func checkMouseMovement() {
        let currentPosition = NSEvent.mouseLocation
        if currentPosition != lastMousePosition {
            lastMousePosition = currentPosition
            lastMovementTime = Date()
        } else if Date().timeIntervalSince(lastMovementTime) >= timeoutInterval {
            // Trigger safety deactivation
            onSafetyTimeout?()
        }
    }

    var onSafetyTimeout: (() -> Void)?
}
```

### Pattern 4: Conditional View -- Permission Setup vs Settings

**What:** Show a permission setup flow on first launch (or when permission is missing), then show the regular settings view once granted.
**When to use:** This is the main content switching logic for SettingsView.
**Why:** User requirement: permission status shown only during initial setup flow, not persistently in settings.

```swift
struct SettingsView: View {
    @State private var permissionManager = PermissionManager()

    var body: some View {
        if permissionManager.isAccessibilityGranted {
            MainSettingsView()
        } else {
            PermissionSetupView(permissionManager: permissionManager)
        }
    }
}
```

### Anti-Patterns to Avoid

- **Using `Window` scene instead of `WindowGroup`:** `Window` quits the app when the window is closed. This directly conflicts with the user requirement that closing keeps the app running.
- **Using `AXIsProcessTrustedWithOptions` with prompt=true on every launch:** Only prompt once during onboarding. On subsequent launches, just check `AXIsProcessTrusted()` silently.
- **Closing the window instead of hiding:** If the window is actually closed (not hidden), restoring its state and position requires more complex logic. `NSApp.hide(nil)` is simpler and preserves everything.
- **Blocking on permission grant:** Never block the main thread waiting for permission. Use async polling.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Accessibility permission check | Custom TCC database queries | `AXIsProcessTrusted()` / `AXIsProcessTrustedWithOptions()` | These are the official, stable APIs. TCC database format is private and changes between macOS versions. |
| Deep link to System Settings | Hardcoded file paths to preference panes | `x-apple.systempreferences:` URL scheme | URL scheme is version-stable; file paths change between macOS versions. |
| User defaults persistence | Custom file-based settings storage | `@AppStorage` / `UserDefaults` | Standard, automatic, handles synchronization. |
| Window lifecycle management | Custom window tracking code | `NSApplicationDelegate` methods | `applicationShouldTerminateAfterLastWindowClosed`, `applicationShouldHandleReopen` are purpose-built for this. |

**Key insight:** Phase 1 uses exclusively system frameworks. No external dependencies. Every component has a well-documented Apple API.

## Common Pitfalls

### Pitfall 1: System Settings URL Scheme Variation

**What goes wrong:** The URL scheme for opening Accessibility settings in System Settings has changed across macOS versions. Code that works on one version fails silently on another.
**Why it happens:** Apple has used different URL formats: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` (older) vs `x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility` (newer).
**How to avoid:** Try the newer URL scheme first, fall back to the older one. Alternatively, use `AXIsProcessTrustedWithOptions` with prompt=true which handles navigation automatically.
**Warning signs:** "Open System Settings" button does nothing on certain macOS versions.

### Pitfall 2: WindowGroup Creates Multiple Windows

**What goes wrong:** User presses Cmd+N and creates a second settings window, leading to duplicate state or confusion.
**Why it happens:** `WindowGroup` allows multiple instances by default. The "New Window" menu item is active.
**How to avoid:** Remove the `newItem` command group: `.commands { CommandGroup(replacing: .newItem) { } }`. This removes File > New Window.
**Warning signs:** Multiple settings windows open simultaneously.

### Pitfall 3: applicationShouldHandleReopen Not Called

**What goes wrong:** Clicking the Dock icon after closing the window doesn't reopen it.
**Why it happens:** Historically a bug in SwiftUI (fixed in Xcode 14 beta 3), but can still occur if `NSApplicationDelegateAdaptor` is misconfigured or if using `Window` scene instead of `WindowGroup`.
**How to avoid:** Use `WindowGroup` + `@NSApplicationDelegateAdaptor`. Also implement `applicationWillBecomeActive` as a fallback to check for visible windows.
**Warning signs:** Dock icon click does nothing; app appears to be running but has no visible window.

### Pitfall 4: Permission Polling Drains Battery

**What goes wrong:** Polling `AXIsProcessTrusted()` continues indefinitely, even after permission is granted or when the user isn't actively in the setup flow.
**Why it happens:** Forgot to stop the timer after permission is granted.
**How to avoid:** Always `stopPolling()` when permission is granted. Only start polling when the permission setup view is visible. Check timer lifecycle in view appear/disappear.
**Warning signs:** High CPU usage in Activity Monitor for a "simple settings app."

### Pitfall 5: Safety Timeout Fires During Normal Use

**What goes wrong:** Safety timeout deactivates scroll mode while the user is actively scrolling, because the mouse position didn't change (e.g., user is scrolling at the edge of a document).
**Why it happens:** Checking `NSEvent.mouseLocation` doesn't detect mouse button state or scroll activity -- only cursor position.
**How to avoid:** Reset the safety timer on ANY mouse event (movement, click, drag), not just position changes. In Phase 2, the event tap will provide this data. For Phase 1, the timer infrastructure is sufficient since the toggle isn't wired up yet.
**Warning signs:** Safety timeout triggers while user is actively using the app.

## Code Examples

### Complete App Entry Point (Phase 1)

```swift
import SwiftUI

@main
struct ScrollMyMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            SettingsView()
                .environment(appState)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
```

### AppState (Phase 1 Subset)

```swift
import SwiftUI

@Observable
class AppState {
    // Scroll mode (toggle exists in Phase 1, wired up in Phase 2)
    var isScrollModeActive: Bool = false

    // Safety mode
    var isSafetyModeEnabled: Bool = true  // Default on

    // Permission state
    var isAccessibilityGranted: Bool = false
    var hasCompletedOnboarding: Bool = false
}
```

### Settings View Layout (Recommended)

```swift
struct MainSettingsView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        Form {
            Section("Scroll Mode") {
                Toggle("Enable Scroll Mode", isOn: $appState.isScrollModeActive)
                    .disabled(true)  // Wired up in Phase 2
            }

            Section("Safety") {
                Toggle("Safety timeout (auto-deactivate after 10s of no movement)",
                       isOn: $appState.isSafetyModeEnabled)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 300)
    }
}
```

### Permission Setup View (Recommended)

```swift
struct PermissionSetupView: View {
    var permissionManager: PermissionManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Accessibility Permission Required")
                .font(.title2)

            Text("Scroll My Mac needs Accessibility access to intercept mouse events and convert them to scroll events system-wide.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Label("Open System Settings", systemImage: "1.circle")
                Label("Go to Privacy & Security > Accessibility", systemImage: "2.circle")
                Label("Enable Scroll My Mac", systemImage: "3.circle")
            }
            .padding()

            Button("Open System Settings") {
                permissionManager.openAccessibilitySettings()
                permissionManager.startPolling()
            }
            .buttonStyle(.borderedProminent)

            Text("The app will detect permission automatically -- no restart needed.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(minWidth: 400, minHeight: 350)
    }
}
```

### Info.plist Configuration

```xml
<key>NSAccessibilityUsageDescription</key>
<string>Scroll My Mac needs Accessibility access to intercept mouse clicks and convert them to scroll events system-wide.</string>
```

### Entitlements -- No Sandbox

The app must NOT be sandboxed. The Xcode project should:
- Have App Sandbox turned OFF in Signing & Capabilities
- Have Hardened Runtime enabled (for future notarization)
- No special entitlements needed for Phase 1

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `CVDisplayLink` for timers | `CADisplayLink` (macOS 14+) | macOS 14 Sonoma | Not relevant to Phase 1, but establishes minimum target |
| Storyboards/XIB for macOS UI | SwiftUI `App` protocol + scenes | Swift 5.3 / macOS 11 | SwiftUI is the standard for new macOS apps |
| `com.apple.security.app-sandbox` | Unsandboxed + Hardened Runtime | N/A | Accessibility apps cannot use sandbox |
| `RegisterEventHotKey` (Carbon) | `KeyboardShortcuts` library | 2020+ | Not needed in Phase 1, but relevant for Phase 5 |

**Deprecated/outdated:**
- `NSApp.sendAction(#selector(AppDelegate.showSettings), to: nil, from: nil)` for opening Settings scene -- this was a workaround; direct window management is more reliable for our use case.

## Open Questions

1. **System Settings URL scheme stability**
   - What we know: Two URL formats exist (`com.apple.preference.security` vs `com.apple.settings.PrivacySecurity.extension`). Both may work depending on macOS version.
   - What's unclear: Which format works on macOS 14-26. The URL schemes are not officially documented.
   - Recommendation: Use `AXIsProcessTrustedWithOptions` with prompt=true for the initial prompt (it navigates automatically). Provide a manual "Open System Settings" button using the URL scheme as fallback. Test on target macOS versions during implementation.

2. **Safety timeout notification style**
   - What we know: User wants a brief notification on safety deactivation. Options include: in-app toast overlay, system `UNUserNotificationCenter` notification, or `NSAlert`.
   - What's unclear: Whether the notification should be visible when the settings window is hidden (headless mode).
   - Recommendation: Use `UNUserNotificationCenter` local notification -- it works even when the app window is hidden, appears briefly in Notification Center, and requires no additional UI infrastructure. If notification permission is declined, fall back to no notification (the deactivation itself is the feedback). Alternatively, a simple floating `NSPanel` overlay would work without needing notification permission.

3. **`applicationShouldHandleReopen` reliability**
   - What we know: Was broken in early SwiftUI lifecycle but fixed in Xcode 14 beta 3 (2022).
   - What's unclear: Whether edge cases remain on macOS 14+.
   - Recommendation: Implement both `applicationShouldHandleReopen` and `applicationWillBecomeActive` as belt-and-suspenders. Test on target macOS versions.

## Sources

### Primary (HIGH confidence)
- [Apple: AXIsProcessTrustedWithOptions](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions) -- Official API docs for permission checking
- [Apple: applicationShouldTerminateAfterLastWindowClosed](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/1428381-applicationshouldterminateafterl) -- Window lifecycle delegate method
- [Apple: NSApplicationDelegate](https://developer.apple.com/documentation/appkit/nsapplicationdelegate) -- applicationShouldHandleReopen and related methods
- [Apple: WindowGroup](https://developer.apple.com/documentation/swiftui/windowgroup) -- SwiftUI scene type docs

### Secondary (MEDIUM confidence)
- [jano.dev: Accessibility Permission in macOS (2025)](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html) -- Practical permission flow patterns
- [Gannon Lawlor: Requesting macOS Privacy Permissions](https://gannonlawlor.com/posts/macos_privacy_permissions/) -- Code signing and permission interaction
- [UnnaturalScrollWheels: Permission Management](https://deepwiki.com/ther0n/UnnaturalScrollWheels/6-permission-management) -- 1-second polling pattern, no-restart-required confirmation
- [Blue Lemon Bits: Restoring macOS Window](https://bluelemonbits.com/2022/12/29/restoring-macos-window-after-close-swiftui-windowsgroup/) -- Hide-instead-of-close pattern
- [Nil Coalescing: Scene Types in SwiftUI Mac App](https://nilcoalescing.com/blog/ScenesTypesInASwiftUIMacApp/) -- Window vs WindowGroup behavior
- [drag-scroll (emreyolcu)](https://github.com/emreyolcu/drag-scroll) -- Reference implementation, no-restart permission grant confirmation
- [rampatra: Open macOS System Settings Programmatically](https://blog.rampatra.com/how-to-open-macos-system-settings-or-a-specific-pane-programmatically-with-swift) -- URL scheme examples
- [Apple System Preferences URL Schemes (GitHub Gist)](https://gist.github.com/rmcdongit/f66ff91e0dad78d4d6346a75ded4b751) -- Comprehensive URL scheme list

### Tertiary (LOW confidence)
- [Gertrude: Request Accessibility Control](https://gertrude.app/blog/macos-request-accessibility-control) -- General permission flow overview
- [Apple Developer Forums: SwiftUI apps don't relaunch windows](https://developer.apple.com/forums/thread/706772) -- Historical bug context

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All system frameworks, well-documented APIs
- Architecture: HIGH -- Proven patterns from multiple reference implementations (UnnaturalScrollWheels, drag-scroll)
- Pitfalls: HIGH -- Well-documented in Apple forums and community projects
- Window lifecycle: MEDIUM -- Some edge cases with `applicationShouldHandleReopen` on different macOS versions
- Safety timeout: HIGH -- Simple Timer-based pattern, no exotic APIs

**Research date:** 2026-02-14
**Valid until:** 2026-03-14 (stable domain, system APIs rarely change)
