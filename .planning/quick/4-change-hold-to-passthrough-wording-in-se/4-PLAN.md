---
phase: quick-4
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - ScrollMyMac/Features/Settings/SettingsView.swift
autonomous: true
requirements: []
must_haves:
  truths:
    - "Toggle label reads 'Click-and-hold passthrough'"
    - "Description text reads 'When enabled, click and hold the mouse still. After a short delay, dragging the mouse behaves normally instead of scrolling.'"
  artifacts:
    - path: "ScrollMyMac/Features/Settings/SettingsView.swift"
      provides: "Updated hold-to-passthrough wording"
      contains: "Click-and-hold passthrough"
  key_links: []
---

<objective>
Update the hold-to-passthrough toggle label and description text in the settings window.

Purpose: Clearer wording that better explains the feature to users.
Output: Updated SettingsView.swift with new wording.
</objective>

<execution_context>
@/Users/blake/.claude/get-shit-done/workflows/execute-plan.md
@/Users/blake/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@ScrollMyMac/Features/Settings/SettingsView.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Update hold-to-passthrough wording in SettingsView</name>
  <files>ScrollMyMac/Features/Settings/SettingsView.swift</files>
  <action>
In SettingsView.swift, around line 76-78, make these two changes:

1. Change the Toggle label from `"Hold-to-passthrough"` to `"Click-and-hold passthrough"`

2. Change the description Text from `"Hold the mouse still within the click dead zone to pass through the click for normal drag operations (text selection, window resize)."` to `"When enabled, click and hold the mouse still. After a short delay, dragging the mouse behaves normally instead of scrolling."`

No other changes needed. The hold delay stepper and its description remain as-is.
  </action>
  <verify>Build the project with `xcodebuild -project ScrollMyMac.xcodeproj -scheme ScrollMyMac -configuration Debug build 2>&1 | tail -5` and confirm it succeeds.</verify>
  <done>Toggle reads "Click-and-hold passthrough" and description reads the new wording. Project builds without errors.</done>
</task>

</tasks>

<verification>
- Build succeeds
- Grep for "Click-and-hold passthrough" in SettingsView.swift confirms new label
- Grep for "After a short delay" in SettingsView.swift confirms new description
</verification>

<success_criteria>
The settings window displays the updated wording for the hold-to-passthrough feature toggle and description.
</success_criteria>

<output>
After completion, create `.planning/quick/4-change-hold-to-passthrough-wording-in-se/4-SUMMARY.md`
</output>
