---
title: Adopt a lightweight maintenance planning workflow
status: complete
created: 2026-08-19
updated: 2026-08-20
---

# Plan: Adopt a Lightweight Maintenance Planning Workflow

## Outcome

Future maintenance has a small, repository-local method for recording planned work, current project state, results, and handoffs without depending on GSD.

## Why

The GSD archive contains valuable history but its full phase, research, verification, and metrics process is too heavy for ongoing maintenance. The living state also drifted behind the v1.4.1 code baseline.

## Scope

- Add durable repository guidance in `AGENTS.md`.
- Add one repo-local `project-maintenance` skill and planning-file formats.
- Document the active and archived portions of `.planning/`.
- Refresh `PROJECT.md`, `STATE.md`, and the current section of `ROADMAP.md` from observable repository state.

## Out of scope

- Rewriting or deleting GSD-era history.
- Changing application code or behavior.
- Selecting the next product feature or release milestone.

## Approach

1. Inventory planning records, recent Git history, build settings, and current source layout.
2. Define the minimum living documents and proportional record rules.
3. Add project instructions, the maintenance skill, templates, and this example work record.
4. Validate the skill structure and review the resulting documentation diff for consistency.

## Verification

- Run the skill creator's `quick_validate.py` against the new skill.
- Run `git diff --check`.
- Confirm the living documents link to the new workflow and reflect v1.4.1.
