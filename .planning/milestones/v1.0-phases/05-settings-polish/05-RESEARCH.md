# Phase 5: Settings & Polish - Research

**Researched:** 2026-02-16
**Domain:** macOS SwiftUI settings UI, hotkey customization, launch-at-login
**Confidence:** HIGH

## Summary

This phase consolidates all scattered settings into one unified view, adds hotkey customization with a key recorder UI, and implements launch-at-login. The codebase already uses `UserDefaults` for persistence (`isSafetyModeEnabled`, `isClickThroughEnabled`, `hasCompletedOnboarding`) and has a `HotkeyManager` with `keyCode` and `requiredModifiers` properties ready for customization. The existing `MainSettingsView` already has a Form-based layout that can be extended.

For launch-at-login, Apple's `SMAppService.mainApp` (macOS 13+, `ServiceManagement` framework) is the standard approach -- two lines to register/unregister, and status should be read from the API (not stored locally) since users can change it in System Settings. The app is non-sandboxed, which simplifies this.

For the key recorder, a custom `NSViewRepresentable` using `NSEvent.addLocalMonitorForEvents(matching:)` for both `.keyDown` and `.flagsChanged` is the standard no-dependency approach. Key-to-display-string conversion for the current keyboard layout uses `UCKeyTranslate` via `TISGetInputSourceProperty`/`TISCopyCurrentKeyboardInputSource`, or a simpler static mapping for the supported key set (function keys + modifier combos).

**Primary recommendation:** Build all three features (unified settings, key recorder, launch-at-login) using only Apple frameworks. No third-party dependencies needed for this scope.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Hotkey customization
- Key recorder UI -- click a field, press desired key/combo, it captures it
- Broad key support: function keys alone OR any key with at least one modifier (Cmd, Ctrl, Option, Shift)
- No conflict detection -- allow any combo silently, user's responsibility
- User can clear the hotkey entirely (removes hotkey toggle, scroll mode only controllable via UI)
- Default hotkey: F6 (matches current hardcoded value)

#### Launch at login
- Standard macOS launch-at-login toggle in settings
- On login launch, app starts with scroll mode inactive -- user presses hotkey to activate
- Silent background launch -- no window shown on login
- Dock icon only (no menu bar icon) -- user clicks dock icon to reopen window

#### Persistence & defaults
- All setting changes take effect immediately (no save button)
- Settings stored in UserDefaults (already used for axis lock)
- "Reset to defaults" button available in settings
- Default values: F6 hotkey, launch at login off, existing defaults for other settings

#### Settings consolidation
- Consolidate ALL settings into one unified settings view: hotkey, launch at login, axis lock, safety timeout, and any other toggles
- Current scattered settings move into this unified view

### Claude's Discretion
- Settings view layout and section organization
- Key recorder visual design and interaction feedback
- Reset confirmation dialog (if any)
- How to handle edge cases in key recording (modifier-only combos, escape to cancel, etc.)

### Deferred Ideas (OUT OF SCOPE)
- On-screen keyboard click detection -- pass through all clicks when on-screen keyboard is active (new capability, possibly extends Click Safety phase)

</user_constraints>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ServiceManagement (`SMAppService`) | macOS 13+ | Launch at login register/unregister | Apple's official replacement for `SMLoginItemSetEnabled`; no helper app needed |
| Carbon.HIToolbox | System | Virtual key code constants (`kVK_*`) | Already imported in HotkeyManager; required for key code matching |
| CoreServices (`UCKeyTranslate`) | System | Convert keyCode to display character for current keyboard layout | Apple's API for layout-aware key name resolution |
| AppKit (`NSEvent`) | System | Local event monitoring for key recorder | `addLocalMonitorForEvents` captures keyDown + flagsChanged within the app |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SwiftUI Form | macOS 13+ | Settings layout | Already used in `MainSettingsView` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom key recorder | `sindresorhus/KeyboardShortcuts` | Full-featured with conflict detection, but adds a dependency for something achievable in ~100 lines. Decision says no conflict detection, so custom is simpler. |
| `UCKeyTranslate` | `Clipy/Sauce` | Nice keyboard layout handling, but overkill -- we only need to display a key name for a small set of keys |
| `SMAppService` | `sindresorhus/LaunchAtLogin-Legacy` | Adds backward compat for macOS 12, but that package was archived Sep 2025; `SMAppService` is 2 lines of code |

