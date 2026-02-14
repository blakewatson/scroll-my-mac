import Foundation

@Observable
class AppState {
    var isScrollModeActive: Bool = false
    var isAccessibilityGranted: Bool = false

    @ObservationIgnored
    var isSafetyModeEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "safetyModeEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "safetyModeEnabled") }
    }

    @ObservationIgnored
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }
}
