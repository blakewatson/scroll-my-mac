# Pitfalls Research

**Domain:** macOS Accessibility/Input Control App (Scroll My Mac)
**Researched:** 2026-02-14
**Confidence:** HIGH (verified with official Apple documentation and established open-source projects)

## Critical Pitfalls

### Pitfall 1: Event Tap Timeout Auto-Disable

**What goes wrong:**
macOS automatically disables event taps when callbacks take too long to process. Your scroll mode suddenly stops working with no obvious error. The app appears functional but the event tap silently fails.

**Why it happens:**
macOS sends `kCGEventTapDisabledByTimeout` when the callback doesn't return quickly enough. Developers often don't handle this event type, assuming once created, event taps stay active.

**How to avoid:**
1. Handle `kCGEventTapDisabledByTimeout` in your callback
2. When received, call `CGEventTapEnable(eventTap, true)` to re-enable
3. Keep callback processing minimal - defer heavy work to dispatch queues
4. Log timeout events to detect problematic code paths

**Warning signs:**
- Scroll mode stops working randomly after extended use
- Works fine in testing but fails in real usage with complex apps
- Users report "it just stopped working"

**Phase to address:**
Phase 1 (Core Event Infrastructure) - Build timeout recovery into the event tap from the start

**Sources:**
- [Apple: CGEventType.tapDisabledByTimeout](https://developer.apple.com/documentation/coregraphics/cgeventtype/tapdisabledbytimeout)
- [Hammerspoon event tap implementation](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/eventtap/libeventtap.m)

---

### Pitfall 2: Accessibility Permission State Not Reloaded Without Restart

**What goes wrong:**
User grants Accessibility permission while the app is running, but the app doesn't detect it. The user thinks permission is granted (checkbox is checked) but the app still doesn't work.

**Why it happens:**
The Accessibility feature is not activated until the app is relaunched. Unlike some permissions that update in real-time, TCC accessibility state is cached at launch.

**How to avoid:**
1. Check Accessibility state using `AXIsProcessTrustedWithOptions`
2. Observe state changes (see drag-scroll v1.2.0 approach)
3. Prompt user to restart the app when permissions are newly granted
4. Display clear UI indicating "Restart required after granting permission"

**Warning signs:**
- User reports "I checked the box but nothing happens"
- Permission checkbox is checked but app logs show no accessibility access
- Works after restart but never after initial grant

**Phase to address:**
Phase 2 (Permission Handling) - Implement robust permission state management with user guidance

**Sources:**
- [Apple Developer Forums: TCC Accessibility permission](https://developer.apple.com/forums/thread/703188)
- [drag-scroll v1.2.0 changelog](https://github.com/emreyolcu/drag-scroll)

---

### Pitfall 3: Sandbox Incompatibility with Event Posting

**What goes wrong:**
App works perfectly in development, passes all tests, then fails silently when sandboxed or submitted to Mac App Store. CGEventPost and CGEventTap stop working.

**Why it happens:**
You cannot sandbox an app that controls another app. Posting keyboard or mouse events using functions like `CGEventPost` is not allowed from a sandboxed app. Input Monitoring privilege can work in sandboxed apps, but Accessibility cannot.

**How to avoid:**
1. Decide distribution model early: App Store (sandboxed) vs Direct (notarized)
2. For scroll injection functionality, you MUST distribute outside App Store
3. Use Developer ID signing + notarization for direct distribution
4. Test in sandboxed environment early to confirm incompatibility

**Warning signs:**
- CGEventPost returns without error but events don't appear
- Works in Xcode debug but not when exported
- AXIsProcessTrustedWithOptions never prompts in sandboxed builds

**Phase to address:**
Phase 0 (Project Setup) - Establish distribution strategy before writing any code. This affects architecture fundamentally.

**Sources:**
- [Apple Developer Forums: Accessibility permission in sandboxed app](https://developer.apple.com/forums/thread/707680)
- [Apple Developer Forums: CGEventPost in sandboxed apps](https://developer.apple.com/forums/thread/724603)

---

### Pitfall 4: Permission Revocation While App Running Causes Crash/Hang

**What goes wrong:**
User revokes Accessibility permission while the app is running. Mouse becomes unresponsive, requiring a reboot. App may crash or enter undefined state.

**Why it happens:**
Event taps hold system resources. Revoking permission while the tap is active doesn't cleanly release the tap. The drag-scroll project explicitly warns: "revoking accessibility access while running risks making your mouse unresponsive, requiring a reboot."

**How to avoid:**
1. Monitor permission state changes using `DistributedNotificationCenter`
2. Gracefully disable event tap before system forcibly revokes
3. Provide clear UI warning about not revoking while scroll mode is active
4. Test permission revocation scenario explicitly

**Warning signs:**
- Testing never includes permission revocation while app is active
- Mouse becomes stuck during development
- User reports requiring reboot after using your app

**Phase to address:**
Phase 2 (Permission Handling) - Implement graceful degradation when permissions change

**Sources:**
- [drag-scroll README warning](https://github.com/emreyolcu/drag-scroll)
- [Macworld: How to fix macOS Accessibility permission](https://www.macworld.com/article/347452/how-to-fix-macos-accessibility-permission-when-an-app-cant-be-enabled.html)

---

### Pitfall 5: System-Wide Cursor Change Not Supported

**What goes wrong:**
Developer assumes they can change the cursor system-wide to indicate scroll mode, but macOS doesn't support system-wide cursor themes. The cursor changes only in the app's own windows or not at all.

**Why it happens:**
macOS doesn't support system-wide cursor themes (.cur or .ani files) as Windows does. NSCursor changes only apply within your app's windows. CGEventTap can observe but not modify the cursor in other apps' windows.

**How to avoid:**
1. Use alternative visual indicators: menu bar icon change, overlay window, color flash
2. Consider a small floating indicator window (NSPanel with appropriate level)
3. Accept that cursor change may not be possible and design UX accordingly
4. Test cursor behavior across different apps before committing to that UX

**Warning signs:**
- Cursor changes work in your own app's window but nowhere else
- NSCursor.set() doesn't affect cursor in Safari, Finder, etc.
- Planning features around cursor changes without prototyping first

**Phase to address:**
Phase 1 (Core Scroll Mechanism) - Validate UX approach early with prototype; likely need alternative to cursor change

**Sources:**
- [Custom Cursor Mac Guide](https://focusee.imobie.com/record-tips/how-to-get-a-custom-cursor-on-mac.htm)
- [Apple Support: Pointers in macOS](https://support.apple.com/guide/mac-help/pointers-in-macos-mh35695/mac)

---

### Pitfall 6: Click-Through Detection Conflicts with Apps

**What goes wrong:**
Click detection works in most apps but fails in specific applications like games, virtual machines, design software. Drop-down menus don't work. Some apps receive events twice or not at all.

**Why it happens:**
Applications with their own mouse interpreters (games, VMs, design tools) handle events differently. Your event tap may intercept events these apps expect to receive unmodified. Determining "click vs drag" requires timing thresholds that conflict with app-specific behavior.

**How to avoid:**
1. Implement app exclusion list (by bundle ID)
2. Provide user-configurable exclusions
3. Test with: Safari, Finder, Terminal, a game, Parallels/VMware, Figma
4. Consider "pass-through" mode that forwards events unmodified to excluded apps

**Warning signs:**
- Works in Finder but fails in Photoshop
- Users report specific apps behaving strangely
- Virtual machine input completely broken

**Phase to address:**
Phase 3 (Click-Through Implementation) - Include app exclusion mechanism and extensive cross-app testing

**Sources:**
- [BetterMouse documentation](https://better-mouse.com/)
- [Mac Mouse Fix issue #28](https://github.com/noah-nuebling/mac-mouse-fix/issues/28)

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcoded scroll sensitivity | Ship faster | Every user has different needs | Never - add settings from start |
| Single event tap for all events | Simpler code | Can't selectively disable/enable | Prototype only |
| Polling for permission changes | Works reliably | Battery drain, CPU usage | Never - use notification observers |
| Synchronous scroll event posting | Simpler flow | Blocks callback, triggers timeout | Never - use async dispatch |
| Skipping notarization during dev | Faster iteration | Discovers signing issues late | Dev only - test notarized builds weekly |

## Integration Gotchas

Common mistakes when connecting to external services/APIs.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| CGEventTap | Creating tap before checking permissions | Check `AXIsProcessTrustedWithOptions` first, then create tap |
| Input Monitoring | Assuming same as Accessibility | Different TCC entries; use `CGPreflightListenEventAccess()` for Input Monitoring |
| Menu Bar (SwiftUI) | Using SettingsLink in MenuBarExtra | SettingsLink doesn't work reliably; use NSApp.sendAction for settings |
| System Settings deep link | Hardcoding preference pane paths | Use `x-apple.systempreferences:` URL scheme which is version-stable |
| Run at Login | Using deprecated login items | Use SMAppService (macOS 13+) or ServiceManagement framework |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Heavy computation in event callback | Events lag, then tap disables | Dispatch to background queue, return immediately | Any sustained use |
| Creating new scroll events synchronously | Jerky scrolling, delays | Pre-create event objects, reuse and modify | >10 scroll events/second |
| Logging every event | Disk I/O blocks callback | Log to memory buffer, flush periodically | Debug builds with high mouse activity |
| Not releasing CGEvent objects | Memory grows unbounded | Always CFRelease returned events | Hours of continuous use |

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Not validating event source | Could process synthetic events from other apps as legitimate | Check event source with CGEventGetIntegerValueField |
| Storing sensitive preferences unencrypted | Hotkey bindings could reveal user patterns | Use Keychain for any sensitive settings |
| Broadcasting scroll activation state | Other apps could detect activity patterns | Keep state internal, don't use DistributedNotificationCenter for state |
| Running as root for HID tap | Major security vulnerability | Never require root; use proper permissions instead |

## UX Pitfalls

Common user experience mistakes in this domain.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No visual feedback when scroll mode activates | User doesn't know if hotkey worked | Immediate visual/audio confirmation |
| Permission prompt with no explanation | User denies permission out of caution | Explain why permission is needed BEFORE system prompt |
| Scroll mode gets "stuck" | User can't click anything, panic | Always provide escape hatch (Esc key, timeout, click count) |
| Inertia that can't be stopped | User overshoots, frustration | Click immediately stops inertia; provide sensitivity settings |
| No way to disable globally | User forced to quit app | Menu bar toggle, global disable hotkey |
| Conflicts with trackpad gestures | Breaks native macOS scrolling | Detect input device; only activate for mouse, not trackpad |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Event Tap:** Often missing timeout recovery handler - verify `kCGEventTapDisabledByTimeout` is handled
- [ ] **Permissions:** Often missing restart prompt after grant - verify permission flow includes restart guidance
- [ ] **Click Detection:** Often missing movement threshold - verify small movements don't trigger scroll
- [ ] **Scroll Events:** Often missing device-specific testing - verify with trackpad AND mouse AND Magic Mouse
- [ ] **Inertia:** Often missing deceleration curve tuning - verify feels natural, matches system behavior
- [ ] **Menu Bar:** Often missing accessibility labels - verify VoiceOver can navigate all controls
- [ ] **Hotkey:** Often missing conflict detection - verify chosen hotkey doesn't conflict with common apps
- [ ] **Notarization:** Often missing hardened runtime - verify app launches on fresh Mac without developer tools

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Event tap timeout disabled | LOW | Re-enable tap in callback; no user action needed |
| Permission revocation while active | MEDIUM | Force quit app; user restarts app and re-grants permission |
| Mouse stuck during development | HIGH | System reboot required; add safety timeout to event tap |
| Sandbox discovery late | HIGH | Refactor for direct distribution; delay release |
| Click-through broken in specific app | LOW | Add to exclusion list; ship update |
| Cursor change doesn't work | MEDIUM | Redesign UX for alternative indicator; requires UI changes |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Event tap timeout | Phase 1: Core Infrastructure | Log shows timeout recovery; tap stays active under load |
| Permission not reloaded | Phase 2: Permissions | Grant permission while running; verify restart prompt appears |
| Sandbox incompatibility | Phase 0: Project Setup | Distribution strategy documented; notarization tested |
| Permission revocation crash | Phase 2: Permissions | Revoke while running; verify graceful degradation |
| Cursor change limitation | Phase 1: Core Scroll | Prototype validates chosen indicator approach |
| Click-through conflicts | Phase 3: Click-Through | Tested in 5+ diverse apps including VM and game |
| Hotkey conflicts | Phase 4: Hotkey System | Default hotkey tested against top 10 productivity apps |
| Inertia feel | Phase 5: Inertia | User testing confirms natural feel |

## Sources

- [Apple Developer: CGEventTap documentation](https://developer.apple.com/documentation/coregraphics/cgevent)
- [Apple Developer: tapDisabledByTimeout](https://developer.apple.com/documentation/coregraphics/cgeventtype/tapdisabledbytimeout)
- [Apple Developer Forums: Accessibility in sandboxed apps](https://developer.apple.com/forums/thread/707680)
- [Apple Developer Forums: CGEventPost issues](https://developer.apple.com/forums/thread/724603)
- [Apple Developer Forums: TCC Accessibility permission](https://developer.apple.com/forums/thread/703188)
- [drag-scroll GitHub project](https://github.com/emreyolcu/drag-scroll) - Similar macOS drag-to-scroll implementation
- [Mac Mouse Fix GitHub](https://github.com/noah-nuebling/mac-mouse-fix) - Comprehensive mouse utility with similar challenges
- [Hammerspoon event tap implementation](https://github.com/Hammerspoon/hammerspoon)
- [Apple Support: Pointers in macOS](https://support.apple.com/guide/mac-help/pointers-in-macos-mh35695/mac)
- [Macworld: Accessibility permission fixes](https://www.macworld.com/article/347452/how-to-fix-macos-accessibility-permission-when-an-app-cant-be-enabled.html)
- [Apple Notarization documentation](https://developer.apple.com/documentation/xcode/notarizing_macos_software_before_distribution)

---
*Pitfalls research for: Scroll My Mac - macOS Accessibility/Input Control App*
*Researched: 2026-02-14*
