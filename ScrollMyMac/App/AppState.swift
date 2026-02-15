import Foundation
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

    var isAccessibilityGranted: Bool = false

    var isSafetyModeEnabled: Bool {
        didSet { UserDefaults.standard.set(isSafetyModeEnabled, forKey: "safetyModeEnabled") }
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
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    // MARK: - Service Wiring

    /// Connects all services together. Call once after init.
    func setupServices() {
        hotkeyManager.onToggle = { [weak self] in
            self?.toggleScrollMode()
        }

        scrollEngine.onDragPositionChanged = { [weak self] cgPoint in
            self?.overlayManager.updatePosition(cgPoint: cgPoint)
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
        overlayManager.show()
        overlayManager.updatePosition()
    }

    private func deactivateScrollMode() {
        scrollEngine.stop()
        overlayManager.hide()
    }
}
