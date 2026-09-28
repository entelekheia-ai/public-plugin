---
name: route-work
description: Decide where work runs — the main loop, one subagent, or a Workflow fan-out — and which model and effort run it, from a pre-configured routing table you can tune to your own work. Use when about to delegate to a subagent or write a Workflow script; when deciding whether a task needs agents at all; when choosing a session's starting model or how to raise capacity mid-session; when a delegation surprised you; or "/route-work use|measure|record|update".
argument-hint: "use  |  measure  |  record <what happened>  |  update"
user-invocable: true
user_invocable: true
---

# /route-work — place the work, pick the model, and tune the table to your own use

Two decisions are made every time work is about to leave the main loop, in this order: **where it runs**,
then **which model and effort run it**. A third decision comes before either and is easy to forget: **which
model the session itself is on, and how to raise it** when the work gets harder. This skill makes all
three from a routing table that ships pre-configured, and lets you replace its defaults with what your own
sessions show.

| Mode | When | What it does |
|---|---|---|
| `use` (default) | About to hand work off, or to choose or raise the session's model | Part 0 (where), Part 0b (the main loop), Part 1 (which model and effort) |
| `measure` | You want to see how your delegations actually chose their model | `references/personalize.md`, Measure |
| `record <what happened>` | A delegation's result was verified — surprising or not | `references/personalize.md`, Record |
| `update` | A row of your table should change | `references/personalize.md`, Update |

`record` is an event skill: each call appends one row, and running it twice correctly produces two rows.
`measure` and `update` are target-state: re-running either repairs rather than duplicates. `use` writes
nothing; it answers fresh each time.

---

## Part 0 — Where the work runs

### The ladder — ask in this order, stop at the first yes

**Count the work before ranking it.** Name how many independent items the request contains before choosing
a rung; a rung chosen from a wrong count is wrong from the start. When your count is narrower than the
request implies, say what you excluded and why before running. **A check whose result decides the next
action is part of that action, not an item of its own**: "check X, fix whichever side is wrong, add a test"
is one coupled change, and the check is its first step.

1. **Is the answer deterministic?** Enumerate, grep, count, run a fixed command, read a file you are about
   to edit. → **main loop**, no agent.
2. **Does step two need step one's whole output?** A relay of subagents passing state through files loses
   more to serialization than isolation buys back. → **main loop**.
3. **Is it one coupled change — plan, implement and test of one feature?** → **main loop**, or **one
   subagent behind a gate** (a build, a test suite, a script with a clear pass/fail).
4. **Is the answer short but the path to it verbose?** Wide search, long logs, test output, fetched docs.
   → **one subagent**. Isolation is the whole justification; if nothing would be isolated, go back to 1.
5. **Are there genuinely independent facets, each needing its own context, that you will reconcile?**
   → **Workflow, 2–4 agents per stage**.
6. **Must the lenses not see each other?** Independent drafts to be judged, blind judges, adversarial
   reviewers who would anchor on one another. → **Workflow, above 4 agents per stage**.

The first run of a newly written skill or procedure goes to **one subagent given the skill and nothing
else**, and asks for the places the skill fell short as a named deliverable — its author fills the gaps
without noticing.

### The widening test

Each rung down costs roughly an order of magnitude and buys exactly one of three things. Name which before
widening; naming none means the widening does not happen.

| Constraint relieved | What it looks like |
|---|---|
| Context pollution | the caller would read something it never needs again |
| True independence | two facets share no state, and neither answer changes the other |
| Tool or prompt conflict | the agents need contradictory instructions, tools or working directories |

**Try a cheaper model before a wider fan-out.** The model on each agent moves a run's cost far more than
the number of agents does.

### Four shapes that waste a fan-out

- **One agent per record** doing a small mechanical edit → one agent given all the records, or the main loop.
- **Agents whose whole job is a fixed command** (`run exactly: npm test`) → a shell step in the main loop.
- **One site handed a whole port or rewrite** → cut it at checkpoints that leave partial work on disk; a
  delegation expected past ~20 minutes loses everything to a stop if nothing is on disk.
- **Width instead of a cheaper model** → change the model first.

Two agents in the same stage never get write access to the same file.

---

## Part 0b — The main loop: the session's own model, and how to raise it

The routing table governs delegations. The session you open runs on whatever model you started it with, and
outside code that session is most of the work — so its model is a decision too, and usually an inherited
one.

**Choose the starting model by how the session will need to raise capacity, not only by the task.** The
three ways to raise it mid-session cost very differently, because of how prompt caching works:

| Raise by | What it costs |
|---|---|
| **Effort** — `/effort`, or a skill whose frontmatter sets `effort:` | On Opus 5.5 and Fable 5.1, nothing: Claude Code applies the change per message and keeps the cache. On other models it invalidates the cache |
| **A subagent** on a stronger model | The session's cache is untouched; the subagent starts cold on its own brief, and the session pays for writing the brief and reading the report |
| **A model switch** — `/model`, `opusplan` entering or leaving plan mode, or a skill whose frontmatter sets `model:` (that turn only; the session model resumes on the next prompt) | The whole context is reprocessed, **twice**: each model has its own cache, so the switch misses it, and the return usually misses too, because the API looks back at most 20 blocks for an earlier cache entry |

