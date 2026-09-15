# ScrollEngine event checks

These standalone checks compile the production engine and capture its event output. They do not install event taps or inject global mouse input. No Xcode test target is required.

From the repository root:

```sh
xcrun swiftc -module-cache-path /tmp/smm-module-cache ScrollMyMac/Services/ScrollEngine.swift ScrollMyMac/Services/InertiaAnimator.swift ScrollMyMac/Services/VelocityTracker.swift Tests/ScrollEngineEventChecks.swift -o /tmp/smm-event-checks
/tmp/smm-event-checks
```

Use a non-sandboxed compiler environment if Swift macro expansion is blocked. These checks verify event sequencing, not Window Server acceptance or real device behavior. The macOS 27 manual checklist is in `.planning/work/2026-09-14-macos27-window-drag/OUTCOME.md`.
