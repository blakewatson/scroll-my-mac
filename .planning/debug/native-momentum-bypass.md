---
status: diagnosed
trigger: "Native apps ignore momentum scrolling toggle and intensity settings"
created: 2026-02-23T00:00:00Z
updated: 2026-02-23T00:00:00Z
---

## Current Focus

hypothesis: Native apps have their own NSScrollView momentum scrolling powered by OS-level momentum scroll events. Our app posts synthetic momentum events (via InertiaAnimator) but does NOT intercept or suppress the OS-generated momentum events from real trackpad/mouse input. When inertia is disabled, we stop posting OUR momentum events but the OS still generates its own momentum events that flow to native apps. Web-view apps may handle things differently (e.g., WKWebView might defer to the event stream we control more closely).
test: CONFIRMED via code analysis
expecting: N/A - root cause confirmed
next_action: Return diagnosis

## Symptoms

expected: Toggling off momentum scrolling should stop ALL momentum/coasting in ALL apps. Intensity slider should affect coasting feel in ALL apps.
actual: Toggle and intensity work for web-view apps but native apps (Finder, IA Writer) ignore these settings and continue to have their own momentum scrolling.
errors: None (behavioral issue, not crash)
reproduction: 1) Enable scroll mode 2) Disable inertia toggle 3) Drag-scroll in Finder - still coasts. 4) Enable inertia, set intensity to min 5) Drag-scroll in Finder - coasting feel unchanged.
started: Since phase 13 added inertia controls (the controls work but only affect our custom InertiaAnimator, not OS-level momentum)

## Eliminated

- hypothesis: AppState does not propagate settings to ScrollEngine
  evidence: Code at AppState.swift lines 94-106 clearly shows didSet observers syncing isInertiaEnabled and inertiaIntensity to scrollEngine. setupServices() at line 220-222 also syncs on init.
  timestamp: 2026-02-23

- hypothesis: ScrollEngine ignores isInertiaEnabled flag
  evidence: ScrollEngine.swift line 374 clearly checks `if isInertiaEnabled` before calling inertiaAnimator.startCoasting(). When false, no coasting starts. This is correct for OUR inertia.
  timestamp: 2026-02-23

- hypothesis: InertiaAnimator does not respect intensity parameter
  evidence: InertiaAnimator.swift lines 67-98 show intensity is correctly clamped and used for two-segment linear interpolation of both tau (0.120-0.900) and velocity scale (0.4x-2.0x). The math is correct.
  timestamp: 2026-02-23

## Evidence

- timestamp: 2026-02-23
  checked: ScrollEngine event tap configuration (lines 109-121)
  found: The CGEventTap ONLY intercepts leftMouseDown, leftMouseDragged, and leftMouseUp events. It does NOT intercept scrollWheel events. The eventMask is `(1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.leftMouseDragged.rawValue) | (1 << CGEventType.leftMouseUp.rawValue)`.
  implication: We have no ability to intercept, filter, or suppress any scroll wheel events flowing through the system -- including OS-generated momentum scroll events.

- timestamp: 2026-02-23
  checked: How scroll events are posted (postScrollEvent and postMomentumScrollEvent)
  found: Both methods create NEW CGEvent scroll wheel events and post them via .cgSessionEventTap. They set scrollWheelEventScrollPhase and scrollWheelEventMomentumPhase fields correctly. These are ADDITIVE -- they add events to the stream.
  implication: When InertiaAnimator posts momentum events, they are added ON TOP of whatever the OS is also generating. We never suppress OS events.

- timestamp: 2026-02-23
  checked: macOS momentum scroll event lifecycle (web research)
  found: macOS generates momentum scroll events automatically after a trackpad gesture ends. These are real CGEvents with momentumPhase set to NSEventPhaseBegan/Changed/Ended. NSScrollView-based apps (Finder, IA Writer, etc.) receive these momentum events directly from the OS and animate accordingly. This is system-level behavior that happens in the window server.
  implication: The OS momentum events are a completely separate stream from our InertiaAnimator events. Native apps respond to BOTH streams. Web-view apps (WKWebView, etc.) may handle scroll events differently and may give more weight to the synthetic events we post.

- timestamp: 2026-02-23
  checked: What happens when user does drag-to-scroll in our app
  found: User drags -> we suppress mouse events and post scroll events (phase began/changed/ended). On release, we post scrollPhaseEnded (phase 4), then InertiaAnimator posts momentum events (momentumPhase 1/2/3). BUT: the OS is not involved in generating momentum here because we intercepted the mouse events (not trackpad scroll events). The drag-to-scroll flow is: mouseDown -> mouseDragged -> mouseUp, converted to scroll events.
  implication: WAIT -- this changes the analysis. Since we intercept MOUSE events (not trackpad events), there should be no OS-generated momentum from trackpad gestures. The momentum issue may actually be that native NSScrollView has its OWN built-in momentum/smoothing behavior that activates in response to our synthetic scroll events.

- timestamp: 2026-02-23
  checked: NSScrollView's internal momentum behavior
  found: NSScrollView.scrollWheel(with:) has built-in momentum handling. When it receives scroll events with proper phase information (began/changed/ended), it can generate its OWN momentum animation internally. This is separate from OS-level momentum events -- NSScrollView interprets the scroll phase sequence and may add its own smooth scrolling/momentum on top.
  implication: This is the actual root cause for native apps. When we post scrollPhaseEnded (phase 4) at the end of a drag, native NSScrollView sees "scroll gesture ended" and may initiate its OWN internal momentum animation based on the velocity of the scroll events it received. Our InertiaAnimator then ALSO posts momentum events. The native app sees BOTH its internal momentum AND our posted momentum events.

