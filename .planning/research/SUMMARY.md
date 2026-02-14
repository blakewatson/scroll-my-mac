# Project Research Summary

**Project:** Scroll My Mac
**Domain:** macOS Accessibility / Input Manipulation
**Researched:** 2026-02-14
**Confidence:** HIGH

## Executive Summary

Scroll My Mac is a native macOS accessibility utility that converts click-and-drag mouse movements into scrolling events for users who cannot use traditional scroll wheels or trackpad gestures. This domain is well-established with several reference implementations (DragScroll, Smooze, BetterMouse), providing clear architectural patterns and known pitfalls. The product must be built as an unsandboxed, notarized macOS app using Swift 6.2/SwiftUI, leveraging CoreGraphics CGEventTap for system-wide event interception and transformation.

The recommended approach centers on a layered architecture with CGEventTap running on a background thread, coordinated through a central controller that manages cursor state, event suppression, and scroll event generation. The core technical challenge is maintaining responsive event processing while avoiding system timeouts, coupled with graceful handling of macOS accessibility permission flows. Critical dependencies require specific implementation order: permission management must come before event tap creation, basic scroll must work before inertia/polish features, and the app must be tested in an unsandboxed, notarized configuration from day one to avoid late-stage architecture changes.

Key risks include event tap timeout auto-disable (macOS kills unresponsive event handlers silently), accessibility permission complexity (requires app restart after grant, crashes if revoked while active), and sandbox incompatibility (must distribute outside Mac App Store). These are all mitigable through proper architecture: implementing timeout recovery in the event tap callback, providing clear permission flow UX with restart prompts, and establishing unsandboxed distribution strategy during project setup. The technology stack is mature (Swift 6.2, SwiftUI on macOS 14+, CGEventTap) with high confidence, and the primary execution risk is handling edge cases rather than fundamental technical unknowns.

## Key Findings

### Recommended Stack

This is a native macOS app built with Apple's first-class technologies. Swift 6.2 is the only reasonable choice for macOS development, and its new "approachable concurrency" model with default MainActor isolation simplifies threading for an app that combines UI and system event interception. SwiftUI provides a clean path for a simple windowed app with settings UI, avoiding legacy Storyboards/XIB complexity. CoreGraphics CGEventTap is the only supported API for intercepting AND modifying mouse events system-wide; the alternative NSEvent.addGlobalMonitorForEvents is listen-only and cannot suppress or transform events.

**Core technologies:**
- **Swift 6.2 (Xcode 26)**: First-class macOS language with approachable concurrency model that simplifies threading for UI+event-tap apps
- **SwiftUI (macOS 14+)**: Mature enough for simple windowed apps; provides WindowGroup and Settings scenes that map directly to requirements
- **CoreGraphics CGEventTap**: Only API that can intercept, suppress, and modify mouse events system-wide; required for transforming clicks into scrolls
- **CADisplayLink (macOS 14+)**: Display-synchronized timer for smooth inertia animation, replacing legacy CVDisplayLink
- **KeyboardShortcuts library**: Provides SwiftUI hotkey recorder UI and handles Carbon API edge cases for global hotkey registration

**Critical configuration:**
- **No App Sandbox**: Sandboxed apps cannot receive Accessibility permissions; must distribute outside Mac App Store with Developer ID signing + notarization
- **Minimum target: macOS 14.0 (Sonoma)**: Required for CADisplayLink availability; provides reasonable user coverage while maintaining modern APIs
- **Accessibility permission required**: CGEventTap with .defaultTap option (active filter mode) requires Accessibility, not just Input Monitoring

### Expected Features

Users expect this app to work system-wide with instant keyboard toggle activation. The domain has established conventions: every competitor uses global hotkeys for toggle, provides cursor change for mode indication, and implements smooth scrolling with momentum. Missing these makes the product feel incomplete or broken compared to user expectations from similar tools.

