# Feature Research

**Domain:** macOS Accessibility / Input Manipulation (Click-and-Drag Scrolling)
**Researched:** 2026-02-14
**Confidence:** MEDIUM (WebSearch verified across multiple sources, no Context7 available for this domain)

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **System-wide operation** | Every competitor works across all apps; users expect one tool for entire system | MEDIUM | Requires Accessibility API permissions; must intercept events globally |
| **Hotkey toggle** | All macOS accessibility tools use keyboard shortcuts (Option-Command-X pattern standard); instant toggle is essential | LOW | Use standard macOS shortcut registration; avoid conflicts with system shortcuts |
| **Mode indicator (cursor change)** | Users must know when scroll mode is active; prevents confusion about why clicks behave differently | LOW | macOS supports custom cursors; open hand / closed hand is universal scroll metaphor |
| **Smooth scrolling with inertia** | macOS users expect trackpad-like momentum; choppy scrolling causes eyestrain complaints | MEDIUM | Implement momentum-based animation; match Apple's inertia curve |
| **Click-through for non-drag clicks** | Stationary clicks must pass through; otherwise users lose ability to click entirely in scroll mode | MEDIUM | Detect movement threshold; if no significant drag, forward original click |
| **Menu bar presence** | macOS utility apps live in menu bar; users expect icon for quick access and status | LOW | Standard SwiftUI MenuBarExtra; minimal UI footprint |
| **Launch at login option** | Accessibility tools must be always-available; users expect persistence across restarts | LOW | SMAppService or LoginItems; standard macOS pattern |
| **Accessibility permission guidance** | App requires Accessibility access; must guide users through System Settings flow clearly | LOW | Detect permission state; provide clear instructions with deep links |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Directional scroll choice** | Natural (content follows drag) vs. Traditional (scrollbar follows drag); users have strong preferences | LOW | Single boolean setting; invert scroll delta calculation |
| **Adjustable scroll speed** | Fine motor control users need slower speeds; power users want faster | LOW | Simple multiplier on scroll delta; slider in preferences |
| **Per-app enable/disable** | Some apps (e.g., design tools with native drag) conflict with drag-to-scroll; allow exclusions | MEDIUM | Track frontmost app; maintain exclusion list |
| **Visual mode indicator (overlay)** | Optional on-screen indicator for users who miss subtle cursor changes | LOW | Transparent overlay window; brief animation on toggle |
| **Audio feedback on toggle** | Accessibility users often benefit from multi-sensory feedback; brief sound on mode change | LOW | System sound or custom audio; respect system mute |
| **Velocity-sensitive inertia** | Faster drags = longer momentum; feels more natural than fixed inertia | MEDIUM | Calculate velocity from drag samples; apply physics-based deceleration |
| **Horizontal + vertical scrolling** | Allow scrolling in any direction, not just vertical | LOW | Already handling both axes if intercepting mouse delta properly |
| **Hold-modifier activation** | Alternative to toggle: hold a key (e.g., Shift) to temporarily enable scroll mode | LOW | Monitor modifier key state; no persistent toggle needed |
| **Customizable activation key** | Let users choose their preferred modifier or hotkey combination | LOW | Standard macOS shortcut recorder; store in UserDefaults |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Always-on scroll mode (no toggle)** | "I just want it to always work" | Breaks all click-and-drag operations (text selection, resizing, drawing, file dragging); makes Mac unusable | Require explicit toggle; make toggle very fast/easy (global hotkey) |
| **Complex gesture recognition** | "Detect if I want to click vs scroll" | Introduces latency (must wait to see if drag starts); unreliable with tremor/motor impairments; frustrating false positives | Use explicit toggle or hold-modifier; no guessing |
| **Automatic app detection** | "Know when I'm in a scroll context" | Heuristics fail; different apps have different scrolling regions; false negatives break user trust | Let user toggle explicitly or use per-app settings |
| **Scroll zone overlay (scroll handles)** | "Show where I can scroll" | Clutters interface; requires understanding each app's scrollable regions; maintenance nightmare | Trust user to know what they're scrolling; just change cursor |
| **Integration with external hardware** | "Support my special mouse/trackball" | Infinite device matrix; driver compatibility issues; scope explosion | Focus on software-level event interception; works with any pointing device |
| **Built-in text-to-speech** | "Announce scroll state" | Redundant with VoiceOver; adds complexity; most users already have TTS if needed | Rely on system accessibility features; provide VoiceOver-compatible labels |
| **Cloud sync of settings** | "Sync preferences across Macs" | Overkill for ~5 settings; iCloud entitlements add complexity; privacy concerns | Local UserDefaults; users can manually replicate settings |
| **Subscription pricing** | "Ongoing revenue" | Accessibility users often on fixed income; creates resentment; utility apps should be one-time | Free, donation-based, or one-time purchase |

