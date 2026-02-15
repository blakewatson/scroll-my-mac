import AppKit
import SwiftUI

/// Manages a floating NSPanel that displays a small indicator dot near the cursor
/// when scroll mode is active. The panel is transparent, borderless, and ignores
/// all mouse events so it never interferes with scrolling or clicking.
class OverlayManager {

    // MARK: - Private State

    private var overlayWindow: NSPanel?

    /// Offset from cursor tip to dot center (pixels).
    private let cursorOffset: CGFloat = 16.0

    // MARK: - Public API

    /// Creates and shows the overlay dot near the current cursor position.
    func show() {
        guard overlayWindow == nil else {
            overlayWindow?.orderFrontRegardless()
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 12, height: 12),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)) - 1)
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: IndicatorDotView())

        overlayWindow = panel
        updatePosition()
        panel.orderFrontRegardless()
    }

    /// Hides and destroys the overlay panel.
    func hide() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
    }

    /// Updates the overlay position relative to the cursor.
    ///
    /// - Parameter cgPoint: Cursor position in CG (top-left origin) coordinates.
    ///   If nil, uses `NSEvent.mouseLocation` (bottom-left origin, no conversion needed).
    func updatePosition(cgPoint: CGPoint? = nil) {
        guard let panel = overlayWindow else { return }

        let update = { [self] in
            let screenPoint: NSPoint

            if let cg = cgPoint {
                // Convert from CG top-left coordinates to NS bottom-left coordinates.
                let screenHeight = NSScreen.screens.first(where: { screen in
                    NSMouseInRect(NSPoint(x: cg.x, y: screen.frame.height - cg.y), screen.frame, false)
                })?.frame.height ?? NSScreen.main?.frame.height ?? 0

                screenPoint = NSPoint(x: cg.x, y: screenHeight - cg.y)
            } else {
                screenPoint = NSEvent.mouseLocation
            }

            // Position: 16px right, 16px below cursor tip.
            // In NS coordinates, "below" means subtracting Y.
            let origin = NSPoint(
                x: screenPoint.x + cursorOffset,
                y: screenPoint.y - cursorOffset - 12 // 12 = panel height
            )
            panel.setFrameOrigin(origin)
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async { update() }
        }
    }
}
