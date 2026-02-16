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

## v1.1 Requirements

Requirements for OSK compatibility milestone. Each maps to roadmap phases.

### OSK Compatibility

- [ ] **OSK-01**: Clicks pass through immediately when cursor is over the Accessibility Keyboard window (no hold-and-decide delay)
- [ ] **OSK-02**: OSK window detection uses cached bounds from periodic CGWindowListCopyWindowInfo polling (never called in event tap callback)
- [ ] **OSK-03**: Detection works regardless of OSK window position (supports repositioning)
- [ ] **OSK-04**: Scroll mode remains toggled on while OSK clicks pass through
- [ ] **OSK-05**: OSK process name is verified empirically at runtime before hardcoding detection logic

## Future Requirements

Deferred to future release. Tracked but not in current roadmap.

### Customization

- **SCRL-05**: Adjustable scroll speed (slider to control sensitivity)
- **SCRL-06**: Directional preference (natural vs traditional scroll direction)
- **APP-04**: Per-app exclusion list (disable scroll mode for specific apps)

### Extended Exclusions

- **EXCL-01**: User can add custom apps/windows to the click pass-through exclusion list
- **EXCL-02**: Third-party on-screen keyboard support

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
| Configurable exclusion list | Keep v1.1 focused — hardcode OSK detection only |
| Third-party OSK support | Defer until user need is established |
| Visual indicator for pass-through zones | Zero config, transparent behavior preferred |

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
| OSK-01 | — | Pending |
| OSK-02 | — | Pending |
| OSK-03 | — | Pending |
| OSK-04 | — | Pending |
| OSK-05 | — | Pending |

**Coverage:**
- v1.0 requirements: 13 total (all complete)
- v1.1 requirements: 5 total
- Mapped to phases: 0
- Unmapped: 5 ⚠️

---
*Requirements defined: 2026-02-14*
*Last updated: 2026-02-16 after v1.1 milestone definition*
