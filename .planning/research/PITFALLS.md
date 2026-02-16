# Pitfalls Research

**Domain:** OSK-aware click pass-through for existing CGEventTap interceptor
**Researched:** 2026-02-16
**Confidence:** MEDIUM (CGWindowListCopyWindowInfo behavior well-documented; Accessibility Keyboard specifics based on training data + community patterns, not verified against live system)

## Critical Pitfalls

### Pitfall 1: Calling CGWindowListCopyWindowInfo Inside the Event Tap Callback

**What goes wrong:**
Calling `CGWindowListCopyWindowInfo` on every `mouseDown` inside the CGEventTap callback causes the callback to block for tens to hundreds of milliseconds. macOS enforces strict timing on event tap callbacks and will send `kCGEventTapDisabledByTimeout`, silently disabling the tap. Scroll mode stops working with no visible error.

**Why it happens:**
`CGWindowListCopyWindowInfo` is a cross-process IPC call to WindowServer. It enumerates all windows in the session, serializes their metadata into dictionaries, and returns a CFArray. This is inherently slow -- developers underestimate the cost because it "works fine" in isolation but breaks under the real-time constraints of an event tap callback.

**How to avoid:**
Never call `CGWindowListCopyWindowInfo` inside the event tap callback. Instead, cache the OSK window bounds outside the callback and do a simple `CGRect.contains(point)` hit test in the callback itself. Two caching strategies:

1. **Timer-based polling (simplest, recommended for this use case):** Poll `CGWindowListCopyWindowInfo` on a background timer (every 0.5-1s) to update cached OSK bounds. The OSK moves infrequently (user drags it), so stale data risk is minimal.

2. **AXObserver-based (more complex, more accurate):** Use `AXObserverCreate` + `kAXMovedNotification` / `kAXResizedNotification` on the AssistiveControl process to get notified when the OSK window moves. More accurate but significantly more code.

The event tap callback should only read from a cached `CGRect?` (nil = no OSK visible, non-nil = OSK bounds). This is O(1) with no IPC.

**Warning signs:**
- Event tap disabled by timeout errors in logs after adding OSK detection
- Scroll mode randomly stops working when many windows are open
- Works in testing (few windows) but fails in real usage (dozens of windows)

**Phase to address:**
Phase 1 of OSK milestone -- cache architecture must be established before any hit-test logic.

