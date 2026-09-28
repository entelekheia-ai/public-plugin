---
name: run-plan
description: 'Carry a plan through its remaining tracks with the maintainer out of the loop between them — questions asked in one batch before the start and in one batch when nothing else can move — pacing the run against the usage limit and the context window. Use when asked to run, drive or continue a plan track by track, or "/run-plan <plan>".'
argument-hint: '[plan-path]'
arguments: plan
user-invocable: true
user_invocable: true
---

# Carry a plan through its tracks, unattended between them

Fires when a plan's remaining tracks are specified and the only input between them would be "go on". The
plan is `$plan`. At the end, every track that could move is committed, every question that needed you was
asked in a batch, and a report on disk says where the run stopped.

**This is a target-state skill.** The target is the plan with every runnable track landed; a second run
reads the plan (and, if this session wrote one, its state file) and resumes at the first track not done.

## The distinct moment this covers

Dispatching an implementer, checking its diff against the gate, and committing one track is already
covered — use [`executing-plans`](https://github.com/obra/superpowers) inline, or
`subagent-driven-development` through a subagent, for that mechanics. This skill is for the stretch
*between* tracks, unattended, over a plan that still has several left:

1. **Pace the run against the usage limit and the context window**, so it stops at a clean point instead
   of being cut off mid-edit, and routes what it learned before a context compaction erases it.
2. **Never ask a question per track.** Classify every question the run meets, and ask the ones that
   actually need you in at most two batches — one before the run starts, one only when nothing else can
   move.

Everything below serves one of those two. For "how do I dispatch and verify a track", read
`executing-plans` or `subagent-driven-development` instead of this file.

## Any plan with a track checklist works

This skill has no opinion on your plan format. All it needs is a markdown file that lists tracks — a
checklist, a table, a set of headings, whatever you already write — each with enough written next to it to
hand to an implementer. A plan that also has an "Open questions" section and a "Decision Log" (or your own
names for the same two things: a parking lot, and a record of what was decided) makes Step 1 and Step 8
below mechanical; without one, keep the same two lists as a plain section at the bottom of the plan file.

If the repository runs [vibe-ops](https://github.com/entelekheia-ai/vibe-ops), its plan and task-dossier
format is a richer, optional backend: `vibe-ops task resolve --json` prints a tasks directory, a template
and the next number, so each track gets a numbered dossier instead of a scratch note. Nothing here requires
it.

## Three outcomes for every question the run meets

| The question | Outcome | What happens |
|---|---|---|
| answerable from the plan, its spec, the code or the repository's own conventions — including a plan sentence that turns out wrong, as long as correcting it leaves the track delivering what the plan promised | **ruling** | decide it, write down `Ruling: <what> — <why> — <cost if wrong>` next to the track (in its dossier, or in the plan itself), continue |
| a decision the plan reserves to whoever is driving the run — "may not be delegated", "decided by the caller" | **main loop** | this session is that caller: take the decision yourself, do the track without an implementer, and record it as a ruling |
| a decision the plan leaves to the maintainer, a review finding that reverses a plan decision or widens the track, a correction that changes what the track delivers, or a gate that still fails after one retry | **park** | write it under the plan's Open questions — naming the track, two to four options and the one you recommend — leave the track's work committed or reverted, and move to the next runnable track |
| the next act is outward-facing (push, pull request, merge, publish, release); the worktree holds changes this run did not make on files a track owns; the budget check says wait; no track is runnable and no question can be asked | **halt** | end the run |

A question the run can answer is a ruling. Parking one costs the maintainer the interruption this skill
removes; ruling on one they had to decide costs a revert. When the two readings are close, park.

A defect that predates the plan and blocks a track's gate is part of that track: fix it inside the track,
and note the command that showed it. A defect that blocks nothing is a deferred minor — write it down,
never a follow-up.

## Step 1 — The pre-flight table exists, and its questions were asked in one batch

Read the plan whole — its tracks, decisions, open questions and success criteria, and the spec it names —
and the target repository's own conventions for what a commit there requires. For each remaining track, in
the plan's order, note: its name, whether it is `runnable`, `question` (parked on something) or `halt`,
who does it (an implementer, or you), what it depends on (an order the plan states, a file two tracks both
write, an interface one produces and the other reads — empty only when the plan says the tracks are
independent), and, for a `question` row, a pointer to its entry under the plan's Open questions.

A `question` row writes its question under Open questions — the track, two to four options, the one you
recommend — unless an entry already asks it. The plan is the parking lot; your table only carries status.

Then ask every open question the runnable work waits on, in one batch, before starting anything. If your
surface has a structured way to ask several questions at once, use it — up to four at a time, your
recommendation first and marked as such, a second batch immediately after if there are more. Move each
answer out of Open questions into the plan's Decision Log (or its equivalent) and mark the row runnable. A
question left open keeps its track parked. This is the one interruption at the start; it replaces every
"go on" the run would otherwise need.

## Step 2 — Something records the run's position

If this session can crash, be backgrounded, or hit a context compaction before the plan is done, write
down enough to resume: the plan's path, the repository and worktree, the branch, the base commit, and each
track's status and commits. Where to write it and in what shape is yours to choose — this skill does not
require a particular file or format. Keep it current after every commit and every park; if you keep
nothing, a second run instead re-derives position from the plan file and `git log` on the branch, which
costs a little re-reading each time.

**If you install this skill's hooks** (see "What the hooks add," below), they read and write a JSON state
file at `~/.claude/plan-runs/<session id>.json` for you, and this step is theirs to keep current instead
of yours.

## Step 3 — Work happens on one branch, from the right base

Compare the local default branch with the remote one first (`git -C <repo> rev-list --count
origin/main..main`, or your VCS's equivalent). When the local branch is ahead and the plan's current text
lives only there, base the run on it and say so in the report; otherwise base it on the remote default.

Create a worktree or branch from that base (`git worktree add <path> -b <branch> <base>`; run your
package manager's clean install if there's a lockfile). One branch carries the whole run; record its
starting commit as the base.

**When the repository builds the tool its own commit hook runs** — the hook calls a binary from `PATH`
that this branch is changing — build the branch and put its binary first on `PATH` for every commit of the
run, and say so in the report.

## Step 4 — The next runnable track is taken

Take the first runnable track in the plan's order whose dependencies are all done. None left: go to Step
8's batch. Mark it running.

Give the track enough written context before its work starts — the track's spec quoted from the plan, its
acceptance line, the gate commands, the files it owns, the decisions already taken for it — whether an
implementer or you does the work. If the repository runs vibe-ops, that's `vibe-ops task resolve --json`
and a numbered dossier as described above; otherwise, a scratch note under the track heading in the plan
file, or a file next to it, serves the same purpose.

**Two tracks run at once only when their write sets are disjoint**, and the second starts only when the
first is dispatched. A follow-up that must edit a file a running track owns waits for that track.

## Step 5 — The track is done and checked, and committed

Dispatch it (see "The distinct moment this covers," above, for how) and verify its report against the
gate yourself before trusting it — a subagent's own account of what passed is not the check.

If the repository has agent definitions for this — an implementer, a reviewer — dispatching them is one
option. If it has none, do the track yourself in the main loop, or, if the [`delegation`
plugin](https://github.com/entelekheia-ai/public-plugin) (or an equivalent set of agents your setup
installs, commonly named `delegation:*`) is present, its agents fit this role.

On a gate failure, dispatch again with the failure described. A second failure parks the track: revert its
uncommitted changes, and the question is what to do about the failure.

Once it passes: tick the track in the plan, add whatever the repository's own conventions require of a
commit, and commit on the run's branch. Mark the row done with its commit.

## Step 6 — The review left nothing standing

Dispatch a review of the track's range — the repository's own reviewer definition if it has one, or do it
yourself. Reproduce each finding before accepting it, and grade it by what it does to the plan:

- stands, and fits the track: a follow-up, back to Step 5;
- stands, and reverses a plan decision or widens the track: park a question on the next track that depends
  on this one, and keep this track done;
- a nit that changes nothing anyone depends on: a deferred-minor note, never a follow-up.

After a follow-up, the rerun gate is the check. Review again only when a finding was serious, and then
only the follow-up's range.

## Step 7 — Pace the run

Before starting the next track, check whether this run should keep going, pause to write down what it
learned, wait out a usage window, or stop. What "check" means is yours to implement — see "What the hooks
and scripts add," below, for a working reference (`scripts/budget.sh`) that reads Claude Code's own
statusline data when it's present, and answers `unknown` gracefully when it is not.

- **Keep going**: return to Step 4 for the next track.
- **Context is getting full**: do whatever you use to write down what this run has taught so far — a
  standing learnings practice, a note in the plan, or nothing if you keep none — before it's lost to a
  compaction, then return to Step 4.
- **The usage window is nearly spent**: leave everything committed, note the readiness to resume, and
  either wait it out (if your surface can schedule a wakeup) or stop here.
- **No signal available**: this is expected outside an interactive session with a statusline; return to
  Step 4 and say so in the report.

**When Step 4 finds no runnable track and some are parked, ask every open question a parked track waits
on, in one batch**, as in Step 1. Each answer moves to the Decision Log, turns its track runnable, and
resumes at Step 4. Without a way to ask, this is a stop.

## Step 8 — The run ends, and the report says where

Write down, in the past tense: each track landed, with its commits; the point reached, and what it needs
from you next; every track still parked, with its question as the plan's Open questions states it; every
ruling made on your behalf, in order, each with its cost if wrong (this list is exhaustive — it is the
only place those decisions reach you); every deferred minor; the base chosen, any binary put first on
`PATH`.

The run stops before any push: publishing the branch is a stop, not a step this skill takes for you.

## What the hooks and scripts add, and what a hookless install loses

This skill ships two optional pieces that work only where this plugin's `hooks/hooks.json` is installed
(a full plugin install, not a skills-only one via `npx skills`):

- **`scripts/hook-precompact.sh`** (a `PreCompact` hook) folds the run's position into the compaction
  summary before it happens, so a run survives an automatic context compaction without losing track of
  which track it was on.
- **`scripts/hook-resume.sh`** (a `SessionStart` hook, matcher `compact`) tells the model where the run
  stood right after that compaction finishes.

Both read and write a small JSON state file at `~/.claude/plan-runs/<session id>.json` (see Step 2). A
skills-only install (no hooks) still runs this skill end to end; it only loses the automatic carry-over
across a compaction it didn't see coming — after one, re-read the plan and this file (if Step 2's notes
survived some other way) before continuing at Step 4, or invoke this skill again to pick the position back
up from what's committed on the branch.

**`scripts/budget.sh`** is the pacing check Step 7 describes. It reads what Claude Code's own statusline
writes to `~/.claude/usage/` (a user setting, not something this plugin installs) and prints one verdict —
`continue`, `route-learnings`, `wait <epoch> <HH:MM>`, or `unknown <reason>` when nothing fresh is there to
read, which is the normal case in a headless run or a surface with no statusline. Its thresholds are
`CTX_ROUTE` (default 60, percent of the context window) and `LIMIT_WAIT` (default 85, percent of the
5-hour usage window), both overridable as environment variables. It needs `jq` on `PATH`; without it, it
reports `unknown` rather than failing.

## Checklist

- [ ] The pre-flight table covered every remaining track, and its questions went out in one batch before
      the first dispatch
- [ ] The base was chosen by comparing the local and remote default branches
- [ ] The run's position was recoverable after every commit and every park
- [ ] Two tracks ran at once only on disjoint write sets
- [ ] Every review finding was reproduced before it went into a follow-up
- [ ] The pacing check ran between every two tracks, and its verdict decided the next step
- [ ] Parked questions went out in one batch, only once nothing else could move
- [ ] The report is on disk and lists every ruling and deferred minor

## ⟳ After every use: review this skill

The outcome table is the step whose failure is silent in both directions. Still asking "go on" between
tracks means a row there parks or halts what should have been a ruling; reverting a ruled decision means a
ruling that should have parked. Rewrite the table, not the run.

The dependency column decides how much work continues past a parked track, and it is written by judgement.
A track that ran on an output a parked track was about to change is the sign the column was read too
narrowly.

Measured once: a headless run over a four-track plan showed `budget.sh` answering `unknown` throughout,
because the statusline never wrote there — expected outside an interactive session with a statusline
configured. The first interactive run in a given surface is the one to check for whether the pacing signal
is actually reaching this skill.
