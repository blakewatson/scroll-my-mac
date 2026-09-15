---
title: Restore hold-to-passthrough window dragging
status: complete
created: 2026-09-14
updated: 2026-09-14
completed: 2026-09-14
---

# Outcome: Restore hold-to-passthrough window dragging

## Result

Fix complete with user verification. Automated verification passed on macOS 27.0 (26A428), Xcode 27.0 (27A266a). The user explicitly confirmed window dragging now works, then said “We are good to go” after receiving the focused regression checklist. This confirms the reported behavior is resolved in their use; the precise OS-level cause remains unproven.

## Changes

- `ScrollEngine.swift`: replay delayed down/drag/up using one retained source, original event metadata, matching mouse-event number, and fresh timestamps. Mark replayed drags so they pass the tap without recursion.
- Explicitly allow local mouse, keyboard, and system events during synthetic dragging and set the replay source suppression interval to zero. This avoids relying on source defaults; changed OS defaults are not established as the cause.
- Guard hold callbacks with a generation token and pending-click check. Release replayed mouse-down on stop/teardown.
- Decide exclusions at mouse-down and retain the decision through release, so app activation changes cannot bypass cleanup halfway through a gesture.
- Add a standalone captured-event regression harness and injectable posting function. Normal production posting locations remain HID for mouse replay and session for scrolling.
- Preserve prior pointer-distance work, now committed by the user as `6621cbb`. Existing project version and workspace/user-state edits remain untouched.

## Verification

- PASS — `xcodebuild -project ScrollMyMac.xcodeproj -scheme ScrollMyMac -configuration Debug -derivedDataPath /tmp/smm-macos27-build CODE_SIGNING_ALLOWED=NO build` after final Swift changes. Initial sandbox build failed because Swift macro plugins could not run; outside-sandbox retry passed. Log: `/tmp/smm-macos27-build.log`.
- PASS — standalone `Tests/ScrollEngineEventChecks.swift` compiled against production sources and ran successfully. Checks: delayed down/drag/up identity and location, replay recursion bypass, quick-click pairing/no late down, canceled timer, shutdown release exactly once, scroll threshold and phases, exclusion changes, modifier passthrough. No global events posted.
- PASS (user-reported) — window dragging now works.
- ACCEPTED (user-reported) — user approved closure after the focused checklist covering resize/text selection, clicks/scrolling, toggle-off mid-drag, Accessibility Keyboard, exclusions, native/browser scrolling, and a second display if applicable. Individual app/device results were not supplied.
- PENDING (broader coverage, non-blocking) — permission revoke/regrant, safety-timeout activation, and the full app/display matrix were not explicitly reported as tested. Automated capture cannot verify Window Server or target app acceptance.

## Manual checklist retained for future regression testing

Use the local Debug build from Xcode, with Accessibility permission, and ensure only one Scroll My Mac instance is running. Retain the configured 0.25-second hold delay.

1. With scroll mode on, hold a draggable Finder/title-bar area still for at least 0.25 seconds, then move; repeat with another native app and a web/Electron app. Confirm the window follows and stops on release.
2. Resize a window and select text after holding. Compare the same title-bar spot with scroll mode off if it does not move.
3. Quick click, double-click, modifier click, and begin scrolling before the delay. Verify no stray click after release and pointer-accurate scrolling remains intact.
4. Disable scroll mode during the hold and during a passed-through drag; confirm no delayed click or stuck button. Exercise the safety timeout too.
5. Begin gestures in excluded/non-excluded apps and switch focus mid-gesture. Check Accessibility Keyboard typing and repositioning, multiple displays, native/web scrolling and inertia, and Accessibility permission revoke/regrant.

## Compatibility audit

- Apple’s [macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes) describe NSTextView moving to NSTextSelectionManager/gesture recognizers, exclusive gesture activation, stuck-gesture cancellation, and new NSScrollView gesture relationships. These justify text-selection and native-scroll testing; they do not establish the reported failure's cause. Notes were fetched directly from Apple's Markdown endpoint.
- The keyboard exclusion cache still identifies the Accessibility Keyboard by the process name `AssistiveControl`. An OS rename would break detection; no rename or failure was observed in this session. Verify it manually before changing identifiers.
- Code inspection shows the tap is installed on the calling run loop, and AppState starts it from the main-thread UI path. The durable project document's claim of a dedicated background thread is stale. Main-thread stalls remain a timeout risk; no threading migration was attempted here.
- AppState still sets scroll-mode UI active even if tap creation fails (ScrollEngine logs failure and returns). This pre-existing permission/startup reporting issue is a separate follow-up, not a confirmed macOS 27 regression.
- No new permission, release, signing, or notarization was performed.

## Follow-ups

No remaining work blocks closing this fix. Broader compatibility coverage and the pre-existing tap-start reporting/main-thread timeout concerns remain separate maintenance candidates. No release was requested.