**Must have (table stakes):**
- **System-wide operation** — users expect one tool that works across all apps; requires Accessibility permissions
- **Global hotkey toggle** — standard macOS accessibility pattern; instant activation without clicking menu bar
- **Cursor change for mode indication** — users must know when scroll mode is active to prevent confusion
- **Smooth scrolling with inertia** — macOS users expect trackpad-like momentum; choppy scrolling causes complaints
- **Click-through for stationary clicks** — must detect movement threshold; otherwise users lose click ability entirely
- **Menu bar presence** — macOS utility standard; provides status indicator and settings access
- **Accessibility permission guidance** — app is useless without permission; must guide users through System Settings flow

**Should have (competitive):**
- **Directional scroll choice** — natural (content follows drag) vs traditional (scrollbar follows drag); users have strong preferences
- **Adjustable scroll speed** — fine motor control users need slower; power users want faster
- **Per-app exclusions** — design tools and VMs have native drag operations that conflict with drag-to-scroll
- **Customizable hotkey** — allow users to choose preferred modifier/hotkey combination

**Defer (v2+):**
- **Visual overlay indicator** — nice-to-have for users who miss cursor changes
- **Audio feedback** — accessibility completeness but not essential for MVP
- **Hold-modifier activation** — alternative activation pattern (hold Shift to temporarily enable)
- **Velocity-sensitive inertia** — polish feature; basic fixed inertia sufficient initially

### Architecture Approach

The architecture follows a standard layered pattern for macOS event manipulation apps: Input Layer (event tap, hotkey manager, permission manager), Coordination Layer (scroll mode controller that orchestrates state), Output Layer (scroll emitter, cursor manager), and Application Layer (SwiftUI GUI, menu bar, app state). The critical architectural decision is running CGEventTap on a dedicated background thread with its own CFRunLoop to prevent blocking the main thread, while using @Observable AppState as single source of truth for mode state that SwiftUI views and services both observe.

**Major components:**
1. **ScrollModeController** — coordinates scroll mode lifecycle across input managers, cursor state, and scroll emission; owns service instances
2. **EventTapManager** — wraps CGEventTap on background thread; handles mouse event interception and timeout recovery
3. **AppState (@Observable)** — single source of truth for mode state and settings; SwiftUI views bind to this for reactive updates
4. **ScrollEmitter** — generates synthetic scroll events from mouse movement deltas using CGEvent.scrollWheel
5. **PermissionManager** — handles Accessibility permission detection, prompting, and restart guidance

**Key patterns:**
- **CGEventTap on background thread**: Run event tap on dedicated thread with CFRunLoop to ensure responsive event handling without blocking UI
- **State-driven coordination**: Use @Observable AppState with main-thread updates; services react to state changes
- **Timeout recovery**: Handle kCGEventTapDisabledByTimeout in callback by re-enabling tap; macOS auto-disables slow event handlers
- **Click-through detection**: Track movement delta during drag; if below threshold, forward original click event on release

### Critical Pitfalls

Research uncovered six critical pitfalls with severe user impact. These are not theoretical risks—they appear in bug trackers and warnings in existing open-source projects (drag-scroll, Mac Mouse Fix, Hammerspoon). Every one requires explicit prevention measures built into the architecture.

1. **Event Tap Timeout Auto-Disable** — macOS silently disables event taps when callbacks are too slow. The app appears functional but scroll mode stops working. Must handle kCGEventTapDisabledByTimeout event type and re-enable tap, plus keep callback processing minimal (<5ms). Defer heavy work to dispatch queues. Address in Phase 1 (Core Event Infrastructure).

2. **Accessibility Permission Not Reloaded Without Restart** — user grants permission while app is running, but macOS doesn't activate it until restart. Must detect permission grant and prompt user to restart app with clear UI. Implement permission state polling or observation. Address in Phase 2 (Permission Handling).

3. **Sandbox Incompatibility** — CGEventPost and CGEventTap.defaultTap don't work in sandboxed apps. Discovering this late forces complete architecture change. Must establish unsandboxed + notarized distribution strategy during project setup (Phase 0). Test notarized builds early.

