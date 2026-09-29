# method

**Carry a plan through its remaining tracks unattended, paced against the usage limit and the context
window.** `method` drives a plan track by track across sessions, batching every question that needs the
maintainer instead of asking one at a time; keeps an always-on agent rule honest as it changes; gives
every skill you use a place to learn from your own runs, without editing the skill itself; and routes
what a piece of work taught to the surface built for that kind of fact.

## Skills

| Command | Fires when |
|---|---|
| `/method:run-plan` | Several tracks of a plan are left and the run should proceed unattended; asked to run, drive or continue a plan track by track. |
| `/method:authoring-rules` | Creating a rules file (an always-on agent rule such as `.claude/rules/<name>.md`), editing one, or when a rule has grown past its job or describes machinery that should be a guard. |
| `/method:skill-notes` | Wanting skills from other authors to remember what your runs taught them, a skill keeps making the same mistake, or a plugin update wiped a fix made inside its skill. |
| `/method:route-learnings` | A piece of work ends with nothing to close it, a session is about to be compacted mid-flight, or a durable-facts store has grown past its budget. |

## Hooks

| Event | What it does |
|---|---|
| `PreCompact` | While a `run-plan` run is in progress in this session, appends its state (plan path, worktree, finished/parked tracks, open questions) to the compaction instructions, so the summary carries what a resume needs. |
| `SessionStart` (matcher `compact`) | After a compaction, if a `run-plan` run was in progress, tells the user the one command that resumes it and instructs the model to invoke it first. |
| `PostToolUse` (matcher `Skill`) | When the model loads a skill through the Skill tool, hands it the notes kept for that skill (user, repository and local scopes, each labelled by where it came from) beside the skill's own text; a notes file behind a symbolic link is skipped, and each is capped at 16 KB. |

## Requirements

`jq` on `PATH` for the `run-plan` and `skill-notes` hooks; each is silent (never blocking) when `jq` is
missing.

## Install

```sh
claude plugin install method@entelekheia
```