So the working order is: **raise by effort where the session's model allows it; otherwise delegate the
separable heavy part; switch the session's model only while the context is still short.**

- A session that will need capacity later is cheaper started on **Opus 5.5 at its default `medium`** than
  started on a smaller model and switched.
- A scripted pipeline that never needs to raise is the case for starting on **Sonnet 5**.
- **A day that mixes routine work with one harder piece** has two sound shapes. If the harder piece shares
  the session's context — a refactor of the module you have been fixing all day — start on Opus 5.5, run the
  routine turns at `low`, and raise the effort for the refactor; you pay Opus's higher price per token on
  the routine turns and nothing at the raise. If the harder piece is separable and the routine work
  dominates, start on Sonnet 5 and delegate the harder piece to an Opus subagent (the second pattern below).
- **Haiku 4.5 is for mechanical work**, not for judgement: it takes no effort parameter, and it reasons at
  length before answering when asked to judge.

Two delegation patterns keep the session's cache:

- **Plan on Opus in the session, execute on Sonnet behind a gate** — instead of `opusplan`. The session
  never switches model, and it reviews what the subagent returns, which is the gate an implement needs.
- **Run the session on Sonnet, delegate the hard part to Opus** — instead of a skill with `model: opus`. The
  Opus subagent pays only its brief, and the session's model becomes a choice about the routine work alone.

---

## Part 1 — Which model and effort run the delegation

### Step 1 — Classify the task on two axes

Classification sets the **effort** and whether a **gate** is attached. It never upgrades the model by itself.

- **Class, by reversibility:** `RESEARCH` (read, locate, report, judge — cheap to be wrong), `BUILD`
  (produce something that must run or ship), `OPERATE` (act on state that is hard to undo — a commit, a
  deploy, a delete). An `OPERATE` task always carries a verification step.
- **Complexity, by breadth:** `S` — one file, one sentence; `M` — several files; `L` — cross-cutting, or
  crosses a wire contract or a public surface.

### Step 2 — Find the row by what the subagent will do

Name the shape of the work, never its topic. When two shapes fit, the later row wins: a task that reads
*and* reproduces is a reproduce.

**The routing table — the recommendation this skill ships with.** Tune it to your own work with `update`.
Every row starts on `basis: shipped default`; `update` replaces that with your own evidence (for example
`own: 6/6 verified, 2026-10`) once you have rows to measure it against.

| The work | Class | `model` | `effort` | `basis` |
|---|---|---|---|---|
| Enumerate, grep, list, parse a manifest, count | RESEARCH·S | **no agent** — do it in the main loop | — | shipped default |
| Verbatim transcription, format conversion, boilerplate from a template | RESEARCH·S | `haiku` | omit | shipped default |
| Locate files or symbols, read excerpts, "does this file still contain X" | RESEARCH·S/M | `sonnet` | `medium` | shipped default |
| Translate, sample documents, write fixture tests, audit records against a template | RESEARCH·M | `sonnet` | `medium` | shipped default |
| Correct a doc, comment or record against the code, with the `file:line` already found | RESEARCH·M | `sonnet` | `medium` | shipped default |
| Classify records against a closed taxonomy from short text | RESEARCH·M | `opus` | `low` | shipped default |
| Read subsystems into a fact sheet with `file:line` | RESEARCH·M/L | `opus` | `medium` | shipped default |
| Adversarial review of a diff | BUILD·M/L | `opus` | `medium` | shipped default |
| Well-specified single-file implement | BUILD·S/M | `sonnet` behind a build/test gate | `medium` | shipped default |
| Reproduce a bug; implement a cross-cutting change in a worktree | BUILD·L | `opus` behind a build/test gate | `medium` | shipped default |
| Design, with the whole spec in the prompt | BUILD·L | `opus` | `high` | shipped default |
| Contest the premise of the task; cross-repository synthesis | BUILD·L | the main loop, or `opus` | `high` | shipped default |

**A shape the table lacks** — map what the subagent *does* to a tier: verbatim copy or template fill →
`haiku`, effort omitted; read, locate, report, routine review → `sonnet`, `medium`; reproduce, build that
must run, design, contest the premise → `opus`, `high`–`xhigh` — start at `high` and let a gate failure
raise it, the same escalation Step 4 uses. If the shape recurs, give it a row with `update`.

**Never route a subagent above `opus`.** No shape of delegated work needs Fable 5.1 in a subagent; a task
that fails at the top of the ladder returns to the main loop instead (Step 4).

### Step 3 — Write the call

Every delegation names `model`; a delegation without one inherits the session's model silently.

**Every `Agent` prompt opens with one line**, naming the decision this row made:

```text
[route-work] shape=<shape> model=<model> effort=<effort>
```

`shape` names the row from Step 2 (`locate`, `verbatim-conversion`, `well-specified-implement`, …).
`effort` is the row's choice even though the `Agent` tool cannot pass one — write it anyway: the call's own
transcript keeps its `input.prompt` verbatim, so `measure` reads the declaration straight out of the call
that made it, and pairs declared with asked exactly, even for several calls running in parallel, with
nothing to keep fresh or let go stale. Add `topology=` (`main-loop`, `one-subagent` or `workflow:N`) and
`relieves=` when widening past one subagent:

```text
Agent call — locate and read (RESEARCH·S):
  subagent_type: Explore, model: sonnet,
  prompt: "[route-work] shape=locate model=sonnet effort=medium\n\n…"

Agent call — verbatim conversion (RESEARCH·S):
  subagent_type: general-purpose, model: haiku,
  prompt: "[route-work] shape=verbatim-conversion model=haiku\n\nMove the text verbatim. Do not paraphrase. …"
```

A Workflow `agent()` site carries no prompt header for the audit to read — its widening rationale goes in
the script's own `meta.description` instead:

```js
// Workflow — model on every agent() site, chosen per site by that site's work
export const meta = { description: 'topology=workflow:3 relieves=true-independence' }

const found = await agent(`Locate every caller of ${sym}`, { label: 'find',   model: 'sonnet', effort: 'medium' })
const fix   = await agent(`Implement …`,                    { label: 'fix',    model: 'sonnet', effort: 'medium' }) // behind the test gate
const rev   = await agent(`Review the diff adversarially …`, { label: 'review', model: 'opus',   effort: 'medium' })
```

**Effort reaches a subagent only through a Workflow `agent()` site or an `effort:` field in a subagent
definition's frontmatter.** The `Agent` tool takes no effort argument: its subagent runs at the level Claude
Code resolves for that model, and the subagent's transcript records which. Omit effort on Haiku 4.5 — the
API rejects it. Opus 5.5 defaults to `medium`; Sonnet 5, Opus 5 and Fable 5.1 default to `high`.

**Before writing any brief, read `references/brief-clauses.md`.** Its clauses — let the agent contest the
brief with `file:line`, state a scope as a limit, allow a refusal — each catch a failure that a model
choice cannot.

### When the subagent's model is already fixed

A subagent definition's own frontmatter `model` is the decision for that subagent — Step 2 never overrides
it. Pass `model` on the call only to **escalate** it after its gate fails; a `model` passed on the call
replaces the definition's, it does not merely suggest one. `Explore` carries no frontmatter of its own: it
inherits the session's model, capped at Opus. The `Agent` tool's `model` parameter accepts only the four
aliases `sonnet`/`opus`/`haiku`/`fable`; a subagent definition's frontmatter also accepts a full model id or
`inherit`. A plugin agent that declares `inherit` runs on the session's model unless the call names one —
it is not exempt from Step 2 the way a fixed-model agent is. These are facts about Claude Code itself, not
about this table, and a platform release can move any of them — re-verify against the
[subagents docs](https://code.claude.com/docs/en/sub-agents) before relying on one.

### Step 4 — Let the gate decide when to escalate

Delegate at the cheaper row behind a real gate, and let the gate — never a hunch — trigger the retry:

1. A `sonnet` implement that fails its gate → the same task on `opus` at `medium`.
2. An `opus` row that fails → `high`, then `xhigh`, one rung per failure. Effort changes need a Workflow
   `agent()` site or an `effort:` frontmatter field.
3. A task that fails at `xhigh` → **back to the main loop**, never to a wider fan-out or a stronger subagent.

When a delegation fails on **reasoning** — it invented, contradicted itself, missed the premise — move it
to the next model up rather than to more effort on the same model. When an expensive delegation is only
**slow**, lower its effort one level before changing its model.

A gate must be real: a build that passes, a test, an adversarial review. A nominal gate costs more than it
saves, because a wrong cheap result is paid at every later step.

---

## Checklist

- [ ] The ladder was walked from rung 1, after counting the independent items in the request
- [ ] Every widening past one subagent names the constraint it relieves
- [ ] A cheaper model was tried before a wider fan-out
- [ ] The session's own model was chosen by how it will raise capacity (Part 0b)
- [ ] The task was classified, and the row found by what the subagent does
- [ ] `model` is on the call and on every Workflow site; `effort` is absent on Haiku and on `Agent` lines
- [ ] Every `Agent` prompt opens with a `[route-work]` line naming `shape`, `model` and `effort`; a widening
      Workflow site's `topology=`/`relieves=` are in its `meta.description`
- [ ] The brief carries the clauses in `references/brief-clauses.md` that fit it
- [ ] A `BUILD` delegation has a real gate, and escalation follows Step 4

## ⟳ After every use: review this skill

**The table is a starting point, and the rows most likely to be wrong for you are the ones still at `basis:
shipped default`** — nobody has weighed them against your own work yet. `record` every delegation you
verify, surprising or not; when a shape recurs twice with no row, give it one through `update`. A row that
reads better and measures the same has not been fixed.

**Part 0b rests on how prompt caching works today.** If Claude Code starts keeping the cache across an
effort change on more models, or across a model switch and back, the raise order changes — re-check the
Prompt caching page of the Claude Code docs when a model or a Claude Code version changes.
