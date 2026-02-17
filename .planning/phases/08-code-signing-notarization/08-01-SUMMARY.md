---
phase: 08-code-signing-notarization
plan: 01
subsystem: infra
tags: [codesign, notarization, gatekeeper, hardened-runtime, xcodebuild]

# Dependency graph
requires:
  - phase: 07-app-icon
    provides: "App icon in asset catalog for distribution-ready app"
provides:
  - "Signed and notarized macOS app binary"
  - "Reproducible build-release.sh script for future releases"
  - "Xcode project configured for manual Developer ID signing"
affects: [09-dmg-github-release]

# Tech tracking
tech-stack:
  added: [codesign, notarytool, stapler, xcodebuild-archive]
  patterns: [release-build-script, manual-code-signing, hardened-runtime]

key-files:
  created: [scripts/build-release.sh]
  modified: [ScrollMyMac.xcodeproj/project.pbxproj]

key-decisions:
  - "Auto-detect Developer ID from keychain rather than hardcoding identity"
  - "Keychain profile for notarytool with env var fallback for CI flexibility"
  - "Re-sign after archive export for belt-and-suspenders hardened runtime"

patterns-established:
  - "Release pipeline: archive -> export -> sign -> notarize -> staple -> zip"
  - "Manual code signing in Xcode project (CODE_SIGN_STYLE = Manual)"

requirements-completed: [SIGN-01, SIGN-02, SIGN-03]

# Metrics
duration: ~30min
completed: 2026-02-16
---

# Phase 8 Plan 1: Code Signing and Notarization Summary

**Reproducible build-release.sh pipeline that archives, signs with Developer ID, notarizes via Apple, and staples the ticket for Gatekeeper-clean distribution**

## Performance

- **Duration:** ~30 min (across multiple sessions with human checkpoints)
- **Started:** 2026-02-16
- **Completed:** 2026-02-16
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments
- Xcode project configured for manual signing with Developer ID Application certificate
- Created `scripts/build-release.sh` covering the full release pipeline: archive, sign, notarize, staple, verify, zip
- App successfully signed, notarized, stapled, and passes Gatekeeper assessment (`spctl` reports "accepted" with Notarized Developer ID)

## Task Commits

Each task was committed atomically:

1. **Task 1: Ensure Developer ID certificate is installed** - (human-action checkpoint, no commit)
2. **Task 2: Create release build-sign-notarize script and update Xcode project** - `a3944e9` (feat)
3. **Task 3: Run build-release script and verify Gatekeeper acceptance** - (human-verify checkpoint, approved)

## Files Created/Modified
- `scripts/build-release.sh` - Full release pipeline: archive, sign with hardened runtime, notarize, staple, verify, create distribution zip
- `ScrollMyMac.xcodeproj/project.pbxproj` - Configured manual code signing with Developer ID Application identity and team ID

## Decisions Made
- Auto-detect Developer ID Application certificate from keychain so the script works without hardcoded identity strings
- Use `xcrun notarytool` keychain profile ("ScrollMyMac") with environment variable fallback for flexibility
- Re-sign the exported .app after archive extraction to guarantee hardened runtime flags are applied

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

**External services required manual configuration.** The user completed:
- Apple Developer Program enrollment (prerequisite)
- Developer ID Application certificate creation and installation via Xcode
- App-specific password for notarization stored as keychain profile

## Next Phase Readiness
- Signed and notarized app binary ready for DMG packaging and GitHub release (Phase 9)
- `scripts/build-release.sh` produces `build/release/ScrollMyMac.zip` for distribution
- No blockers for next phase

## Self-Check: PASSED

- FOUND: scripts/build-release.sh
- FOUND: ScrollMyMac.xcodeproj/project.pbxproj
- FOUND: commit a3944e9
- FOUND: 08-01-SUMMARY.md

---
*Phase: 08-code-signing-notarization*
*Completed: 2026-02-16*
