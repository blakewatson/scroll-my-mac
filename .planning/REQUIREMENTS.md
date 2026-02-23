# Requirements: Scroll My Mac

**Defined:** 2026-02-14
**Core Value:** Users can scroll any scrollable area by clicking and dragging with the mouse pointer, with natural inertia — no scroll wheel or trackpad required.

## v1.0 Requirements (Shipped)

### Core Scrolling

- [x] **SCRL-01**: User can scroll any scrollable area by clicking and dragging the mouse in scroll mode
- [x] **SCRL-02**: Scrolling works in all directions (vertical and horizontal)
- [x] **SCRL-03**: Clicking without significant movement (~8px) passes through as a normal click
- [x] **SCRL-04**: Releasing a drag produces iOS-style inertia — momentum proportional to drag speed with natural deceleration

### Activation

- [x] **ACTV-01**: User can toggle scroll mode on/off via a global hotkey
- [x] **ACTV-02**: Visual indicator shows when scroll mode is active (cursor change or alternative)
- [x] **ACTV-03**: User can configure their preferred hotkey combination in settings

### Safety

- [x] **SAFE-01**: Pressing Escape always exits scroll mode regardless of other state
- [x] **SAFE-02**: Stationary clicks always pass through as normal clicks in scroll mode
- [x] **SAFE-03**: App gracefully handles Accessibility permission revocation without freezing input

### App & Permissions

- [x] **APP-01**: App detects Accessibility permission state and guides user through granting it
- [x] **APP-02**: Simple GUI window with on/off toggle and settings
- [x] **APP-03**: Option to launch at login

## v1.1 Requirements (Shipped)

### OSK Compatibility

- [x] **OSK-01**: Clicks pass through immediately when cursor is over the Accessibility Keyboard window (no hold-and-decide delay)
- [x] **OSK-02**: OSK window detection uses cached bounds from periodic CGWindowListCopyWindowInfo polling (never called in event tap callback)
- [x] **OSK-03**: Detection works regardless of OSK window position (supports repositioning)
- [x] **OSK-04**: Scroll mode remains toggled on while OSK clicks pass through
- [x] **OSK-05**: OSK process name is verified empirically at runtime before hardcoding detection logic

## v1.2 Requirements (Shipped)

### Icon

- [x] **ICON-01**: App has a properly formatted macOS AppIcon.appiconset (all required sizes generated from source image)
- [x] **ICON-02**: Icon appears correctly in Dock, Finder, and app switcher

### Signing

- [x] **SIGN-01**: App is signed with Developer ID Application certificate
- [x] **SIGN-02**: App is notarized with Apple (stapled notarization ticket)
- [x] **SIGN-03**: App opens without Gatekeeper warnings on a clean machine

### Release

- [x] **REL-01**: Build produces a zipped .app bundle ready for distribution
- [x] **REL-02**: Release is published on GitHub with version tag and release notes

### Documentation

- [x] **DOC-01**: README.md explains what the app is, what it does, and why it exists
- [x] **DOC-02**: README includes personal motivation (accessibility need)
- [x] **DOC-03**: README includes AI-assisted development disclaimer

## v1.3.0 Requirements (Shipped)

### Menu Bar Icon

- [x] **MBAR-01**: User can see scroll mode state (on/off) via a menu bar icon
- [x] **MBAR-02**: User can toggle scroll mode by clicking the menu bar icon
- [x] **MBAR-03**: User can access settings window via right-click context menu on the menu bar icon
- [x] **MBAR-04**: User can disable the menu bar icon in settings

### Hold-to-Passthrough

- [x] **PASS-01**: User can hold still within the dead zone for a configurable delay to pass through the click for normal drag operations (text select, window resize)
- [x] **PASS-02**: User can enable/disable hold-to-passthrough in settings (off by default)
- [x] **PASS-03**: User can configure the hold delay duration in settings (default 1.5s)

### Per-App Exclusion

- [x] **EXCL-01**: User can add apps to an exclusion list where scroll mode is automatically disabled
- [x] **EXCL-02**: User can remove apps from the exclusion list
- [x] **EXCL-03**: Exclusion list is managed in the settings UI

## v1.4 Requirements

Requirements for this milestone. Each maps to roadmap phases.

### Inertia Control

