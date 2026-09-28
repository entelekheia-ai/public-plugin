---
name: run-plan
description: 'Carry several remaining tracks of a plan through to landing, unattended between them — pacing the run against the usage limit and the context window, and batching every question that needs the maintainer instead of asking one per track. Fires when several tracks are left, the run should proceed unattended, and pacing or batched questions are wanted; for driving a single track inline, use executing-plans instead. Use when asked to run, drive or continue a plan track by track, or "/run-plan <plan>".'
argument-hint: '[plan-path | continue]'
arguments: plan
user-invocable: true
user_invocable: true
---

# Carry a plan through its tracks, unattended between them

**Before starting, read your notes for this skill**, where they exist — `~/.agents/skill-notes/run-plan.md`,
then `.agents/skill-notes/run-plan.md`, then `.agents/skill-notes/run-plan.local.md`. Where two disagree, the
more specific one wins. They hold what earlier runs taught; see the last section for how they are written.

Fires when a plan has **several remaining tracks** and the run should proceed **unattended between
them** — the only input the maintainer would otherwise give is "go on" — with the run **paced** against
the usage limit and context window, and its questions **batched** rather than asked one per track. The
plan is `$plan` — or, when that says `continue` or is empty, the plan this session's state file records
(`state.sh show`), or, without one, the plan the compaction summary names — and if none does, ask. At the end, every track that could move is committed, every question that needed the
maintainer was asked in a batch, and a report on disk says where the run stopped.

A single track, or a run where nobody needs pacing or batching, does not need this skill — see the next
section for what to use instead.

**This is a target-state skill.** The target is the plan with every runnable track landed; a second run
reads the plan (and, if this session wrote one, its state file) and resumes at the first track not done.

## The distinct moment this covers

Dispatching an implementer, checking its diff against the gate, and committing one track is its own
moment, already covered elsewhere:

- **[`executing-plans`](https://github.com/obra/superpowers)** — the loop for working through a plan's
  tracks yourself, in the current session, one at a time.
- **`subagent-driven-development`** — the same loop, but each track goes to a subagent instead of being
  done inline.

Follow only their per-task loop — dispatch, verify, commit — not their own Setup (a worktree, a ledger
file) or Finish (a merge, a pull-request menu): this skill's own Step 3 and Step 9 replace those, so that
one branch and one state file carry the whole run instead of per-track ceremony.

This skill is for the stretch *between* tracks, unattended, over a plan that still has several left:

1. **Pace the run against the usage limit and the context window**, so it stops at a clean point instead
   of being cut off mid-edit, and writes down what it learned before a context compaction erases it.
2. **Never ask a question per track.** Classify every question the run meets, and ask the ones that
   actually need the maintainer in at most two batches — one before the run starts, one only when nothing
   else can move.

Everything below serves one of those two. For "how do I dispatch and verify a track", read
`executing-plans` or `subagent-driven-development` instead of this file.

## Start it in the surface that can pace it

- `/run-plan <plan-path>` runs until it halts.
- `/run-plan continue` resumes the run this session's state file records — the one command after a
  context compaction.
- `/loop /run-plan <plan-path>` runs until it halts and can also wait out the usage limit, because
  `ScheduleWakeup` exists only inside `/loop` without an interval — confirmed for the `loop` skill
  shipped with Claude Code; a third-party equivalent may not offer it.

**After a compaction, the resume is an invocation, not a memory.** A compacted session holds a summary
of this skill, not its text, and a summary drops exactly the steps that have not happened yet — measured
once: a run resumed from its summary skipped Step 8's `routed false` and never opened the plan's read-first
list, while every step it did take looked right. So the first act after a compaction is `/run-plan
continue`, typed by the user or invoked by the model before anything else, and it does five things in
order: read the notes (top of this file); read the state file (`state.sh show`); read the plan's "Read
these first" section, if it has one, in its order; invoke again every other skill the run was using —
routing, hand-off, publishing, whichever it called before the compaction — since the summary holds a
retelling of those too, and their references (a brief checklist, a template) are exactly what a
retelling drops; then a track still `running` — its worktree and notes first, since a compaction may
have cut it mid-edit — and only then Step 4. The hooks below put that command in front
of both the model and the user; without them, it is the user's to type — so a run without the hooks
tells the user, once, at Step 2: "after a compaction, send `/run-plan continue`".

Run it in an interactive session in the foreground when possible. Claude Code can resume a task by itself
when the usage limit resets ("Automatic continue", set in `/rate-limit-options`); **unconfirmed from the
public docs**: the exact conditions under which that resume is cancelled (backgrounding the session,
relaunching Claude Code, a reset more than 24 hours out) — treat that list as a hypothesis to verify on
your own setup, not a guarantee.

A headless run (`claude -p`) has no `AskUserQuestion` and no `ScheduleWakeup`, so every question stays in
the plan (or the state file's `questions[]`, see Step 2) and `scripts/budget.sh` paces by context alone —
it has no statusline to read the 5-hour window from either (see Step 8). **Unconfirmed**: whether a
background subagent still running some time after the main loop's last turn gets killed mid-edit in a
headless run, and whether an environment variable changes that; if your own runs show a subagent cut off
mid-edit, that is the first thing to check.

## Any plan with a track checklist works

This skill has no opinion on your plan format. All it needs is a markdown file that lists tracks — a
checklist, a table, a set of headings, whatever you already write — each with enough written next to it to
hand to an implementer. A plan that also has an "Open questions" section and a "Decision Log" (or your own
names for the same two things: a parking lot, and a record of what was decided) makes Step 1 and Step 8
below mechanical; without one, keep the same two lists as a plain section at the bottom of the plan file.

**When the plan file itself may not be edited** — a generated or read-only spec, a document someone else
owns — keep both lists in the state file instead: `state.sh question <text> track=<name>
options=A|B recommend=<A>` appends to its `questions[]`, and the run's final report (Step 9) is where they
surface for the maintainer. Wherever this file says to add an "Open questions" section, the state file's
`questions[]` is the fallback when the plan cannot carry that section itself.

If the repository runs [vibe-ops](https://github.com/entelekheia-ai/vibe-ops) (also listed in this catalog), its plan and task
format is a richer, optional backend: `vibe-ops task resolve --json` prints a tasks directory, a template
and the next number, so each track gets a numbered task file instead of a scratch note. Nothing here requires
it.

## Three outcomes for every question the run meets

| The question | Outcome | What happens |
|---|---|---|
| answerable from the plan, its spec, the code or the repository's own conventions — including a plan sentence that turns out wrong, as long as correcting it leaves the track delivering what the plan promised | **ruling** | decide it, write down `Ruling: <what> — <why> — <cost if wrong>` next to the track (in its task file, or in the plan itself), continue |
| a decision the plan reserves to whoever is driving the run — "may not be delegated", "decided by the caller" | **main loop** | this session is that caller: take the decision yourself, do the track without an implementer, and record it as a ruling |
| a decision the plan leaves to the maintainer, a review finding that reverses a plan decision or widens the track, a correction that changes what the track delivers, or a gate that still fails after one retry | **park** | write it under the plan's Open questions (or `state.sh question`, see above) — naming the track, two to four options and the one you recommend — leave the track's work committed or reverted, and move to the next runnable track |
| the next act is outward-facing (push, pull request, merge, publish, release); the worktree holds changes this run did not make on files a track owns; the budget check says wait; no track is runnable and no question can be asked | **halt** | end the run |

A question the run can answer is a ruling. Parking one costs the maintainer the interruption this skill
removes; ruling on one they had to decide costs a revert. When the two readings are close, park.

A defect that predates the plan and blocks a track's gate is part of that track: fix it inside the track,
and note the command that showed it. A defect that blocks nothing is a deferred minor — write it down,
never a follow-up.

## Step 1 — The pre-flight table exists, and its questions were asked in one batch

Read the plan whole — its tracks, decisions, open questions and success criteria, and the spec it names —
and the target repository's own conventions for what a commit there requires. For each remaining track, in
the plan's order, note: its name, its status — `runnable`, `waiting` (nothing about the track itself is
undecided, but it depends on an earlier track not yet `done`), `parked` (blocked on a question or
anything else) or `halt` — who does it (an
implementer, or you), what it depends on (an order the plan states, a file two tracks both write, an
interface one produces and the other reads — empty only when the plan says the tracks are independent),
and, for a `parked` row blocked on a question, a pointer to its entry under the plan's Open questions (or
`state.sh question`).

A `parked` row blocked on a question writes it under Open questions — the track, two to four options, the
one you recommend — unless an entry already asks it. The plan is the parking lot; your table only carries
status.

Then ask every open question the runnable work waits on, in one batch, before starting anything. If your
surface has a structured way to ask several questions at once, use it — up to four at a time, your
recommendation first and marked as such, a second batch immediately after if there are more. Move each
answer out of Open questions into the plan's Decision Log (or its equivalent) and mark the row runnable. A
question left open keeps its track parked. This is the one interruption at the start; it replaces every
"go on" the run would otherwise need.

## Step 2 — Something records the run's position

If this session can crash, be backgrounded, or hit a context compaction before the plan is done, write
down enough to resume: the plan's path, the repository and worktree, the branch, the base commit, and each
track's status and commits. Keep it current after every commit and every park; without it, a second run
instead re-derives position from the plan file and `git log` on the branch, which costs a little
re-reading each time.

**This skill ships a state writer that does that for you: `scripts/state.sh`.** Its file is
`~/.claude/plan-runs/<session id>.json` (session id from `$CLAUDE_CODE_SESSION_ID`), and **only
`state.sh` writes it** — never `Write`, `Edit` or a heredoc. Each call stamps `at` from the clock and
replaces the file atomically; a hand-written file has been seen to carry an `at` the model invented, hours
ahead of the clock, and `learnings_routed: true` set before any track ran. It needs `jq` on `PATH` and
exits 1 with a clear message when `jq` is absent, rather than writing something malformed.

```sh
S="sh ${CLAUDE_SKILL_DIR}/scripts/state.sh"
$S init <plan> <repo> <worktree> <branch> <base>      # learnings_routed starts false; refuses if a file already exists — resume it, don't restart
$S track "Track 2" by=implementer depends="Track 1"    # adds the row as runnable
$S track "Track 2" status=waiting                      # its dependency isn't done yet
$S track "Track 2" status=running task=<task file path>
$S track "Track 2" status=done commit=<sha>            # commit= appends; repeat it, in one call or several
$S track "Track 1" status=done commit=<sha>            # right after init, for each track that landed before it
$S question "does X take Y?" track="Track 3" options="yes|no" recommend="no"
$S answer 0 "no"                                       # sets questions[0].answer once the maintainer answers it
$S routed true                                         # after learnings are written down, and only then
$S show | path | delete
```

Its schema: `plan`, `repo`, `worktree`, `branch`, `base`, `at`, `learnings_routed`, `tracks[]` (each with
`track`, `status`, `by`, `depends_on`, `task`, `commits`), and `questions[]` (each with `text`, `track`,
`options`, `recommend`, `answer` — `null` until `state.sh answer` sets it) — the fallback for Step 1's Open
questions when the plan file may not carry them.
`status` moves through `runnable`, `waiting`, `running`, `done`, `parked` and `halt` — one `parked` status
covers a track blocked on a question and one blocked on anything else alike. Update it
at every status change, commit and park. `state.sh delete` when no track is left; keep it at every other
halt, so the next run resumes from it.

**If you install this skill's hooks** (see "What the hooks and scripts add," below), they read only the
file `state.sh` writes, at a compaction boundary; writing it during the run is still yours to do at each
step below. Without them — a skills-only install via `npx skills` — `state.sh` is still the writer; you
re-read its file yourself after a compaction instead of the hooks doing it for you.

## Step 3 — Work happens on one branch, from the right base

Compare the local default branch with the remote one first: `git -C <repo> remote get-url origin` — when
there is no `origin` remote, base the run on local `HEAD` and say so in the report. Otherwise `git -C
<repo> fetch origin`, then resolve the remote's default branch with `git -C <repo> symbolic-ref --short
refs/remotes/origin/HEAD` — never a hardcoded `main` — falling back to `origin/main` when that ref is
unset, and to local `HEAD` (with the reason stated in the report) when neither resolves. Run `git -C
<repo> rev-list --count <remote-default>..<local-default>` (or your VCS's equivalent). When the local
branch is ahead and the plan's current text lives only there, base the run on it and say so in the
report; otherwise base it on the remote default.

Create a worktree or branch from that base (`git worktree add <path> -b <branch> <base>`; run your
package manager's clean install if there's a lockfile). One branch carries the whole run; record its
starting commit as the base.

**When the repository builds the tool its own commit hook runs** — the hook calls a binary from `PATH`
that this branch is changing — build the branch and put its binary first on `PATH` for every commit of the
run, and say so in the report.

## Step 4 — The next runnable track is taken

Take the first runnable track in the plan's order whose dependencies are all done — a `waiting` track
whose dependencies just landed becomes `runnable` here. None left: go to Step 8's batch. Mark it running.

Give the track enough written context before its work starts — the track's spec quoted from the plan, its
acceptance line, the gate commands, the files it owns, the decisions already taken for it — whether an
implementer or you does the work. If the repository runs vibe-ops, that's `vibe-ops task resolve --json`
and a numbered task file as described above; otherwise, a scratch note under the track heading in the plan
file, or a file next to it, serves the same purpose.

**Two tracks run at once only when their write sets are disjoint**, and the second starts only when the
first is dispatched. A follow-up that must edit a file a running track owns waits for that track.

## Step 5 — The track is done and checked

Dispatch it (see "The distinct moment this covers," above, for how) and verify its report against the
gate yourself before trusting it — a subagent's own account of what passed is not the check.

Use a reviewer or implementer agent if the repository has one; otherwise do the track yourself in the
main loop.

**A subagent that was killed before it reported leaves a partial diff.** Read `git -C <worktree> diff` for
what it left; either finish it with a fresh dispatch naming what is already there, or revert it before
moving on — an unfinished, unaccounted-for diff left in the worktree is what the next track would silently
build on.

On a gate failure, dispatch again with the failure described. A second failure parks the track: revert its
uncommitted changes, and the question is what to do about the failure.

## Step 6 — The track is committed on the run's branch

Once the gate passes: tick the track in the plan, add whatever the repository's own conventions require of
a commit, check `git branch --show-current` immediately before committing — so a track never lands on the
wrong branch because something else in the worktree changed it — and commit. Mark the row done with its
commit.

## Step 7 — The review left nothing standing

Dispatch a review of the track's range — the repository's own reviewer definition if it has one, or do it
yourself. Reproduce each finding before accepting it, and grade it by what it does to the plan:

- stands, and fits the track: a follow-up, back to Step 5;
- stands, and reverses a plan decision or widens the track: park a question on the next track that depends
  on this one, and keep this track done;
- a nit that changes nothing anyone depends on: a deferred-minor note, never a follow-up.

After a follow-up, the rerun gate is the check. Review again only when a finding was serious, and then
only the follow-up's range.

## Step 8 — Pace the run

Before starting the next track, check whether this run should keep going, pause to write down what it
learned, wait out a usage window, or stop. What "check" means is yours to implement — see "What the hooks
and scripts add," below, for a working reference, run as `sh ${CLAUDE_SKILL_DIR}/scripts/budget.sh`.

- **`continue`**: run `state.sh routed false` (if you're using the state file), so the "not written down
  yet" reminder in the resume hook can fire again once something new is learned, then return to Step 4
  for the next track.
- **`record-learnings`**: context is getting full. Do whatever you use to write down what this run has
  taught so far — a standing learnings practice, a note in the plan, or nothing if you keep none — before
  it's lost to a compaction, mark it done (`state.sh routed true` if you're using the state file), then
  return to Step 4.
- **`wait <epoch> <HH:MM>`**: the usage window is nearly spent. Leave everything committed, note the
  readiness to resume, and either wait it out (`/loop`'s `ScheduleWakeup`, if your surface can schedule
  one) or stop here.
- **`unknown <reason>`**: no signal was readable — there was neither a fresh statusline file nor a
  readable transcript to fall back to (the transcript fallback works in the VS Code extension and in a
  headless run alike; it only fails on a session with nothing in it yet). Treat it the same as
  `record-learnings` — write down what the run learned so far, since the next compaction could be one turn
  away with nothing to warn you — then return to Step 4, and say so in the report.

**When Step 4 finds no runnable track and some are parked, ask every open question a parked track waits
on, in one batch**, as in Step 1. Each answer moves to the Decision Log (or, for a question that lives
only in the state file, `state.sh answer <index> <text>`), turns its track runnable, and resumes at
Step 4. Without a way to ask, this is a stop.

## Step 9 — The run ends, and the report is on disk

Once nothing else can move, write the report to a named file **before** the final message, and repeat it
as the final message — a repository's own automation can replace or truncate a headless run's final
message, and the file is what a caller reads then. When the state file is in use, that path is
`~/.claude/plan-runs/<session id>-report.md`; otherwise, name one in the worktree and say its path in the
final message.

In the past tense, the report holds: each track landed, with its commits; the point reached, and what it
needs from the maintainer next; every track still parked, with its question as the plan's Open questions
(or the state file's `questions[]`, filtered to the entries whose `answer` is still `null` or empty) states it;
every ruling made on the maintainer's behalf, in order, each with its cost if wrong (this list is
exhaustive — it is the only place those decisions reach them); every deferred minor; the base chosen, any
binary put first on `PATH`, and the pacing readings.

The run stops before any push: publishing the branch is a stop, not a step this skill takes for you.

## What the hooks and scripts add, and what a hookless install loses

This skill ships two optional pieces that work only where this plugin's `hooks/hooks.json` is installed
(a full plugin install, not a skills-only one via `npx skills`):

- **`scripts/hook-precompact.sh`** (a `PreCompact` hook) folds the run's position into the compaction
  summary before it happens, so a run survives an automatic context compaction without losing track of
  which track it was on, and asks the summary to name the invocation (`/method:run-plan continue` in a plugin install) as the
  first action after it.
- **`scripts/hook-resume.sh`** (a `SessionStart` hook, matcher `compact`) answers in JSON right after that
  compaction finishes: a `systemMessage` shows the user the one command that resumes the run, and
  `additionalContext` tells the model where the run stood and that invoking this skill with `continue` is
  its first act.

Both read the state file at `~/.claude/plan-runs/<session id>.json` (see Step 2). A skills-only install
(no hooks) still runs this skill end to end, including `scripts/state.sh` and `scripts/budget.sh` — it
only loses the automatic carry-over across a compaction it didn't see coming: after one, send `/run-plan
continue` yourself — it re-reads the state file, or, if that did not survive, picks the position back up
from the plan and what is committed on the branch.

**`scripts/budget.sh`** is the pacing check Step 8 describes. It reads a per-session context reading and,
separately, the 5-hour usage window, and prints one verdict — `continue`, `record-learnings`, `wait
<epoch> <HH:MM>`, or `unknown <reason>` when nothing is there to read.

- **Context** comes from `~/.claude/usage/sessions/<session id>.json` (a JSON object with
  `{"at": <epoch>, "context_window": {"used_percentage": <0-100>}}`) when that file is fresh; otherwise
  from this session's own transcript — the last main-loop turn's input tokens, read from
  `~/.claude/projects/*/<session id>.jsonl`, divided by a context window size. That window is not read
  from any file the plugin ships: it's the environment variable `RUN_PLAN_CONTEXT_WINDOW`, default
  `200000`, set it to whatever your model's actual context window is. The transcript fallback works in
  the VS Code extension and in a headless run alike — neither writes the statusline's session file, but
  both keep this session's own transcript (`~/.claude/projects/*/<session id>.jsonl`). The reading is
  `unknown` only when there is neither a fresh statusline session file nor a readable transcript — a
  session with nothing written yet.
- **The 5-hour window** comes from `~/.claude/usage/rate_limits.json` (`{"at": <epoch>, "five_hour":
  {"used_percentage": <0-100>, "resets_at": <epoch>}}`). Neither file is written by this plugin or by
  Claude Code itself out of the box: they need a statusline script on your own setup that writes them on
  every render. Without one, the 5-hour reading is always `unknown` and only the context reading decides.

Its thresholds are `CTX_ROUTE` (default 60, percent of the context window) and `LIMIT_WAIT` (default 85,
percent of the 5-hour usage window), both overridable as environment variables. It needs `jq` on `PATH`;
without it, it reports `unknown` rather than failing.

## Checklist

- [ ] The pre-flight table covered every remaining track, and its questions went out in one batch before
      the first dispatch
- [ ] The base was chosen by comparing the local and remote default branches, falling back to local `HEAD`
      when there is no `origin`
- [ ] The run's position was recoverable after every commit and every park
- [ ] A killed subagent's partial diff was read and either finished or reverted before the next dispatch
- [ ] `git branch --show-current` was checked immediately before every commit
- [ ] Two tracks ran at once only on disjoint write sets
- [ ] Every review finding was reproduced before it went into a follow-up
- [ ] The pacing check ran between every two tracks, and its verdict decided the next step
- [ ] Parked questions went out in one batch, only once nothing else could move
- [ ] The report was written to a named file before the final message, and lists every ruling and
      deferred minor

## ⟳ After every use: note what this run taught

**Never edit this file** — it is an installed copy, and the next update overwrites it without a word.
Write what the run taught to a notes file instead, one dated line per point, in the narrowest scope that
fits:

- **local** — `.agents/skill-notes/run-plan.local.md`, kept out of git (add `*.local.md` to that folder's
  ignore rules if it is not there yet). The default.
- **repo** — `.agents/skill-notes/run-plan.md`, committed, read by everyone who works in this repository.
- **user** — `~/.agents/skill-notes/run-plan.md`, true for you in every project.

Then ask the user whether a note should go back into the skill itself, through the flow they use for it
— an issue, a pull request, an edit in the plugin's own repository. When you do not know that flow, ask.

What is worth noting, in this skill:
