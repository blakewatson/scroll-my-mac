import AppKit
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    /// Returns the app's main settings window, filtering out panels and status bar windows.
    static func settingsWindow() -> NSWindow? {
        NSApp.windows.first { window in
            !(window is NSPanel)
                && type(of: window) != NSClassFromString("NSStatusBarWindow")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let isLoginItem = getppid() == 1 && SMAppService.mainApp.status == .enabled

        // Defer window setup to let SwiftUI finish creating the window.
        // On first launch, settingsWindow() may return nil if SwiftUI hasn't
        // created the Window scene yet.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let window = AppDelegate.settingsWindow() {
                window.delegate = self
                if isLoginItem {
                    // Login item: hide window for silent background launch
                    window.orderOut(nil)
                } else {
                    // Normal launch: ensure settings window is visible and focused
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.hide(nil)
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            AppDelegate.settingsWindow()?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }
}