- [x] **INRT-01**: User can toggle inertia on/off in settings (enabled by default)
- [x] **INRT-02**: User can adjust inertia intensity via a slider (weaker ↔ stronger) controlling coasting speed and duration
- [x] **INRT-03**: When inertia is disabled, releasing a drag stops scrolling immediately with no coasting

### Scroll Direction

- [x] **SDIR-01**: User can toggle scroll direction between natural (default) and inverted in settings
- [x] **SDIR-02**: When inverted, drag direction is flipped (drag down → content moves down instead of up)

### Click-Through Hotkey

- [x] **CTHK-01**: User can configure a hotkey to toggle click-through mode on/off
- [x] **CTHK-02**: Click-through hotkey uses the same key recorder UI as the scroll mode hotkey
- [x] **CTHK-03**: Toggling click-through via hotkey updates the setting persistently (same as changing it in settings)

## Future Requirements

Deferred to future release. Tracked but not in current roadmap.

### Customization

- **SCRL-05**: Adjustable scroll speed (slider to control sensitivity)

### Extended Exclusions

- **EXCL-04**: Third-party on-screen keyboard support

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Hold-modifier activation | Toggle hotkey is simpler and sufficient |
| Audio feedback on toggle | Not essential; visual indicator covers this |
| CLI-only version | GUI selected for ease of use |
| Multi-button support | Left click only for v1 |
| Third-party OSK support | Defer until user need is established |
| .dmg installer | Zip is sufficient for initial release |
| Homebrew cask | Defer until user demand exists |
| CI/CD automation | Manual build process is fine for now |
| Menu bar as primary settings UI | Menu bar icon is toggle + shortcut to settings only |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SCRL-01 | Phase 2 | Complete |
| SCRL-02 | Phase 2 | Complete |
| SCRL-03 | Phase 3 | Complete |
| SCRL-04 | Phase 4 | Complete |
| ACTV-01 | Phase 2 | Complete |
| ACTV-02 | Phase 2 | Complete |
| ACTV-03 | Phase 5 | Complete |
| SAFE-01 | Phase 3 | Complete |
| SAFE-02 | Phase 3 | Complete |
| SAFE-03 | Phase 3 | Complete |
| APP-01 | Phase 1 | Complete |
| APP-02 | Phase 1 | Complete |
| APP-03 | Phase 5 | Complete |
| OSK-01 | Phase 6 | Complete |
| OSK-02 | Phase 6 | Complete |
| OSK-03 | Phase 6 | Complete |
| OSK-04 | Phase 6 | Complete |
| OSK-05 | Phase 6 | Complete |
| ICON-01 | Phase 7 | Complete |
| ICON-02 | Phase 7 | Complete |
| SIGN-01 | Phase 8 | Complete |
| SIGN-02 | Phase 8 | Complete |
| SIGN-03 | Phase 8 | Complete |
| REL-01 | Phase 9 | Complete |
| REL-02 | Phase 9 | Complete |
| DOC-01 | Phase 9 | Complete |
| DOC-02 | Phase 9 | Complete |
| DOC-03 | Phase 9 | Complete |
| MBAR-01 | Phase 10 | Complete |
| MBAR-02 | Phase 10 | Complete |
| MBAR-03 | Phase 10 | Complete |
| MBAR-04 | Phase 10 | Complete |
| PASS-01 | Phase 11 | Complete |
| PASS-02 | Phase 11 | Complete |
| PASS-03 | Phase 11 | Complete |
| EXCL-01 | Phase 12 | Complete |
| EXCL-02 | Phase 12 | Complete |
| EXCL-03 | Phase 12 | Complete |
| INRT-01 | Phase 13 | Complete |
| INRT-02 | Phase 13 | Complete |
| INRT-03 | Phase 13 | Complete |
| SDIR-01 | Phase 14 | Complete |
| SDIR-02 | Phase 14 | Complete |
| CTHK-01 | Phase 15 | Complete |
| CTHK-02 | Phase 15 | Complete |
| CTHK-03 | Phase 15 | Complete |

**Coverage:**
- v1.0 requirements: 13 total (all complete)
- v1.1 requirements: 5 total (all complete)
- v1.2 requirements: 10 total (all complete)
- v1.3.0 requirements: 10 total (all complete)
- v1.4 requirements: 8 total
- Mapped to phases: 8/8
- Unmapped: 0

---
*Requirements defined: 2026-02-14*
*Last updated: 2026-02-22 after v1.4 roadmap created*
