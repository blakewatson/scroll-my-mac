# Phase 1: Permissions & App Shell - Context

**Gathered:** 2026-02-14
**Status:** Ready for planning

<domain>
## Phase Boundary

User can launch the app, grant Accessibility permissions with guidance, and see a functional main window. The window serves as a settings interface. Scroll mode toggle is wired up in Phase 2, but the UI control exists here. No menu bar presence — Dock app only.

</domain>

<decisions>
## Implementation Decisions

### App window & identity
- Dock app only — no menu bar icon
- Single window that serves as the settings interface
- Native macOS visual style — standard window chrome, system fonts, default SwiftUI controls
- Closing the settings window does NOT quit the app — app continues running headlessly with Dock icon
- Reopening the window from the Dock shows settings again

### Toggle & status display
- On/off toggle for scroll mode included as a regular settings row (not prominently placed)
- Toggle is part of the settings list alongside other options, no special treatment
- Permission status shown only during initial setup flow, not persistently in settings
- Phase 1 settings content is Claude's discretion — at minimum: toggle and whatever makes sense for the shell

### Safety mode
- Safety timeout: if no mouse movement for 10 seconds while scroll mode is active, scroll mode auto-deactivates
- Brief notification shown on safety deactivation (e.g., "Scroll mode deactivated (safety timeout)")
- Safety mode is on by default
- Safety mode can be toggled off in settings once user trusts the tool
- This is in addition to the hotkey toggle (same key on/off) — belt and suspenders

### Claude's Discretion
- Exact settings window layout and content for Phase 1
- Permission flow UI details (tone, steps, visual treatment)
- Notification style for safety timeout
- How to handle app relaunch after permission grant

</decisions>

<specifics>
## Specific Ideas

- User envisions this primarily as a keyboard-driven utility — the window is just for settings, not daily interaction
- Safety timeout is explicitly a development-era safeguard that can be disabled later
- The 10-second no-movement threshold was specifically chosen by the user

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-permissions-app-shell*
*Context gathered: 2026-02-14*
