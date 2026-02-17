---
phase: quick-2
plan: 01
type: execute
wave: 1
depends_on: []
files_modified: [README.md]
autonomous: true
requirements: [QUICK-2]

must_haves:
  truths:
    - "README explains the safety timeout feature and its purpose"
    - "README advises new users to keep safety timeout on when first trying the app"
    - "README notes users can turn it off once comfortable"
  artifacts:
    - path: "README.md"
      provides: "Safety timeout documentation"
      contains: "safety timeout"
---

<objective>
Add a note to the README about the safety timeout feature, advising new users to keep it enabled when first trying the app so they can recover if clicks stop working, and noting it can be turned off once comfortable.

Purpose: Help new users feel confident trying the app by knowing there is a built-in safety net.
Output: Updated README.md
</objective>

<execution_context>
@/Users/blake/.claude/get-shit-done/workflows/execute-plan.md
@/Users/blake/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@README.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add safety timeout tip to README</name>
  <files>README.md</files>
  <action>
Add a "Tip" or short note about the safety timeout feature in the Usage section of README.md, after the existing usage steps. The note should:

1. Explain that the app includes a safety timeout (enabled by default) that automatically deactivates scroll mode after 10 seconds of no mouse movement.
2. Frame it as helpful for new users: if your clicks ever stop working as expected while in scroll mode, the safety timeout will automatically restore normal mouse behavior.
3. Mention that once you are comfortable with the app, you can turn the safety timeout off in Settings.

Keep the tone concise and consistent with the rest of the README. Use a brief paragraph or a blockquote-style tip -- not a full new section. Place it naturally after the numbered usage steps and before "The app window provides settings..." line.
  </action>
  <verify>Read README.md and confirm the safety timeout note is present in the Usage section, mentions the 10-second auto-deactivation, and advises keeping it on initially.</verify>
  <done>README Usage section contains a clear, concise note about the safety timeout feature that helps new users understand the safety net and know they can disable it later.</done>
</task>

</tasks>

<verification>
- README.md contains safety timeout information in the Usage section
- Note is concise and fits the tone of the existing README
- No other sections of the README were unintentionally modified
</verification>

<success_criteria>
- Safety timeout note present in Usage section
- Mentions automatic deactivation after inactivity
- Recommends keeping it on for new users
- Notes it can be turned off in Settings
</success_criteria>

<output>
After completion, create `.planning/quick/2-add-safety-timeout-note-to-readme/2-01-SUMMARY.md`
</output>