## Architecture Patterns

### Current Project Structure
```
ScrollMyMac/
├── App/
│   ├── AppDelegate.swift          # NSApplicationDelegate, window management
│   └── AppState.swift             # @Observable, central state + UserDefaults
├── Features/Settings/
│   ├── SettingsView.swift         # Main settings UI (Form-based)
│   └── PermissionSetupView.swift  # Onboarding permission flow
├── Services/
│   ├── HotkeyManager.swift        # CGEventTap for global hotkey (keyUp)
│   ├── ScrollEngine.swift         # Mouse-to-scroll event conversion
│   ├── SafetyTimeoutManager.swift # Idle timeout for scroll mode
│   ├── OverlayManager.swift       # Visual overlay during scroll
│   ├── VelocityTracker.swift      # Drag velocity for inertia
│   ├── InertiaAnimator.swift      # Momentum scrolling
│   └── PermissionManager.swift    # Accessibility permission polling
├── Views/
│   └── IndicatorDotView.swift
├── ScrollMyMacApp.swift           # @main App entry point
└── Resources/
    └── Info.plist
```

### Pattern 1: Unified Settings via Extended AppState

**What:** All settings live as `@Observable` properties on `AppState` with UserDefaults persistence in `didSet`.
**When to use:** This is the existing pattern. New settings (hotkey keyCode, hotkey modifiers, launch-at-login) follow the same approach.

Current pattern in `AppState.swift`:
```swift
var isSafetyModeEnabled: Bool {
    didSet { UserDefaults.standard.set(isSafetyModeEnabled, forKey: "safetyModeEnabled") }
}

// Init reads defaults:
init() {
    self.isSafetyModeEnabled = UserDefaults.standard.object(forKey: "safetyModeEnabled") as? Bool ?? true
}
```

New hotkey settings follow the same pattern:
```swift
var hotkeyKeyCode: Int {
    didSet {
        UserDefaults.standard.set(hotkeyKeyCode, forKey: "hotkeyKeyCode")
        applyHotkeySettings()
    }
}

var hotkeyModifiers: UInt64 {
    didSet {
        UserDefaults.standard.set(hotkeyModifiers, forKey: "hotkeyModifiers")
        applyHotkeySettings()
    }
}

private func applyHotkeySettings() {
    hotkeyManager.keyCode = Int64(hotkeyKeyCode)
    hotkeyManager.requiredModifiers = CGEventFlags(rawValue: hotkeyModifiers)
}
```

### Pattern 2: Key Recorder via NSEvent Local Monitor

**What:** A SwiftUI view that enters "recording mode" on click, captures the next key event via `NSEvent.addLocalMonitorForEvents`, and exits recording mode.
**When to use:** For the hotkey customization field.

The key recorder needs to monitor two event types:
- `.keyDown` -- for regular keys (with or without modifiers)
- `.flagsChanged` -- NOT needed per user decisions (modifier-only combos not supported; requirement is function keys alone OR any key with at least one modifier)

Recommended approach -- use `NSEvent.addLocalMonitorForEvents(matching: .keyDown)`:

```swift
// Enter recording mode
keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
    guard let self else { return event }

    let keyCode = event.keyCode
    let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

    // Escape cancels recording
    if keyCode == UInt16(kVK_Escape) && modifiers.isEmpty {
        self.stopRecording()
        return nil  // consume
    }

    // Validate: function key alone OR any key with at least one modifier
    let isFunctionKey = Self.functionKeyCodes.contains(Int(keyCode))
    let hasModifier = !modifiers.subtracting(.function).isEmpty  // .function flag is set for F-keys

    if isFunctionKey || hasModifier {
        self.capturedKeyCode = Int(keyCode)
        self.capturedModifiers = modifiers
        self.stopRecording()
        return nil  // consume
    }

    return nil  // consume but ignore invalid combos
}
```

### Pattern 3: Launch at Login via SMAppService

**What:** Read status from `SMAppService.mainApp.status`, toggle with `register()`/`unregister()`.
**When to use:** For the launch-at-login toggle.

Important: Do NOT store the launch-at-login state in UserDefaults. Always read from `SMAppService.mainApp.status` because users can change it in System Settings independently.

