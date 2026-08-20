# Project State

_Updated: 2026-08-20_

## Snapshot

- **Core value:** Users can scroll any scrollable area by clicking and dragging the mouse pointer, with optional natural inertia and no scroll wheel or trackpad.
- **Release baseline:** v1.4.1 (`0533855`), macOS 14+, Apple Silicon.
- **Current focus:** No active feature milestone; pointer-accurate active drag scrolling is runtime-verified.
- **Status:** The drag-distance accounting change passes a full Debug build and user verification confirms that scroll motion tracks the mouse pointer during click-and-drag.
- **Latest maintenance:** Preserved threshold-crossing and fractional pointer movement during active drag scrolling without retuning inertia. See [`work/2026-08-20-pointer-accurate-drag/`](./work/2026-08-20-pointer-accurate-drag/).

## Active Work

None.

## Planned Next

1. Complete remaining targeted manual verification of click safety, hold-to-passthrough, axis lock, direction inversion, and fast-release inertia.
2. If a tracking mismatch appears in a specific app, capture the app and sensitivity setting before changing event generation further.

One confirmed documentation-maintenance candidate is to refresh the public `README.md` roadmap, which still shows v1.4 capabilities as unfinished.

## Known Concerns

- There is no automated test target. Swift and Xcode changes require a Debug build plus targeted manual verification.
- Global mouse-event behavior, Accessibility Keyboard pass-through, excluded apps, multiple displays, native `NSScrollView` momentum, and web-view scrolling cannot be considered verified from compilation alone.
- The event-tap callback is latency-sensitive. Expensive system queries must remain outside the input callback and use cached state.
- The pointer-accurate drag change has been exercised with real global mouse input and user verification reports that it works well; broader safety and behavior regression checks remain pending.
- Signing and notarization require local credentials and should run only for an explicitly requested release.

## Recent Outcomes

- **2026-08-20:** Changed active drag accounting to preserve the dead-zone crossing displacement, carry fractional pixel remainders, and avoid zero-delta scroll phases; Debug build passed and user verified pointer tracking during click-and-drag.
- **2026-08-20:** Replaced the retired GSD operating process with lightweight project instructions, a repo-local maintenance skill, living state, and per-change plan/outcome records.
- **2026-05-02:** Released v1.4.1 and resolved Steam launcher wrappers to the actual running game bundle identifier for app exclusions (`efae0d8`, `0533855`).
- **2026-05-02:** Added fallback path identifiers for app bundles without `CFBundleIdentifier` (`8bf243c`).
- **2026-02-24:** Shipped v1.4 with configurable inertia, direction inversion, and a click-through hotkey.

Older milestone and quick-task history remains under `.planning/milestones/` and `.planning/quick/`.

## Resume Here

1. Exercise click pass-through, hold-to-passthrough, axis lock, direction inversion, and fast-release inertia.
2. Record any app-specific mismatch before changing the pixel-scroll event path.
