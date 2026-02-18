import Foundation
import AppKit

/// Monitors the frontmost application and manages a per-app exclusion list.
///
/// When the frontmost app's bundle ID is on the exclusion list, the
/// `onExclusionStateChanged` callback fires so the scroll engine can
/// bypass event interception entirely.
///
/// **Design:** Plain class (not @Observable) — pure AppKit/Foundation,
/// like MenuBarManager.  Persists the exclusion list to UserDefaults.
class AppExclusionManager {

    // MARK: - Public State

    /// Whether the current frontmost app is on the exclusion list.
    private(set) var isFrontmostExcluded: Bool = false

    /// Localized display name of the frontmost app (when excluded).
    private(set) var frontmostAppName: String?

    /// Fires with `(isExcluded, appName)` whenever the exclusion state
    /// changes (i.e., user switches to/from an excluded app).
    var onExclusionStateChanged: ((Bool, String?) -> Void)?

    /// The current exclusion list (read-only view).
    var excludedBundleIDs: [String] {
        return storedBundleIDs
    }

    // MARK: - Private State

    private static let defaultsKey = "excludedAppBundleIDs"
    private var storedBundleIDs: [String]
    private var workspaceObserver: NSObjectProtocol?

    // MARK: - Init

    init() {
        self.storedBundleIDs = UserDefaults.standard.stringArray(forKey: Self.defaultsKey) ?? []
    }

    // MARK: - Exclusion List Management

    func add(bundleID: String) {
        guard !storedBundleIDs.contains(bundleID) else { return }
        storedBundleIDs.append(bundleID)
        save()
    }

    func remove(bundleID: String) {
        storedBundleIDs.removeAll { $0 == bundleID }
        save()
    }

    /// Removes all excluded apps and saves.
    func clearAll() {
        storedBundleIDs.removeAll()
        save()
    }

    // MARK: - Monitoring

    /// Registers the workspace notification observer and performs an
    /// immediate check of the current frontmost app.
    func startMonitoring() {
        stopMonitoring()

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkFrontmostApp()
        }

        // Immediate check so state is correct at startup.
        checkFrontmostApp()
    }

    /// Removes the notification observer.
    func stopMonitoring() {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
    }

    /// Re-evaluates the current frontmost app against the exclusion list.
    /// Call after adding/removing an app to update state immediately.
    func recheckFrontmostApp() {
        checkFrontmostApp()
    }

    // MARK: - Private

    private func save() {
        UserDefaults.standard.set(storedBundleIDs, forKey: Self.defaultsKey)
    }

    private func checkFrontmostApp() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else {
            updateState(isExcluded: false, appName: nil)
            return
        }

        let bundleID = frontmost.bundleIdentifier ?? ""
        let isExcluded = storedBundleIDs.contains(bundleID)
        let appName = isExcluded ? frontmost.localizedName : nil
        updateState(isExcluded: isExcluded, appName: appName)
    }

    private func updateState(isExcluded: Bool, appName: String?) {
        // Only fire callback when the state actually changes.
        guard isExcluded != isFrontmostExcluded else { return }
        isFrontmostExcluded = isExcluded
        frontmostAppName = appName
        onExclusionStateChanged?(isExcluded, appName)
    }
}
