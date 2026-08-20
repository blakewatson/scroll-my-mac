---
title: Adopt a lightweight maintenance planning workflow
status: complete
created: 2026-08-19
completed: 2026-08-20
---

# Outcome: Adopt a Lightweight Maintenance Planning Workflow

## Result

Scroll My Mac now has a repository-local maintenance method that preserves the useful parts of GSD—planned outcomes, project state, decisions, verification, and handoffs—without its phase and metrics machinery. The existing GSD records remain intact as history.

## Changes

- `AGENTS.md` — added durable repository priorities, sources of truth, planning expectations, accessibility-sensitive engineering constraints, and verification guidance.
- `.agents/skills/project-maintenance/` — added an implicitly discoverable workflow plus concise formats for plans, outcomes, and living state.
- `.planning/README.md` — documented which files are living records and which directories are GSD-era archives.
- `.planning/work/` — established the new per-change record format using this task as the first example.
- `.planning/PROJECT.md` — refreshed the release baseline, code-size context, and v1.4.1 exclusion capability.
- `.planning/STATE.md` — replaced stale GSD metrics and session fields with a current, concise handoff.
- `.planning/ROADMAP.md` — made the absence of an active milestone explicit and recorded one confirmed documentation-maintenance candidate.

## Verification

- PASS — `quick_validate.py .agents/skills/project-maintenance` reported `Skill is valid!`.
- PASS — `git diff --check` reported no whitespace errors.
- PASS — all required instruction, skill, reference, planning, and work-record files exist.
- PASS — the diff contains no Swift or Xcode project changes; an application build was not applicable.

## Decisions

- Use `AGENTS.md` for rules that must be present on every repository task and one focused repo-local skill for the maintenance workflow.
- Keep `PROJECT.md`, `STATE.md`, and `ROADMAP.md` as the three living planning documents.
- Preserve GSD output as read-only historical context and put new meaningful work under `.planning/work/`.
- Require planning records only for meaningful changes so maintenance stays proportional.

## Follow-ups

- Refresh the public `README.md` roadmap when that documentation task is prioritized.
- Choose the next product milestone only when there is a concrete user need; none was invented during this workflow change.
