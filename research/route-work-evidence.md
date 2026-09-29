# Where route-work's defaults come from

[Português](route-work-evidence.pt-br.md)

Feeds the routing table that the `delegation` plugin's `route-work` skill ships as its default.
Expires when that table changes a row, or when a new measurement covers a row this page marks as a
prior or a hypothesis.

**The answer.** The model-and-effort table comes from measurement of real use:

- 6 of its 12 rows were decided by paired experiments with an answer key written before the runs.
- 5 rest on verified real delegations with no comparison arm.
- 1 is a definition.

The cost argument behind the topology advice is measured too. The main-loop advice is a different case.
It builds on measured prompt-cache behaviour, but its order of preference and its choice of starting
model are hypotheses that no experiment has tested. Each row rests on a small sample: 2 or 3 tasks per
shape. Confidence: **moderate**.

> **Attribution.** External findings are **linked inline at first mention**. Everything unlinked is the
> author's own analysis: classifying each recommendation as measured, prior or hypothesis, and every
> count, ratio and percentage.

## Terms

- **Delegation**: work the main session hands to a subagent, or to one agent site in a multi-agent
  workflow.
- **Main loop**: the session the user opened and talks to. Its model is chosen when the session starts.
- **Effort**: how much reasoning the model is asked for (`low · medium · high · xhigh · max`).
- **Gate**: a check with a clear pass or fail: a build, a test suite, an adversarial review.
- **Paired experiment**: one task run on two or more arms, each arm a model and effort pair. Each arm
  runs in a fresh headless session, and a blind judge scores the result against a key written before
  the run.
- **Prior**: a claim taken from a published source, such as vendor documentation or a benchmark, and not
  measured here.

## The model table, row by row

Costs are **relative**. The usage ran on a subscription, so no dollar amount was billed. Every ratio below
is token counts priced at the vendor's list price, with cache reads and writes accounted for, and
compared between arms.

| Row | Default | Kind | Evidence |
|---|---|---|---|
| Enumerate, grep, count | no agent | definition | Deterministic work, done in the main loop by definition |
| Verbatim transcription, format conversion | `haiku` | real use, no comparison | Data came back byte-identical. Prose it was asked to move was paraphrased, and one paraphrase introduced a factual error |
| Locate files, read excerpts | `sonnet` `medium` | paired | Sonnet 5 and Opus 5.5 both 2/2; Opus at 1.4× the cost per correct task. Haiku 4.5 matched Sonnet 5 on 3 search tasks (9/9 key items each) at 86 % of the cost, with twice the turns. In earlier real use, Sonnet made no error in 9 searches; an inherited Opus made 2 errors in 51 and took twice as long |
| Translate, sample, write fixtures, audit against a template | `sonnet` `medium` | real use, no comparison | About 27 delegations with no rework. None of them recorded its effort level |
| Correct a doc against the code, `file:line` given | `sonnet` `medium` | paired | Sonnet 5 2/2 at 54 % of Opus 5.5's cost (also 2/2). Opus at `low` got 1/2 |
| Classify against a closed taxonomy | `opus` `low` | paired | 35 items. Opus 5.5 `low` was the only arm clearly above the majority-class baseline. Sonnet 5 was at the edge, at half the cost. Haiku 4.5 fell below the baseline, at about Opus's cost and 12× the wall time |
| Fact sheet with `file:line` | `opus` `medium` | paired, contested | Opus 5.5 2/2. Sonnet 5 1/2, with two false claims. Cost per correct task was even. Several real delegations had Sonnet holding on this shape |
| Adversarial review of a diff | `opus` `medium` | paired | Sonnet 5 0/2: it found the planted defects but made one false claim in each review. Opus 5.5 at `medium` and at `low` both 2/2. On 3 more review tasks, `medium` matched `xhigh` (3/3) at 56 % of the cost; `low` got 2/3 |
| Single-file implement | `sonnet` `medium` behind a gate | real use, no comparison | 7 delegations held behind a test suite. In 2 of them the gate was green and a review still found blocking defects |
| Reproduce a bug; cross-cutting change | `opus` `medium` behind a gate | paired (reproduce) | `medium` matched `xhigh` (3/3) at 72 % of the cost; `low` got 2/3 |
| Design, with the whole spec in the prompt | `opus` `high` | real use, earlier model | 12/12 on Opus 5, against 4 errors in 9 for a planner that inherited its model. Not yet measured on Opus 5.5 |
| Contest the premise | main loop or `opus` `high` | real use | 4 delegations, one of them on Opus 5.5 `high`. Nothing measures the main-loop half |

## The rest of the skill

**Where the work runs: the cost argument is measured.** A census covered 25 multi-agent workflow runs
with 194 agent sites. It found three things:

- **The model moves cost more than the width.** An Opus 5 agent cost 7.9× a Sonnet 5 agent. Two runs of
  the same shape differed 6.6×: 12 Opus agents against 13 Sonnet agents.
- **Long sites are expensive.** Sites that ran past 20 minutes were 5 % of sites and 11 % of the spend,
  which is why the skill cuts long work at checkpoints.
- **Fixed-command sites are waste.** Sites whose only job was running a fixed command often produced no
  output at all.

The rungs of the ladder and the three constraints of the widening test come from
[Anthropic's multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)
and [Building multi-agent systems: when and how to use them](https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them).
How they are ordered is the author's analysis.

**Raising capacity in the main loop: what each move costs is measured; the preferred order is a
hypothesis.**

- **Effort changes:** on Opus 5.5 and Fable 5.1, a clean effort change read 99 % of the context from
  cache. On Opus 5 it read 7 %, and on Sonnet 5 none.
- **Model switches:** switching to a new model left the cache cold in 65 % of switches. Switching back to
  a model already used left it cold in 91 %. The
  [prompt caching documentation](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
  explains why: each model has its own cache, and the lookup for an earlier entry reaches back a limited
  number of blocks.

From these costs the skill recommends raising by effort first, then by delegating, and switching model
only while the context is short, and it suggests a starting model. Neither the order nor the starting
model has been tested as a way of working.

**Escalation is partly measured.**

- **Measured:** `medium` matched `xhigh` on all six reproduce and review tasks.
- **Prior:** the `high` rung comes from the vendor's published effort ladder for Opus 5.5.
- **The author's call:** returning to the main loop after `xhigh` fails. The vendor recommends switching
  to Fable 5.1 instead.
- **One recorded escalation:** in the only escalation recorded in real use, a review triggered it; the
  test gate had stayed green.

**"Never route a subagent above Opus" is a price-and-benchmark prior.**
[Opus 5.5's launch page](https://www.anthropic.com/claude-opus-5-5) puts it at or above Fable 5.1 on the
benchmarks it lists. Its input and output tokens cost 40 % of Fable's; its cache reads cost 80 %.

**A new skill's first run goes to a blind subagent: measured in use, without a control.** Blind runs found
defects the author had not seen: 3 in one case, 17 gaps in another. No run by the author was compared
with them.

## Where the skill says more than the evidence

- **Fact sheet on Opus** rests on 2 tasks at even cost, while real delegations had Sonnet holding.
- **Review:** the cheapest passing arm was Opus at `low`. `medium` was kept because it held on three
  further tasks.
- **Classification:** Sonnet also passed on the main axis, at the edge.
- **Cost per agent:** the 7.9× compares Opus 5 with Sonnet 5. With Opus 5.5 the per-token ratio is about
  1.5×. The advice to change the model before widening still holds, by a smaller margin: width alone
  moved per-run cost about 4× between the 1–4 and the 9–12 agent bands.
- **Escalation:** the skill says the gate triggers it; in real use a review did.
- **Starting model:** the main-loop section states as advice what the evidence holds as a hypothesis.

## How this was measured

The routing data covers about two months of the author's own use, and several instruments measured it:

- **Censuses over session transcripts.** About 400 delegations and about 200 sessions of six or more
  messages. The censuses' windows overlap, so their counts are not added together.
- **A log of real delegations,** each verified by the session that dispatched it.
- **Paired experiments:** 17 tasks and 48 runs over code from several repositories, plus a classification
  run of 35 hand-labelled items across 3 arms.

Each experiment arm ran in a fresh headless Claude Code session. A blind Opus 5.5 judge scored each
result against a key written before the runs.

Every figure on this page was traced to the measurement that produced it, and four were checked again by
hand.

## Rejected, and what would reopen it

- **Publishing absolute costs.** The usage ran on a subscription, so a list-price dollar figure describes
  spending that never happened. Reopens if a measurement runs on billed API usage.
- **One total across instruments.** Their windows overlap, and a sum counts one delegation more than once.
  Reopens with a single census deduplicated by agent id.
- **Marking each row's basis inside the skill.** The skill ships its table as a default to tune, and
  this page carries the provenance instead. Reopens when a row changes.

## Open

- No row has more than 3 paired tasks per shape, or more than one run per arm.
- The tasks and keys were written by Opus 5.5 and judged by the same model family.
- No experiment ran inside a subagent. Carrying results from headless sessions over to subagents is an
  assumption.
- Three things have no measurement yet: Opus 5.5 at `high`, design on Opus 5.5, and the cost of a model
  switch in the main loop in tokens.
- The main-loop hypotheses have not been run as experiments.
