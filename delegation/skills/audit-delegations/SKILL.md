---
name: audit-delegations
description: Decide, when the same kind of brief keeps being written from scratch, which of a repository's recurring delegations deserve a custom subagent, a hook, a skill or nothing — read from the repository's own session transcripts — then write and blind-test each subagent; `review` repairs existing definitions against their runs. Use before writing another long delegation prompt, when asked whether something should be an agent, when an existing agent definition needs repair after a run surprised, when a subagent keeps hitting refusals or overrunning its report, or when two repositories' definitions of one role may have drifted apart.
argument-hint: '[repo-path | audit <repo-path> | review <definition>…]'
user-invocable: true
user_invocable: true
---

# Turn recurring delegations into subagents

**Before starting, read your notes for this skill**, where they exist — `~/.agents/skill-notes/audit-delegations.md`,
then `.agents/skill-notes/audit-delegations.md`, then `.agents/skill-notes/audit-delegations.local.md`. Where
two disagree, the more specific one wins. They hold what earlier runs taught; see the last section for how
they are written.

Fires when a repository's delegations start repeating: the same role briefed again and again, each brief
restating the same rules. At the end, each recurring role has a decision — subagent, hook, skill or
nothing — and each subagent decided on exists in `<repo>/.claude/agents/`, has run once on real work
from a fresh session, and carries what that run found missing.

**This is a target-state skill.** A second run over the same repository repairs the definitions against
newer sessions; `audit` runs Steps 1–3 and writes nothing.

**`review <definition>…` is a mode of its own**, for definitions that already exist: it measures their
runs (turns, refusals by source, report length), compares sibling definitions of one role across
repositories, and repairs both. Read `references/review-mode.md` and follow it instead of the steps
below; it is target-state too — its commands run from this skill's folder, `${CLAUDE_SKILL_DIR}`.

The mining of Step 1 and the reading of Step 2 can go to the `delegation:miner` subagent, a plugin agent
available wherever the plugin is installed, which returns the roles and their fixed half without filling
this session with prompts. Its brief carries two inputs: the repository's absolute path, and the absolute
path of this skill's own `${CLAUDE_SKILL_DIR}/scripts/mine-delegations.mjs`; the decisions from Step 3 on
stay here. Do Steps 1–2 yourself when the agent is missing from the available agent types — a skills-only
install carries no agents — and when this skill is itself being run by a subagent, which has no tool to
dispatch another.

`audit` writes nothing into any repository. Dumping prompts into a scratch directory to read them is
fine.

## Step 1 — List the candidate families

```sh
node ${CLAUDE_SKILL_DIR}/scripts/mine-delegations.mjs <repo-path> [--days=N]
```

It reads every session transcript under `~/.claude/projects/` that **wrote a file inside the repository,
or dispatched a call whose prompt contains its path as a substring** — the directory a session was opened
from says nothing, since sessions that edit a repository are often opened at a parent folder. A session
like that also delegates work aimed elsewhere, so only calls whose prompt names the repository (its path,
or its folder name as a word) are clustered. A repository path that contains other repositories (nested
`.git` directories, or linked worktrees of them) absorbs their calls too, since the substring test cannot
tell them apart on its own — each call's `lands` column, next to `target` in `--calls`, names which nested
repository (or `.` for the repository itself) it actually mentions most, and `--lands=.` restricts
clustering and the one-off count to the repository's own calls. A sentence counts as **fixed** when
prompts from two or more sessions carry it; a fixed sentence most calls carry is **generic** — the
caller's house phrases — and is listed apart instead of joining calls. Calls sharing the remaining fixed
sentences form a family. For each family it prints the calls with their index, the sessions, the share of
prompt text that is fixed, and the fixed sentences by frequency.

Then list every call, the one-off ones included:

```sh
node ${CLAUDE_SKILL_DIR}/scripts/mine-delegations.mjs <repo-path> [--days=N] --calls
```

Read the one-off calls' descriptions too. A role whose briefs were written in another language, or
reworded each time, never clusters, and it sits among the one-offs.

Read the output with three limits in mind:

- **The fixed share is a floor, and it says nothing about coherence.** Only nearly verbatim sentences in
  one language count; a rule restated in new words, or translated, is invisible to it. A family of one
  clean role and a family of five unrelated ones can show the same share. The paraphrased half, and the
  roles, are found in Step 2.
- **A family is not a role.** Sentences shared by neighbouring roles still join them, so a family can hold
  an implementer, a reviewer and a one-time writer.
