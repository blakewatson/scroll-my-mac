---
title: Make active drag scrolling track pointer displacement
status: complete
created: 2026-08-20
completed: 2026-08-20
---

# Outcome: Make active drag scrolling track pointer displacement

## Result

Active drag scrolling now accounts for the full pointer displacement from mouse-down once the click dead zone is crossed. Fractional movement carries between drag events, keeping the engine's emitted whole-pixel distance within one point of pointer displacement on the active axis. The existing velocity tracker, inertia animator, and intensity curves were not retuned.

## Changes

- `ScrollEngine` — the dead-zone crossing event starts from the original mouse-down anchor instead of discarding the initial movement.
- `ScrollEngine` — per-axis fractional remainders prevent independent integer truncation from accumulating drift.
- `ScrollEngine` — zero-delta scroll events are deferred, and scroll-ended/inertia phases are skipped if no nonzero scroll sequence began.
- Planning state — recorded the maintenance priority, implementation result, and pending runtime checks.

## Verification

- PASS — `git diff --check`
- PASS — `xcodebuild -project ScrollMyMac.xcodeproj -scheme ScrollMyMac -configuration Debug -derivedDataPath /tmp/scroll-my-mac-derived-data CODE_SIGNING_ALLOWED=NO build`
- PASS — user verified that active scroll motion tracks the mouse pointer during click-and-drag and reports that it is working well.
- PENDING — exercise click pass-through, hold-to-passthrough, vertical/horizontal axis lock, direction inversion, and fast-release inertia in the running app.

## Decisions

- Treat the on-screen pointer location as the sensitivity-adjusted source of truth; do not read or compensate for the macOS sensitivity setting.
- Preserve fractional movement by carrying remainders into later whole-pixel events rather than changing the established Core Graphics event format.
- Preserve the existing release momentum algorithms; only active-drag distance accounting changed.

## Follow-ups

- Complete the remaining safety and behavior regression checks when convenient: click pass-through, hold-to-passthrough, axis lock, direction inversion, and fast-release inertia.
- If a mismatch remains isolated to a particular app, investigate that app's scroll-event interpretation before adding global scaling or event batching.
