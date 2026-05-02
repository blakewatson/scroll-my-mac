---
quick_id: "9"
slug: fix-exclusion-list-apps-without-bundle-id
status: complete
date: 2026-05-02
---

# Quick Task 9: Summary

## What was done

Fixed the exclusion list silently failing to add apps from `~/Applications` that lack a `CFBundleIdentifier`.

**Root cause confirmed:** Apps like Balatro, Baldur's Gate 3, Divinity Original Sin 2, Into the Breach, Luck be a Landlord, and Universe Sandbox in `~/Applications` are minimal wrappers created by game launchers without `CFBundleIdentifier` in their `Info.plist`. Both `Bundle(url:)?.bundleIdentifier` and `NSDictionary(contentsOf:)` reading `Contents/Info.plist` returned nil for these apps.

## Changes

### `AppExclusionManager.swift`
- `checkFrontmostApp()` now also checks `frontmost.bundleURL?.standardizedFileURL.path` against the stored identifiers, enabling path-based matching for apps without a bundle ID.

### `SettingsView.swift`
- `addExcludedAppViaPanel()`: falls back to `normalizedURL.path` when no bundle ID is available, so games without CFBundleIdentifier can be stored and matched
- `addExcludedAppViaPanel()`: file picker now starts at `~/Applications` if it exists (better UX for the reporter's use case), otherwise `/Applications`
- `iconForBundleID(_:)`: detects path-based identifiers (start with `/`) and fetches icon directly via `NSWorkspace.shared.icon(forFile:)`
- `displayNameForBundleID(_:)`: detects path-based identifiers and extracts the app name from the last path component (without `.app` extension)
- Added `preferredAppsDirectory()` helper

## Build status
Build succeeded.
