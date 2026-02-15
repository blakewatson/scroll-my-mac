# Roadmap: Scroll My Mac

## Overview

This roadmap delivers a macOS accessibility app that converts click-and-drag into scrolling system-wide. The journey starts with permissions and app scaffolding, builds core scroll functionality, hardens click safety, adds inertia polish, and finishes with user-facing settings. Each phase produces a testable, progressively more complete app.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Permissions & App Shell** - Accessibility permission flow and basic SwiftUI window
- [ ] **Phase 2: Core Scroll Mode** - Drag-to-scroll with hotkey toggle and visual indicator
- [ ] **Phase 3: Click Safety** - Click-through detection, escape bail-out, and graceful error handling
- [ ] **Phase 4: Inertia** - Momentum scrolling with natural deceleration
- [ ] **Phase 5: Settings & Polish** - Hotkey customization and launch at login

## Phase Details

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
- [ ] 02-01-PLAN.md — ScrollEngine (CGEventTap drag-to-scroll) and HotkeyManager (F6 global hotkey)
- [ ] 02-02-PLAN.md — OverlayManager (floating indicator dot), service wiring, UI toggle activation

### Phase 3: Click Safety
**Goal**: User can safely click things while scroll mode is active, and always bail out with Escape
**Depends on**: Phase 2
**Requirements**: SCRL-03, SAFE-01, SAFE-02, SAFE-03
**Success Criteria** (what must be TRUE):
  1. Clicking without significant movement (~8px) passes through as a normal click
  2. Pressing Escape exits scroll mode instantly regardless of other state
  3. Stationary clicks (no movement at all) always pass through as normal clicks
  4. If Accessibility permission is revoked while the app is running, the app disables scroll mode gracefully without freezing input
**Plans**: 2 plans

Plans:
- [ ] 03-01-PLAN.md — Hold-and-decide click-through in ScrollEngine, modifier/double-click pass-through, click-through setting in UI
- [ ] 03-02-PLAN.md — Permission health check polling, mid-toggle/mid-drag cleanup, graceful permission revocation handling

### Phase 4: Inertia
**Goal**: Released drags produce natural momentum scrolling that feels like iOS/trackpad
**Depends on**: Phase 3
**Requirements**: SCRL-04
**Success Criteria** (what must be TRUE):
  1. Releasing a drag at speed produces continued scrolling with gradual deceleration
  2. Faster drags produce more momentum; slow drags produce little or no momentum
  3. Inertia scrolling feels smooth (frame-synchronized, no stuttering or jumping)
**Plans**: TBD

Plans:
- [ ] 04-01: TBD

### Phase 5: Settings & Polish
**Goal**: User can customize their hotkey and have the app start automatically at login
**Depends on**: Phase 4
**Requirements**: ACTV-03, APP-03
**Success Criteria** (what must be TRUE):
  1. User can open settings and change their hotkey to any supported key or modifier combination
  2. User can enable "launch at login" and the app starts automatically on next login
  3. Changed settings persist across app restarts
**Plans**: TBD

Plans:
- [ ] 05-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Permissions & App Shell | 2/2 | Complete | 2026-02-14 |
| 2. Core Scroll Mode | 0/2 | Not started | - |
| 3. Click Safety | 0/TBD | Not started | - |
| 4. Inertia | 0/TBD | Not started | - |
| 5. Settings & Polish | 0/TBD | Not started | - |
