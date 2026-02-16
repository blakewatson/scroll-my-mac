import Foundation
import AppKit
import ApplicationServices
import Carbon.HIToolbox

@Observable
class AppState {
    var isScrollModeActive: Bool = false {
        didSet {
            if isScrollModeActive {
                activateScrollMode()
            } else {
                deactivateScrollMode()
            }
        }
    }

    var isAccessibilityGranted: Bool = false {
        didSet {
            if isAccessibilityGranted {
                if hotkeyKeyCode >= 0 {
                    hotkeyManager.start()
                }
            } else {
                hotkeyManager.stop()
                if isScrollModeActive {
                    isScrollModeActive = false
                }
            }
        }
    }

    var isSafetyModeEnabled: Bool {
        didSet { UserDefaults.standard.set(isSafetyModeEnabled, forKey: "safetyModeEnabled") }
    }

    var isClickThroughEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isClickThroughEnabled, forKey: "clickThroughEnabled")
            scrollEngine.clickThroughEnabled = isClickThroughEnabled
        }
    }

    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    var hotkeyKeyCode: Int {
        didSet {
            UserDefaults.standard.set(hotkeyKeyCode, forKey: "hotkeyKeyCode")
            applyHotkeySettings()
        }
    }

    var hotkeyModifiers: UInt64 {
        didSet {
            UserDefaults.standard.set(Int(bitPattern: UInt(hotkeyModifiers)), forKey: "hotkeyModifiers")
            applyHotkeySettings()
        }
    }

    // MARK: - Services

    let scrollEngine = ScrollEngine()
    let hotkeyManager = HotkeyManager()
    let overlayManager = OverlayManager()

    // MARK: - Permission Health Check

    private var permissionHealthTimer: Timer?

    // MARK: - Init

    init() {
        self.isSafetyModeEnabled = UserDefaults.standard.object(forKey: "safetyModeEnabled") as? Bool ?? true
        self.isClickThroughEnabled = UserDefaults.standard.object(forKey: "clickThroughEnabled") as? Bool ?? true
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        let defaults = UserDefaults.standard
        if defaults.object(forKey: "hotkeyKeyCode") != nil {
            self.hotkeyKeyCode = defaults.integer(forKey: "hotkeyKeyCode")
        } else {
            self.hotkeyKeyCode = Int(kVK_F6)
        }
        if defaults.object(forKey: "hotkeyModifiers") != nil {
            self.hotkeyModifiers = UInt64(UInt(bitPattern: defaults.integer(forKey: "hotkeyModifiers")))
        } else {
            self.hotkeyModifiers = 0
        }
    }

    // MARK: - Service Wiring

    /// Connects all services together. Call once after init.
    func setupServices() {
        hotkeyManager.onToggle = { [weak self] in
            self?.toggleScrollMode()
        }

        applyHotkeySettings()

        scrollEngine.clickThroughEnabled = isClickThroughEnabled

        scrollEngine.shouldPassThroughClick = { cgPoint in
            // Allow clicks on the app's own windows (e.g. the settings toggle).
            // CG coordinates are top-left origin; NSWindow frames are bottom-left.
            guard let screenHeight = NSScreen.main?.frame.height else { return false }
            let nsPoint = NSPoint(x: cgPoint.x, y: screenHeight - cgPoint.y)
            return NSApp.windows.contains { window in
                window.isVisible && !window.ignoresMouseEvents && window.frame.contains(nsPoint)
            }
        }
    }

    // MARK: - Hotkey Settings

    /// Syncs the stored hotkey configuration to HotkeyManager.
    /// If keyCode is -1 (no hotkey), stops the hotkey listener entirely.
    private func applyHotkeySettings() {
        if hotkeyKeyCode >= 0 {
            hotkeyManager.keyCode = Int64(hotkeyKeyCode)
            hotkeyManager.requiredModifiers = CGEventFlags(rawValue: hotkeyModifiers)
            hotkeyManager.suppressUntil = Date().addingTimeInterval(0.5)
            hotkeyManager.start()  // re-enable if previously stopped by clear
        } else {
            hotkeyManager.stop()
        }
    }

    // MARK: - Reset to Defaults

    /// Restores all app preferences to defaults. Launch at login intentionally NOT reset (system-level setting).
    func resetToDefaults() {
        hotkeyKeyCode = Int(kVK_F6)
        hotkeyModifiers = 0
        isSafetyModeEnabled = true
        isClickThroughEnabled = true
    }

    // MARK: - Scroll Mode Toggle

    /// Toggles scroll mode. Works even mid-drag — stop() handles cleanup.
    func toggleScrollMode() {
        isScrollModeActive.toggle()
    }

    // MARK: - Activation / Deactivation

    private func activateScrollMode() {
        guard AXIsProcessTrusted() else {
            print("[AppState] Accessibility permission not granted. Cannot activate scroll mode.")
            // Defer to avoid recursive didSet.
            DispatchQueue.main.async { [weak self] in
                self?.isScrollModeActive = false
            }
            return
        }

        scrollEngine.start()
        startPermissionHealthCheck()
    }

    private func deactivateScrollMode() {
        scrollEngine.stop()
        stopPermissionHealthCheck()
    }

    // MARK: - Permission Health Monitoring

    private func startPermissionHealthCheck() {
        permissionHealthTimer?.invalidate()
        permissionHealthTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if !AXIsProcessTrusted() {
                self.handlePermissionLost()
            }
        }
    }

    private func stopPermissionHealthCheck() {
        permissionHealthTimer?.invalidate()
        permissionHealthTimer = nil
    }

    private func handlePermissionLost() {
        stopPermissionHealthCheck()
        // Setting isScrollModeActive to false triggers deactivateScrollMode via didSet,
        // which calls scrollEngine.stop() — cleaning up drag state.
        isScrollModeActive = false
        // Setting isAccessibilityGranted to false triggers its didSet,
        // which stops hotkeyManager and shows the permission warning in UI.
        isAccessibilityGranted = false
        // Start polling so we detect when permission is re-granted.
        startPermissionRecoveryPolling()
    }

    private func startPermissionRecoveryPolling() {
        permissionHealthTimer?.invalidate()
        permissionHealthTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if AXIsProcessTrusted() {
                self.permissionHealthTimer?.invalidate()
                self.permissionHealthTimer = nil
                self.isAccessibilityGranted = true
            }
        }
    }
}
