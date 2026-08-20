# Planning and Project State

This directory keeps the context needed to maintain Scroll My Mac across sessions. It is intentionally lighter than the GSD workflow that originally built the project.

## Living documents

| File | Purpose | Update when |
|---|---|---|
| [`PROJECT.md`](./PROJECT.md) | Durable product scope, constraints, validated capabilities, and key decisions | A lasting product or architecture fact changes |
| [`STATE.md`](./STATE.md) | Current release, focus, active work, concerns, and next action | Meaningful work completes, pauses, or changes the handoff |
| [`ROADMAP.md`](./ROADMAP.md) | Planned priorities and milestone history | Priorities, milestone scope, or completion status changes |
| [`work/`](./work/) | A concise plan and outcome for each meaningful new change | A feature, bug fix, refactor, release, or substantial maintenance task starts or ends |

## Historical material

The following file and directories are the GSD-era archive:

- [`MILESTONES.md`](./MILESTONES.md) — legacy milestone summary; not an active planning file
- `milestones/` — completed milestone plans, summaries, and verification
- `quick/` — completed small-task plans and summaries
- `debug/` — resolved investigation notes
- `research/` — architecture and product research from earlier milestones

They remain useful context, but new work should not add phases, plan metrics, execution-context pointers, or other GSD-specific ceremony.

## Lightweight workflow

1. Confirm current truth from Git, code, `PROJECT.md`, `STATE.md`, and `ROADMAP.md`.
2. For meaningful work, create `work/YYYY-MM-DD-short-slug/PLAN.md` before implementation.
3. Implement and verify in proportion to user impact. Accessibility and global-input changes require explicit manual checks in addition to a successful build.
4. Add `OUTCOME.md` with actual results and verification. Mark unfinished manual checks as pending.
5. Refresh `STATE.md`. Change `PROJECT.md` or `ROADMAP.md` only when their durable information changed.

Tiny, contained edits do not need a work directory. Planning should help the next session, not create paperwork for its own sake.

The repo-local `$project-maintenance` skill in `.agents/skills/project-maintenance/` applies this workflow.
