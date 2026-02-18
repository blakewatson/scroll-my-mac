import AppKit

/// Manages an NSStatusItem in the menu bar for quick scroll-mode toggling.
class MenuBarManager {
    private var statusItem: NSStatusItem?

    /// Called when the user left-clicks the status item (toggle scroll mode).
    var onToggle: (() -> Void)?

    /// Called when the user selects "Settings..." from the context menu.
    var onOpenSettings: (() -> Void)?

    // MARK: - Show / Hide

    func show() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = makeMenuBarIcon()
        icon.isTemplate = true
        item.button?.image = icon
        item.button?.target = self
        item.button?.action = #selector(handleClick)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
    }

    func hide() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    // MARK: - State

    func updateIcon(isActive: Bool) {
        statusItem?.button?.alphaValue = isActive ? 1.0 : 0.4
    }

    // MARK: - Click Handling

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            onToggle?()
        }
    }

    private func showContextMenu() {
        let menu = buildContextMenu()
        guard let button = statusItem?.button else { return }
        menu.popUp(positioning: nil,
                   at: NSPoint(x: 0, y: button.bounds.height),
                   in: button)
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings...",
                                      action: #selector(settingsMenuAction),
                                      keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Scroll My Mac",
                                  action: #selector(NSApplication.terminate(_:)),
                                  keyEquivalent: "")
        menu.addItem(quitItem)

        return menu
    }

    @objc private func settingsMenuAction() {
        onOpenSettings?()
    }

    // MARK: - Programmatic Icon

    /// Draws a simple mouse outline as an 18x18 template image.
    private func makeMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()

            // Mouse body: rounded rect, centered
            let bodyRect = NSRect(x: 5, y: 1.5, width: 8, height: 13)
            let body = NSBezierPath(roundedRect: bodyRect, xRadius: 4, yRadius: 4)
            body.lineWidth = 1.2
            body.stroke()

            // Scroll wheel divider: vertical line from top of body down ~1/3
            let divider = NSBezierPath()
            divider.move(to: NSPoint(x: 9, y: 14.5))
            divider.line(to: NSPoint(x: 9, y: 10))
            divider.lineWidth = 1.0
            divider.stroke()

            // Small scroll wheel circle
            let wheelRect = NSRect(x: 7.75, y: 11, width: 2.5, height: 2.5)
            let wheel = NSBezierPath(ovalIn: wheelRect)
            wheel.lineWidth = 0.8
            wheel.stroke()

            return true
        }
        image.isTemplate = true
        return image
    }
}
