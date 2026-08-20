---
title: Make active drag scrolling track pointer displacement
status: complete
created: 2026-08-20
updated: 2026-08-20
---

# Plan: Make active drag scrolling track pointer displacement

## Outcome

During an active scroll drag, the synthetic pixel-scroll distance preserves the full on-screen pointer displacement, independent of mouse sensitivity, while the existing release velocity and inertia behavior remain unchanged.

## Why

The click-through transition currently discards all movement through the 8-point dead zone, and each later pointer delta is independently truncated to an integer. The resulting content offset or rounding drift makes dragging feel detached from the pointer, especially when sensitivity or event cadence changes.

## Scope

- Preserve the threshold-crossing displacement when click-through commits to scrolling.
- Carry fractional drag deltas between events and emit only nonzero integer pixel deltas.
- Preserve axis lock, direction inversion, click replay, hold-to-passthrough, and release velocity tracking.
- Update the living project state when work closes.

## Out of scope

- Retuning inertia curves or intensity.
- Adding a drag-speed or sensitivity setting.
- Compensating for application-specific scroll scaling beyond the existing pixel-precision event path.
- Signing, notarization, publishing, or release work.

## Approach

1. Add per-drag fractional remainder state and reset it with the existing drag state.
2. Process the dead-zone crossing event from the original mouse-down anchor so its displacement is not lost.
3. Quantize only the active axis or axes, defer the scroll-began phase until a nonzero event exists, and keep raw pointer deltas feeding velocity tracking.
4. Build and inspect the resulting diff, then record manual checks that still require the running app.

## Verification

- `git diff --check`
- `xcodebuild -project ScrollMyMac.xcodeproj -scheme ScrollMyMac -configuration Debug -derivedDataPath /tmp/scroll-my-mac-derived-data CODE_SIGNING_ALLOWED=NO build`
- Manual: compare pointer/content tracking at low, medium, and high mouse sensitivity in native and web-view scroll containers.
- Manual: verify click pass-through, hold-to-passthrough, vertical/horizontal axis lock, direction inversion, and fast-release inertia.
