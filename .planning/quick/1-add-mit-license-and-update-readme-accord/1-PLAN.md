---
phase: quick-1
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - LICENSE
  - README.md
autonomous: true
requirements: []
must_haves:
  truths:
    - "LICENSE file exists at project root with MIT license text"
    - "README.md License section references the MIT license"
  artifacts:
    - path: "LICENSE"
      provides: "MIT license text with correct year and copyright holder"
      contains: "MIT License"
    - path: "README.md"
      provides: "Updated license section"
      contains: "MIT"
  key_links:
    - from: "README.md"
      to: "LICENSE"
      via: "license section reference"
      pattern: "MIT"
---

<objective>
Add an MIT LICENSE file to the project root and update the README.md license section to reference it.

Purpose: Establish clear open-source licensing for the project.
Output: LICENSE file and updated README.md
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
  <name>Task 1: Add MIT LICENSE file and update README</name>
  <files>LICENSE, README.md</files>
  <action>
    1. Create a LICENSE file at the project root with the standard MIT License text.
       - Year: 2025
       - Copyright holder: Blake Watson
    2. Update README.md: replace the "License TBD." line (line 51) with a reference to the MIT license, e.g.:
       "This project is licensed under the [MIT License](LICENSE)."
  </action>
  <verify>
    - Confirm LICENSE file exists and contains "MIT License" and "Blake Watson"
    - Confirm README.md license section no longer says "TBD" and references MIT
  </verify>
  <done>
    LICENSE file exists with MIT license text (2025, Blake Watson). README.md license section says MIT and links to the LICENSE file.
  </done>
</task>

</tasks>

<verification>
- LICENSE file exists at project root
- README.md license section updated (no "TBD")
- Both files are valid and well-formatted
</verification>

<success_criteria>
- MIT LICENSE file present at project root with correct copyright
- README.md references MIT license instead of "License TBD"
</success_criteria>

<output>
After completion, create `.planning/quick/1-add-mit-license-and-update-readme-accord/1-SUMMARY.md`
</output>