- timestamp: 2026-02-23
  checked: Why web-view apps behave differently
  found: WKWebView and similar web rendering engines handle scroll events through their own rendering pipeline. They tend to be more responsive to the raw event stream (including momentum phase events) rather than using NSScrollView's built-in momentum. When we post momentumPhase events, web views use those directly. When we don't post them (inertia disabled), web views stop scrolling.
  implication: This explains the differential behavior: web-view apps follow our momentum events; native NSScrollView apps generate their own momentum regardless of what we post.

## Resolution

root_cause: Native macOS apps using NSScrollView have built-in momentum/inertia scrolling that activates when they receive a scroll gesture sequence (began -> changed -> ended). When ScrollEngine posts the scrollPhaseEnded event (phase 4) on mouse-up, NSScrollView interprets this as "user finished scrolling" and initiates its own internal momentum animation based on the velocity of recent scroll deltas. This native momentum is completely independent of our InertiaAnimator. Disabling our inertia toggle only stops our InertiaAnimator from posting additional momentum events -- it does NOT prevent NSScrollView from generating its own internal momentum. Similarly, our intensity slider only affects InertiaAnimator's tau and velocity scale -- NSScrollView's internal momentum is unaffected.

The fundamental issue: we control what events we POST, but we don't control how native scroll views RESPOND to those events. NSScrollView momentum is a framework-level behavior triggered by the scroll phase sequence, not by our momentum-phase events.

fix: (not yet applied -- see suggested fix direction below)
verification: (not yet verified)
files_changed: []

### Suggested Fix Direction

There are several approaches, each with trade-offs:

**Approach A: Intercept and suppress OS scroll wheel events (add scrollWheel to event tap)**
- Add `CGEventType.scrollWheel` to the eventMask in the CGEventTap
- When inertia is disabled: after posting scrollPhaseEnded, intercept and suppress any incoming momentum scroll events (where momentumPhase != 0) for a short window
- When inertia is enabled: let our InertiaAnimator events through but suppress any other momentum events
- Pros: Most direct solution, full control over what apps see
- Cons: Intercepting ALL scroll wheel events could affect trackpad/mouse scrolling when NOT in drag-to-scroll mode. Needs careful filtering to only suppress momentum events that follow our synthetic scroll sequences.

**Approach B: Don't post scrollPhaseEnded, use a different phase sequence**
- Instead of posting scrollPhaseEnded (which triggers NSScrollView's momentum), keep the scroll phase as "changed" and let deltas go to zero naturally
- When inertia is disabled: ramp deltas to zero over a few frames, then post ended
- When inertia IS enabled: post scroll events (not momentum events) with decaying deltas, then post ended when done
- Pros: Avoids NSScrollView triggering its own momentum
- Cons: May break other app behaviors that depend on proper phase sequences. Some apps need the ended event to finalize scroll position.

**Approach C: Intercept scroll wheel events and filter momentum-phase events after our sequences**
- Add scrollWheel to the event tap mask
- Track state: when we post a scrollPhaseEnded, set a flag
- While flagged, suppress any incoming scroll events where momentumPhase is non-zero (these are NSScrollView-generated momentum events being re-posted, or OS-generated ones)
- Clear the flag when our InertiaAnimator finishes (or immediately if inertia is disabled)
- Pros: Targeted suppression, doesn't affect normal trackpad scrolling
- Cons: NSScrollView momentum is internal to the app's process -- it doesn't generate new CGEvents that flow through the event tap. This approach would only work for OS-level momentum, NOT NSScrollView's internal momentum.

**Approach D (RECOMMENDED): Post momentum-cancel event when inertia is disabled**
- After posting scrollPhaseEnded (phase 4), immediately post a momentum event with momentumPhase = kCGMomentumScrollPhaseEnd (3) and zero deltas
- This tells NSScrollView "momentum has ended" immediately, preventing it from starting its own internal momentum
- When inertia IS enabled: InertiaAnimator already posts momentumPhase begin/continue/end -- this should already be suppressing NSScrollView's own momentum, BUT we need to verify the timing (if there's a gap between scrollPhaseEnded and InertiaAnimator's first momentum event, NSScrollView may start its own momentum in that gap)
- For intensity: if NSScrollView is adding its own momentum ON TOP of ours, posting a momentum-begin event immediately after scrollPhaseEnded should claim the momentum phase and let InertiaAnimator control it fully
- Pros: Minimal change, works with NSScrollView's phase state machine, doesn't require intercepting scroll events
- Cons: Depends on NSScrollView respecting momentum-end events from the event stream. Needs testing.

**Key insight for Approach D:** The scroll phase state machine that NSScrollView follows is: began -> changed -> ended -> [optional: momentum began -> momentum changed -> momentum ended]. If we always send a complete momentum sequence (even a zero-length one when inertia is disabled), NSScrollView should not generate its own momentum.

### Files That Would Need Changes

- `ScrollMyMac/Services/ScrollEngine.swift` -- primary changes to handleMouseUp and/or postScrollEvent
- `ScrollMyMac/Services/InertiaAnimator.swift` -- possibly ensure first momentum event fires synchronously (no gap after scrollPhaseEnded)
