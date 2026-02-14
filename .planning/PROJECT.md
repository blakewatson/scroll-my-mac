# Scroll My Mac

## What This Is

A macOS accessibility app that enables click-and-drag scrolling anywhere on screen. For users who can't use a trackpad or scroll wheel, this brings the "Scroll Anywhere" browser extension experience to the entire operating system.

## Core Value

Users can scroll any scrollable area by clicking and dragging with the mouse pointer, with natural inertia — no scroll wheel or trackpad required.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] System-wide scroll mode activated via configurable hotkey
- [ ] Left-click + drag scrolls the area under cursor (all directions)
- [ ] Click without movement passes through as normal click (~8px threshold)
- [ ] Inertia/momentum when drag is released (like iOS/touch scrolling)
- [ ] Cursor changes to indicate scroll mode is active
- [ ] Simple GUI window with on/off toggle and settings
- [ ] Hotkey configuration (supports regular keys and modifier combos)
- [ ] Works with macOS Accessibility permissions

### Out of Scope

- Menu bar app — user prefers simple window app
- CLI-only version — GUI selected for ease of use
- Multi-button support — left click only for v1

## Context

The user has a disability that makes trackpad and scroll wheel use difficult or impossible. They currently:
- Click and drag scroll bars (works but scroll bars are sometimes hidden or too small)
- Use "Scroll Anywhere" browser extension for web (works great)
- Need this same capability system-wide in macOS

The accessibility keyboard (on-screen keyboard) is used for typing and will be used to trigger the hotkey to enter/exit scroll mode.

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
*Last updated: 2026-02-14 after initialization*
