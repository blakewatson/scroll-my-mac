---
quick_id: "9"
slug: fix-exclusion-list-apps-without-bundle-id
description: Fix exclusion list not adding apps from ~/Applications that lack CFBundleIdentifier
date: 2026-05-02
status: complete
---

# Quick Task 9: Fix exclusion list for apps without CFBundleIdentifier

## Root Cause

Apps in `~/Applications` (games like Balatro, BG3, Divinity OS2, etc.) are minimal `.app` wrappers created by game launchers (Steam, GOG, etc.) that do NOT include a `CFBundleIdentifier` in their `Info.plist`. When the user tries to add these apps via `addExcludedAppViaPanel()`, `Bundle(url:)?.bundleIdentifier` returns nil and the app is silently not added.

## Tasks

### Task 1: Use bundle path as fallback identifier

**Files:** `ScrollMyMac/Features/Settings/SettingsView.swift`

- Change `addExcludedAppViaPanel()` to fall back to `selectedURL.standardizedFileURL.path` when `Bundle(url:)?.bundleIdentifier` is nil
- Update `directoryURL` to start at `~/Applications` if it exists, otherwise `/Applications`
- Add `preferredAppsDirectory()` helper
- Update `iconForBundleID(_:)` to detect path-based identifiers (start with `/`) and use `NSWorkspace.shared.icon(forFile:)` directly
- Update `displayNameForBundleID(_:)` to extract app name from path when identifier starts with `/`

**Files:** `ScrollMyMac/Services/AppExclusionManager.swift`

- Update `checkFrontmostApp()` to also match against `frontmost.bundleURL?.standardizedFileURL.path` in addition to `bundleIdentifier`
