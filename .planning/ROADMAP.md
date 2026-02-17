# Roadmap: Scroll My Mac

## Overview

This roadmap delivers a macOS accessibility app that converts click-and-drag into scrolling system-wide. The journey starts with permissions and app scaffolding, builds core scroll functionality, hardens click safety, adds inertia polish, and finishes with user-facing settings. v1.1 extends the app with Accessibility Keyboard awareness so typing on the on-screen keyboard is uninterrupted by scroll mode. v1.2 packages the app for public distribution with a custom icon, code signing, notarization, and a GitHub release with documentation.

## Milestones

- **v1.0 MVP** - Phases 1-5 (shipped 2026-02-16)
- **v1.1 OSK Compat** - Phase 6 (shipped 2026-02-16)
- **v1.2 Distribution Ready** - Phases 7-9 (in progress)

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

<details>
<summary>v1.0 MVP (Phases 1-5) - SHIPPED 2026-02-16</summary>

- [x] **Phase 1: Permissions & App Shell** - Accessibility permission flow and basic SwiftUI window
- [x] **Phase 2: Core Scroll Mode** - Drag-to-scroll with hotkey toggle and visual indicator
- [x] **Phase 3: Click Safety** - Click-through detection, escape bail-out, and graceful error handling
- [x] **Phase 4: Inertia** - Momentum scrolling with natural deceleration
- [x] **Phase 5: Settings & Polish** - Hotkey customization and launch at login

### Phase 1: Permissions & App Shell
**Goal**: User can launch the app, grant Accessibility permissions with guidance, and see a functional main window
**Depends on**: Nothing (first phase)
**Requirements**: APP-01, APP-02
**Success Criteria** (what must be TRUE):
  1. App launches as an unsandboxed macOS app with a visible main window
  2. App detects whether Accessibility permission is granted and shows clear status
  3. If permission is missing, app guides the user to System Settings and detects grant automatically (no restart needed)
  4. Main window shows an on/off toggle for scroll mode (toggle wired up in Phase 2)
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md — Xcode project, app shell, window lifecycle, permission detection and onboarding UI
- [x] 01-02-PLAN.md — Full settings view with scroll mode toggle, safety timeout manager

### Phase 2: Core Scroll Mode
**Goal**: User can toggle scroll mode via hotkey and scroll any area by clicking and dragging
**Depends on**: Phase 1
**Requirements**: SCRL-01, SCRL-02, ACTV-01, ACTV-02
**Success Criteria** (what must be TRUE):
  1. User can press a hotkey to toggle scroll mode on and off
  2. In scroll mode, clicking and dragging scrolls the content under the cursor
  3. Scrolling works in all directions (up, down, left, right)
  4. A visual indicator (cursor change or alternative) shows when scroll mode is active vs inactive
  5. The on/off toggle in the main window reflects and controls scroll mode state
**Plans**: 2 plans

Plans:
- [x] 02-01-PLAN.md — ScrollEngine (CGEventTap drag-to-scroll) and HotkeyManager (F6 global hotkey)
- [x] 02-02-PLAN.md — OverlayManager (floating indicator dot), service wiring, UI toggle activation

### Phase 3: Click Safety
**Goal**: User can safely click things while scroll mode is active
**Depends on**: Phase 2
**Requirements**: SCRL-03, SAFE-01, SAFE-02, SAFE-03
**Success Criteria** (what must be TRUE):
  1. Clicking without significant movement (~8px) passes through as a normal click
  2. Stationary clicks (no movement at all) always pass through as normal clicks
  3. If Accessibility permission is revoked while the app is running, the app disables scroll mode gracefully without freezing input
**Plans**: 2 plans

Plans:
- [x] 03-01-PLAN.md — Hold-and-decide click-through in ScrollEngine, modifier/double-click pass-through, click-through setting in UI
- [x] 03-02-PLAN.md — Permission health check polling, mid-toggle/mid-drag cleanup, graceful permission revocation handling

### Phase 4: Inertia
**Goal**: Released drags produce natural momentum scrolling that feels like iOS/trackpad
**Depends on**: Phase 3
**Requirements**: SCRL-04
**Success Criteria** (what must be TRUE):
  1. Releasing a drag at speed produces continued scrolling with gradual deceleration
  2. Faster drags produce more momentum; slow drags produce little or no momentum
  3. Inertia scrolling feels smooth (frame-synchronized, no stuttering or jumping)
**Plans**: 2 plans

Plans:
- [x] 04-01-PLAN.md — VelocityTracker, InertiaAnimator (CADisplayLink + exponential decay), ScrollEngine integration
- [x] 04-02-PLAN.md — Axis-lock settings toggle, full inertia behavior verification

### Phase 5: Settings & Polish
**Goal**: User can customize their hotkey and have the app start automatically at login
**Depends on**: Phase 4
**Requirements**: ACTV-03, APP-03
**Success Criteria** (what must be TRUE):
  1. User can open settings and change their hotkey to any supported key or modifier combination
  2. User can enable "launch at login" and the app starts automatically on next login
  3. Changed settings persist across app restarts
