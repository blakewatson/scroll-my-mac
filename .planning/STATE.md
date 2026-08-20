# Project State

_Updated: 2026-08-20_

## Snapshot

- **Core value:** Users can scroll any scrollable area by clicking and dragging the mouse pointer, with optional natural inertia and no scroll wheel or trackpad.
- **Release baseline:** v1.4.1 (`0533855`), macOS 14+, Apple Silicon.
- **Current focus:** Maintenance; no active feature milestone.
- **Status:** Shipped and stable enough for normal maintenance. No work is currently in progress after the planning-workflow refresh.
- **Latest maintenance:** Adopted a lightweight, repo-local planning and state workflow. See [`work/2026-08-19-lightweight-planning-workflow/`](./work/2026-08-19-lightweight-planning-workflow/).

## Active Work

None.

## Planned Next

No product work has been prioritized. The next maintainer should choose a concrete issue or milestone before creating a work plan.

One confirmed documentation-maintenance candidate is to refresh the public `README.md` roadmap, which still shows v1.4 capabilities as unfinished.

## Known Concerns

- There is no automated test target. Swift and Xcode changes require a Debug build plus targeted manual verification.
- Global mouse-event behavior, Accessibility Keyboard pass-through, excluded apps, multiple displays, native `NSScrollView` momentum, and web-view scrolling cannot be considered verified from compilation alone.
- The event-tap callback is latency-sensitive. Expensive system queries must remain outside the input callback and use cached state.
- Signing and notarization require local credentials and should run only for an explicitly requested release.

## Recent Outcomes

- **2026-08-20:** Replaced the retired GSD operating process with lightweight project instructions, a repo-local maintenance skill, living state, and per-change plan/outcome records.
- **2026-05-02:** Released v1.4.1 and resolved Steam launcher wrappers to the actual running game bundle identifier for app exclusions (`efae0d8`, `0533855`).
- **2026-05-02:** Added fallback path identifiers for app bundles without `CFBundleIdentifier` (`8bf243c`).
- **2026-02-24:** Shipped v1.4 with configurable inertia, direction inversion, and a click-through hotkey.

Older milestone and quick-task history remains under `.planning/milestones/` and `.planning/quick/`.

## Resume Here

1. Read `AGENTS.md`, this file, and the relevant code.
2. Confirm the requested maintenance item against Git and current behavior.
3. Use `$project-maintenance` and create a work plan if the change is meaningful.
