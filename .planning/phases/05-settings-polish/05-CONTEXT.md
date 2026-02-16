# Phase 5: Settings & Polish - Context

**Gathered:** 2026-02-15
**Status:** Ready for planning

<domain>
## Phase Boundary

User can customize their hotkey and have the app start automatically at login. All settings persist across app restarts. Existing scattered settings (axis lock, safety timeout) are consolidated into one unified settings view.

</domain>

<decisions>
## Implementation Decisions

### Hotkey customization
- Key recorder UI — click a field, press desired key/combo, it captures it
- Broad key support: function keys alone OR any key with at least one modifier (Cmd, Ctrl, Option, Shift)
- No conflict detection — allow any combo silently, user's responsibility
- User can clear the hotkey entirely (removes hotkey toggle, scroll mode only controllable via UI)
- Default hotkey: F6 (matches current hardcoded value)

### Launch at login
- Standard macOS launch-at-login toggle in settings
- On login launch, app starts with scroll mode inactive — user presses hotkey to activate
- Silent background launch — no window shown on login
- Dock icon only (no menu bar icon) — user clicks dock icon to reopen window

### Persistence & defaults
- All setting changes take effect immediately (no save button)
- Settings stored in UserDefaults (already used for axis lock)
- "Reset to defaults" button available in settings
- Default values: F6 hotkey, launch at login off, existing defaults for other settings

### Settings consolidation
- Consolidate ALL settings into one unified settings view: hotkey, launch at login, axis lock, safety timeout, and any other toggles
- Current scattered settings move into this unified view

### Claude's Discretion
- Settings view layout and section organization
- Key recorder visual design and interaction feedback
- Reset confirmation dialog (if any)
- How to handle edge cases in key recording (modifier-only combos, escape to cancel, etc.)

</decisions>

<specifics>
## Specific Ideas

No specific references — open to standard macOS settings patterns.

</specifics>

<deferred>
## Deferred Ideas

- On-screen keyboard click detection — pass through all clicks when on-screen keyboard is active (new capability, possibly extends Click Safety phase)

</deferred>

---

*Phase: 05-settings-polish*
*Context gathered: 2026-02-15*