**Plans**: 2 plans

Plans:
- [x] 05-01-PLAN.md — Hotkey customization: key recorder UI, display helper, AppState persistence, HotkeyManager wiring
- [x] 05-02-PLAN.md — Settings consolidation, launch at login, silent background launch, reset to defaults

</details>

<details>
<summary>v1.1 OSK Compat (Phase 6) - SHIPPED 2026-02-16</summary>

- [x] **Phase 6: OSK-Aware Click Pass-Through** - Detect Accessibility Keyboard window and bypass scroll engine for clicks over it

### Phase 6: OSK-Aware Click Pass-Through
**Goal**: Clicks over the Accessibility Keyboard pass through instantly so typing is never interrupted by scroll mode
**Depends on**: Phase 5 (v1.0 complete)
**Requirements**: OSK-01, OSK-02, OSK-03, OSK-04, OSK-05
**Success Criteria** (what must be TRUE):
  1. With scroll mode on, clicking anywhere on the Accessibility Keyboard immediately registers as a normal click (no hold-and-decide delay, no scroll initiation)
  2. Moving or resizing the Accessibility Keyboard does not break pass-through detection (works at any screen position)
  3. Scroll mode remains toggled on while clicks pass through over the OSK -- moving the cursor off the OSK and dragging still scrolls normally
  4. Scrolling outside the OSK area is completely unaffected by the new detection logic
**Plans**: 1 plan

Plans:
- [x] 06-01-PLAN.md — WindowExclusionManager service with OSK detection, AppState integration, human verification

</details>

### v1.2 Distribution Ready (Phases 7-9)

**Milestone Goal:** Package the app for public distribution with a proper icon, code signing, notarization, and a GitHub release with documentation.

- [ ] **Phase 7: App Icon** - Generate macOS icon set from source image and integrate into build
- [ ] **Phase 8: Code Signing & Notarization** - Sign with Developer ID and notarize for Gatekeeper-clean distribution
- [ ] **Phase 9: Release & Documentation** - Write README and publish GitHub release with zipped .app bundle

## Phase Details

### Phase 7: App Icon
**Goal**: App displays its own custom icon everywhere macOS shows it
**Depends on**: Phase 6 (v1.1 complete)
**Requirements**: ICON-01, ICON-02
**Success Criteria** (what must be TRUE):
  1. The Xcode project contains a complete AppIcon.appiconset with all required sizes generated from the source image
  2. The app icon appears correctly in the Dock when the app is running
  3. The app icon appears correctly in Finder and Spotlight
  4. The app icon appears correctly in the app switcher (Cmd+Tab)
**Plans**: 1 plan

Plans:
- [ ] 07-01-PLAN.md — Generate AppIcon.appiconset from source image, wire into Xcode project, verify icon display

### Phase 8: Code Signing & Notarization
**Goal**: App installs and opens on any Mac without Gatekeeper warnings
**Depends on**: Phase 7
**Requirements**: SIGN-01, SIGN-02, SIGN-03
**Success Criteria** (what must be TRUE):
  1. App binary is signed with a Developer ID Application certificate (verifiable via `codesign -v`)
  2. App has a stapled notarization ticket from Apple (verifiable via `stapler validate`)
  3. Double-clicking the app on a clean Mac opens it without any Gatekeeper warning or "unidentified developer" dialog
**Plans**: 1 plan

Plans:
- [ ] 08-01-PLAN.md -- Build-sign-notarize pipeline with Developer ID certificate setup, release script, and Gatekeeper verification

### Phase 9: Release & Documentation
**Goal**: Users can discover, understand, and download the app from GitHub
**Depends on**: Phase 8
**Requirements**: REL-01, REL-02, DOC-01, DOC-02, DOC-03
**Success Criteria** (what must be TRUE):
  1. README.md explains what Scroll My Mac is, what it does, and why it exists (accessibility need)
  2. README.md includes a note about AI-assisted development
  3. A zipped .app bundle is attached to a GitHub release with a version tag
  4. The GitHub release includes release notes describing the app's capabilities
  5. A user can download the zip from GitHub, extract it, and open the app without issues
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Permissions & App Shell | v1.0 | 2/2 | Complete | 2026-02-14 |
| 2. Core Scroll Mode | v1.0 | 2/2 | Complete | 2026-02-15 |
| 3. Click Safety | v1.0 | 2/2 | Complete | 2026-02-15 |
| 4. Inertia | v1.0 | 2/2 | Complete | 2026-02-15 |
| 5. Settings & Polish | v1.0 | 2/2 | Complete | 2026-02-16 |
| 6. OSK-Aware Click Pass-Through | v1.1 | 1/1 | Complete | 2026-02-16 |
| 7. App Icon | v1.2 | 0/? | Not started | - |
| 8. Code Signing & Notarization | v1.2 | 0/? | Not started | - |
| 9. Release & Documentation | v1.2 | 0/? | Not started | - |
