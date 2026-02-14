# Requirements: Scroll My Mac

**Defined:** 2026-02-14
**Core Value:** Users can scroll any scrollable area by clicking and dragging with the mouse pointer, with natural inertia — no scroll wheel or trackpad required.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Core Scrolling

- [ ] **SCRL-01**: User can scroll any scrollable area by clicking and dragging the mouse in scroll mode
- [ ] **SCRL-02**: Scrolling works in all directions (vertical and horizontal)
- [ ] **SCRL-03**: Clicking without significant movement (~8px) passes through as a normal click
- [ ] **SCRL-04**: Releasing a drag produces iOS-style inertia — momentum proportional to drag speed with natural deceleration

### Activation

- [ ] **ACTV-01**: User can toggle scroll mode on/off via a global hotkey
- [ ] **ACTV-02**: Visual indicator shows when scroll mode is active (cursor change or alternative)
- [ ] **ACTV-03**: User can configure their preferred hotkey combination in settings

### Safety

- [ ] **SAFE-01**: Pressing Escape always exits scroll mode regardless of other state
- [ ] **SAFE-02**: Stationary clicks always pass through as normal clicks in scroll mode
- [ ] **SAFE-03**: App gracefully handles Accessibility permission revocation without freezing input

### App & Permissions

- [ ] **APP-01**: App detects Accessibility permission state and guides user through granting it
- [ ] **APP-02**: Simple GUI window with on/off toggle and settings
- [ ] **APP-03**: Option to launch at login

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Customization

- **SCRL-05**: Adjustable scroll speed (slider to control sensitivity)
- **SCRL-06**: Directional preference (natural vs traditional scroll direction)
- **APP-04**: Per-app exclusion list (disable scroll mode for specific apps)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Menu bar app | User prefers simple window app |
| Hold-modifier activation | Toggle hotkey is simpler and sufficient |
| Audio feedback on toggle | Not essential; visual indicator covers this |
| Visual overlay indicator | Cursor change or alternative sufficient |
| CLI-only version | GUI selected for ease of use |
| Multi-button support | Left click only for v1 |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SCRL-01 | — | Pending |
| SCRL-02 | — | Pending |
| SCRL-03 | — | Pending |
| SCRL-04 | — | Pending |
| ACTV-01 | — | Pending |
| ACTV-02 | — | Pending |
| ACTV-03 | — | Pending |
| SAFE-01 | — | Pending |
| SAFE-02 | — | Pending |
| SAFE-03 | — | Pending |
| APP-01 | — | Pending |
| APP-02 | — | Pending |
| APP-03 | — | Pending |

**Coverage:**
- v1 requirements: 13 total
- Mapped to phases: 0
- Unmapped: 13 ⚠️

---
*Requirements defined: 2026-02-14*
*Last updated: 2026-02-14 after initial definition*
