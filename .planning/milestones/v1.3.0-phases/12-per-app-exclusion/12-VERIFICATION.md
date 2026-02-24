---
phase: 12-per-app-exclusion
verified: 2026-02-17T00:00:00Z
status: human_needed
score: 10/10 must-haves verified
re_verification: false
human_verification:
  - test: "Add an app to the exclusion list, enable scroll mode, switch to that app, verify clicks pass through normally and menu bar shows slash icon with tooltip"
    expected: "Clicks in the excluded app work normally. Menu bar icon shows a diagonal slash. Tooltip reads 'Scroll mode paused — [App Name] is excluded'."
    why_human: "Event interception behavior and menu bar icon visual can only be confirmed by running the app and observing real mouse event behavior."
  - test: "Switch away from an excluded app to a non-excluded app while scroll mode is on"
    expected: "Menu bar icon returns to normal (no slash). Scroll mode is active again in the non-excluded app."
    why_human: "NSWorkspace app-switch detection and live menu bar icon transition require runtime observation."
  - test: "Quit and relaunch the app after adding an exclusion"
    expected: "The excluded app appears in the list and scroll mode is still bypassed for it."
    why_human: "UserDefaults persistence requires actually running the app across two launches."
---

# Phase 12: Per-App Exclusion Verification Report

**Phase Goal:** Users can designate specific apps where scroll mode is automatically disabled
**Verified:** 2026-02-17
**Status:** human_needed — all automated checks pass; runtime behavior requires human confirmation
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | When the frontmost app is on the exclusion list, all mouse events pass through as normal | VERIFIED | `scrollEventCallback` in `ScrollEngine.swift` line 520-522: `if engine.shouldBypassAllEvents?() == true { return Unmanaged.passUnretained(event) }` placed before the switch — all event types bypassed |
| 2 | Switching away from an excluded app restores scroll mode immediately | VERIFIED | `AppExclusionManager` observes `NSWorkspace.didActivateApplicationNotification` and calls `checkFrontmostApp()` on every app switch. Callback fires only when state changes (guard in `updateState`) |
| 3 | Menu bar icon shows a slash overlay when scroll mode is bypassed due to excluded app | VERIFIED | `makeSlashedMenuBarIcon()` in `MenuBarManager.swift` draws diagonal slash (3,2)→(15,16) with lineWidth 1.5. `applyIconState()` uses it when `isActive && isExcludedApp` |
| 4 | Menu bar tooltip shows which app is excluded | VERIFIED | `applyIconState()` line 75: `button.toolTip = "Scroll mode paused \u{2014} \(excludedAppDisplayName ?? "App") is excluded"` |
| 5 | Exclusion list persists across app restarts | VERIFIED | `AppExclusionManager.init()` loads from `UserDefaults.standard.stringArray(forKey: "excludedAppBundleIDs")`. `save()` writes on every add/remove/clearAll |
| 6 | User can add an app via + button / NSOpenPanel filtered to .app bundles | VERIFIED | `addExcludedAppViaPanel()` in `SettingsView.swift`: `NSOpenPanel` with `allowedContentTypes = [.application]`, starts in `/Applications`, reads `Bundle(url:)?.bundleIdentifier` |
| 7 | User can remove an app via – button | VERIFIED | Minus button in `SettingsView.swift` calls `appState.removeExcludedApp(bundleID: selected)`, clears `selectedExcludedApp` after removal. Disabled when nothing selected |
| 8 | Exclusion list displays each app with its icon and display name | VERIFIED | `iconForBundleID()` uses `NSWorkspace.shared.icon(forFile:)` with fallback. `displayNameForBundleID()` reads `CFBundleDisplayName`/`CFBundleName` from bundle, falls back to bundleID. Both used in `ForEach` rows |
| 9 | Empty exclusion list shows "No excluded apps" placeholder | VERIFIED | `SettingsView.swift` line 134-136: `if appState.excludedAppBundleIDs.isEmpty { Text("No excluded apps").foregroundStyle(.secondary) }` |
| 10 | Adding a duplicate app is silently ignored | VERIFIED | `AppExclusionManager.add(bundleID:)` line 46: `guard !storedBundleIDs.contains(bundleID) else { return }` |

