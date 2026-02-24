# Phase 12: Per-App Exclusion - Context

**Gathered:** 2026-02-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Settings UI to add/remove apps from an exclusion list where scroll mode is automatically bypassed. When the frontmost app is excluded, scroll mode stays toggled on but clicks pass through as normal. Visual feedback via menu bar icon. Creating new scroll behaviors or modifying scroll engine fundamentals are out of scope.

</domain>

<decisions>
## Implementation Decisions

### App selection method
- macOS System Settings style: a list of apps with + and – buttons below
- Plus button opens a standard macOS file picker (NSOpenPanel) filtered to .app bundles
- Minus button removes the selected app from the list
- No per-app enabled/disabled toggle — presence in the list means excluded, absence means not excluded
- Apps identified by bundle ID (resilient to moves/reinstalls)
- Adding a duplicate app is silently ignored

### Exclusion list display
- Each row shows app icon + app display name
- List placed at the bottom of the settings view — last section
- All settings remain in one window (no tabs/pages)
- List grows with content (no fixed height / internal scroll)
- Empty state shows placeholder text: "No excluded apps"

### Exclusion feedback
- Menu bar icon receives a slash through it when the frontmost app is excluded (indicates scroll mode is bypassed)
- Menu bar tooltip changes to show context, e.g. "Scroll mode paused — [App Name] is excluded"
- No overlay dot (overlay dot was removed previously)
- When switching away from an excluded app, menu bar icon returns to normal state

### Default exclusions
- Exclusion list starts empty — user adds apps as needed
- No limit on number of excluded apps
- Duplicates silently ignored when adding

### Claude's Discretion
- Toggle behavior while in an excluded app (hotkey/menu bar click) — pick the least confusing UX
- Stale app handling (uninstalled apps in the list) — pick the simplest approach
- Exact slash icon design for menu bar
- Frontmost app detection mechanism

</decisions>

<specifics>
## Specific Ideas

- "Similar to how the accessibility security settings pane does it" — list with +/– buttons pattern
- Menu bar slash icon should clearly communicate "disabled/paused" state

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 12-per-app-exclusion*
*Context gathered: 2026-02-17*