## Feature Dependencies

```
[Accessibility Permission]
    |
    +--requires--> [Event Interception (CGEventTap)]
                       |
                       +--enables--> [Hotkey Toggle]
                       |
                       +--enables--> [Click-and-Drag Detection]
                                         |
                                         +--enables--> [Scroll Event Generation]
                                         |                   |
                                         |                   +--enhances--> [Inertia Animation]
                                         |
                                         +--enables--> [Click-Through Logic]

[Menu Bar App]
    |
    +--enables--> [Launch at Login]
    |
    +--enables--> [Settings UI]
                      |
                      +--configures--> [Scroll Speed]
                      |
                      +--configures--> [Hotkey Customization]
                      |
                      +--configures--> [Per-App Exclusions]

[Cursor Change]
    |
    +--enhances--> [Visual Overlay] (optional)
    |
    +--enhances--> [Audio Feedback] (optional)
```

### Dependency Notes

- **Accessibility Permission requires Event Interception:** Without Accessibility access, cannot intercept mouse events; this is the foundational gate
- **Click-Through requires Click-and-Drag Detection:** Must distinguish movement from stationary clicks to know when to forward click events
- **Inertia enhances Scroll Event Generation:** Inertia is applied after basic scrolling works; not required for MVP
- **Per-App Exclusions enhance Menu Bar App:** Need a place to configure exclusions; depends on settings UI existing

## MVP Definition

### Launch With (v1)

Minimum viable product - what's needed to validate the concept.

- [x] **Accessibility permission detection + guidance** - Fundamental gate; app is useless without it
- [x] **Global hotkey toggle** - Core activation mechanism; default to simple key combo
- [x] **Click-and-drag to scroll** - The entire point of the app
- [x] **Click-through for non-drag clicks** - Without this, users can't click in scroll mode
- [x] **Cursor change for mode indication** - Users must know current state
- [x] **Basic menu bar presence** - macOS utility standard; quit option minimum
- [x] **Smooth scrolling with inertia** - macOS users expect this; feels broken without it

### Add After Validation (v1.x)

Features to add once core is working.

