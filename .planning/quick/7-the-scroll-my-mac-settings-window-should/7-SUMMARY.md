---
phase: quick-7
plan: 01
subsystem: WindowExclusionManager
tags: [bug-fix, multi-display, coordinate-conversion, click-through]
dependency_graph:
  requires: []
  provides: [correct-CG-coordinate-flip-for-all-displays]
  affects: [ScrollEngine.shouldPassThroughClick, WindowExclusionManager.isPointInAppWindow]
tech_stack:
  added: []
  patterns: [NSScreen.screens.first for primary-screen Y-flip baseline]
key_files:
  created: []
  modified:
    - ScrollMyMac/Services/WindowExclusionManager.swift
decisions:
  - "Use NSScreen.screens.first (not NSScreen.main) as the Y-flip anchor for AppKit-to-CG coordinate conversion. screens.first is always the primary screen; main changes dynamically to whichever screen holds the key window."
metrics:
  duration: ~5min
  completed: 2026-02-21
---

# Quick Task 7: Fix Settings Window Click-Through on Secondary Displays

**One-liner:** Replace `NSScreen.main` with `NSScreen.screens.first` in `WindowExclusionManager.refreshCache()` so the CG-coordinate Y-flip uses the primary screen's height regardless of which display the settings window is on.

## What Was Done

### Task 1: Fix per-window CG coordinate conversion in WindowExclusionManager

**File:** `ScrollMyMac/Services/WindowExclusionManager.swift`

**Root cause:** `NSScreen.main?.frame.height` was used as the Y-flip constant when converting AppKit window frames (origin at primary screen's bottom-left) into CG coordinates (origin at primary screen's top-left). `NSScreen.main` returns the screen containing the current key window — when the settings window was moved to a secondary display, `NSScreen.main` returned the secondary screen's height, producing incorrect CG rects. As a result, `isPointInAppWindow(_:)` returned `false` for clicks inside the settings window on secondary displays, and the scroll engine intercepted those clicks instead of passing them through.

**Fix:** One-line change — `NSScreen.main?.frame.height` → `NSScreen.screens.first?.frame.height`.

`NSScreen.screens.first` is always the primary screen (the one with the menu bar, which defines the NSScreen coordinate origin). The CG coordinate system anchors Y=0 at the top-left of that same primary screen, so `primaryHeight - frame.origin.y - frame.height` is the correct formula for every window regardless of which display it is currently on.

**Commit:** 7c8ec9a

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- [x] `ScrollMyMac/Services/WindowExclusionManager.swift` modified correctly
- [x] Commit 7c8ec9a exists
- [x] Build succeeded with no new errors or warnings