**Score:** 10/10 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `ScrollMyMac/Services/AppExclusionManager.swift` | Frontmost app detection and exclusion list management | VERIFIED | 121 lines (min_lines: 60). NSWorkspace observer, UserDefaults persistence, add/remove/clearAll, onExclusionStateChanged callback, isFrontmostExcluded, recheckFrontmostApp |
| `ScrollMyMac/App/AppState.swift` | Exclusion list persistence and service wiring | VERIFIED | `appExclusionManager` instantiated, `excludedAppBundleIDs` stored property, `isCurrentAppExcluded`, `excludedAppName`, `addExcludedApp`, `removeExcludedApp`, wired in `setupServices()`, `resetToDefaults()` calls `clearAll()` |
| `ScrollMyMac/Services/ScrollEngine.swift` | Exclusion bypass via shouldBypassAllEvents callback | VERIFIED | `var shouldBypassAllEvents: (() -> Bool)?` at line 30. Called in C callback at line 520 before the event-type switch |
| `ScrollMyMac/Services/MenuBarManager.swift` | Slash icon overlay and contextual tooltip | VERIFIED | `updateExclusionState(isExcluded:appName:)`, `makeSlashedMenuBarIcon()`, `applyIconState()` with all three state branches |
| `ScrollMyMac/Features/Settings/SettingsView.swift` | Exclusion list UI section with add/remove | VERIFIED | "Excluded Apps" Section at bottom of Form; ForEach rows with icon/name; +/- buttons; NSOpenPanel; `UniformTypeIdentifiers` imported |
| `ScrollMyMac.xcodeproj/project.pbxproj` | AppExclusionManager.swift registered in Xcode project | VERIFIED | PBXBuildFile and PBXFileReference entries present; file appears in Sources build phase |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `AppExclusionManager.swift` | `AppState.swift` | `onExclusionStateChanged` callback | WIRED | `onExclusionStateChanged` property defined in AppExclusionManager line 24; assigned in AppState `setupServices()` line 179; fires with `(isExcluded, appName)` |
| `AppState.swift` | `ScrollEngine.swift` | `shouldBypassAllEvents` closure | WIRED | `scrollEngine.shouldBypassAllEvents` assigned in `setupServices()` line 175-177; returns `appExclusionManager.isFrontmostExcluded`; checked in C callback before event switch |
| `AppState.swift` | `MenuBarManager.swift` | `updateExclusionState` and `updateIcon` calls | WIRED | Called in `onExclusionStateChanged` closure (line 183) and in `isScrollModeActive` didSet (lines 15-16) |
| `SettingsView.swift` | `AppState.swift` | `addExcludedApp` and `removeExcludedApp` calls | WIRED | Plus button calls `appState.addExcludedApp(bundleID:)` (line 289); minus button calls `appState.removeExcludedApp(bundleID:)` (line 172) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| EXCL-01 | 12-01-PLAN.md | User can add apps to an exclusion list where scroll mode is automatically disabled | SATISFIED | `AppExclusionManager.add(bundleID:)` persists to UserDefaults; `ScrollEngine.shouldBypassAllEvents` bypasses all mouse events; UI + button calls `addExcludedApp` |
| EXCL-02 | 12-01-PLAN.md | User can remove apps from the exclusion list | SATISFIED | `AppExclusionManager.remove(bundleID:)` removes and persists; `AppState.removeExcludedApp` updates stored property; UI minus button invokes it |
| EXCL-03 | 12-02-PLAN.md | Exclusion list is managed in the settings UI | SATISFIED | "Excluded Apps" section in `MainSettingsView` with full CRUD: add via NSOpenPanel, remove via minus button, display with icon and name, empty state |

All three requirement IDs declared across plans are accounted for. No orphaned requirements found in REQUIREMENTS.md for Phase 12.

### Anti-Patterns Found

No anti-patterns detected in any modified file:
- `AppExclusionManager.swift`: no TODO/FIXME, no stub implementations, no empty returns
- `ScrollEngine.swift`: no TODO/FIXME, bypass is real (returns event unmodified, not nil)
- `AppState.swift`: no TODO/FIXME, all methods fully delegating
- `MenuBarManager.swift`: no TODO/FIXME, all three state branches in `applyIconState()` are substantive
- `SettingsView.swift`: no TODO/FIXME, panel and row actions are fully wired

### Build Verification

`xcodebuild -project ScrollMyMac.xcodeproj -scheme ScrollMyMac build` -- **BUILD SUCCEEDED**

### Human Verification Required

#### 1. Exclusion bypass in excluded app

**Test:** Add an app (e.g., TextEdit) to the exclusion list in Settings. Enable scroll mode. Switch to that app. Try clicking and dragging — clicks should behave normally, not trigger scrolling.
**Expected:** Clicks and drags in TextEdit work normally. Menu bar icon shows a diagonal slash through the mouse icon. Hovering over the icon shows "Scroll mode paused — TextEdit is excluded".
**Why human:** CGEventTap pass-through and menu bar icon visual appearance can only be confirmed at runtime.

#### 2. App-switch restores scroll mode

**Test:** With scroll mode on and an app excluded, switch away from the excluded app to a normal app. Try scrolling in the normal app.
**Expected:** Menu bar icon returns to the normal mouse icon (no slash). Scroll mode works normally (clicks-and-drags produce scroll events).
**Why human:** NSWorkspace notification timing and live menu bar icon transition require runtime observation.

#### 3. Exclusion list persistence across restarts

**Test:** Add an app to the exclusion list. Quit Scroll My Mac completely. Relaunch it. Open Settings.
**Expected:** The excluded app still appears in the Excluded Apps list.
**Why human:** UserDefaults persistence only verifiable across two separate process lifetimes.

### Gaps Summary

No gaps. All automated checks pass. Three human verification items remain, but none represent a code defect — they confirm runtime behavior that cannot be verified by static analysis.

---

_Verified: 2026-02-17_
_Verifier: Claude (gsd-verifier)_
