# Feature Landscape: OSK-Aware Click Pass-Through

**Domain:** macOS Accessibility / Window Exclusion for Mouse Event Interception
**Researched:** 2026-02-16
**Milestone:** v1.1 OSK Compat

## Table Stakes

Features that are fundamental to the OSK pass-through working correctly. Missing any of these makes the feature feel broken.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Instant click pass-through over OSK** | The entire point -- clicks on the Accessibility Keyboard must not enter the hold-and-decide model at all. Any delay (even the ~8px dead zone evaluation time) breaks fast typing flow | LOW | Check cursor position against OSK bounds in `handleMouseDown` before the pending/hold logic. Return event unmodified. No replay needed -- the original event passes through directly |
| **Dynamic OSK position tracking** | The Accessibility Keyboard can be dragged to any position on screen and has a minimize mode that changes its size. Detection must work regardless of where the OSK is | MEDIUM | Use `CGWindowListCopyWindowInfo` to find the OSK window by owner name and read its `kCGWindowBounds`. Cache the rect and refresh on a reasonable interval |
| **Scroll mode stays active during OSK pass-through** | User toggles scroll mode on, types on OSK, then wants to scroll again without re-toggling. Pass-through must be transparent to the scroll mode state machine | LOW | Already how `shouldPassThroughClick` works in `ScrollEngine` -- the `passedThroughClick` flag lets the event through without changing `isDragging` or `isActive` state |
| **Zero configuration** | User should not have to tell the app about the OSK. Detection must be automatic. The user population for this feature has motor impairments -- extra setup is a barrier | LOW | Auto-detect by process name. No settings UI needed for this feature |
| **Works without Screen Recording permission** | The app currently only requires Accessibility permission. Adding a Screen Recording requirement would be a significant UX regression and user friction | LOW | `kCGWindowBounds` and `kCGWindowOwnerName` are available from `CGWindowListCopyWindowInfo` without Screen Recording permission on macOS 10.15+. `kCGWindowName` is restricted but not needed -- we match on owner name only |

## Differentiators

Features that improve the experience beyond basic functionality. Not strictly required but add significant polish.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Cached OSK bounds with event-driven refresh** | Calling `CGWindowListCopyWindowInfo` on every mouseDown adds IPC overhead to the hot path. Cache the OSK rect and refresh it smartly | MEDIUM | Use `AXObserver` with `kAXWindowMovedNotification` / `kAXWindowResizedNotification` on the OSK process to update cache only when the window actually moves. Fallback: periodic refresh (every 1-2 seconds) is acceptable since the OSK moves rarely |
| **Generous hit-test margin around OSK bounds** | Cursor right on the edge of the OSK window might be targeting a key. A small margin (4-8px) around the detected bounds prevents edge-case misses | LOW | Inflate the cached `CGRect` by margin before hit testing. Small constant, no user config needed |
| **Pass-through for modifier clicks on OSK** | Shift-click, Option-click on OSK keys for uppercase/special characters. Current engine already passes through modifier clicks but that is a separate code path | LOW | Already handled -- the existing modifier-key pass-through in `handleMouseDown` fires before the OSK check would. No work needed, but worth verifying in testing |
| **Support for multiple exclusion windows** | If user has other floating panels (Panel Editor custom panels, Dwell Control overlay), those should also pass through | MEDIUM | Generalize detection to match multiple process names or a list of window owners. Initial implementation can hardcode the known set; make it extensible |
| **Graceful handling when OSK is not running** | Most users of Scroll My Mac may not use the OSK at all. Detection should not log errors, consume resources, or degrade performance when no OSK is present | LOW | If `CGWindowListCopyWindowInfo` finds no matching window, cache an empty/nil rect. Skip the bounds check entirely. Near-zero overhead for non-OSK users |

## Anti-Features

