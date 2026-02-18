---
phase: quick-5
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - ScrollMyMac/ScrollMyMacApp.swift
  - ScrollMyMac/App/AppDelegate.swift
  - ScrollMyMac/Services/MenuBarManager.swift
autonomous: true
requirements: [FIX-WINDOW-LAUNCH, FIX-WINDOW-DOUBLE, FIX-MENUBAR-RESTORE]
must_haves:
  truths:
    - "Settings window appears on normal app launch (non-login-item)"
    - "Clicking dock icon when window is hidden shows exactly one window"
    - "Toggling menu bar icon OFF then ON restores the icon in menu bar"
  artifacts:
    - path: "ScrollMyMac/ScrollMyMacApp.swift"
      provides: "Single-window lifecycle management"
    - path: "ScrollMyMac/App/AppDelegate.swift"
      provides: "Window show/reopen handling"
    - path: "ScrollMyMac/Services/MenuBarManager.swift"
      provides: "Status item show/hide/restore"
  key_links:
    - from: "ScrollMyMacApp.swift"
      to: "AppDelegate.swift"
      via: "NSApplicationDelegateAdaptor"
      pattern: "NSApplicationDelegateAdaptor"
---

<objective>
Fix three related window/menu-bar lifecycle bugs:
1. Settings window not showing on normal (non-login-item) launch
2. Settings window appearing twice when clicking dock icon
3. Menu bar icon not restoring after toggling the setting off and back on

Purpose: Correct window and status item lifecycle so the app behaves as expected
Output: Fixed AppDelegate, ScrollMyMacApp, and MenuBarManager
</objective>

<execution_context>
@/Users/blake/.claude/get-shit-done/workflows/execute-plan.md
@/Users/blake/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@ScrollMyMac/ScrollMyMacApp.swift
@ScrollMyMac/App/AppDelegate.swift
@ScrollMyMac/App/AppState.swift
@ScrollMyMac/Services/MenuBarManager.swift
@ScrollMyMac/Features/Settings/SettingsView.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix settings window lifecycle (launch + dock click)</name>
  <files>ScrollMyMac/ScrollMyMacApp.swift, ScrollMyMac/App/AppDelegate.swift</files>
  <action>
Two bugs stem from SwiftUI `WindowGroup` behavior:

**Bug 1 — Window not showing on launch:**
The `WindowGroup` creates the window, but there may be a timing issue where `applicationDidFinishLaunching` runs before SwiftUI has created the window, causing `settingsWindow()` to return nil. The login-item hide logic (`orderOut`) may also fire incorrectly, or the window may not activate properly.

Investigate and fix: Ensure the settings window is visible and focused on normal launch. The `applicationDidFinishLaunching` login-item detection (`getppid() == 1 && SMAppService.mainApp.status == .enabled`) should be the ONLY case where the window is hidden. For all other launches, the window should be key and ordered front. If `settingsWindow()` returns nil in `applicationDidFinishLaunching`, defer the window setup using `DispatchQueue.main.async` to let SwiftUI finish creating the window.

**Bug 2 — Window appearing twice on dock click:**
When the user clicks the dock icon with no visible windows, `applicationShouldHandleReopen` correctly shows the existing window. However, SwiftUI's `WindowGroup` may ALSO respond to the reopen by creating a new window instance, resulting in two windows.

Fix approach: Replace `WindowGroup` with `Window` (single-window scene) in `ScrollMyMacApp.swift`. This prevents SwiftUI from ever creating a second window instance. The `Window` scene type is designed for exactly this use case — a single settings/preferences window.

```swift
// Replace WindowGroup with Window:
var body: some Scene {
    Window("Scroll My Mac", id: "settings") {
        SettingsView()
            .environment(appState)
    }
    .commands {
        CommandGroup(replacing: .newItem) { }
    }
}
```

After switching to `Window`, update `AppDelegate.settingsWindow()` if needed — the window filtering logic should still work, but verify. Also ensure `applicationShouldHandleReopen` still correctly shows the single window on dock click. The `Window` scene type should handle dock reopen automatically, but test both paths.
  </action>
  <verify>
Build the project with `xcodebuild -project ScrollMyMac.xcodeproj -scheme ScrollMyMac build 2>&1 | tail -5` to confirm no compilation errors. Visually inspect the code to confirm: (1) `Window` scene is used instead of `WindowGroup`, (2) login-item hide logic is preserved, (3) dock click shows exactly one window.
  </verify>
  <done>App uses single-window `Window` scene. Normal launch shows settings window. Login-item launch hides window. Dock click with hidden window shows exactly one window (no duplicates).</done>
</task>

<task type="auto">
  <name>Task 2: Fix menu bar icon toggle restore</name>
  <files>ScrollMyMac/Services/MenuBarManager.swift</files>
  <action>
When the user toggles "Show menu bar icon" OFF and back ON, the icon should reappear in the menu bar with correct state (active/inactive/excluded).

The current flow in `AppState.isMenuBarIconEnabled` didSet:
- ON: calls `menuBarManager.show()` then `menuBarManager.updateIcon(isActive:)`
- OFF: calls `menuBarManager.hide()`

`show()` creates a new NSStatusItem with a default icon, then `updateIcon()` applies the correct state. This should work, but investigate the actual failure mode.

Possible issues to check and fix:
1. **NSStatusItem deallocation**: After `hide()` sets `statusItem = nil`, the status item may be deallocated. When `show()` creates a new one, confirm it persists (strong reference in `statusItem` property).
2. **Menu not rebuilt**: `show()` calls `buildMenu()` and sets `menu.delegate = self`. The `toggleItem` reference is reset. Confirm `updateToggleTitle()` works on the new toggle item.
3. **applyIconState timing**: If `updateIcon` sets `self.isActive` which triggers `applyIconState()`, but `statusItem?.button` is nil at that moment (e.g., the status item hasn't finished layout), the icon won't update. Add a guard or defer the icon update.

After identifying and fixing the root cause, ensure `show()` ends with the icon in the correct visual state by calling `applyIconState()` at the end of `show()`:

```swift
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
    applyIconState()  // Apply current active/exclusion state to new item
}
```

This ensures that even if the external `updateIcon` call has a timing issue, the icon is always correct after `show()`.
  </action>
  <verify>
Build the project with `xcodebuild -project ScrollMyMac.xcodeproj -scheme ScrollMyMac build 2>&1 | tail -5` to confirm no compilation errors. Code review: confirm `show()` calls `applyIconState()` after creating the status item.
  </verify>
  <done>Toggling "Show menu bar icon" OFF then ON restores the status item with correct icon state (active/inactive/excluded). The `show()` method applies current state immediately after creating the new status item.</done>
</task>

</tasks>

<verification>
- `xcodebuild build` succeeds with no errors
- `Window` scene type used (not `WindowGroup`) — prevents duplicate windows
- `AppDelegate.settingsWindow()` still finds the single window
- `applicationShouldHandleReopen` shows window on dock click
- Login-item detection hides window on background launch
- `MenuBarManager.show()` applies correct icon state after recreating status item
</verification>

<success_criteria>
- Settings window visible on normal launch
- Exactly one window shown when clicking dock icon (no duplicates)
- Menu bar icon restored with correct state after toggling setting off and on
- Project builds without errors
</success_criteria>

<output>
After completion, create `.planning/quick/5-fix-settings-window-not-showing-on-launc/5-SUMMARY.md`
</output>
