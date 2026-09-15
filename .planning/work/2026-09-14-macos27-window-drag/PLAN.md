---
title: Restore hold-to-passthrough window dragging
status: complete
created: 2026-09-14
updated: 2026-09-14
---

# Plan: Restore hold-to-passthrough window dragging

## Outcome

Make delayed mouse dragging robust on macOS 27, preserving ordinary clicks, scroll conversion, and safe release.

## Evidence and scope

- User reports window dragging fails after upgrading to macOS 27. Host reports 27.0 (26A428), Xcode 27.0 (27A266a).
- Stored click-through and hold-to-passthrough settings are enabled; hold delay is 0.25 seconds.
- Current hold path combines a generated down, hardware drags, and separately generated up. OS-specific causality remains unverified.
- Preserve existing uncommitted pointer-distance changes and Xcode/user-state changes.
- Inspect permission, keyboard exclusion, and tap lifecycle compatibility; record additional concerns without speculative broad changes.

## Approach

1. Preserve mouse-event metadata and use a consistent replay source through delayed dragging; explicitly permit local input.
2. Guard delayed activation against cancellation/replacement and clean up replayed button state on stop.
3. Build with Xcode 27 and exercise event handling without posting global input where feasible.

## Verification

- Required Debug build with writable derived data and signing disabled.
- Focused event-sequence regression checks.
- User explicitly confirmed restored window dragging and subsequently approved closure after the focused regression checklist. See OUTCOME.md for verification scope and remaining broader coverage.

## Out of scope

Release, signing, notarization, permission additions, and changing inertia tuning.