Features to explicitly NOT build for this milestone.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **User-configurable exclusion zone drawing** | Over-engineered for the specific problem. User draws a rectangle on screen to exclude -- fragile when OSK moves, adds complex UI | Auto-detect the OSK window bounds. If future need arises for arbitrary exclusion zones, revisit then |
| **Per-app exclusion list (generalized)** | Scope creep. The OSK is a specific, well-defined target. A general per-app exclusion system is a different feature entirely | Hardcode detection of known accessibility windows (OSK, Panel Editor). Generalize later if demanded |
| **Visual feedback when click passes through OSK** | Adds visual noise. The whole point is that clicking on the OSK should feel exactly like scroll mode is off. Any indicator breaks the "transparency" goal | Silence is the correct UX. The click just works |
| **Setting to enable/disable OSK detection** | Adds a toggle for something that should just work. If the OSK is not present, detection is a no-op. If it is present, you always want pass-through | Always-on detection. No toggle. If somehow it causes issues, that is a bug to fix, not a feature to configure |
| **Polling CGWindowListCopyWindowInfo on every mouse event** | IPC to WindowServer on every mouseDown/mouseDragged is expensive and unnecessary. The OSK window position changes rarely (only when user drags it) | Cache the bounds rect. Refresh on AXObserver notifications or periodic timer (1-2s). Check cached rect on mouse events |
| **Screen Recording permission prompt** | Would add friction for all users to support one feature. `kCGWindowBounds` works without it | Use only the data available without Screen Recording permission |

## Feature Dependencies

```
[Existing Accessibility Permission]
    |
    +--already granted--> [CGWindowListCopyWindowInfo access]
    |                         |
    |                         +--provides--> [OSK Window Bounds Detection]
    |                                            |
    |                                            +--enables--> [Cached OSK Rect]
    |                                                              |
    |                                                              +--enables--> [Hit Test in handleMouseDown]
    |
    +--already granted--> [AXObserver for OSK window] (optional, for cache refresh)

[Existing ScrollEngine.shouldPassThroughClick]
    |
    +--extend or parallel--> [OSK-specific pass-through check]
                                 |
                                 +--must fire BEFORE--> [Hold-and-decide model (pendingMouseDown)]
```

### Dependency Notes

- **No new permissions required.** `CGWindowListCopyWindowInfo` works with existing Accessibility permission for bounds data. `kCGWindowOwnerName` is available without Screen Recording.
- **Existing shouldPassThroughClick pattern is the template.** The current implementation checks if cursor is over the app's own windows. OSK detection is the same pattern but for an external process's window.
- **OSK detection must be checked early in handleMouseDown.** It must happen before the hold-and-decide `pendingMouseDown` logic to avoid any delay. The current `shouldPassThroughClick` callback already fires at the right point in the code flow (line 168 of ScrollEngine.swift).
- **AXObserver for move/resize notifications requires the OSK's PID.** Get PID from `CGWindowListCopyWindowInfo` (`kCGWindowOwnerPID`), then create `AXObserver` for that PID.

## OSK Window Detection Strategy

### Identifying the Accessibility Keyboard Window

The macOS Accessibility Keyboard runs as the process **"Assistive Control"** (also known as `com.apple.inputmethod.AssistiveControl`). Its window is named **"Panel"** in the accessibility hierarchy.

**Detection approach:**
1. Call `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)`
2. Filter for `kCGWindowOwnerName == "Assistive Control"`
3. Read `kCGWindowBounds` to get the window rect
4. The list is returned in front-to-back order; take the first match (topmost OSK panel)

**Confidence:** LOW -- The process name "Assistive Control" is based on AppleScript/accessibility tree inspection reports, not Apple documentation. The actual `kCGWindowOwnerName` string MUST be verified empirically on the target macOS version by running a test with the Accessibility Keyboard visible. Apple may use a different string internally (e.g., "AssistiveControl" without space, or "KeyboardViewerServer"). A simple enumeration script during development will confirm the exact string.

### Performance Considerations

`CGWindowListCopyWindowInfo` involves IPC to the WindowServer and is flagged as expensive by multiple developers. It should NOT be called on every mouse event.

**Recommended caching strategy:**
- On scroll mode activation (`start()`): query once to find and cache OSK bounds
- Periodic refresh: every 1-2 seconds via timer (OSK moves rarely)
- Optimal refresh: use `AXObserver` on the OSK process for `kAXWindowMovedNotification` and `kAXWindowResizedNotification`
- On mouse event: check against cached `CGRect` only (simple, fast bounds check)

## Edge Cases

