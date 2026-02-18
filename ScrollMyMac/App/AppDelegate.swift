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
        if let window = AppDelegate.settingsWindow() {
            window.delegate = self
        }

        // If launched by launchd as a login item, hide window (silent background launch)
        if getppid() == 1 && SMAppService.mainApp.status == .enabled {
            AppDelegate.settingsWindow()?.orderOut(nil)
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
