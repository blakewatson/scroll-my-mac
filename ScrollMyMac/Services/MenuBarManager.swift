import AppKit

/// Manages an NSStatusItem in the menu bar for quick scroll-mode toggling.
///
/// Any click opens the menu (standard macOS pattern). The first item toggles
/// scroll mode. This works universally with all input methods including
/// accessibility dwell-click.
class MenuBarManager: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var toggleItem: NSMenuItem?

    /// Called when the user selects "Toggle Scroll Mode" from the menu.
    var onToggle: (() -> Void)?

    /// Called when the user selects "Settings..." from the menu.
    var onOpenSettings: (() -> Void)?

    /// Current scroll mode state, used to update the toggle item title.
    var isActive: Bool = false {
        didSet { updateToggleTitle() }
    }

    // MARK: - Show / Hide

    func show() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = makeMenuBarIcon()
        icon.isTemplate = true
        item.button?.image = icon

        let menu = buildMenu()
        menu.delegate = self
        item.menu = menu

        statusItem = item
    }

    func hide() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    // MARK: - State

    /// Stored exclusion state so updateIcon and updateExclusionState stay in sync.
    private var isExcludedApp: Bool = false
    private var excludedAppDisplayName: String?

    func updateIcon(isActive: Bool) {
        self.isActive = isActive
        applyIconState()
    }

    // MARK: - Exclusion State

    /// Updates visual feedback for per-app exclusion (slash icon + tooltip).
    func updateExclusionState(isExcluded: Bool, appName: String?) {
        isExcludedApp = isExcluded
        excludedAppDisplayName = appName
        applyIconState()
    }

    /// Applies the correct icon, alpha, and tooltip based on combined state.
    private func applyIconState() {
        guard let button = statusItem?.button else { return }

        if isActive && isExcludedApp {
            // Active but excluded: slashed icon, full opacity, tooltip.
            let icon = makeSlashedMenuBarIcon()
            icon.isTemplate = true
            button.image = icon
            button.alphaValue = 1.0
            button.toolTip = "Scroll mode paused \u{2014} \(excludedAppDisplayName ?? "App") is excluded"
        } else if isActive {
            // Active and not excluded: normal icon, full opacity, no tooltip.
            let icon = makeMenuBarIcon()
            icon.isTemplate = true
            button.image = icon
            button.alphaValue = 1.0
            button.toolTip = nil
        } else {
            // Inactive: normal icon, dimmed, no tooltip.
            let icon = makeMenuBarIcon()
            icon.isTemplate = true
            button.image = icon
            button.alphaValue = 0.4
            button.toolTip = nil
        }
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let toggle = NSMenuItem(title: "Turn Scroll Mode On",
                                action: #selector(toggleAction),
                                keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        toggleItem = toggle

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings...",
                                      action: #selector(settingsAction),
                                      keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "Quit Scroll My Mac",
                                  action: #selector(NSApplication.terminate(_:)),
                                  keyEquivalent: "")
        menu.addItem(quitItem)

        return menu
    }

    private func updateToggleTitle() {
        toggleItem?.title = isActive ? "Turn Scroll Mode Off" : "Turn Scroll Mode On"
    }

    @objc private func toggleAction() {
        onToggle?()
    }

    @objc private func settingsAction() {
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

    /// Draws the mouse icon with a diagonal slash (bottom-left to top-right)
    /// indicating scroll mode is bypassed for the current app.
    private func makeSlashedMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()

            // Mouse body: same as normal icon
            let bodyRect = NSRect(x: 5, y: 1.5, width: 8, height: 13)
            let body = NSBezierPath(roundedRect: bodyRect, xRadius: 4, yRadius: 4)
            body.lineWidth = 1.2
            body.stroke()

            // Scroll wheel divider
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

            // Diagonal slash: bottom-left to top-right
            let slash = NSBezierPath()
            slash.move(to: NSPoint(x: 3, y: 2))
            slash.line(to: NSPoint(x: 15, y: 16))
            slash.lineWidth = 1.5
            slash.stroke()

            return true
        }
        image.isTemplate = true
        return image
    }
}