| Edge Case | Expected Behavior | Implementation Note |
|-----------|-------------------|---------------------|
| Cursor exactly on OSK window border | Pass through (favor the OSK) | Use inflated bounds with small margin (4-8px) |
| OSK minimized | No pass-through (minimized OSK has no visible area) | Minimized windows may not appear in `optionOnScreenOnly` results, or bounds shrink. Verify empirically |
| OSK on different display/space | Only detect if OSK is on current screen | `CGWindowListCopyWindowInfo` with `.optionOnScreenOnly` already handles this |
| OSK not running at all | No-op, zero overhead | Cache is nil/empty; skip hit test entirely |
| OSK appears after scroll mode is already active | Should detect within 1-2 seconds | Periodic refresh timer catches this. AXObserver approach would catch it via app launch notification |
| Multiple OSK panels (custom panels from Panel Editor) | Pass through all of them | Match all windows from "Assistive Control" owner, union their bounds or check each |
| User clicks and drags starting on OSK, moves off OSK | Click passes through, subsequent drag events belong to OSK (not intercepted) | The `passedThroughClick` flag in ScrollEngine already handles this correctly -- once set for mouseDown, all subsequent drag/up events pass through |
| Fast click sequence across OSK keys | Each mouseDown independently checked against cached bounds | No state accumulation needed. Each click is an independent pass-through decision |
| OSK window overlaps app's own window | Both checks pass, click goes through | Either `shouldPassThroughClick` or OSK check triggers pass-through. Order does not matter since both return the event unmodified |

## MVP Recommendation

### Must Build (v1.1)

1. **OSK window detection via CGWindowListCopyWindowInfo** -- Find the Accessibility Keyboard by owner name, cache its bounds
2. **Hit test in handleMouseDown** -- Check cursor position against cached OSK bounds before hold-and-decide logic
3. **Periodic cache refresh** -- Timer-based refresh of OSK bounds (every 1-2 seconds)
4. **Graceful no-OSK path** -- Zero overhead when Accessibility Keyboard is not running

### Defer

- **AXObserver-based cache refresh**: Event-driven refresh is more elegant but adds complexity (PID tracking, observer lifecycle). Timer-based refresh is good enough since the OSK moves rarely. Add later if performance profiling shows timer overhead is a concern (unlikely).
- **Multiple exclusion windows**: Start with just the Accessibility Keyboard. Extend to Panel Editor custom panels if user reports issues.
- **Hit-test margin inflation**: Start with exact bounds. Add margin only if edge-case misses are reported in real usage.

## Sources

### Apple Developer Documentation (HIGH confidence for API behavior)
- [CGWindowListCopyWindowInfo](https://developer.apple.com/documentation/coregraphics/1455137-cgwindowlistcopywindowinfo) -- Window enumeration API
- [Quartz Window Services](https://developer.apple.com/documentation/coregraphics/quartz-window-services) -- Window list options and keys
- [NSWindowDelegate](https://developer.apple.com/documentation/appkit/nswindowdelegate) -- Window move/resize notifications (own process)

### Screen Recording Permission Behavior (MEDIUM confidence)
- [Screen Recording Permissions in Catalina are a Mess](https://www.ryanthomson.net/articles/screen-recording-permissions-catalina-mess/) -- Documents which CGWindowList fields require Screen Recording vs not. Key finding: `kCGWindowBounds` available without permission, `kCGWindowName` is not.
- [alt-tab-macos Issue #3819](https://github.com/lwouis/alt-tab-macos/issues/3819) -- Real-world confirmation of CGWindowListCopyWindowInfo behavior without Screen Recording
- [alt-tab-macos Issue #45](https://github.com/lwouis/alt-tab-macos/issues/45) -- Performance cost discussion for CGWindowListCopyWindowInfo

### OSK Process Identification (LOW confidence -- needs empirical verification)
- [Podfeet Podcasts - Panel Editor](https://www.podfeet.com/blog/2026/01/panel-editor/) -- References Accessibility Keyboard process
- AppleScript community references "Assistive Control" as the process name with window "Panel"
- `KeyboardViewerServer` is the separate Keyboard Viewer (layout display), NOT the Accessibility Keyboard

### macOS Accessibility Keyboard (HIGH confidence for user-facing behavior)
- [Apple Support - Use the Accessibility Keyboard](https://support.apple.com/guide/mac-help/use-the-accessibility-keyboard-mchlc74c1c9f/mac) -- Official feature documentation
- [NSHipster - Accessibility Keyboard](https://nshipster.com/accessibility-keyboard/) -- Developer-oriented overview

### Window Observation (MEDIUM confidence)
- [Hacking with Swift - Detect window position](https://www.hackingwithswift.com/forums/macos/detect-the-position-of-a-window/9306) -- AXObserver for cross-process window tracking
- [Accessibility Windows and Spaces](https://ianyh.com/blog/accessibility-windows-and-spaces-in-os-x/) -- Detailed exploration of window management via Accessibility API

---
*Feature research for: OSK-Aware Click Pass-Through (v1.1 milestone)*
*Researched: 2026-02-16*