```swift
import ServiceManagement

// Reading current state (in onAppear or computed property):
var launchAtLogin: Bool {
    SMAppService.mainApp.status == .enabled
}

// Toggling:
func setLaunchAtLogin(_ enabled: Bool) {
    do {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    } catch {
        print("[Settings] Launch at login error: \(error)")
    }
}
```

### Pattern 4: Silent Background Launch (No Window on Login)

**What:** Suppress the main window when launched as a login item.
**When to use:** When the app starts at login, it should NOT show a window.

There is no direct Apple API to detect "this launch was from a login item" vs "user launched manually." The most reliable approaches:

**Option A -- Check if launched by launchd (parent PID 1):**
```swift
// In AppDelegate.applicationDidFinishLaunching:
let parentPID = getppid()
let isLoginLaunch = parentPID == 1  // launchd is PID 1
if isLoginLaunch && SMAppService.mainApp.status == .enabled {
    NSApp.windows.first?.orderOut(nil)  // hide window
}
```

**Option B -- Hide window, let dock click reopen:**
Since the app already implements `applicationShouldHandleReopen` to show the window when clicking the dock icon, the approach is:
1. On login launch, hide the window in `applicationDidFinishLaunching`
2. User clicks dock icon -> `applicationShouldHandleReopen` fires -> window shows

The existing `AppDelegate` already has `applicationShouldHandleReopen` and `applicationWillBecomeActive` handlers that show the window, so hiding on login launch is the only new piece needed.

**Recommendation:** Use Option A (parent PID check). It is simple, reliable, and does not require helper apps or launch arguments.

### Pattern 5: Key Display String Conversion

**What:** Convert a (keyCode, modifiers) pair to a human-readable string like "F6" or "Cmd+Shift+A".
**When to use:** For displaying the current hotkey in the recorder field and elsewhere.

For modifier symbols, use standard macOS conventions:
```swift
// Modifier display order (standard macOS convention):
// Control (^) -> Option (⌥) -> Shift (⇧) -> Command (⌘)

static func modifierSymbols(_ flags: NSEvent.ModifierFlags) -> String {
    var result = ""
    if flags.contains(.control) { result += "⌃" }
    if flags.contains(.option)  { result += "⌥" }
    if flags.contains(.shift)   { result += "⇧" }
    if flags.contains(.command) { result += "⌘" }
    return result
}
```

