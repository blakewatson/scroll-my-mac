import Foundation
import AppKit
import ApplicationServices

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
                hotkeyManager.start()
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

    // MARK: - Services

    let scrollEngine = ScrollEngine()
    let hotkeyManager = HotkeyManager()
    let overlayManager = OverlayManager()

    // MARK: - Init

    init() {
        self.isSafetyModeEnabled = UserDefaults.standard.object(forKey: "safetyModeEnabled") as? Bool ?? true
        self.isClickThroughEnabled = UserDefaults.standard.object(forKey: "clickThroughEnabled") as? Bool ?? true
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    // MARK: - Service Wiring

    /// Connects all services together. Call once after init.
    func setupServices() {
        hotkeyManager.onToggle = { [weak self] in
            self?.toggleScrollMode()
        }



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

    // MARK: - Scroll Mode Toggle

    /// Toggles scroll mode, ignoring the toggle if a drag is in progress.
    func toggleScrollMode() {
        guard !scrollEngine.isDragging else { return }
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
    }

    private func deactivateScrollMode() {
        scrollEngine.stop()
    }
}
