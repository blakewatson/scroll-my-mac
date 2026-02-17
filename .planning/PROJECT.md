# Scroll My Mac

## What This Is

A macOS accessibility app that enables click-and-drag scrolling anywhere on screen. For users who can't use a trackpad or scroll wheel, this brings the "Scroll Anywhere" browser extension experience to the entire operating system.

## Core Value

Users can scroll any scrollable area by clicking and dragging with the mouse pointer, with natural inertia — no scroll wheel or trackpad required.

## Requirements

### Validated

- ✓ System-wide scroll mode activated via configurable hotkey — v1.0
- ✓ Left-click + drag scrolls the area under cursor (all directions) — v1.0
- ✓ Click without movement passes through as normal click (~8px threshold) — v1.0
- ✓ Inertia/momentum when drag is released (like iOS/touch scrolling) — v1.0
- ✓ Cursor changes to indicate scroll mode is active — v1.0
- ✓ Simple GUI window with on/off toggle and settings — v1.0
- ✓ Hotkey configuration (supports regular keys and modifier combos) — v1.0
- ✓ Works with macOS Accessibility permissions — v1.0

### Validated

- ✓ Clicks pass through immediately when cursor is over the Accessibility Keyboard — v1.1
- ✓ Detection is dynamic — works regardless of OSK position or size — v1.1
- ✓ Scroll mode stays toggled on while OSK pass-through is active — v1.1

### Validated

- ✓ App has a custom icon (converted from source image to macOS AppIcon.appiconset) — v1.2
- ✓ App is signed with Developer ID and notarized for Gatekeeper-clean distribution — v1.2
- ✓ App is released on GitHub as a downloadable zipped .app bundle — v1.2

### Validated

- ✓ Cached app window frames for thread-safe click pass-through — v1.2.2
- ✓ Only match app windows when app is frontmost (occluded window fix) — v1.2.2
- ✓ CGEventTap runs on dedicated background thread — v1.2.2

### Active

- [ ] Menu bar icon shows scroll mode state (on/off), left-click toggles, right-click context menu for settings
- [ ] Menu bar icon is optional (can be disabled in settings)
- [ ] Hold-to-passthrough: hold still in dead zone for configurable delay, then drag passes through for text selection/window resize
- [ ] Hold-to-passthrough is optional (off by default), delay is configurable (default 1.5s)
- [ ] Per-app exclusion list: add/remove apps where scroll mode is disabled
- [ ] Exclusion list managed in settings UI

### Out of Scope

- CLI-only version — GUI selected for ease of use
- Multi-button support — left click only for v1
- Menu bar as primary settings interface — menu bar icon is toggle + shortcut to settings only

## Current Milestone: v1.3.0 Visual Indicator, Scroll Engine Improvements, Per-App Exclusion

**Goal:** Add a menu bar status icon, hold-to-passthrough for normal drag interactions without leaving scroll mode, and per-app exclusion so scroll mode is automatically disabled in specific apps.

**Target features:**
- Menu bar icon (optional) showing scroll mode state, click to toggle, right-click for settings
- Hold-to-passthrough: hold still in dead zone past configurable delay to enable normal drag (text select, resize)
- Per-app exclusion list managed in settings

## Context

The user has a disability that makes trackpad and scroll wheel use difficult or impossible. They currently:
- Click and drag scroll bars (works but scroll bars are sometimes hidden or too small)
- Use "Scroll Anywhere" browser extension for web (works great)
- Need this same capability system-wide in macOS

The accessibility keyboard (on-screen keyboard) is used for typing and will be used to trigger the hotkey to enter/exit scroll mode. When typing quickly, the fast mouse movements between OSK keys cause the scroll engine's hold-and-decide model to consume clicks (>8px movement triggers scroll instead of click pass-through). The OSK can be repositioned and has a minimize mode.

## Constraints

- **Platform**: macOS only (uses CGEventTap, NSCursor, Accessibility APIs)
- **Build**: SwiftUI app, avoid heavy Xcode dependency where possible
- **Permissions**: Requires Accessibility permissions (System Preferences grant)
- **Input method**: Must work with clicks from accessibility keyboard hotkeys

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| SwiftUI GUI over CLI | User prefers visual interface, avoids config files | — Pending |
| Left-click for scroll drag | Matches Scroll Anywhere behavior, most natural | — Pending |
| Small movement threshold (~8px) | Responsive scrolling preferred over accidental protection | — Pending |
| 1:1 scroll ratio with inertia | Natural touch-like feel, matches iOS/tablet behavior | — Pending |
| Cursor change for mode indicator | Clear visual feedback without menu bar clutter | — Pending |

---
*Last updated: 2026-02-17 after milestone v1.3.0 started*
