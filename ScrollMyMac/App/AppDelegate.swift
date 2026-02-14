import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApp.windows.first {
            window.delegate = self
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.hide(nil)
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        // Belt-and-suspenders: if no visible windows when activated, show the first one
        let hasVisibleWindows = NSApp.windows.contains { $0.isVisible }
        if !hasVisibleWindows, let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
