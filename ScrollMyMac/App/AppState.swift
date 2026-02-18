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
            menuBarManager.updateIcon(isActive: isScrollModeActive)
            menuBarManager.updateExclusionState(isExcluded: isCurrentAppExcluded, appName: excludedAppName)
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

    var isHoldToPassthroughEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isHoldToPassthroughEnabled, forKey: "holdToPassthroughEnabled")
            scrollEngine.holdToPassthroughEnabled = isHoldToPassthroughEnabled
        }
    }

    var holdToPassthroughDelay: Double {
        didSet {
            UserDefaults.standard.set(holdToPassthroughDelay, forKey: "holdToPassthroughDelay")
            scrollEngine.holdToPassthroughDelay = holdToPassthroughDelay
        }
    }

    var isMenuBarIconEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isMenuBarIconEnabled, forKey: "menuBarIconEnabled")
            if isMenuBarIconEnabled {
                menuBarManager.show()
                menuBarManager.updateIcon(isActive: isScrollModeActive)
            } else {
                menuBarManager.hide()
            }
        }
    }

    // MARK: - Per-App Exclusion

    /// The current exclusion list — synced from AppExclusionManager.
    var excludedAppBundleIDs: [String] = []

    /// True when the frontmost app is on the exclusion list.
    var isCurrentAppExcluded: Bool = false

    /// Display name of the currently excluded frontmost app (for tooltip).
    var excludedAppName: String?

    // MARK: - Services

    let scrollEngine = ScrollEngine()
    let hotkeyManager = HotkeyManager()
    let overlayManager = OverlayManager()
    let windowExclusionManager = WindowExclusionManager()
    let menuBarManager = MenuBarManager()
    let appExclusionManager = AppExclusionManager()

    // MARK: - Permission Health Check

    private var permissionHealthTimer: Timer?

    // MARK: - Init

    init() {
        self.isSafetyModeEnabled = UserDefaults.standard.object(forKey: "safetyModeEnabled") as? Bool ?? true
        self.isClickThroughEnabled = UserDefaults.standard.object(forKey: "clickThroughEnabled") as? Bool ?? true
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.isHoldToPassthroughEnabled = UserDefaults.standard.object(forKey: "holdToPassthroughEnabled") as? Bool ?? false
        self.holdToPassthroughDelay = UserDefaults.standard.object(forKey: "holdToPassthroughDelay") as? Double ?? 1.0
        self.isMenuBarIconEnabled = UserDefaults.standard.object(forKey: "menuBarIconEnabled") as? Bool ?? true

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

        self.excludedAppBundleIDs = appExclusionManager.excludedBundleIDs

        setupServices()

        // Check accessibility permission directly so the hotkey works
        // even when the window is hidden (e.g. silent login launch).
        if AXIsProcessTrusted() {
            isAccessibilityGranted = true
        }
    }

    // MARK: - Service Wiring

    /// Connects all services together. Called once from init.
    private func setupServices() {
        hotkeyManager.onToggle = { [weak self] in
            self?.toggleScrollMode()
        }

        applyHotkeySettings()

        scrollEngine.clickThroughEnabled = isClickThroughEnabled
        scrollEngine.holdToPassthroughEnabled = isHoldToPassthroughEnabled
        scrollEngine.holdToPassthroughDelay = holdToPassthroughDelay

        // Menu bar icon
        menuBarManager.onToggle = { [weak self] in
            self?.toggleScrollMode()
        }
        menuBarManager.onOpenSettings = {
            AppDelegate.settingsWindow()?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        if isMenuBarIconEnabled {
            menuBarManager.show()
            menuBarManager.updateIcon(isActive: isScrollModeActive)
        }

        // Per-app exclusion: bypass all events when frontmost app is excluded.
        scrollEngine.shouldBypassAllEvents = { [weak self] in
            self?.appExclusionManager.isFrontmostExcluded ?? false
        }

        appExclusionManager.onExclusionStateChanged = { [weak self] isExcluded, appName in
            guard let self else { return }
            self.isCurrentAppExcluded = isExcluded
            self.excludedAppName = appName
            self.menuBarManager.updateExclusionState(isExcluded: isExcluded, appName: appName)
        }

        // Always monitor app switches (not tied to scroll mode activation).
        appExclusionManager.startMonitoring()

        scrollEngine.shouldPassThroughClick = { [weak self] cgPoint in
            guard let self else { return false }

            // Check 1: App's own windows (cached CG coordinates — no AppKit calls).
            if self.windowExclusionManager.isPointInAppWindow(cgPoint) { return true }

            // Check 2: OSK / excluded windows (cached CG coordinates).
            return self.windowExclusionManager.isPointExcluded(cgPoint)
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
        isHoldToPassthroughEnabled = false
        holdToPassthroughDelay = 1.0
        isMenuBarIconEnabled = true
        appExclusionManager.clearAll()
        excludedAppBundleIDs = appExclusionManager.excludedBundleIDs
        appExclusionManager.recheckFrontmostApp()
    }

    // MARK: - Per-App Exclusion

    func addExcludedApp(bundleID: String) {
        appExclusionManager.add(bundleID: bundleID)
        excludedAppBundleIDs = appExclusionManager.excludedBundleIDs
        appExclusionManager.recheckFrontmostApp()
    }

    func removeExcludedApp(bundleID: String) {
        appExclusionManager.remove(bundleID: bundleID)
        excludedAppBundleIDs = appExclusionManager.excludedBundleIDs
        appExclusionManager.recheckFrontmostApp()
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
        windowExclusionManager.startMonitoring()
        startPermissionHealthCheck()
    }

    private func deactivateScrollMode() {
        scrollEngine.stop()
        windowExclusionManager.stopMonitoring()
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
