# Phase 10: Menu Bar Icon - Context

**Gathered:** 2026-02-17
**Status:** Ready for planning

<domain>
## Phase Boundary

A persistent menu bar status item that reflects scroll mode state (on/off) and provides quick toggle access via left-click. Right-click opens a minimal context menu. The icon can be disabled in settings. This phase does not change how scroll mode works — it adds a visible control surface in the menu bar.

</domain>

<decisions>
## Implementation Decisions

### Icon appearance
- Custom drawn icon (not SF Symbol) depicting a computer mouse — similar to the app icon but adapted for menu bar size
- Template image format so macOS automatically handles light/dark menu bar
- On vs off state conveyed through opacity: full opacity when scroll mode is on, semi-transparent when off

### Context menu (right-click)
- Minimal menu: just "Settings..." and "Quit Scroll My Mac"
- No toggle item in the menu — left-click handles toggling
- No status info or hotkey display in the menu

### Default state and accessibility
- Menu bar icon is enabled by default on first launch
- User can disable it in settings; it disappears from the menu bar
- When menu bar icon is disabled, the app remains accessible via the Dock icon (Dock icon always stays visible)
- Re-enabling in settings makes the icon reappear without restart

### Claude's Discretion
- Exact icon dimensions and line weight for menu bar readability
- Interaction feedback (e.g., whether icon briefly animates on toggle)
- Menu item keyboard shortcuts (if any)

</decisions>

<specifics>
## Specific Ideas

- Icon should be a computer mouse, echoing the app icon's design language
- Opacity change for state — not filled/outlined, not color-based

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 10-menu-bar-icon*
*Context gathered: 2026-02-17*