**Sources:**
- [Apple: CGEventType.tapDisabledByTimeout](https://developer.apple.com/documentation/coregraphics/cgeventtype/tapdisabledbytimeout)
- [Apple: CGWindowListCopyWindowInfo](https://developer.apple.com/documentation/coregraphics/1455137-cgwindowlistcopywindowinfo)
- [JDK-8238435: Remove use of CGEventTap](https://bugs.openjdk.org/browse/JDK-8238435) -- documents tap timeout issues
- [alt-tab-macos issue #45](https://github.com/lwouis/alt-tab-macos/issues/45) -- documents CGWindowListCopyWindowInfo performance

---

### Pitfall 2: Race Condition Between OSK Movement and Cached Bounds

**What goes wrong:**
User drags the Accessibility Keyboard to a new position. The cached bounds still reflect the old position. A click lands where the OSK used to be and gets intercepted (false negative -- click should have passed through). Or a click lands where the OSK now is but the cache shows empty space, so it gets intercepted instead of passed through (also false negative).

**Why it happens:**
`CGWindowListCopyWindowInfo` is a snapshot API with no change notification mechanism. There is no public API to be notified when a window moves. The TOCTOU (time-of-check/time-of-use) gap between polling the window list and the user clicking is inherent.

**How to avoid:**
1. **Accept imperfection.** The OSK is dragged rarely (seconds/minutes between repositions). A 0.5-1s polling interval means at most a 1-second window where cached bounds are stale. This is acceptable because:
   - The user just finished dragging the OSK (their hand is still on the mouse).
   - They are unlikely to immediately click the exact spot where the OSK just was or just arrived.
2. **Add padding to the cached bounds.** Expand the hit-test rect by 10-20px on all sides. This catches near-misses from slight position drift without significantly expanding the pass-through zone.
3. **Refresh cache on mouseDown (but off the callback).** When a mouseDown arrives and the cursor is near the cached OSK bounds (within, say, 50px), trigger an immediate cache refresh on the next run loop iteration. This won't help the current click but will be accurate for the next one.

**Warning signs:**
- Users report OSK clicks occasionally being "swallowed" right after moving the OSK
- Inconsistent pass-through behavior that users cannot reproduce reliably

**Phase to address:**
Phase 1 -- build padding into the hit-test from the start. Do not treat this as a post-ship polish item.

**Sources:**
- [Apple Developer Forums: kCGWindowListOptionOnScreenOnly wrong ordering](https://developer.apple.com/forums/thread/713113) -- documents TOCTOU race

---

### Pitfall 3: Misidentifying the Accessibility Keyboard Process/Window

**What goes wrong:**
The OSK detection logic uses the wrong process name, window name, or window layer. It either never detects the OSK (false negatives -- all OSK clicks intercepted) or matches unrelated system windows (false positives -- clicks near random windows pass through).

**Why it happens:**
The Accessibility Keyboard is owned by the `AssistiveControl` process, which also manages other assistive features (Switch Control, Dwell Control). Developers may filter by window name (`kCGWindowName`), but that key requires Screen Recording permission -- without it, the key is absent from the dictionary. Or they may match the process name but catch non-keyboard AssistiveControl windows.

**How to avoid:**
1. **Filter by `kCGWindowOwnerName == "AssistiveControl"` first.** This does NOT require Screen Recording permission. `kCGWindowOwnerName` is always available.
2. **Filter by `kCGWindowLayer`.** The Accessibility Keyboard renders at an elevated window level (above normal app windows). Use `kCGWindowLayer` to distinguish it from normal windows. Empirically verify the layer value on your target macOS version by printing all AssistiveControl windows.
3. **Filter by `kCGWindowBounds` size.** The keyboard window has a recognizable minimum size (roughly 800x200+ pixels). Tiny AssistiveControl windows are likely toolbar panels, not the keyboard.
4. **Do NOT rely on `kCGWindowName`.** It requires Screen Recording permission. Use owner name + layer + bounds instead.
5. **Empirically verify.** Before writing any detection logic, run a diagnostic that prints all `CGWindowListCopyWindowInfo` entries for AssistiveControl. Document the exact keys and values. The Accessibility Keyboard may appear as multiple windows (the keyboard panel, the toolbar, resize handles).

**Warning signs:**
- Detection works in development but not after distribution (Screen Recording permission not requested)
- Detection matches too many windows (clicking near any system UI passes through)
- Detection works on your macOS version but fails on others

**Phase to address:**
Phase 1 -- empirical verification of window properties must happen before any detection logic is written. This is a "measure twice, cut once" task.

**Sources:**
- [Apple: CGWindowListCopyWindowInfo](https://developer.apple.com/documentation/coregraphics/cgwindowlistcopywindowinfo(_:_:))
- [Apple Developer Forums: window name not available in macOS 10.15](https://developer.apple.com/forums/thread/126860)

---

### Pitfall 4: Breaking the Existing shouldPassThroughClick Architecture

**What goes wrong:**
The OSK detection is added by modifying the existing `shouldPassThroughClick` closure in AppState, but the new code introduces blocking calls or changes the semantics. The existing pass-through for app-owned windows (settings panel) breaks, or the callback now takes too long for all clicks, not just OSK-area clicks.

**Why it happens:**
The current `shouldPassThroughClick` closure (line 112-120 of AppState.swift) iterates `NSApp.windows` -- a fast, in-process operation. Developers may add OSK detection inline, turning a microsecond check into a millisecond-or-worse IPC call. Or they may restructure the closure in a way that changes the evaluation order, breaking the existing app-window pass-through.

**How to avoid:**
1. **Keep the existing NSApp.windows check untouched.** Add OSK detection as a second, independent check. The closure should short-circuit: if the click is on an app window, return true immediately without checking OSK bounds.
2. **OSK check must be a simple rect-contains test against cached data.** No IPC in the callback path.
3. **Structure as OR logic:**
   ```swift
   scrollEngine.shouldPassThroughClick = { cgPoint in
       // Check 1: App's own windows (existing, unchanged)
       if self.isClickOnOwnWindow(cgPoint) { return true }
       // Check 2: OSK bounds (new, cache-based)
       if self.isClickOnOSK(cgPoint) { return true }
       return false
   }
   ```
4. **Test the existing behavior first.** Before adding OSK detection, verify the settings-panel click pass-through still works. Regression here would be a significant UX break.

**Warning signs:**
- Settings panel clicks stop working after adding OSK detection
- All clicks feel slightly sluggish (blocking call added to hot path)
- Test coverage only exercises the new OSK path, not the existing app-window path

**Phase to address:**
Phase 1 -- the integration point is the very first thing to design. Do not bolt on OSK detection without understanding the existing closure.

---

### Pitfall 5: OSK Visibility State Tracking (Minimized, Hidden, Closed)

**What goes wrong:**
The OSK detection reports the keyboard as present even when it is minimized to the Dock, hidden behind other windows, or closed. Clicks in the cached bounds area pass through incorrectly, creating "dead zones" on screen where clicks are never intercepted.

**Why it happens:**
`CGWindowListCopyWindowInfo` with `.optionOnScreenOnly` excludes minimized windows, but the cached bounds may be stale from before the minimize. If polling interval is 1s, there is up to 1s where the cache says "OSK is here" but it is already minimized. Worse, if the user disables the Accessibility Keyboard in System Settings, the AssistiveControl process may terminate, and the cache still holds the last-known bounds.

**How to avoid:**
1. **Always use `.optionOnScreenOnly` flag** when polling. This excludes minimized and off-screen windows.
2. **Set cache to nil when no matching window is found.** If a poll returns no AssistiveControl windows, immediately clear the cached bounds. Do not retain stale bounds.
3. **Handle the "OSK toggled off" case.** When the Accessibility Keyboard is disabled in System Settings, AssistiveControl may exit. The next poll will find no matching windows and clear the cache. The 0.5-1s latency is acceptable here.
4. **Consider observing `NSWorkspace.didTerminateApplicationNotification`** for the AssistiveControl process. This gives immediate cache invalidation when the OSK process exits.

**Warning signs:**
- "Dead zone" on screen where clicks always pass through even without OSK visible
- Users report clicks not working in a specific screen area after minimizing the OSK
- Bug only appears when OSK has been used and then dismissed

**Phase to address:**
Phase 1 -- cache invalidation logic must be part of the initial cache design.

---

### Pitfall 6: Coordinate System Mismatch (CG vs NS)

**What goes wrong:**
The hit test incorrectly compares CG coordinates (top-left origin, from `event.location`) with NS/screen coordinates (bottom-left origin). Clicks pass through in the wrong location -- mirrored vertically from where the OSK actually is.

**Why it happens:**
The existing codebase already handles this for app-window detection (line 115-116 of AppState.swift converts CG to NS coordinates). But `CGWindowListCopyWindowInfo` returns bounds in CG coordinate space (top-left origin). If the developer converts the event location to NS coordinates and then compares against CG-origin bounds, the hit test is vertically flipped.

**How to avoid:**
1. **Keep everything in CG coordinate space for the OSK check.** The event location (`event.location`) is already in CG coordinates. `kCGWindowBounds` from `CGWindowListCopyWindowInfo` is also in CG coordinates. Compare directly without conversion.
2. **Do NOT reuse the NS coordinate conversion from the app-window check.** The two checks operate in different coordinate systems for good reason: NSApp.windows use NS coordinates, CGWindowList uses CG coordinates.
3. **Use `CGRectMakeWithDictionaryRepresentation`** to parse `kCGWindowBounds` into a `CGRect`. This handles the dictionary-to-rect conversion correctly.

**Warning signs:**
- OSK detection works on the primary display but fails on secondary displays (different coordinate offsets)
- Hit test seems "off" vertically -- clicks above the OSK pass through, clicks on it get intercepted
- Works only when the menu bar is at the top of the screen

**Phase to address:**
Phase 1 -- coordinate system handling must be correct from the first implementation. This is not something to "fix later."

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Polling CGWindowListCopyWindowInfo on every mouseDown | Simplest implementation | Event tap timeout, janky scrolling | Never -- always cache |
| Hardcoding "AssistiveControl" process name | Works today | May break on future macOS versions if Apple renames the process | Acceptable with a comment noting the assumption and a UserDefaults override for debugging |
| Skipping multi-display coordinate testing | Faster development | Broken hit tests on external monitors | Never for coordinate-based detection |
| Using kCGWindowName for identification | More precise matching | Requires Screen Recording permission users did not agree to | Never -- use owner name + layer + bounds instead |
| Not invalidating cache when OSK closes | Fewer code paths | Phantom "dead zones" where clicks pass through | Never -- nil cache when no matching window found |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| CGWindowListCopyWindowInfo | Calling with `.optionAll` (includes off-screen, minimized) | Use `.excludeDesktopElements` + `.optionOnScreenOnly` |
| kCGWindowBounds parsing | Manually extracting x/y/width/height from dictionary | Use `CGRectMakeWithDictionaryRepresentation` |
| Event tap + window query | Synchronous window query inside callback | Cache outside callback, read cache inside callback |
| shouldPassThroughClick | Replacing entire closure when adding new check | Extend with additional OR condition, keep existing checks |
| CG coordinate space | Mixing CG (top-left) and NS (bottom-left) coordinates | Keep OSK detection entirely in CG space; only convert for NSWindow comparisons |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| CGWindowListCopyWindowInfo per mouseDown | Event tap timeouts, scroll stuttering | Cache-and-read pattern | Immediately on systems with 20+ windows |
| Polling window list too frequently (<100ms) | CPU spike, WindowServer load | 500ms-1000ms poll interval | Sustained use with many windows open |
| Iterating full window list when only one window needed | Unnecessary allocations per poll cycle | Filter early: break after finding AssistiveControl match | Systems with 50+ windows |
| Creating new CGRect objects in callback | GC pressure in hot path | Cache as stored property, update only on poll | High-frequency click patterns |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| OSK clicks swallowed silently | User thinks keyboard is broken; cannot type | Always err toward passing clicks through near the OSK (generous bounds) |
| Pass-through zone too large | Scrolling stops working near the OSK; user confused | Use actual window bounds + small padding (10-20px), not an oversized region |
| No feedback when pass-through activates | User does not understand why click behavior changes near OSK | Not needed -- pass-through should be invisible. The click just works. |
| OSK detection active when OSK is not enabled | Unnecessary overhead, possible false positives | Only poll when Accessibility Keyboard is known to be enabled (check on app launch + periodically) |

## "Looks Done But Isn't" Checklist

- [ ] **Cache invalidation:** Verify cache clears when OSK is minimized, closed, or disabled in System Settings
- [ ] **Multi-display:** Verify hit test works on secondary displays with different resolutions and arrangements
- [ ] **Coordinate system:** Verify CG coordinates are used consistently (not accidentally converting to NS for the OSK check)
- [ ] **Existing pass-through:** Verify settings panel clicks still work after adding OSK detection
- [ ] **AssistiveControl windows:** Verify only the keyboard window is matched, not Switch Control or Dwell panels
- [ ] **Event tap performance:** Verify no event tap timeouts occur under normal use (check Console.app for kCGEventTapDisabledByTimeout)
- [ ] **OSK not running:** Verify no errors or unexpected behavior when AssistiveControl process is not running at all
- [ ] **Padding bounds:** Verify edge clicks on the OSK border pass through correctly (not off-by-one on bounds)

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| CGWindowListCopyWindowInfo in callback | MEDIUM | Refactor to cache pattern; requires extracting polling logic |
| Wrong coordinate system | LOW | Fix comparison to use CG coordinates consistently; localized change |
| Wrong process name matching | LOW | Update filter string; single constant change |
| Cache not invalidated | LOW | Add nil-assignment in poll when no window found; small logic fix |
| Existing pass-through broken | LOW | Revert closure to original; add OSK check as separate condition |
| Dead zone from stale cache | LOW | Add `.optionOnScreenOnly` flag and nil-on-empty logic |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| CGWindowListCopyWindowInfo in callback | Phase 1: Cache architecture | Run with Console.app open; no tapDisabledByTimeout events |
| Race condition on OSK movement | Phase 1: Cache + padding | Move OSK, immediately click old position; click passes to underlying app |
| Wrong process/window identification | Phase 1: Empirical discovery | Print all AssistiveControl window properties; document exact filter criteria |
| Breaking existing pass-through | Phase 1: Integration | Settings panel click-through works identically before and after change |
| OSK visibility state | Phase 1: Cache invalidation | Minimize OSK; verify no dead zone remains. Disable OSK; verify no errors |
| Coordinate system mismatch | Phase 1: Hit-test implementation | Click center of OSK on primary and secondary display; both pass through |

## Sources

- [Apple: CGWindowListCopyWindowInfo](https://developer.apple.com/documentation/coregraphics/1455137-cgwindowlistcopywindowinfo)
- [Apple: CGEventType.tapDisabledByTimeout](https://developer.apple.com/documentation/coregraphics/cgeventtype/tapdisabledbytimeout)
- [Apple: CGWindowLevelForKey](https://developer.apple.com/documentation/coregraphics/cgwindowlevelforkey(_:))
- [Apple Developer Forums: window name not available in macOS 10.15](https://developer.apple.com/forums/thread/126860)
- [Apple Developer Forums: kCGWindowListOptionOnScreenOnly wrong ordering](https://developer.apple.com/forums/thread/713113)
- [alt-tab-macos issue #45: Window list performance](https://github.com/lwouis/alt-tab-macos/issues/45)
- [AeroSpace issue #445: Unreliable AX window notifications](https://github.com/nikitabobko/AeroSpace/issues/445)
- [FB12113281: Event taps stop receiving events](https://github.com/feedback-assistant/reports/issues/390)
- [JDK-8238435: Remove use of CGEventTap (documents timeout issues)](https://bugs.openjdk.org/browse/JDK-8238435)

---
*Pitfalls research for: OSK-aware click pass-through — Scroll My Mac v1.1*
*Researched: 2026-02-16*