- **The target test is a heuristic.** A prompt that names the repository only in passing counts as
  targeting it, and this is common rather than rare — measured once: about one targeting call in six named
  the repository only as a source to read. So open the prompt, not only the description, of every
  targeting call before it counts toward a role, and drop in Step 2 any call whose work is aimed at
  another repository.

A family seen in one session only is a task that fanned out, not a recurrence. Nothing below applies to it.

**The unit of evidence is the piece of work, not the session id.** One long session can carry several
separate tasks — a plan run across its tracks, resumed across a compaction — and a role it dispatched for
each of them has recurred, even though every call shares one session id. When the window holds few, long
sessions, count the distinct tasks a role's calls served, read from their variable half, in place of
sessions, and say in the report that you did. One task fanned out into batches still counts once.

**No family at all is a result, not a failure of the run.** When no fixed sentence is shared across
sessions, lowering `--threshold` finds nothing more, because the shared sentences are what is missing: the
briefs in this repository are written from scratch each time. Group the one-off calls by what the agent
is asked to do, from their descriptions, and open the prompts only of a group that spans two sessions, or two distinct tasks of one long session. An
audit that finds no recurring role ends there, with a Step 3 table whose surfaces are all **nothing** and
the not-yet-reused list — that is the audit done.

## Step 2 — Split each family into roles and write down its fixed half

Print a family's prompts with `--show=<n>` (add `--session=<id>` when the family is large), or chosen calls
with `--prompt=<i>,<j>,…`, and read them. A **role** is a set of calls that give the same kind of agent the
same boundaries and ask for the same kind of report: *implement one change in one language behind its
gate*, *review a range read-only*. Two calls differing only in which file or language they name are one
role. Add to each role the one-off calls whose description and prompt match it. A role whose agent was renamed inside the window — a definition moved into a plugin, a prefix changed — is still one role: group calls by what they ask, not by the agent's name. Where a role has more calls than you read, report each count as "k of the n read".

For each role, write down two lists:

- **The fixed half**: every rule the briefs restate, verbatim or paraphrased — the git verbs never to run,
  the paths the agent may write, the gate commands, what "done" means, whether stopping red is allowed,
  the report's sections, the scratch location.
- **The variable half**: what changes per call — the task, the worktree, the items owned, what siblings
  are touching.

Count the sessions each role appears in, across families and one-off calls — the family's own count is
not the role's. That count, not the call count, is the evidence. A role found in one session only — a
well-specified brief fanned out into batches — gets no surface yet, but list it as **not yet reused**
rather than dropping it: the next audit is where it either recurs or leaves the list.

Two kinds of rule need a reading before they enter the fixed half:

- **A rule the briefs contradict** — one brief lets the reviewer run the tests, another forbids it. Put
  the stricter reading in the definition, and let the brief widen it explicitly (the definition says
  "the brief may widen this").
- **A rule that depends on the brief** — "writes stay in the named worktree", "the registry only when
  authorised". A program could check it, but a frontmatter hook cannot see the brief, so it stays prose.

## Step 3 — Choose the surface for each role

| The role… | Surface |
|---|---|
| recurs in 2+ sessions, and its fixed half is instructions to the doer | **subagent** in `<repo>/.claude/agents/` |
| recurs in 2+ sessions but works across repositories — a blind first run of a new skill, a web research brief | **subagent** as a user-level `~/.claude/agents/` definition (or in the `.claude/agents/` of the folder where such sessions open) |
| has a fixed rule a program can check — a path never written, a verb never run, a tree left clean, a setup step | **hook** in that subagent's frontmatter, with the prose kept beside it |
| is the caller's own sequence between delegations — prepare, dispatch, verify, commit, review, triage | not an agent: that is the `delegation:hand-off` skill's procedure |
| has, as its only fixed rule, one a built-in agent type already enforces — read-only search, which `Explore` is by its tool set | **nothing** — dispatch the built-in type; a definition would restate what its tools already guarantee |
| is already dispatched through a definition | **`review <definition>`** — repair it against these runs; every rule the briefs still restate is one the definition lacks |
| appeared in one session, or its fixed half is two sentences | **nothing** — a subagent that fires once is a file nobody maintains |

