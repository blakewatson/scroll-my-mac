import Foundation
import AppKit
import Carbon.HIToolbox
import CoreServices

struct HotkeyDisplayHelper {

    // MARK: - Modifier Symbols

    /// Returns macOS-standard modifier symbols in order: Control, Option, Shift, Command.
    /// Strips `.function` and `.numericPad` flags before checking.
    static func modifierSymbols(from rawValue: UInt64) -> String {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(rawValue))
            .subtracting([.function, .numericPad])
        var result = ""
        if flags.contains(.control) { result += "\u{2303}" }  // Control
        if flags.contains(.option)  { result += "\u{2325}" }  // Option
        if flags.contains(.shift)   { result += "\u{21E7}" }  // Shift
        if flags.contains(.command) { result += "\u{2318}" }  // Command
        return result
    }

    // MARK: - Key Name Maps

    /// Function key names (F1 through F20).
    static let functionKeyNames: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
        kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
        kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16",
        kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]

    /// Special key names (Space, Return, Tab, Delete, arrows, etc.).
    static let specialKeyNames: [Int: String] = [
        kVK_Space: "Space",
        kVK_Return: "Return",
        kVK_Tab: "Tab",
        kVK_Delete: "Delete",
        kVK_ForwardDelete: "\u{2326}",
        kVK_Escape: "Esc",
        kVK_UpArrow: "\u{2191}",
        kVK_DownArrow: "\u{2193}",
        kVK_LeftArrow: "\u{2190}",
        kVK_RightArrow: "\u{2192}",
        kVK_Home: "Home",
        kVK_End: "End",
        kVK_PageUp: "Page Up",
        kVK_PageDown: "Page Down",
    ]

    /// The set of all function key codes (kVK_F1 through kVK_F20) for validation.
    static let functionKeyCodes: Set<Int> = Set(functionKeyNames.keys)

    // MARK: - Key Name Resolution

    /// Returns a human-readable name for the given key code.
    /// Checks function keys, then special keys, then falls back to UCKeyTranslate.
    static func keyName(for keyCode: Int) -> String {
        if let name = functionKeyNames[keyCode] { return name }
        if let name = specialKeyNames[keyCode] { return name }
        return characterForKeyCode(keyCode) ?? "Key \(keyCode)"
    }

    /// Returns a full display string combining modifier symbols and key name.
    static func displayString(keyCode: Int, modifiers: UInt64) -> String {
        let modStr = modifierSymbols(from: modifiers)
        let keyStr = keyName(for: keyCode)
        return modStr + keyStr
    }

    // MARK: - UCKeyTranslate

    /// Uses TISCopyCurrentKeyboardInputSource + UCKeyTranslate to get the
    /// layout-aware character for a key code, uppercased. Returns nil on failure.
    static func characterForKeyCode(_ keyCode: Int) -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let layoutDataRef = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let layoutData = unsafeBitCast(layoutDataRef, to: CFData.self)
        guard let layoutPtr = CFDataGetBytePtr(layoutData) else { return nil }
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
