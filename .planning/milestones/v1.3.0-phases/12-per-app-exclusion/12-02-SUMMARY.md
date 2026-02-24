---
phase: 12-per-app-exclusion
plan: 02
subsystem: ui
tags: [swiftui, nsopenpanel, nsworkspace, settings, exclusion-list]

# Dependency graph
requires:
  - phase: 12-per-app-exclusion plan 01
    provides: AppExclusionManager, AppState add/removeExcludedApp methods, excludedAppBundleIDs
provides:
  - Exclusion list management UI in Settings with add/remove via NSOpenPanel
affects: []

# Tech tracking
tech-stack:
  added: [UniformTypeIdentifiers]
  patterns: [NSOpenPanel for .app bundle selection, NSWorkspace bundle ID resolution for icon and display name]

key-files:
  created: []
  modified:
    - ScrollMyMac/Features/Settings/SettingsView.swift

key-decisions:
  - "excludedAppBundleIDs changed from computed to stored @Published property for SwiftUI reactivity"
  - "Full-width rows with expanded click areas for better usability"

patterns-established:
  - "NSOpenPanel with UTType.application filter for app selection in SwiftUI settings"
  - "Bundle ID to icon/name resolution via NSWorkspace.shared.urlForApplication(withBundleIdentifier:)"

requirements-completed: [EXCL-03]

# Metrics
duration: 15min
completed: 2026-02-17
---

# Phase 12 Plan 02: Per-App Exclusion Settings UI Summary

**Exclusion list management UI in Settings with NSOpenPanel app picker, icon/name display, and add/remove controls**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-02-17
- **Completed:** 2026-02-17
- **Tasks:** 2 (1 auto + 1 human-verify checkpoint)
- **Files modified:** 1

## Accomplishments
- Added "Excluded Apps" section at bottom of Settings view with app icon and display name per row
- Implemented + button that opens NSOpenPanel filtered to .app bundles starting in /Applications
- Implemented - button to remove selected app from exclusion list
- Empty state shows "No excluded apps" placeholder
- Full end-to-end verification: exclusion bypass, menu bar slash icon, persistence across restarts

## Task Commits

Each task was committed atomically:

1. **Task 1: Add exclusion list section to SettingsView** - `64260f1` (feat)
2. **Task 2: Verify per-app exclusion end-to-end** - human-verify checkpoint (approved)

**Post-verification fixes:**
- `0d19c66` fix(12): make excludedAppBundleIDs a stored property for SwiftUI reactivity
- `64d5e4c` fix(12): make exclusion list rows full-width for click area and selection highlight
- `1292fb6` fix(12): enlarge hit area for exclusion list +/- buttons
- `989d838` fix(12): expand clickable area of excluded app rows
- `b1982c1` fix(12): adjust excluded app row spacing

## Files Created/Modified
- `ScrollMyMac/Features/Settings/SettingsView.swift` - Added "Excluded Apps" section with list, +/- buttons, NSOpenPanel integration, app icon/name resolution

## Decisions Made
- Changed excludedAppBundleIDs from computed property to stored @Published property so SwiftUI observes changes correctly
- Expanded row click areas and button hit targets for better macOS usability

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] SwiftUI not reacting to exclusion list changes**
- **Found during:** Task 2 verification
- **Issue:** excludedAppBundleIDs was a computed property forwarding to AppExclusionManager; SwiftUI did not detect changes
- **Fix:** Changed to a stored @Published property updated via callback from AppExclusionManager
- **Files modified:** ScrollMyMac/App/AppState.swift
- **Committed in:** 0d19c66

**2. [Rule 1 - Bug] Exclusion list rows had small click targets**
- **Found during:** Task 2 verification
- **Issue:** Rows and buttons were difficult to click due to narrow hit areas
- **Fix:** Made rows full-width with contentShape, enlarged button hit areas
- **Files modified:** ScrollMyMac/Features/Settings/SettingsView.swift
- **Committed in:** 64d5e4c, 1292fb6, 989d838, b1982c1

---

**Total deviations:** 2 auto-fixed (2 bugs)
**Impact on plan:** Both fixes necessary for correct SwiftUI reactivity and usable click targets. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Per-app exclusion feature is complete (engine + UI)
- Phase 12 is the final phase -- all planned features are now implemented
- Project is feature-complete per the roadmap

## Self-Check: PASSED

- SUMMARY.md: FOUND
- Commit 64260f1: FOUND
- Commit 0d19c66: FOUND
- Commit 64d5e4c: FOUND
- Commit 1292fb6: FOUND
- Commit 989d838: FOUND
- Commit b1982c1: FOUND

---
*Phase: 12-per-app-exclusion*
*Completed: 2026-02-17*