A definition shipped inside a plugin has its frontmatter `hooks` ignored by Claude Code, so for a plugin
agent the guard goes in the plugin's own `hooks/hooks.json` instead, as a `PreToolUse` hook that acts only
when the payload's `agent_type` names the agent — this plugin's own `${CLAUDE_SKILL_DIR}/../../hooks/hooks.json` and
`${CLAUDE_SKILL_DIR}/../../scripts/guard.mjs` are a working example, both outside this skill's own folder.
A skills-only install (`npx skills add`) fetches this skill's folder only, not the plugin's `hooks/` and
`scripts/`; copy both by hand from the catalog repository, `entelekheia-ai/public-plugin` on GitHub, folder
`delegation/hooks/` and `delegation/scripts/`.

A second reason favours a subagent even for a short fixed half: **an `effort` level reaches a subagent
dispatched through the Agent tool only through its frontmatter.** When the routing table wants a level
other than the model's default, a definition is the only way to get it.

Two shapes of role need a choice made here:

- **Its model varied with the size of the task** (Sonnet on small tasks, Opus on large ones). Write one
  definition on the cheaper model the routing table names, and let the caller pass `model` on the call
  for a large task — that per-call override is the escalation lever. Write two definitions only when the
  fixed halves differ too.
- **Its fixed half came from an existing template** — a reviewer brief copied from a generic review
  prompt. The definition must stand alone, so it carries the parts of the template the role used, plus
  the repository's delta; it does not point at the template.

In `audit` mode, stop here and report the table.

## Step 4 — Write each definition

A subagent is Claude-only: it lives in `<repo>/.claude/agents/<name>.md`, a folder other harnesses do
not read. Read `references/frontmatter.md` now; it gives each field's reason and the hook recipes.

The body carries the fixed half as instructions, in the repository's language:

- **When to invoke**: the triggers, as scenarios.
- **What the caller gives you**: the variable half, and "if one is missing, stop and say which".
- **Where you work**: the worktree rule. A subagent starts in the caller's directory and a `cd` does not
  carry over between commands, so a non-isolated agent is told to use absolute paths and prefix every
  command with `cd <worktree> &&`, and that the named worktree wins over any directory the environment
  reports.
- **The boundaries**: what it may write, what is generated, the gate — per variant where the role has
  variants (a table per language).
- **The report**: past tense only, bounded length, and one required section for rulings — decisions the
  brief left open, each with its cost if wrong.

Where the role runs on findings from a review, say that the findings arrive triaged: judging a finding is
the caller's, and the agent reproduces, fixes and reports.

Then add one line to the repository's agent instructions file (`AGENTS.md`, `CLAUDE.md`) naming the agents
and that a caller omits `model`.

## Step 5 — Make the definitions visible where sessions open

A session loads `.claude/agents/` from its directory up to the repository root, never from a
subfolder. A session opened at a parent folder therefore does not see a subfolder repository's agents.
What does load them:

- a VS Code multi-root workspace listing the repository as a folder — the Claude Code extension passes
  every folder other than the session's own as an additional directory;
- `claude --add-dir <repo>`, or `/add-dir` inside a CLI session.

Both load the definitions once, at session start. `permissions.additionalDirectories` in a settings file
grants file access only and loads no agents. After changing a definition, open a new session.

## Step 6 — Run each new subagent once on real work, from a fresh session

Pick a task that needs doing anyway. A task invented to exercise the agent proves the invention. Then
start a headless session **inside the repository**, so it loads the definitions as committed:

```sh
cd <repo-or-its-worktree> && CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0 \
claude -p "Dispatch the <name> subagent in the foreground (do not pass a model parameter) \
and return its report verbatim. The brief: <the variable half>. Additionally, as a final section titled \
'Where this agent definition fell short', list every place your definition was missing, ambiguous, \
wrong for this repository, or made you guess. This section is required." \
  --allowedTools "Agent Read Grep Glob Bash Edit Write LSP" --model sonnet --output-format json \
  --settings '{"disableAllHooks":true}' > run.json
```

A headless session waits 600 seconds for background work after its last turn and then kills it, so a
subagent dispatched in the background and still running is cut off mid-edit with no report; the
environment variable lifts that ceiling, and the foreground dispatch avoids it.

