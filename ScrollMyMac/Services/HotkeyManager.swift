import Cocoa
import Carbon.HIToolbox

/// Listens for a global hotkey (default: F6) via CGEventTap and fires a
/// callback when pressed. The hotkey event is consumed (not passed through).
///
/// Supports optional modifier flags for future customization (Phase 5).
class HotkeyManager {

    // MARK: - Public API

    /// Called on the main thread when the hotkey is pressed.
    var onToggle: (() -> Void)?

    // MARK: - Configuration

    /// Virtual key code to match. Default is F6 (kVK_F6 = 0x61).
    var keyCode: Int64 = Int64(kVK_F6)

    /// Required modifier flags. Empty means no modifiers required (plain key).
    /// Set to e.g. `[.maskControl, .maskShift]` for Ctrl+Shift combos.
    var requiredModifiers: CGEventFlags = []

    /// Suppresses the next match until this time. Set when the hotkey is
    /// reconfigured so the keyUp from the recorder doesn't immediately toggle.
    var suppressUntil: Date?

    // MARK: - Private State

    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // MARK: - Lifecycle

    /// Creates the CGEventTap for keyDown events and adds it to the current run loop.
    func start() {
        guard eventTap == nil else {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }

        let eventMask: CGEventMask = 1 << CGEventType.keyUp.rawValue

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else {
            print("[HotkeyManager] ERROR: Failed to create CGEventTap. Check Accessibility permissions.")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(nil, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    /// Disables the event tap. Call `start()` to re-enable.
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }

    /// Tears down the event tap completely. Call on app termination.
    func tearDown() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - Key Matching

    /// Returns true if the event matches the configured hotkey.
    fileprivate func matches(_ event: CGEvent) -> Bool {
        if let until = suppressUntil {
            if Date() < until {
                suppressUntil = nil
                return false
            }
            suppressUntil = nil
        }

        let eventKeyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard eventKeyCode == keyCode else { return false }

        if requiredModifiers.isEmpty {
            return true
        }

        return event.flags.contains(requiredModifiers)
    }
}

// MARK: - C Callback Bridge

private func hotkeyEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    // Handle tap disabled by timeout — re-enable.
    if type == .tapDisabledByTimeout {
        if let userInfo {
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            if let tap = manager.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .keyUp, let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()

    if manager.matches(event) {
        DispatchQueue.main.async {
            manager.onToggle?()
        }
        return nil // Consume the hotkey event.
    }

    return Unmanaged.passUnretained(event) // Pass through non-matching keys.
}
