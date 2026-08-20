# Scroll My Mac Repository Guide

## Project priorities

Scroll My Mac is a macOS accessibility tool. Preserve reliable mouse input and a safe path back to ordinary clicking above convenience or cleverness. Treat changes to event taps, click pass-through, exclusions, hotkeys, and permission handling as high-risk behavior changes.

The supported baseline is macOS 14+, Apple Silicon, SwiftUI/AppKit, `CGEventTap`, Accessibility APIs, and `CADisplayLink`. The current release baseline is v1.4.1.

## Sources of truth

- Running code and Git history establish implemented behavior.
- `.planning/STATE.md` is the concise current handoff.
- `.planning/PROJECT.md` holds durable product scope, constraints, and decisions.
- `.planning/ROADMAP.md` holds planned work and milestone history.
- `.planning/work/` holds one plan and one outcome record for each meaningful new change.
- `.planning/milestones/`, `.planning/quick/`, `.planning/debug/`, and `.planning/research/` are legacy GSD history. Consult them when useful, but do not extend their old phase machinery.

If a planning document conflicts with the repository, verify the repository and correct the living document instead of propagating stale information.

## Maintenance records

Use the repo-local `project-maintenance` skill for a feature, bug fix, refactor, release, multi-file change, or project-state update that should survive the current conversation. Keep the process proportional:

- A trivial, contained edit does not need its own work directory.
- Meaningful work gets `.planning/work/YYYY-MM-DD-short-slug/PLAN.md` before implementation and `OUTCOME.md` when work completes, pauses, or blocks.
- Update `.planning/STATE.md` at the end of meaningful work and before handing off unfinished work.
- Update `.planning/PROJECT.md` only for durable scope, constraint, architecture, or product-decision changes.
- Update `.planning/ROADMAP.md` when planned priorities or milestone status change.

Do not invent dates, results, commits, tests, or manual verification. Planning records do not require one commit per task.

## Engineering constraints

- Keep the event-tap path fast. Do not add blocking I/O, Window Server queries, or other expensive work to mouse-event handling; cache external state away from the callback.
- Do not add a new macOS permission requirement without explicit product justification.
- Preserve click-through and safety-timeout escape paths when changing scroll behavior.
- Respect the existing background-thread and cached-window-state design around `CGEventTap`.
- Do not run signing, notarization, publishing, or the release script unless the user explicitly asks for a release.

## Verification

After Swift or Xcode project changes, run:

```sh
xcodebuild -project ScrollMyMac.xcodeproj -scheme ScrollMyMac -configuration Debug build
```

Use a writable `-derivedDataPath` and `CODE_SIGNING_ALLOWED=NO` when the environment requires it. There is currently no automated test target, so behavior affecting global input, Accessibility permission, multiple displays, native scrolling, web views, or the Accessibility Keyboard also needs targeted manual verification. Record any manual verification not performed as pending; never report it as passed.