`disableAllHooks` keeps a repository's `Stop` hook from replacing the final message: without it, a
repository whose stop hook speaks returns the model's reply to that hook as `result`, at exit 0. The flag
also switches off the agent's own frontmatter hooks, so this run exercises the definition's prose; the
hooks are tested on their own below, and a live check of them is a second run without the flag. Either
way, read the report from its source: it is the subagent's last message, in `~/.claude/projects/<slug>/<session_id>/subagents/agent-*.jsonl`; the `.meta.json` beside it
names the `agentType`. Confirm what ran, where the tools that answer it are installed:
`/route-work measure` (the `delegation:route-work` skill's measure mode) reports, per kind of delegation,
the model asked against the model that actually ran; for this one agent's turns, this skill's own
`node ${CLAUDE_SKILL_DIR}/scripts/agent-runs.mjs <repo>/.claude/agents/<name>.md` reports turns against the
definition's `maxTurns`, the report's length, and refusals by source. Without either installed, read the
subagent's own transcript directly — its first assistant message and the record's `message.model` state
the model and effort it ran with. Where what ran differs from the frontmatter, the definition is not doing
its job.

A subagent dispatched from a `-p` session in a trusted folder runs its frontmatter hooks, so a false
positive costs the run a turn. Test each hook command on its own first:

```sh
node ${CLAUDE_SKILL_DIR}/scripts/extract-hooks.mjs <repo>/.claude/agents/<name>.md <tmp-dir>
printf '%s' '<hook input JSON>' | sh <tmp-dir>/<Event>-<n>.sh; echo "exit=$?"
```

For each hook, feed one input it must block (expect `exit=2`) and one it must let through (expect `0`).

Judge the run once its result is checked: where the `delegation:route-work` skill is installed,
`/route-work record <what happened>` records the verified result. Without it, note the result yourself —
a line in the definition's commit message, or wherever this repository already tracks a delegation's
outcome.

## Step 7 — Fold what the run found missing, then commit

Every item under "Where this agent definition fell short" is either written into the definition or
answered with why it stays out. Run
`node ${CLAUDE_SKILL_DIR}/scripts/agent-runs.mjs <definition> --refusals` over the test run too: a refusal the
agent worked around in silence never reaches its shortfall list.
Then commit the definitions in the repository through its own gate, on a branch, and open the pull
request.

## Checklist

- [ ] The miner ran over the sessions that wrote the repository, and each family was read, not only counted
- [ ] Each role has its fixed half and variable half written down, with its session count
- [ ] Each role has a surface; a one-session role got nothing
- [ ] Each definition has a `name` that says which repository it serves, when several repositories' agents load in one session, plus `model`, `effort`, a `tools` allowlist, `maxTurns`, and hooks for every deterministic rule
- [ ] The repository's agent instructions file (`AGENTS.md`, `CLAUDE.md`) names the agents and says a caller omits `model`
- [ ] The definitions load where sessions actually open
- [ ] Each new subagent ran once on real work from a fresh session, and `/route-work measure` or the subagent's own transcript confirmed the model and effort that ran
- [ ] Each hook command blocked one input and passed another
- [ ] Every shortfall the run reported is folded in or answered

## ⟳ After every use: note what this run taught

**Never edit this file** — it is an installed copy, and the next update overwrites it without a word.
Write what the run taught to a notes file instead, one dated line per point, in the narrowest scope that
fits:

- **local** — `.agents/skill-notes/audit-delegations.local.md`, kept out of git (add `*.local.md` to that
  folder's ignore rules if it is not there yet). The default.
- **repo** — `.agents/skill-notes/audit-delegations.md`, committed, read by everyone who works in this
  repository.
- **user** — `~/.agents/skill-notes/audit-delegations.md`, true for you in every project.

Then ask the user whether a note should go back into the skill itself, through the flow they use for it
— an issue, a pull request, an edit in the plugin's own repository. When you do not know that flow, ask.

What is worth noting, in this skill:

- The weakest step is 2: a role drawn too wide gives one agent two jobs, and one drawn too narrow gives
  two agents one job. Check the first dispatches after a definition lands — a caller still restating a
  rule the definition carries means the fixed half was read wrong.
- The thresholds of Step 1 (`--threshold=0.25`, `--generic=0.3`) and the "two sessions" evidence bar rest
  on the repositories that produced families; one whose briefs share no sentence produces none at any
  threshold, which tests nothing about them. Note it when the next audit of a repository that does form
  families tests them.
- Step 2 carries most of the cost: the miner matches sentences, so it both joins unrelated briefs on one
  shared clause and splits one role whose briefs are worded differently, and the reader re-splits by hand.
  Clustering on paraphrase rather than on sentences is the change to try when a family keeps needing more
  than one split.

Verified against: Claude Code 2.1.282 (VS Code extension) and its subagent documentation, 2026-09-26.
