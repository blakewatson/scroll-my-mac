import ApplicationServices
import AppKit

@Observable
class PermissionManager {
    var isAccessibilityGranted: Bool = false

    @ObservationIgnored
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
        stopPolling()
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