For key names, two options:
1. **Simple static map** for function keys + common keys (sufficient for this app's scope)
2. **`UCKeyTranslate`** for full keyboard-layout-aware character resolution

**Recommendation:** Use a static map for function keys (F1-F20) and special keys (Space, Tab, Return, Delete, arrows, etc.), and `UCKeyTranslate` only for letter/number/symbol keys where the keyboard layout matters. This avoids showing "A" when the user's layout has a different character on that physical key.

### Anti-Patterns to Avoid

- **Storing launch-at-login in UserDefaults:** The state can go out of sync if the user changes it in System Settings. Always read from `SMAppService.mainApp.status`.
- **Using `addGlobalMonitorForEvents` for the key recorder:** Global monitors can only observe events, not consume them. Use `addLocalMonitorForEvents` (local to the app) and return `nil` to consume.
- **Modifier-only hotkeys:** The user decided against these. The HotkeyManager uses `CGEventTap` for `keyUp` events, which are not generated for modifier-only presses. Do not support modifier-only combos.
- **Forgetting to remove event monitors:** Always pair `addLocalMonitorForEvents` with `removeMonitor` in the view's disappear/cleanup path to avoid leaking monitors.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Launch at login | Custom launchd plist or helper app | `SMAppService.mainApp.register()` | 2 lines vs. complex plist management; Apple's official API |
| Key code to string | Manual keyCode-to-character mapping for all keys | `UCKeyTranslate` for layout-dependent keys | Keyboard layouts vary; hard-coded maps break for non-US layouts |
| Modifier flag display | Custom flag-to-string logic | Standard macOS symbol convention (Control->Option->Shift->Command order) | Users expect consistent modifier ordering |

**Key insight:** The scope here is narrow enough that no third-party dependencies are needed. `SMAppService` is trivial, the key recorder is ~100-150 lines, and the settings consolidation is just reorganizing existing SwiftUI Form sections.

## Common Pitfalls

### Pitfall 1: Launch-at-Login State Desync
**What goes wrong:** UI shows "launch at login: ON" but user disabled it in System Settings, or vice versa.
**Why it happens:** Storing the state in UserDefaults instead of reading from `SMAppService`.
**How to avoid:** Always derive UI state from `SMAppService.mainApp.status`. Check in `onAppear` and when the settings window regains focus.
**Warning signs:** Toggle state doesn't match System Settings > General > Login Items.

### Pitfall 2: Key Recorder Event Monitor Leak
**What goes wrong:** After leaving the settings view, the local event monitor keeps intercepting key events, breaking normal keyboard input.
**Why it happens:** `NSEvent.addLocalMonitorForEvents` returns a monitor object that must be explicitly removed.
**How to avoid:** Store the monitor reference. Remove it in `stopRecording()`, `onDisappear`, and when the view is deallocated. Use `NSEvent.removeMonitor(_:)`.
**Warning signs:** After visiting settings, keyboard shortcuts in other parts of the app stop working.

### Pitfall 3: CGEventFlags vs NSEvent.ModifierFlags Mismatch
**What goes wrong:** Hotkey saved with NSEvent modifier flags doesn't match when compared against CGEvent flags in the HotkeyManager callback.
**Why it happens:** `NSEvent.ModifierFlags` and `CGEventFlags` have the same underlying bits but different Swift types. The HotkeyManager uses `CGEventFlags`.
**How to avoid:** Store the raw `UInt64` value and construct the appropriate flag type at usage site. Or convert: `CGEventFlags(rawValue: UInt64(nsModifiers.rawValue))`.
**Warning signs:** Hotkey works when set via code but not when set via UI, or vice versa.

### Pitfall 4: Function Key .function Flag
**What goes wrong:** Function keys (F1-F12) include `.function` in their modifier flags. If the recorder checks `modifiers.isEmpty` to determine "no modifiers," F-keys fail validation.
**Why it happens:** macOS sets the `.function` flag on F-key events automatically.
**How to avoid:** When checking for user-provided modifiers, strip `.function` and `.numericPad` from the modifier flags first: `modifiers.subtracting([.function, .numericPad])`.
**Warning signs:** Pressing F6 alone is rejected by the recorder as "no modifier, not a function key."

### Pitfall 5: Window Shows Briefly on Login Launch
**What goes wrong:** The window flashes for a frame before being hidden on login launch.
**Why it happens:** SwiftUI's `WindowGroup` creates and shows the window before `applicationDidFinishLaunching` completes.
**How to avoid:** Hide the window as early as possible in `applicationDidFinishLaunching`. If needed, use `NSApp.windows.first?.orderOut(nil)`. The existing `windowShouldClose` -> `NSApp.hide(nil)` pattern already handles the dock-click-to-reopen cycle.
**Warning signs:** Brief window flash on every login.

### Pitfall 6: HotkeyManager Event Tap Restart on Key Change
**What goes wrong:** Changing the hotkey doesn't take effect until app restart.
**Why it happens:** The `CGEventTap` callback uses the manager's `keyCode` and `requiredModifiers` properties. If these are updated, the callback automatically picks up the new values on the next key event (since it reads them via the `Unmanaged` pointer to the manager instance).
**How to avoid:** Actually, this is NOT a pitfall for this codebase. The existing `HotkeyManager.matches()` reads `keyCode` and `requiredModifiers` on every event. Updating these properties takes effect immediately -- no tap restart needed.
**Warning signs:** N/A -- this works correctly by design.

## Code Examples

### Key Recorder View (SwiftUI + NSEvent Monitor)

```swift
import SwiftUI
import Carbon.HIToolbox

struct HotkeyRecorderView: View {
    @Binding var keyCode: Int
    @Binding var modifiers: UInt64
    @State private var isRecording = false
    @State private var keyMonitor: Any?

    var body: some View {
        HStack {
            Text(isRecording ? "Press a key..." : displayString)
                .frame(minWidth: 120, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.accentColor : Color.secondary.opacity(0.3))
                )
                .onTapGesture { startRecording() }

            if keyCode >= 0 {
                Button("Clear") {
                    keyCode = -1  // -1 = no hotkey
                    modifiers = 0
                }
                .buttonStyle(.borderless)
            }
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyEvent(event)
            return nil  // consume all key events while recording
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let code = Int(event.keyCode)
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Escape cancels
        if code == kVK_Escape && mods.subtracting([.function, .numericPad]).isEmpty {
            stopRecording()
            return
        }

        let isFunctionKey = functionKeyCodes.contains(code)
        let userModifiers = mods.subtracting([.function, .numericPad])
        let hasModifier = !userModifiers.isEmpty

        if isFunctionKey || hasModifier {
            keyCode = code
            modifiers = UInt64(mods.rawValue)
            stopRecording()
        }
        // else: invalid combo, keep recording
    }
}
```

### Launch at Login Toggle

```swift
import SwiftUI
import ServiceManagement

struct LaunchAtLoginToggle: View {
    @State private var isEnabled = false

    var body: some View {
        Toggle("Launch at login", isOn: $isEnabled)
            .onChange(of: isEnabled) { _, newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    // Revert toggle on failure
                    isEnabled = SMAppService.mainApp.status == .enabled
                    print("[Settings] Launch at login error: \(error)")
                }
            }
            .onAppear {
                isEnabled = SMAppService.mainApp.status == .enabled
            }
    }
}
```

### Silent Background Launch Detection

```swift
// In AppDelegate.swift:
func applicationDidFinishLaunching(_ notification: Notification) {
    if let window = NSApp.windows.first {
        window.delegate = self
    }

    // If launched by launchd as a login item, hide window
    if getppid() == 1 && SMAppService.mainApp.status == .enabled {
        NSApp.windows.first?.orderOut(nil)
    }
}
```

### Key Display String Helper

```swift
import Carbon.HIToolbox

struct HotkeyDisplayHelper {
    // Standard macOS modifier symbol ordering
    static func modifierSymbols(from rawValue: UInt64) -> String {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(rawValue))
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option)  { result += "⌥" }
        if flags.contains(.shift)   { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        return result
    }

    // Function key names (static map -- keyboard-layout independent)
    static let functionKeyNames: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
        kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
        kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16",
        kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]

    // Special key names (static map)
    static let specialKeyNames: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "Return", kVK_Tab: "Tab",
        kVK_Delete: "Delete", kVK_ForwardDelete: "⌦", kVK_Escape: "Esc",
        kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_Home: "Home", kVK_End: "End",
        kVK_PageUp: "Page Up", kVK_PageDown: "Page Down",
    ]

    static func keyName(for keyCode: Int) -> String {
        if let name = functionKeyNames[keyCode] { return name }
        if let name = specialKeyNames[keyCode] { return name }
        // For letter/number/symbol keys, use UCKeyTranslate
        return characterForKeyCode(keyCode) ?? "Key \(keyCode)"
    }

    static func displayString(keyCode: Int, modifiers: UInt64) -> String {
        let modStr = modifierSymbols(from: modifiers)
        let keyStr = keyName(for: keyCode)
        return modStr + keyStr
    }

    // Layout-aware character lookup via UCKeyTranslate
    private static func characterForKeyCode(_ keyCode: Int) -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let layoutDataRef = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let layoutData = unsafeBitCast(layoutDataRef, to: CFData.self)
        let layoutPtr = CFDataGetBytePtr(layoutData)!
        let layout = layoutPtr.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { $0 }

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length: Int = 0

        let status = UCKeyTranslate(
            layout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,  // no modifiers for display
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )

        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }
}
```

### Reset to Defaults

```swift
// In AppState:
static let defaults: [String: Any] = [
    "hotkeyKeyCode": Int(kVK_F6),
    "hotkeyModifiers": UInt64(0),
    "safetyModeEnabled": true,
    "clickThroughEnabled": true,
]

func resetToDefaults() {
    hotkeyKeyCode = Int(kVK_F6)
    hotkeyModifiers = 0
    isSafetyModeEnabled = true
    isClickThroughEnabled = true

    // Launch at login is intentionally NOT reset
    // (it's a system-level setting, not an app preference)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `SMLoginItemSetEnabled` + helper app | `SMAppService.mainApp` | macOS 13 (2022) | No helper app needed; 2-line API |
| `LSSharedFileList` for login items | `SMAppService` | macOS 13 (2022) | Deprecated API removed |
| `sindresorhus/LaunchAtLogin-Legacy` | Direct `SMAppService` | Sep 2025 (archived) | Package archived; use Apple API directly |

**Deprecated/outdated:**
- `SMLoginItemSetEnabled` + helper app bundle: Replaced by `SMAppService` in macOS 13
- `LaunchAtLogin-Legacy` Swift package: Archived September 2025; unnecessary for macOS 13+ only targets

## Open Questions

1. **Window flash on login launch**
   - What we know: `getppid() == 1` check in `applicationDidFinishLaunching` should catch login launches. `NSApp.windows.first?.orderOut(nil)` hides the window.
   - What's unclear: SwiftUI `WindowGroup` may render one frame before AppDelegate fires. There could be a brief flash.
   - Recommendation: Test during implementation. If flash occurs, consider using `NSApp.hide(nil)` instead, which is what the existing `windowShouldClose` handler does. The `applicationShouldHandleReopen` handler already brings the window back on dock click.

2. **UCKeyTranslate availability in modern Swift**
   - What we know: `UCKeyTranslate` was historically hard to call from Swift (missing from some SDK versions). Modern Swift with `import CoreServices` should expose it.
   - What's unclear: Whether the exact calling convention shown works in the project's deployment target.
   - Recommendation: Verify during implementation by testing with `import CoreServices`. If it fails to compile, use `import Carbon` which already works in the project.

3. **CGEventFlags rawValue mapping from NSEvent.ModifierFlags**
   - What we know: Both use the same underlying bit positions. `NSEvent.ModifierFlags.rawValue` is `UInt`, `CGEventFlags.rawValue` is `UInt64`.
   - What's unclear: Whether a simple cast suffices or if there are alignment issues.
   - Recommendation: Store as `UInt64` in UserDefaults. Convert via `CGEventFlags(rawValue: storedValue)` for HotkeyManager and `NSEvent.ModifierFlags(rawValue: UInt(storedValue))` for UI display. Test with Cmd+Shift+F6 type combos.

## Sources

### Primary (HIGH confidence)
- [Apple Developer: SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice) - API reference for launch-at-login
- [Apple Developer: SMAppService.mainApp](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp) - Login item registration
- [Apple Developer: UCKeyTranslate](https://developer.apple.com/documentation/coreservices/1390584-uckeytranslate) - Key code to character conversion
- [Apple Developer: NSEvent.SpecialKey](https://developer.apple.com/documentation/appkit/nsevent/specialkey-swift.struct) - Special key constants
- [Apple Developer: CGKeyCode](https://developer.apple.com/documentation/coregraphics/cgkeycode) - Key code type reference
- [Apple Developer: Function-Key Unicode Values](https://developer.apple.com/documentation/appkit/nsevent/1535851-function-key_unicodes) - Function key character constants

### Secondary (MEDIUM confidence)
- [Nil Coalescing: Launch at Login Setting](https://nilcoalescing.com/blog/LaunchAtLoginSetting/) - Verified SwiftUI implementation pattern with SMAppService
- [theevilbit: SMAppService API Notes](https://theevilbit.github.io/posts/smappservice/) - Detailed API behavior and edge cases
- [Clipy/Sauce: Key.swift](https://github.com/Clipy/Sauce/blob/master/Lib/Sauce/Key.swift) - Carbon key code to Swift enum mapping reference
- [Clipy/Sauce: KeyboardLayout.swift](https://github.com/Clipy/Sauce/blob/master/Lib/Sauce/KeyboardLayout.swift) - UCKeyTranslate usage pattern
- [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - Reference for key recorder interaction patterns
- [Gaitatzis: Capture Key Bindings in Swift](https://gaitatzis.medium.com/capture-key-bindings-in-swift-3050b0ccbf42) - CGEvent + NSEvent key capture patterns
- [LaunchAtLogin-Legacy Issue #33](https://github.com/sindresorhus/LaunchAtLogin-Legacy/issues/33) - Discussion on detecting login-item launch

### Tertiary (LOW confidence)
- Parent PID check (`getppid() == 1`) for login item detection - Community pattern, not officially documented by Apple

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All Apple frameworks, well-documented APIs
- Architecture: HIGH - Extends existing patterns already in the codebase
- Pitfalls: HIGH - Well-known issues with established solutions
- Key recorder: MEDIUM - Custom implementation, patterns verified but not copied from a single authoritative source
- Silent launch detection: MEDIUM - `getppid()` approach is widely used but not officially documented

**Research date:** 2026-02-16
**Valid until:** 2026-03-16 (stable APIs, unlikely to change)
