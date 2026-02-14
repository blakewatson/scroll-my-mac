---
phase: 01-permissions-app-shell
plan: 01
subsystem: ui
tags: [swiftui, macos, accessibility, xcode, appkit, permissions]

# Dependency graph
requires: []
provides:
  - Xcode project with unsandboxed macOS app shell targeting macOS 14+
  - Window lifecycle (close hides, dock reopens, no quit on last window close)
  - Accessibility permission detection with 1s polling via AXIsProcessTrusted
  - Permission setup onboarding flow with guided UI
  - AppState with scroll mode toggle, safety mode toggle, permission state
  - PermissionManager service for permission checking and System Settings deep link
affects: [02-settings-ui, 02-event-tap, 03-scroll-engine]

# Tech tracking
tech-stack:
  added: [SwiftUI, AppKit, ApplicationServices]
  patterns: [WindowGroup+NSApplicationDelegateAdaptor, Observable-macro, AXIsProcessTrusted-polling, hide-instead-of-close]

key-files:
  created:
    - ScrollMyMac/ScrollMyMacApp.swift
    - ScrollMyMac/App/AppDelegate.swift
    - ScrollMyMac/App/AppState.swift
    - ScrollMyMac/Services/PermissionManager.swift
    - ScrollMyMac/Features/Settings/SettingsView.swift
    - ScrollMyMac/Features/Settings/PermissionSetupView.swift
    - ScrollMyMac.xcodeproj/project.pbxproj
    - ScrollMyMac/Resources/Info.plist
    - ScrollMyMac/ScrollMyMac.entitlements
  modified: []

key-decisions:
  - "Used manually-crafted pbxproj instead of xcodegen or swift package -- most reliable from CLI"
  - "Safety mode toggle uses manual Binding with UserDefaults since @ObservationIgnored properties cannot use @Bindable"
  - "PermissionSetupView offers both Grant Permission (system prompt) and Open System Settings (deep link) buttons"

patterns-established:
  - "WindowGroup + NSApplicationDelegateAdaptor for close-hides-window lifecycle"
  - "@Observable classes for state management (AppState, PermissionManager)"
  - "Conditional view switching based on permission + onboarding state"
  - "1-second Timer polling for permission detection with auto-stop on grant"

# Metrics
duration: 3min
completed: 2026-02-14
---

# Phase 1 Plan 1: Xcode Project, App Shell, and Permission Flow Summary

**Unsandboxed macOS SwiftUI app with Accessibility permission detection, 1s polling, guided onboarding UI, and close-hides-window lifecycle**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-14T23:24:25Z
- **Completed:** 2026-02-14T23:27:37Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments
- Xcode project compiles and produces a buildable .app with hardened runtime, unsandboxed, macOS 14+
- Window lifecycle: closing hides window (preserves state), dock click reopens, app stays running in background
- PermissionManager polls AXIsProcessTrusted every 1 second, auto-stops on grant, supports System Settings deep link
- PermissionSetupView guides user through Accessibility permission grant with numbered steps and two action buttons
- SettingsView conditionally shows onboarding or main settings based on permission + hasCompletedOnboarding state
- AppState persists safety mode and onboarding state via UserDefaults

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Xcode project and app entry point with window lifecycle** - `864c8de` (feat)
2. **Task 2: Implement AppState, PermissionManager, and permission UI views** - `5cf3cca` (feat)

## Files Created/Modified
- `ScrollMyMac/ScrollMyMacApp.swift` - @main App entry point with WindowGroup and NSApplicationDelegateAdaptor
- `ScrollMyMac/App/AppDelegate.swift` - Window lifecycle: close hides, dock reopens, applicationWillBecomeActive fallback
- `ScrollMyMac/App/AppState.swift` - @Observable state: scroll mode, safety mode (persisted), permission state, onboarding (persisted)
- `ScrollMyMac/Services/PermissionManager.swift` - AXIsProcessTrusted polling, requestPermission, openAccessibilitySettings
- `ScrollMyMac/Features/Settings/SettingsView.swift` - Root view with conditional permission setup vs main settings display
- `ScrollMyMac/Features/Settings/PermissionSetupView.swift` - Onboarding UI with steps, buttons, auto-detection caption
- `ScrollMyMac.xcodeproj/project.pbxproj` - Xcode project configuration
- `ScrollMyMac/Resources/Info.plist` - NSAccessibilityUsageDescription
- `ScrollMyMac/ScrollMyMac.entitlements` - App Sandbox disabled

## Decisions Made
- Used manually-crafted pbxproj rather than xcodegen or SPM since direct file creation is more reliable from CLI
- Safety mode toggle uses explicit Binding(get:set:) wrapper because @ObservationIgnored properties on @Observable classes are not compatible with @Bindable -- this is a Swift Observation framework limitation
- Provided both "Grant Permission" (triggers system prompt via AXIsProcessTrustedWithOptions) and "Open System Settings" (deep link) buttons for flexibility

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- xcode-select was pointed at CommandLineTools instead of Xcode.app; worked around by setting DEVELOPER_DIR environment variable to use Xcode's xcodebuild directly (no sudo available)

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- App shell is complete and compiling, ready for Plan 02 (full settings UI, safety timeout manager)
- PermissionManager is ready for use by event tap code in Phase 2
- AppState scroll mode toggle exists but is not wired to functionality (Phase 2)

## Self-Check: PASSED

- All 9 created files verified on disk
- Commit `864c8de` (Task 1) verified in git log
- Commit `5cf3cca` (Task 2) verified in git log

---
*Phase: 01-permissions-app-shell*
*Completed: 2026-02-14*
