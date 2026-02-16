# Research Summary: OSK-Aware Click Pass-Through

**Domain:** macOS window detection and event pass-through for on-screen keyboards
**Researched:** 2026-02-16
**Overall confidence:** HIGH (APIs well-documented; process identification MEDIUM -- needs runtime verification)

## Executive Summary

Adding Accessibility Keyboard (OSK) detection to Scroll My Mac requires no new frameworks, dependencies, or permissions. The existing `shouldPassThroughClick` closure in ScrollEngine is the perfect integration point -- it already handles pass-through for the app's own windows. The new feature extends this closure with a cached window bounds check.

The approach uses `CGWindowListCopyWindowInfo` to enumerate on-screen windows, filtering by `kCGWindowOwnerName == "Assistive Control"` to find the Accessibility Keyboard. Critically, both `kCGWindowOwnerName` and `kCGWindowBounds` are available WITHOUT Screen Recording permission -- only `kCGWindowName` (window title) is gated, and we do not need it. This means no additional permission prompts for users.

The key architectural decision is caching: `CGWindowListCopyWindowInfo` is a cross-process IPC call to the Window Server and must NOT be called inside the event tap callback. Instead, a new `WindowExclusionManager` service polls window positions every 500ms and exposes cached `CGRect` bounds. The event tap callback performs a simple `CGRect.contains(CGPoint)` check against the cache -- effectively zero latency.

Both `CGEvent.location` and `kCGWindowBounds` use the same coordinate system (CG: top-left origin, Y down). This eliminates the coordinate conversion complexity that exists in the current NSWindow-based pass-through check. The OSK hit test is a direct comparison with no transformation needed.

## Key Findings

**Stack:** No new dependencies. `CGWindowListCopyWindowInfo` (CoreGraphics), `NSWorkspace` notifications (AppKit), and `NSRunningApplication` (AppKit) are all already available in the project.

**Architecture:** New `WindowExclusionManager` service owned by `AppState`, wired into the existing `shouldPassThroughClick` closure. One new file (~60 lines), one modified file (AppState.swift -- add property + extend closure + add start/stop calls).

**Critical pitfall:** Calling `CGWindowListCopyWindowInfo` inside the event tap callback will cause tap timeout and silent disabling of scroll mode. Must cache outside the callback path.

**Process identity:** The Accessibility Keyboard runs as process "Assistive Control" (with space) with input method ID `com.apple.inputmethod.AssistiveControl`. This is MEDIUM confidence from community sources and needs runtime verification.

## Implications for Roadmap

This is a small, focused milestone that can be completed in a single phase:

1. **Phase 1: Discovery and Implementation**
   - Empirically verify Accessibility Keyboard process/window names by printing CGWindowList output
   - Implement `WindowExclusionManager` with timer-based caching
   - Wire into `AppState.setupServices()` extending `shouldPassThroughClick`
   - Test: OSK clicks pass through, non-OSK clicks scroll, existing app-window pass-through unaffected

**Phase ordering rationale:**
- Discovery first: Verify exact process names before writing detection logic
- Cache architecture before hit-testing: Ensures no IPC in the callback path
- Integration last: Existing code changes are minimal and low-risk once the new service works independently

**Research flags for phases:**
- Process name verification: HIGH priority -- "Assistive Control" name is from community sources, not Apple docs. Run diagnostic first.
- Multi-display testing: MEDIUM priority -- CG coordinates should work across displays but verify empirically
- Standard patterns, unlikely to need research: CGRect.contains hit testing, NSWorkspace notifications, Timer-based polling

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack (APIs) | HIGH | CGWindowListCopyWindowInfo is well-documented, not deprecated, and confirmed to provide owner name + bounds without Screen Recording permission |
| Process identification | MEDIUM | "Assistive Control" owner name confirmed by AppleScript community; exact bundle ID uncertain. Needs runtime verification. |
| Architecture | HIGH | Extends existing shouldPassThroughClick pattern; no new abstractions needed. WindowExclusionManager is straightforward cache-and-check. |
| Performance | HIGH | CGRect.contains is nanoseconds. CGWindowListCopyWindowInfo at 500ms polling is well within acceptable overhead. Event tap callback budget is ~100ms. |
| Pitfalls | HIGH | All pitfalls have clear prevention strategies. Most important (no IPC in callback) is a simple architectural constraint. |

## Gaps to Address

- **Exact process name on current macOS version:** "Assistive Control" vs "AssistiveControl" (with/without space). Must verify by opening the Accessibility Keyboard and inspecting CGWindowListCopyWindowInfo output before writing detection logic.
- **Multiple AssistiveControl windows:** The process may own multiple windows (keyboard panel, toolbar, resize handles). Need to determine which to include in the exclusion zone -- likely all of them.
- **Keyboard Viewer vs Accessibility Keyboard:** These may be separate processes. Verify whether both need exclusion.
- **Third-party on-screen keyboards:** Users may use non-Apple OSK software. Consider making the exclusion list configurable in a future iteration.

---
*Research completed: 2026-02-16*
*Ready for roadmap: yes*
