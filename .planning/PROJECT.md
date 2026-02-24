# Scroll My Mac

## What This Is

A macOS accessibility app that enables click-and-drag scrolling anywhere on screen. For users who can't use a trackpad or scroll wheel, this brings the "Scroll Anywhere" browser extension experience to the entire operating system. Features configurable inertia, scroll direction, per-app exclusion, and keyboard shortcuts.

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
- ✓ Clicks pass through immediately when cursor is over the Accessibility Keyboard — v1.1
- ✓ Detection is dynamic — works regardless of OSK position or size — v1.1
- ✓ Scroll mode stays toggled on while OSK pass-through is active — v1.1
- ✓ App has a custom icon (converted from source image to macOS AppIcon.appiconset) — v1.2
- ✓ App is signed with Developer ID and notarized for Gatekeeper-clean distribution — v1.2
- ✓ App is released on GitHub as a downloadable zipped .app bundle — v1.2
- ✓ Cached app window frames for thread-safe click pass-through — v1.2.2
- ✓ Only match app windows when app is frontmost (occluded window fix) — v1.2.2
- ✓ CGEventTap runs on dedicated background thread — v1.2.2
- ✓ Menu bar icon shows scroll mode state (on/off), left-click toggles, right-click context menu for settings — v1.3.0
- ✓ Menu bar icon is optional (can be disabled in settings) — v1.3.0
- ✓ Hold-to-passthrough: hold still in dead zone for configurable delay, then drag passes through for text selection/window resize — v1.3.0
- ✓ Hold-to-passthrough is optional (off by default), delay is configurable (default 1.5s) — v1.3.0
- ✓ Per-app exclusion list: add/remove apps where scroll mode is disabled — v1.3.0
- ✓ Exclusion list managed in settings UI — v1.3.0
- ✓ Inertia on/off toggle (enabled by default) to completely disable coasting — v1.4
- ✓ Inertia intensity slider controlling coasting speed and duration — v1.4
- ✓ Direction inversion toggle (natural default, inverted flips scroll direction) — v1.4
- ✓ Configurable hotkey to toggle click-through mode on/off — v1.4

### Active

(None — planning next milestone)

### Out of Scope

- CLI-only version — GUI selected for ease of use
- Multi-button support — left click only for v1
- Menu bar as primary settings interface — menu bar icon is toggle + shortcut to settings only
- Adjustable scroll speed (slider to control sensitivity) — deferred to future release
- Third-party on-screen keyboard support — defer until user need is established

## Context

Shipped v1.4 with 2,830 LOC Swift. Tech stack: SwiftUI, CGEventTap, Accessibility APIs, CADisplayLink.

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
| SwiftUI GUI over CLI | User prefers visual interface, avoids config files | ✓ Good |
| Left-click for scroll drag | Matches Scroll Anywhere behavior, most natural | ✓ Good |
| Small movement threshold (~8px) | Responsive scrolling preferred over accidental protection | ✓ Good |
| 1:1 scroll ratio with inertia | Natural touch-like feel, matches iOS/tablet behavior | ✓ Good |
| Cursor change for mode indicator | Clear visual feedback without menu bar clutter | ✓ Good |
| Velocity ramp injection for native momentum | NSScrollView ignores momentum-phase deltas; inject velocity-scaled scrollPhaseChanged events to control perceived exit velocity | ✓ Good |
| Separate native/web-app intensity curves | NSScrollView dampens intensity effect; wider native range (0.25x-4.0x) vs web (0.4x-2.0x) | ✓ Good |
| Quadratic tail deceleration | exp(-t/tau - 1.5*t^2) eliminates lingering web-app coasting tail | ✓ Good |
| Direction inversion at ScrollEngine level | Keeps InertiaAnimator generic and reusable | ✓ Good |

---
*Last updated: 2026-02-24 after v1.4 milestone*
