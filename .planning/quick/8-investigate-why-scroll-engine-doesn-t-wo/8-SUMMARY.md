# Quick Task 8: Fix scroll engine on WKWebView-based apps (MarkEdit)

## Problem

ScrollMyMac's scroll engine didn't work on MarkEdit (a WKWebView + CodeMirror 6 editor) when click-through mode was enabled. Scrolling worked fine with click-through disabled.

## Root Cause

When click-through is enabled and the user drags past the 8px dead zone, the code fell through to process that same drag event as the first scroll event. But it had just set `lastDragPoint = currentPoint`, so the scroll processing computed zero deltas. This posted a `kCGScrollPhaseBegan` event with zero movement.

Most AppKit-based apps tolerate a zero-delta scroll-began, but WKWebView-based apps (MarkEdit, and likely others using WKWebView for content) ignore scroll sequences that begin with no movement. The web view never initializes its scroll handling, so all subsequent `kCGScrollPhaseChanged` events are also dropped.

With click-through disabled, `lastDragPoint` is set during mouseDown, so the first drag event always has a real delta — no zero-delta began event.

## Fix

Changed the dead-zone-exceeded transition to return `nil` instead of falling through. The next `mouseDragged` event becomes the first scroll event with `kCGScrollPhaseBegan` and a real non-zero delta, matching the click-through-OFF behavior.

Also removed `activateWindowUnderCursor` (from an earlier fix attempt) which was calling `CGWindowListCopyWindowInfo` inside the event tap callback — a potentially slow operation that could cause macOS to disable the tap.

## Files Changed

- `ScrollMyMac/Services/ScrollEngine.swift` — dead-zone transition returns nil; removed activateWindowUnderCursor method

## Commit

970a4a5
