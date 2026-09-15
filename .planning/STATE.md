# Project State

_Updated: 2026-09-14_

## Snapshot

- **Core value:** Users can scroll any scrollable area by clicking and dragging the mouse pointer, with optional natural inertia and no scroll wheel or trackpad.
- **Release baseline:** v1.4.1 (`0533855`), macOS 14+, Apple Silicon.
- **Current focus:** No active maintenance item; macOS 27 window-drag fix is user-verified.
- **Status:** Window dragging confirmed working by the user; closure accepted after the focused regression checklist. Debug build and captured-event checks pass.
- **Latest maintenance:** [`macOS 27 window-drag outcome`](./work/2026-09-14-macos27-window-drag/OUTCOME.md).
- **Repository baseline:** Pointer-accurate scrolling committed by the user as `6621cbb`; local project version is 1.4.2, with existing project/user-state edits preserved. Last recorded release remains v1.4.1.

## Active Work

None.

## Planned Next

No immediate work is required for the completed window-drag fix. Unscheduled candidates include tap-start failure reporting, main-run-loop timeout exposure, and broader permission/safety-timeout regression coverage.

## Known Concerns

- There is no Xcode test target; standalone captured-event checks now cover mouse replay and hold behavior. Swift and Xcode changes require a Debug build plus targeted manual verification.
- Global mouse-event behavior, Accessibility Keyboard pass-through, excluded apps, multiple displays, native `NSScrollView` momentum, and web-view scrolling cannot be considered verified from compilation alone.
- The event-tap callback is latency-sensitive. Expensive system queries must remain outside the input callback and use cached state.
- The pointer-accurate drag change has been exercised with real global mouse input and user verification reports that it works well; broader safety and behavior regression checks remain pending.
- Signing and notarization require local credentials and should run only for an explicitly requested release.

## Recent Outcomes

- **2026-09-14:** Completed the macOS 27 held-drag fix with coherent mouse replay, timer cancellation protection, and paired release across exclusions/shutdown. Debug build and standalone checks passed; user confirmed dragging works and accepted closure after the focused checklist.

- **2026-08-20:** Changed active drag accounting to preserve the dead-zone crossing displacement, carry fractional pixel remainders, and avoid zero-delta scroll phases; Debug build passed and user verified pointer tracking during click-and-drag.
- **2026-08-20:** Replaced the retired GSD operating process with lightweight project instructions, a repo-local maintenance skill, living state, and per-change plan/outcome records.
- **2026-05-02:** Released v1.4.1 and resolved Steam launcher wrappers to the actual running game bundle identifier for app exclusions (`efae0d8`, `0533855`).
- **2026-05-02:** Added fallback path identifiers for app bundles without `CFBundleIdentifier` (`8bf243c`).
- **2026-02-24:** Shipped v1.4 with configurable inertia, direction inversion, and a click-through hotkey.

Older milestone and quick-task history remains under `.planning/milestones/` and `.planning/quick/`.

## Resume Here

The window-drag fix is complete. See its [outcome](./work/2026-09-14-macos27-window-drag/OUTCOME.md) for verification scope and separate compatibility follow-ups.