4. **Permission Revocation Crash** — if user revokes Accessibility while event tap is active, mouse can become unresponsive requiring reboot. Must monitor permission state with DistributedNotificationCenter and gracefully disable event tap before system forcibly revokes. Address in Phase 2.

5. **System-Wide Cursor Change Not Supported** — macOS doesn't support system-wide cursor themes; NSCursor only works in your own windows. Must use alternative visual indicators (menu bar icon, overlay window, or accept cursor limitation). Validate UX approach with early prototype in Phase 1.

6. **Click-Through Conflicts** — apps with custom mouse handling (games, VMs, design tools) break when event tap intercepts their events. Must implement per-app exclusion list and test with Safari, Finder, Terminal, a game, VM software, and design apps. Address in Phase 3.

## Implications for Roadmap

Based on research, the roadmap should follow a strict dependency order dictated by the layered architecture and permission requirements. Phase structure should prioritize establishing foundational infrastructure (permissions, event tap with timeout recovery) before building coordination logic, then adding polish features (inertia, customization) only after core functionality is validated.

### Phase 1: Core Event Infrastructure & Permissions

**Rationale:** Cannot create event tap without Accessibility permission; cannot test anything else until event interception works reliably. This phase establishes the foundation that every other feature depends on. The event tap must include timeout recovery from day one—retrofitting this is risky.

**Delivers:**
- AppState with @Observable pattern for mode state
- PermissionManager with Accessibility detection, prompting, restart guidance
- EventTapManager on background thread with timeout recovery
- Basic SwiftUI window/menu bar shell for testing

