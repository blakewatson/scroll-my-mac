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
                .onTapGesture {
                    startRecording()
                }

            if keyCode >= 0 {
                Button("Clear") {
                    keyCode = -1
                    modifiers = 0
                }
                .buttonStyle(.borderless)
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - Display

    private var displayString: String {
        if keyCode < 0 {
            return "None"
        }
        return HotkeyDisplayHelper.displayString(keyCode: keyCode, modifiers: modifiers)
    }

    // MARK: - Recording

    private func startRecording() {
        guard !isRecording else { return }
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

        // Escape (with no user modifiers after stripping .function/.numericPad) cancels recording
        let userMods = mods.subtracting([.function, .numericPad])
        if code == kVK_Escape && userMods.isEmpty {
            stopRecording()
            return
        }

        let isFunctionKey = HotkeyDisplayHelper.functionKeyCodes.contains(code)
        let hasModifier = !userMods.isEmpty

        if isFunctionKey || hasModifier {
            // Store the raw modifier flags (stripping .function and .numericPad for storage)
            // so that CGEventFlags comparison in HotkeyManager works correctly.
            // Keep .function for function keys since CGEvent also sets it.
            keyCode = code
            modifiers = UInt64(mods.rawValue)
            stopRecording()
        }
        // else: invalid combo (bare letter key, etc.), silently ignore -- keep recording
    }
}
