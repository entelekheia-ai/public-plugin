---
name: work-a-dossier
description: 'How an implementer or a reviewer subagent works when its brief names a task dossier: the dossier is the spec, rulings are written into it as they are made, questions only the maintainer can answer come back in the report, and each review finding says what it does to the plan. Preloaded into (or named in the brief of) an implementer or reviewer subagent; use when a brief names a dossier under project/tasks/.'
user-invocable: false
user_invocable: false
---

# Work a task dossier

**Before starting, read your notes for this skill**, where they exist — `~/.agents/skill-notes/work-a-dossier.md`,
then `.agents/skill-notes/work-a-dossier.md`, then `.agents/skill-notes/work-a-dossier.local.md`. Where two disagree, the
more specific one wins. They hold what earlier runs taught; see the last section for how they are written.

Applies when the brief names a task dossier (commonly `<repo>/project/tasks/NNN-*.md` — the common
convention, not a requirement: a task note the brief names by another path works the same way). Without
one, follow your definition alone. The caller that dispatched you is usually carrying a whole plan, track
after track, and reads your report to decide whether the next track starts or waits for the maintainer —
so each rule below exists to make that decision mechanical.

**This is a target-state skill.** The target is the dossier holding every decision the run made, and a
report the caller can act on without asking you anything. A second dispatch on the same dossier repairs
what the first left missing.

## The dossier is the spec

Read the dossier first, then the plan sections it quotes. Where the two disagree, the dossier wins: it
carries the decisions the caller took for this track. The write set is the dossier's list of files it
owns, plus the dossier itself.

The plan is the caller's. Never write under `project/plans/` — a question about the plan goes into your
report, and the caller moves it into the plan.

## Rulings are written into the dossier when they are made

Every decision the brief left open and you took goes under the dossier's **Surprises & Discoveries** as

```text
Ruling: <what you decided> — <why> — <what it costs if wrong>
```

in the moment you take it, and again in your report's rulings section. The dossier copy survives if the
caller's context is compacted before it reads your report.

**When a sibling agent works from the same dossier, the report is the only copy.** Two agents writing one
file at once lose each other's edits, so the brief that names siblings on this dossier makes it the
caller's alone: write nothing into it, and the caller copies your rulings in when you return.

**A ruling that another track or implementation can observe is a question.** Where the dossier carries
the same change for several siblings — the same behaviour in two languages, two packages meeting at one
interface — a name or a helper's place stays a ruling, but anything the others can see (an output field,
an error kind, an accepted or refused input) would be decided again by each of them unseen. Land what
does not depend on it and report it under **Questions for the maintainer**.

A defect you found that predates the track goes there too, as `Observation:` with the command that shows
it. Fix it only when the track cannot pass its gate without the fix, and say so in the ruling.

## A question only the maintainer can answer comes back in the report

A question is the maintainer's when the plan leaves it to them, when its Decision Log reserves it, or when
every answer changes what the track delivers. Everything else is a ruling. Do not stop red on such a
question when part of the track can land without it: land that part, and report the question under
**Questions for the maintainer**, each as

- the question, in one sentence;
- two to four options, each with what it costs;
- the option you recommend, and why.

The caller writes it into the plan's Open questions and asks it in a batch with others. When no part of
the track can land without the answer, stop, leave the worktree as it was, and report only the question.

## Each review finding says what it does to the plan

A reviewer adds one line to every finding:

```text
Against the plan: fits the track | reverses <the plan decision, quoted> | widens the track to <what>
```

The caller sends a finding that fits the track back to the implementer, and parks one that reverses or
widens. A `NOTE` is recorded by the caller as a deferred minor; write it so it stands alone in one line.

## Checklist

- [ ] The dossier was read before the plan, and its decisions were followed
- [ ] Every ruling is in the dossier's Surprises & Discoveries and in the report
- [ ] Nothing under `project/plans/` was written
- [ ] Every question for the maintainer carries options and a recommendation
- [ ] Every review finding carries its `Against the plan` line

## ⟳ After every use: put what this run taught in the report

This skill runs only inside an implementer or reviewer subagent — never on its own — so it cannot write a
notes file itself: a reviewer's write access is read-only by its own guard, an implementer's is scoped to
the files its brief names, and neither can ask the user anything mid-run. What the notes-file contract
above does for a user-invocable skill, a report section does here instead.

Put a **Notes for work-a-dossier** section in your report, one dated line per point, in the same shape a
notes file would carry. The caller — who does have a notes file, a repository and a user to ask — decides
the scope (local, repo or user) and writes each line there, then asks the user whether it should go back
into the skill itself.

What is worth noting, in this section:

- The line between a ruling and a question for the maintainer is the one that fails silently. Note a
  caller that had to rewrite a report's question into options, or that reverted a ruling the maintainer
  should have made instead.
- Note a dossier path that did not match `project/tasks/NNN-*.md` and what the brief called it instead,
  so the convention line above stays honest.
- Note a review finding that arrived without an `Against the plan` line, and what the caller had to infer.

Verified against: Claude Code 2.1.280 (subagent `skills:` preloading), 2026-09-26.