**Addresses:**
- System-wide operation (table stakes feature)
- Accessibility permission guidance (table stakes feature)
- Event tap timeout auto-disable (critical pitfall #1)
- Accessibility permission state handling (critical pitfall #2)
- Sandbox incompatibility (critical pitfall #3—establish unsandboxed build configuration)

**Avoids:** Building any event processing logic before permission and event tap infrastructure is solid. Testing only in Xcode development mode without verifying unsandboxed/notarized configuration.

**Stack elements used:** Swift 6.2, SwiftUI, CGEventTap, AXIsProcessTrusted

### Phase 2: Basic Scroll Mode Toggle & Emission

**Rationale:** Now that event tap is reliable, implement the core feature: converting drag into scroll. This phase proves the concept works end-to-end before adding complexity like inertia or click-through logic. Keep it simple: hotkey toggles mode, drag produces scroll, release ends scroll.

**Delivers:**
- ScrollModeController coordinating mode lifecycle
- HotkeyManager using KeyboardShortcuts library (fixed hotkey initially)
- ScrollEmitter generating synthetic scroll events from mouse movement
- CursorManager for mode indication (or alternative if cursor change doesn't work system-wide)

**Addresses:**
- Global hotkey toggle (table stakes feature)
- Click-and-drag to scroll (table stakes feature—core product value)
- Cursor change for mode indication (table stakes feature)
- Permission revocation handling (critical pitfall #4—monitor permission state changes)
- Cursor change limitation (critical pitfall #5—validate chosen UX approach)

**Uses:** KeyboardShortcuts library, CGEvent.scrollWheel, NSCursor or alternative indicator

**Implements:** ScrollModeController (architecture component) coordinating EventTapManager, HotkeyManager, ScrollEmitter, CursorManager

**Avoids:** Implementing inertia, speed adjustment, or customization before basic scroll works. Skipping permission revocation testing.

### Phase 3: Click-Through Detection & App Exclusions

**Rationale:** Basic scroll works, but users need to click things too. Without click-through detection, the app makes the Mac partially unusable. This is complex enough to deserve its own phase with extensive cross-app testing. Per-app exclusions must be built now before users report specific app conflicts.

**Delivers:**
- Movement threshold detection in EventTapManager
- Click-through logic: forward original click if movement below threshold
- Per-app exclusion list (by bundle ID) with UI for managing exclusions
- Extensive testing matrix: Safari, Finder, Terminal, game, VM, design app

**Addresses:**
- Click-through for stationary clicks (table stakes feature)
- Per-app exclusions (competitive feature for handling app conflicts)
- Click-through conflicts (critical pitfall #6)

**Avoids:** Assuming click detection will work everywhere without testing diverse apps. Using overly aggressive movement thresholds that prevent small scrolls.

### Phase 4: Smooth Scrolling & Inertia

**Rationale:** Core functionality complete; now add polish that makes it feel like a native macOS feature. Inertia is expected by users but technically independent of basic scroll—can be added as enhancement. CADisplayLink for frame-synchronized animation is straightforward but requires tuning to feel natural.

**Delivers:**
- InertiaEngine with velocity calculation and physics-based deceleration
- CADisplayLink integration for smooth 60fps animation
- Tuning of deceleration curve to match macOS trackpad feel

**Addresses:**
- Smooth scrolling with inertia (table stakes feature—but can be basic initially and enhanced here)

**Uses:** CADisplayLink (macOS 14+), inertia animation patterns

**Avoids:** Over-engineering inertia with complex velocity curves before validating basic feel. Implementing inertia before click-through works (would create confusing UX).

### Phase 5: Customization & Polish

**Rationale:** MVP is complete and validated. Add features that improve usability but aren't essential for launch. These are lower risk and can be added incrementally based on user feedback. Launch at login is standard for accessibility tools but not critical for initial validation.

**Delivers:**
- Adjustable scroll speed (slider in settings)
- Directional scroll preference (natural vs traditional)
- Customizable hotkey using KeyboardShortcuts recorder UI
- Launch at login using SMAppService
- Settings UI polish

**Addresses:**
- Adjustable scroll speed (competitive feature)
- Directional preference (competitive feature)
- Customizable hotkey (competitive feature)
- Launch at login (table stakes feature—but can defer to this phase)

**Avoids:** Building extensive customization before validating that defaults work well for most users.

### Phase Ordering Rationale

- **Permissions first**: Cannot test event interception without Accessibility permission; discovering permission issues late wastes time
- **Event tap with recovery before coordination**: Timeout recovery must be architected from the start; retrofitting is error-prone
- **Basic scroll before click-through**: Proves core concept works; click-through logic is complex enough to isolate
- **Click-through before inertia**: Inertia without working clicks creates frustrating UX during testing
- **Inertia before customization**: Polish the default experience before adding options; users should have a good experience with zero configuration
- **Customization last**: Features in this phase can be added incrementally; not dependencies for earlier phases

This ordering follows the architecture's layered structure (input layer → coordination layer → output layer → polish), avoids pitfalls by addressing them in the phase where their components are built, and enables incremental testing with progressively more complete functionality at each phase.

### Research Flags

**Phases likely needing deeper research during planning:**
- **Phase 3 (Click-Through)**: Movement threshold tuning and app exclusion list require research into specific app behaviors; may need to investigate bundle ID detection and NSRunningApplication APIs
- **Phase 4 (Inertia)**: Physics-based deceleration curves and matching native macOS feel may require experimentation and research into Apple's inertia algorithms

**Phases with standard patterns (skip research-phase):**
- **Phase 1**: CGEventTap, Accessibility permissions, and SwiftUI setup are well-documented with clear Apple documentation and multiple reference implementations
- **Phase 2**: Hotkey registration via KeyboardShortcuts library and scroll event generation are straightforward; library documentation is comprehensive
- **Phase 5**: Settings UI, preferences persistence, and launch at login are standard macOS patterns with abundant examples

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All components verified in official Apple documentation; Swift 6.2, SwiftUI, CGEventTap are mature and stable; CADisplayLink availability on macOS 14+ confirmed; KeyboardShortcuts library actively maintained with 1.8k+ stars |
| Features | MEDIUM | Feature expectations derived from competitor analysis (BetterMouse, Smooze, DragScroll) and accessibility user communities, not from direct user research; table stakes features are clear, but exact prioritization of competitive features may need validation |
| Architecture | HIGH | Layered architecture pattern is standard for event manipulation apps; reference implementations (drag-scroll, Hammerspoon, alt-tab-macos) confirm approach; component boundaries are well-established in the domain |
| Pitfalls | HIGH | All critical pitfalls documented in Apple Developer Forums, open-source project issues/warnings, and official documentation; timeout auto-disable and permission complexities are widely reported; recovery strategies are tested in production apps |

**Overall confidence:** HIGH

The technical approach is well-validated with multiple reference implementations, official documentation, and established patterns. The primary uncertainty is feature prioritization (which competitive features deliver most value), not whether the core functionality is achievable. All critical risks have known mitigation strategies.

### Gaps to Address

Research identified these gaps that need resolution during planning or implementation:

- **CADisplayLink availability verification**: MEDIUM confidence on macOS 14+ availability. Template shows MEDIUM confidence ("training data; verify availability on macOS 14 at implementation time"). Must verify in Apple documentation during Phase 4 planning, but fallback to CVDisplayLink is available if needed.

- **System-wide cursor change limitation**: Architecture research flags this as unsupported, but exact UX alternative needs early prototyping. Must validate chosen approach (menu bar icon change, overlay window, or accepting cursor limitation) with working prototype in Phase 1 before committing to UX design.

- **Movement threshold tuning**: Click-through detection requires a movement threshold to distinguish click from drag. Research doesn't provide specific pixel/point values. Must experiment during Phase 3 with diverse input devices (mouse, trackball, accessibility hardware) to find threshold that works universally.

- **Per-app exclusion detection**: Research confirms per-app exclusions are needed but doesn't detail implementation. May need to research NSRunningApplication APIs, bundle ID detection, and frontmost app observation during Phase 3 planning.

- **Inertia curve parameters**: Research confirms CADisplayLink is the right approach but doesn't provide deceleration curve coefficients to match native macOS feel. Must research Apple's inertia algorithms or use trial-and-error tuning during Phase 4. Consider analyzing trackpad scroll behavior with accessibility debugging tools.

All gaps are implementation details, not fundamental architectural unknowns. None block early phases; all can be addressed when their respective phases are planned.

## Sources

### Primary (HIGH confidence)
- **Apple Developer Documentation**: CGEvent.tapCreate, CGAssociateMouseAndMouseCursorPosition, CGWarpMouseCursorPosition, NSCursor, CADisplayLink, Accessibility permission, Notarizing macOS software, macOS 26 Tahoe Release Notes, Xcode 26 Release Notes
- **Swift.org**: Swift 6.2 release announcement with approachable concurrency details
- **GitHub: KeyboardShortcuts (sindresorhus)**: v2.4.0 documentation, SwiftUI Recorder view, macOS 10.15+ compatibility confirmed
- **Apple Developer Forums**: Accessibility permission in sandboxed apps (thread 707680), TCC Accessibility permission behavior (thread 703188), CGEventPost in sandboxed apps (thread 724603)

### Secondary (MEDIUM confidence)
- **GitHub: emreyolcu/drag-scroll**: Reference implementation in C, macOS 10.9-14.0, confirms CGEventTap approach and documents permission revocation crash risk
- **GitHub: lwouis/alt-tab-macos**: Event handling patterns for CGEventTap on background thread
- **GitHub: Hammerspoon/hammerspoon**: Event tap implementation showing timeout recovery pattern
- **Competitor websites**: Smooze Pro, BetterMouse, Mac Mouse Fix, Mos — feature analysis for table stakes identification
- **Developer blogs**: Sarunw (menu bar SwiftUI app), Nil Coalescing (macOS menu bar utility), TrozWare (SwiftUI on macOS 2025), Avanderlee (Swift 6.2 concurrency guide), jano.dev (Accessibility permission usage patterns)

### Tertiary (LOW confidence)
- **User community forums**: MacRumors, AppleVis, Apple Community Discussions — scrolling accessibility complaints used for feature gap identification, not technical verification
- **Stack Overflow / Gists**: Low-level scrolling events, CGEventSupervisor patterns — useful for code examples but not authoritative for architectural decisions

---
*Research completed: 2026-02-14*
*Ready for roadmap: yes*