- [ ] **Launch at login** - Add when users request persistence
- [ ] **Scroll speed adjustment** - Add if users report speed too fast/slow
- [ ] **Directional preference (natural vs traditional)** - Add if users request inverted scrolling
- [ ] **Customizable hotkey** - Add if default hotkey conflicts for users
- [ ] **Per-app exclusions** - Add when specific apps conflict

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] **Visual overlay indicator** - Nice-to-have for users who miss cursor changes
- [ ] **Audio feedback** - Nice-to-have for accessibility completeness
- [ ] **Hold-modifier activation** - Alternative activation pattern; not MVP
- [ ] **Velocity-sensitive inertia** - Polish feature; basic inertia sufficient initially

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Click-and-drag scrolling | HIGH | HIGH | P1 |
| Global hotkey toggle | HIGH | LOW | P1 |
| Cursor mode indicator | HIGH | LOW | P1 |
| Click-through for stationary clicks | HIGH | MEDIUM | P1 |
| Smooth scrolling with inertia | HIGH | MEDIUM | P1 |
| Menu bar presence | MEDIUM | LOW | P1 |
| Accessibility permission guidance | HIGH | LOW | P1 |
| Launch at login | MEDIUM | LOW | P2 |
| Scroll speed adjustment | MEDIUM | LOW | P2 |
| Directional preference | MEDIUM | LOW | P2 |
| Customizable hotkey | MEDIUM | LOW | P2 |
| Per-app exclusions | MEDIUM | MEDIUM | P2 |
| Visual overlay indicator | LOW | LOW | P3 |
| Audio feedback | LOW | LOW | P3 |
| Hold-modifier activation | LOW | LOW | P3 |
| Velocity-sensitive inertia | LOW | MEDIUM | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | Smooze Pro | BetterMouse | Mac Mouse Fix | Mos | DragScroll | Our Approach |
|---------|------------|-------------|---------------|-----|------------|--------------|
| Drag-to-scroll | Yes (grab & drag) | Yes (drag panning) | No (gesture-focused) | No (smooth scroll only) | Yes (toggle-based) | Yes - primary feature |
| Smooth scrolling | Yes | Yes | Yes | Yes | No | Yes - with inertia |
| Per-app settings | Yes (per app, per display) | Yes | Limited | Yes | Yes (exclusions) | P2 - keep simple initially |
| Button customization | Yes (mouse buttons to actions) | Yes (extensive) | Yes (5-button mice) | Yes (bindings) | Yes (configurable button) | No - focused scope |
| Modifier-based activation | Unknown | Yes | Yes | Yes (dash key) | Yes (configurable) | P3 - hotkey toggle simpler |
| Menu bar app | Yes | Yes | Yes | Yes | Yes | Yes - standard pattern |
| Free/Open source | No ($14.99) | No ($7.99) | Open source ($2.99) | Free (CC BY-NC) | Open source (free) | Free or donation-based |
| macOS version support | Recent | Recent | 10.13+ | 10.13+ | 10.9-14.0 | Modern macOS (14+) |

### Competitive Positioning

**Our differentiator:** Focused simplicity for accessibility users who specifically need click-and-drag scrolling due to motor impairments. Competitors are general mouse enhancement tools with many features. We do one thing well.

**Gap we fill:** Most competitors focus on smooth scrolling for external mice or gesture mapping. Few specifically address "I cannot use scroll wheel/trackpad gestures" use case with a simple toggle-based solution.

## Sources

### Primary Competitor Analysis (WebFetch - MEDIUM confidence)
- [Smooze Pro](https://smooze.co/) - Feature-rich mouse enhancement
- [BetterMouse](https://better-mouse.com/) - Comprehensive mouse utility
- [Mac Mouse Fix](https://macmousefix.com/) - Trackpad gestures for mice
- [Mos](https://mos.caldis.me/) - Free smooth scrolling utility
- [DragScroll](https://github.com/emreyolcu/drag-scroll) - Open source drag-to-scroll

### Apple Documentation (MEDIUM confidence)
- [macOS Accessibility Features](https://support.apple.com/guide/mac-help/get-started-mh35884/mac)
- [Pointer Control Settings](https://support.apple.com/guide/mac-help/change-pointer-control-settings-accessibility-unac899/mac)
- [Mac Keyboard Shortcuts](https://support.apple.com/en-us/102650)
- [Menu Bar Design](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar)

### User Research (WebSearch - LOW confidence, patterns observed)
- [MacRumors Forums](https://forums.macrumors.com/threads/i-cant-believe-ive-had-to-install-a-third-party-app-to-fix-mouse-scrolling.2445811/) - User complaints about scrolling
- [AppleVis](https://www.applevis.com/) - Accessibility user community feedback
- [Apple Community Discussions](https://discussions.apple.com/) - Scrolling accessibility issues

---
*Feature research for: macOS Accessibility / Input Manipulation*
*Researched: 2026-02-14*
