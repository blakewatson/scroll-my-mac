# Planning File Formats

Use these formats as a starting point. Omit empty optional sections and keep records brief enough to scan.

## Work directory

Create one directory per meaningful change:

```text
.planning/work/YYYY-MM-DD-short-slug/
├── PLAN.md
└── OUTCOME.md
```

Use the date work was first planned. Keep the slug stable if work spans sessions.

## PLAN.md

Create this before implementation when possible.

```markdown
---
title: Short outcome-oriented title
status: planned
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# Plan: Short title

## Outcome

State what will be true when the work is done.

## Why

State the user need, defect, or maintenance reason.

## Scope

- Concrete change or investigation boundary
- Relevant files or subsystems when known

## Out of scope

- Important adjacent work intentionally excluded

## Approach

1. A small number of verifiable steps

## Verification

- Automated check or build
- Targeted manual behavior to exercise

## Open questions

- Include only decisions that genuinely remain unresolved
```

Use `status: in_progress` once implementation starts. Use `paused`, `blocked`, or `complete` only when that is the actual work state.

## OUTCOME.md

Create this when work completes, pauses, or blocks.

```markdown
---
title: Same title as the plan
status: complete
created: YYYY-MM-DD
completed: YYYY-MM-DD
---

# Outcome: Short title

## Result

Summarize what is now true. For paused or blocked work, state exactly where it stopped.

## Changes

- File or subsystem — observable change

## Verification

- PASS — command or behavior and result
- PENDING — manual check not performed and why

## Decisions

- Durable choice and its rationale; omit if none

## Follow-ups

- Remaining work; write `None` when there is none
```

Do not claim a check passed from code inspection alone. Link to a commit only if the work was committed.

## STATE.md

`STATE.md` is a current dashboard, not a diary. Prefer this shape:

```markdown
# Project State

_Updated: YYYY-MM-DD_

## Snapshot

- Release baseline
- Current focus
- Status
- Latest meaningful activity with a link to its outcome

## Active Work

- Work item, status, next step, and record link; or `None`

## Planned Next

- Ordered, genuinely intended work; do not invent priorities

## Known Concerns

- Confirmed risk, defect, documentation drift, or missing verification

## Recent Outcomes

- A short list of recent changes; history belongs in work records and Git

## Resume Here

- The first useful action for the next session
```

Remove stale detail instead of accumulating every completed task. Durable history belongs in Git, work outcomes, and archived milestones.

## PROJECT.md and ROADMAP.md

- `PROJECT.md` changes rarely. Keep the core value, validated capabilities, constraints, and durable decisions accurate.
- `ROADMAP.md` answers what is planned and in what order. It may link to completed milestone history, but should make the current planning state obvious near the top.
- Do not copy the same active status into multiple files. `STATE.md` is authoritative for the immediate handoff; `ROADMAP.md` is authoritative for planned sequence.
