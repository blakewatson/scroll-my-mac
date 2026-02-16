import Foundation
import CoreGraphics

/// Detects the Accessibility Keyboard (OSK) windows and provides fast
/// hit-testing so clicks over the OSK pass through the scroll engine.
///
/// **Design:** A timer periodically calls `CGWindowListCopyWindowInfo` to
/// cache the on-screen bounds of all windows owned by the target process.
/// The `isPointExcluded(_:)` method reads the cache — it never makes IPC
/// calls — so it is safe to call from the event-tap callback path.
class WindowExclusionManager {

    // MARK: - Cached State

    private var excludedRects: [CGRect] = []
    private var pollTimer: Timer?
    private var oskDetected: Bool = false

    // MARK: - Configuration

    /// Process name for the Accessibility Keyboard.
    /// Verified empirically via CGWindowListCopyWindowInfo.
    private let targetOwnerName = "Assistive Control"

    /// Poll interval when the OSK is on-screen (tracks repositioning).
    private let activeInterval: TimeInterval = 0.5

    /// Poll interval when the OSK is not detected (watches for appearance).
    private let passiveInterval: TimeInterval = 2.0

    // MARK: - Public API

    /// Returns `true` if `point` (CG coordinates, top-left origin) falls
    /// inside any cached OSK window rectangle.
    func isPointExcluded(_ point: CGPoint) -> Bool {
        return excludedRects.contains { $0.contains(point) }
    }

    /// Begins periodic polling for OSK windows.  Performs an immediate
    /// cache refresh so detection is instant on scroll-mode activation.
    func startMonitoring() {
        refreshCache()
        scheduleTimer()
    }

    /// Stops polling and clears all cached state.
    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        excludedRects = []
        oskDetected = false
    }

    // MARK: - Private

    private func refreshCache() {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            excludedRects = []
            updatePollingRate(oskFound: false)
            return
        }

        excludedRects = windowList.compactMap { info in
            guard let ownerName = info[kCGWindowOwnerName as String] as? String,
                  ownerName == targetOwnerName,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict)
            else { return nil }
            return bounds
        }

        updatePollingRate(oskFound: !excludedRects.isEmpty)
    }

    private func updatePollingRate(oskFound: Bool) {
        guard oskFound != oskDetected else { return }
        oskDetected = oskFound
        scheduleTimer()
    }

    private func scheduleTimer() {
        pollTimer?.invalidate()
        let interval = oskDetected ? activeInterval : passiveInterval
        pollTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            self?.refreshCache()
        }
    }
}
