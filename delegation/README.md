# delegation

**Decide where delegated work runs, on which model, and carry it across the hand-off.** `delegation`
picks between the main loop, one subagent and a Workflow fan-out, routes to a model and effort tuned to
the work, carries a piece of work across a phase boundary (worktree, dispatch, verify, commit, review,
follow-up), and gives an implementer or reviewer subagent the task-file contract it needs to work from a
spec instead of a fresh brief each time.

## Skills

| Command | Fires when |
|---|---|
| `/delegation:route-work` | About to delegate to a subagent or write a Workflow script; deciding whether a task needs agents at all; choosing a session's starting model or how to raise capacity mid-session; a delegation surprised you. |
| `/delegation:hand-off` | A subagent has just returned; about to dispatch the next phase of a change; deciding whether a review finding stands; worktrees from earlier phases may be left over. |
| `/delegation:audit-delegations` | The same kind of brief keeps being written from scratch, before writing another long delegation prompt, when asked whether something should be an agent, or when an existing agent definition needs repair after a run surprised. |
| `work-a-task` | Not user-invocable — preloaded into (or named in the brief of) an implementer or reviewer subagent whenever its brief names a task, story, ticket or issue note file. |

## Agents

| Agent | What it does |
|---|---|
| `delegation:plan-scout` | Finds, read-only, what already exists — CLI flags, library APIs, existing skills and scripts — that a plan-in-progress should reuse instead of rebuilding. |
| `delegation:blind-run` | Carries out a written procedure exactly as written, on real work, having seen none of the session that wrote it, and reports where the text fell short. |
| `delegation:reviewer` | Reviews a diff, branch or design document adversarially and read-only, with every finding reproduced by a probe or pinned to `file:line`. |
| `delegation:implementer` | Implements one well-specified change inside one named repository and worktree, behind that repository's own gate. |
| `delegation:fact-sheet` | Reads one or more subsystems and returns a fact sheet where every claim carries a `file:line`, read-only. |
| `delegation:miner` | Mines a repository's past sessions for delegations that recur, and reports each role's fixed and variable halves, read-only. |

## Hooks

A `PreToolUse` hook on `Bash`, `Edit`, `Write` and `NotebookEdit` limits every agent above to git's
read-only subcommands (no `add`, `commit`, `checkout`, `reset` and their kin); `plan-scout`, `reviewer`,
`fact-sheet` and `miner` are further confined to writing only under a temporary directory, while
`blind-run` and `implementer` write files where their own brief says. The hook acts only when the call
comes from one of this plugin's agents and otherwise steps aside immediately.

## Requirements

`node` on `PATH` (the hook that enforces the read-only guard runs on it; without it, a call from a
read-only agent is refused rather than let through unchecked).

## Install

```sh
claude plugin install delegation@entelekheia
```
