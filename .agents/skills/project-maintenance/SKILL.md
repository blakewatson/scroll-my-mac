---
name: project-maintenance
description: Plan, resume, implement, and close meaningful Scroll My Mac maintenance while keeping the repository's project state and planned-work records accurate. Use for features, bug fixes, refactors, releases, handoffs, or requests to assess or update project state. Do not use for read-only questions or trivial edits that do not change project state.
---

# Project Maintenance

Keep enough context for another session to understand what is true, what is next, and why decisions were made. Do not recreate the legacy GSD phase system.

## Establish the current truth

Before planning or resuming meaningful work:

1. Read `.planning/README.md`, `.planning/PROJECT.md`, `.planning/STATE.md`, and the current portion of `.planning/ROADMAP.md`.
2. Inspect `git status`, recent Git history, and the relevant code or documentation.
3. Reconcile discrepancies in favor of observable repository state. Preserve unrelated user changes.
4. Treat legacy directories under `.planning/` as historical evidence, not active workflow instructions.

If the request is only to plan, assess, or report, do not implement unrequested changes.

## Scale the record to the work

- For a trivial, contained edit, make the change without a dedicated work record. Update `STATE.md` only if the project state actually changed.
- For a meaningful change, create `.planning/work/YYYY-MM-DD-short-slug/PLAN.md` before implementation.
- For a new milestone or a change in priorities, update `ROADMAP.md` before breaking work into individual records.
- If work already began without a plan, record only confirmed facts and label the plan as created after work began. Do not fabricate foresight.

Read [references/planning-files.md](references/planning-files.md) whenever creating or materially updating planning records.

## Execute and verify

Use the plan as a short contract for outcome, scope, and verification, not as a transcript. Update it when a discovery materially changes scope or the intended result.

Verify in proportion to risk and follow the repository verification guidance in `AGENTS.md`. Separate automated checks from manual checks. If a necessary manual accessibility or input test cannot be performed, record it as pending and explain what the user should exercise.

Do not publish, notarize, create a release, or otherwise mutate external systems unless the user explicitly requested that action.

## Close or hand off

For meaningful work:

1. Write `OUTCOME.md` in the same work directory with status `complete`, `paused`, or `blocked`.
2. Record actual changes, verification evidence, decisions, and remaining work. Commit hashes are optional; include them only when they exist.
3. Refresh `.planning/STATE.md` so its snapshot, active work, known concerns, and next actions are correct.
4. Update `.planning/PROJECT.md` only when durable product facts or decisions changed.
5. Update `.planning/ROADMAP.md` only when priorities, milestone scope, or completion status changed.

End the user handoff with the result, verification performed, any manual checks still needed, and links to the plan/outcome records.
