# What supports route-work's model recommendations?

[Português](route-work-evidence.pt-br.md)

***Expires when** there are new measurements, answers to the hypotheses, or a review of the external
claims not measured here; when Sonnet 5.5 and Haiku 5.5 ship; or when Anthropic issues new recommendations.*

**The answer.** `route-work`'s model recommendations rest on 391 readings of the author's own use, taken up
to the moment the table was written: 241 verified real delegations (work handed to a subagent and checked
before it was accepted) and 150 paired tests with an answer key — each delegation or test is one reading.
The real-use readings show the chosen model working in four kinds of work: implementation, review,
locating and translation. The tests that compare one model with another have 2 to 5 tasks per arm, which
makes the choice between Sonnet and Opus the least settled part. Confidence: **moderate**, for
`route-work` as a whole.

> **Attribution.** External findings are **linked inline at first mention**. Everything unlinked is the
> author's own analysis: classifying each recommendation, and every count, token figure and ratio.

## Why this research exists

`route-work` answers a question that comes up every time a coding agent works: who does this, where, and
with how much reasoning (the effort, from `low` to `max`)? The question reaches past subagents. It also
decides whether the work stays in the main session — the main loop, the conversation the user opened —,
goes to a subagent, or goes to a Workflow of several agents, and how the main session raises its capacity
when the work gets harder. The skill ships a ready table — Sonnet to locate and correct, Opus to review and
reproduce, Haiku only for mechanical copying — and invites whoever installs it to replace each row with
evidence from their own use. In the published version, every row says only `shipped default`.

This research counts what stood behind each recommendation when it was written. Most of it is
observation: real use and side-by-side tests. Where the numbers fell short, the recommendation came from
published sources (the priors) and from the author's earlier studies. Opus 5.5 starting at `medium` is an
example: `medium` is the default Anthropic set for that model and the first rung of the effort ladder it
published, and a test confirmed that it matches `xhigh` on 6 tasks. The model table is the most measured
part; where the work runs has cost measurements; and the main loop is still a pilot — its cache behaviour
was measured, the way of working the skill suggests was not tested.

## The analysis

The survey brought together two families of reading. The **paired tests** put the same task in front of
different models, with the answer key written beforehand and a blind judge checking the result. **Real
use** is everyday work: each delegation the session verified before accepting it. The two families
complement each other. A test compares models on the same task, but over few tasks; real use accumulates
volume, but almost always with a single model. A test repeated 1 to N times counts as one reading, and the
run with the highest ceiling counts; in real use, each delegation is one reading. A correct result, in a
test, covers the whole answer key with no false claim; in real use, it holds up under verification.

Each table row brings together three things. On the left, the skill's recommendation: the model and effort
in bold, above the name of the task. In the middle, the form of analysis behind it. On the right, the
evidence, which opens with a sentence on what the readings show, continues with the count per model and
ends with the tokens. Some recommendations sit "behind a gate": the result is accepted only after passing
a check with a clear pass or fail, such as a test suite or an adversarial review.

The count per model gives the correct results, the errors and a label that says whether the sample is
enough to trust the model on that task. The label comes from the 95 % Wilson interval — the worst and best
case consistent with the sample —, compared with a bar set by the task's risk. Where an error is costly,
the bar is 75 % correct. For classification, the bar is chance: always answering the most common label
gets 43 % right, and a classifier is only useful if it does better. When even the worst case clears the
bar, the label is **monitor**: the model holds, and it is enough to keep watching. When the bar falls
inside the margin of error, the label is **measure more**. When not even the best case reaches the bar, it
is **do not use**. And with 3 readings or fewer, the interval is too wide to say anything: **needs
analysis**.

Tokens appear in two parts, with the turns in parentheses: cache read, and new tokens (input, cache
writes and output). A cache read costs the same on Opus 5.5 and Sonnet 5 and weighs little in the price,
but it grows with every turn — whoever finishes in fewer turns re-reads less. New tokens cost twice as
much on Opus 5.5 as on Sonnet 5. The usage ran on a subscription, so consumption appears in tokens and
never in money.

## What the readings show

| Task | Form of analysis | Evidence |
|---|---|---|
| **no agent**<br>Enumerate, grep, list, count | definition | Deterministic work, done in the main loop.<br>0 readings |
| **`haiku` — effort omitted**<br>`publishing:edit-applier`<br>Verbatim transcription, format conversion | real use | Haiku 4.5 returned the data byte-identical; the prose it was only meant to move came back paraphrased, with a factual error.<br>2 readings: Haiku 4.5 2 (1 correct on data, 1 error on prose; needs analysis)<br>Tokens: not recorded |
| **`sonnet — medium`**<br>`delegation:plan-scout` · `delegation:miner`<br>Locate files, read excerpts | paired test<br>real use | Sonnet 5 and Opus 5.5 located the target every time. Haiku 4.5 tied in the tests, but failed 2 times in 5 in real use, once by inventing a fact.<br>80 readings: Sonnet 5 17 (17 correct; monitor) — 8 at `medium`, 9 with no effort recorded · Opus 5.5 `medium` 2 (2; needs analysis) · Opus 5.5 `low` 2 (2; needs analysis) · Haiku 4.5 8 (6 correct, 2 errors; measure more) · Opus 5 on the session's model (the delegation named no model and ran on the main conversation's) 51 (49 correct, 2 errors; monitor — the alternative)<br>Tokens (cache + new, turns): test with Opus — Sonnet 672K + 64K (10) · Opus `medium` 391K + 56K (9) · Opus `low` 200K + 42K (4); test with Haiku — Sonnet 310K + 40K (10) · Haiku 935K + 49K (21); real use — Sonnet 171K + 72K (3) · Haiku 531K + 65K (10) |
| **`sonnet — medium`**<br>Translate, sample, write fixtures, audit against a template | real use | Sonnet 5 did all 27 delegations without rework; none recorded its effort.<br>27 readings: Sonnet 5 27 (27 correct; monitor)<br>Tokens: not recorded |
| **`sonnet — medium`**<br>Correct a doc against the code, `file:line` given | paired test<br>real use | Sonnet 5 got every correction right, in tests and in real use. Opus 5.5 `medium` did too, and at `low` it introduced a false claim.<br>9 readings: Sonnet 5 `medium` 5 (5 correct; measure more) · Opus 5.5 `medium` 2 (2; needs analysis) · Opus 5.5 `low` 2 (1 correct, 1 error; needs analysis)<br>Tokens (cache + new, turns): Sonnet 131K + 38K (5) · Opus `medium` 156K + 36K (6) · Opus `low` 155K + 36K (6) |
| **`opus — low`**<br>Classify against a closed taxonomy | paired test | Opus 5.5 `low` came out clearly above chance — always answering the most common label gets 43 % —; Sonnet 5 cleared it at the edge, and Haiku 4.5 did no better than chance.<br>102 readings: Opus 5.5 `low` 35 (23 correct, 12 errors; monitor) · Sonnet 5 `medium` 33 (20, 13; monitor) · Haiku 4.5 34 (15, 19; measure more)<br>Tokens: no cache, one turn — Opus 1.4K · Sonnet 1.5K · Haiku 3.2K, and Haiku took 12× the time |
| **`opus — medium`**<br>`delegation:fact-sheet`<br>Subsystem fact sheet with `file:line` | paired test<br>real use | Opus 5.5 `medium` got every fact sheet right. Sonnet 5 missed 1 of 2 in the tests and held 11 of 14 in real use.<br>24 readings: Opus 5.5 `medium` 5 (5 correct; measure more) · Opus 5.5 `low` 2 (1, 1; needs analysis) · Sonnet 5 16 (12 correct, 4 errors; measure more) · Opus 5 `high` 1 (0, 1; needs analysis)<br>Tokens (cache + new, turns): Opus `medium` 516K + 39K (11) · Sonnet 137K + 50K (4) · Opus `low` 170K + 31K (4) |
| **`opus — medium`**<br>`delegation:reviewer` · `delegation:hand-off`<br>Adversarial review of a diff | paired test<br>real use | Opus 5.5 found the defects with no false claim in every review. Sonnet 5 found the planted defects, but invented one in each test; in real use it held 3 of 3.<br>38 readings: Opus 5.5 `medium` 19 (19 correct; monitor) · Opus 5.5 `low` 5 (4, 1; measure more) · Opus 5.5 `xhigh` 3 (3; needs analysis) · Sonnet 5 5 (3 correct, 2 errors; measure more) · Opus 5 6 (5, 1; measure more)<br>Tokens (cache + new, turns): test — Opus `medium` 507K + 49K (11) · Opus `low` 423K + 45K (9) · Opus `xhigh` 1.19M + 93K (21) · Sonnet 873K + 52K (14); real use — Opus `medium` 4.15M + 127K (51) · Sonnet 1.76M + 82K (36) |
| **`sonnet — medium` behind a gate**<br>`delegation:implementer` · `delegation:hand-off`<br>Well-specified implementation, one file | real use | Sonnet 5 behind a gate held in 61 of 68 implementations; where it failed, Opus 5.5 was the escalation.<br>79 readings: Sonnet 5 68 (61 correct, 7 errors; monitor) · Opus 5.5 10 (9, 1; measure more) · Opus 5 `xhigh` 1 (1; needs analysis)<br>Tokens (cache + new, turns), real use: Sonnet 5.60M + 146K (58) · Opus 5.5 18.73M + 403K (95) |
| **`opus — medium` behind a gate**<br>Reproduce a bug; cross-cutting change | paired test<br>real use | Opus 5.5 `medium` reproduced every bug, like `xhigh`, with fewer tokens; `low` left one answer-key item out.<br>10 readings: Opus 5.5 `medium` 3 (3 correct; needs analysis) · `xhigh` 3 (3; needs analysis) · `low` 3 (2, 1; needs analysis) · Opus 5 1 (1; needs analysis)<br>Tokens (cache + new, turns): `medium` 365K + 38K (9) · `xhigh` 439K + 53K (13) · `low` 295K + 34K (7) |
| **`opus — high`**<br>Design, with the whole spec in the prompt | real use | Opus at `high` with the whole spec designed without error; a planner running on the session's model got 4 of 9 wrong.<br>16 readings: Opus 5 `high` 5 (5 correct; measure more) · Opus 5.5 2 (2; needs analysis) · `Plan` on the session's model 9 (5, 4; measure more)<br>Tokens: not recorded |
| **main loop or `opus — high`**<br>Contest the premise; cross-repository synthesis | real use | Opus at `high` contested the premise with `file:line` all four recorded times, once on Opus 5.5.<br>4 readings: Opus 4 (4 correct; measure more)<br>Tokens: not recorded |

In total there are 391 readings: 150 from tests (locate 12, correct 6, classify 102, fact sheet 6, review
15, reproduce 9) and 241 from real use.

Real use alone already supports four recommendations: implementation on Sonnet behind a gate (61 of 68),
review on Opus 5.5 `medium` (19 of 19), translation on Sonnet (27 of 27) and locating on Sonnet (17 of 17).
In classification, Opus 5.5 `low` and Sonnet 5 also come out as **monitor**, against the chance bar. No
count comes out as **do not use**. The rest sits between **measure more** and **needs analysis** — and
that is where the comparison between models lives, the part the tests still cover with few tasks.

Turns explain much of the consumption. When locating, Sonnet 5 re-read 672K cache tokens over 10 turns,
against 391K for Opus 5.5 `medium` over 9; since a cache read costs the same on both, the cost difference
sits in the new tokens, where Sonnet is cheaper. For subsystem fact sheets it is the other way round: Opus
used 11 turns against Sonnet's 4 and re-read almost 4 times as much cache. There is no single ratio
between models; it changes with the kind of work.

## Beyond the table

### Where the work runs

Each agent's model weighs more in the cost than the number of agents. The data come from a census of 25
Workflow runs and 194 agents over about two months.

| Observation | Data |
|---|---|
| Opus 5 agent against Sonnet 5 agent | 7.9× the cost |
| Same run shape: 12 Opus against 13 Sonnet | 6.6× |
| Agents running past 20 minutes | 9 of 194 agents, 11 % of the spend |
| Agents whose only job was a fixed command | zero output tokens in 6 of 10 and 5 of 8 |

The topology ladder and the widening test are priors
([Anthropic, How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system);
[Claude, Building multi-agent systems: when and how to use them](https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them)),
ordered by the author's analysis.

### Raising capacity in the main loop

Changing effort keeps the cache only on the newer models, and switching model almost always loses it.
Hence the skill says to raise by effort first, then by delegating, and to switch model only while the
context is short. That order is a hypothesis: the costs were measured in the session transcripts, the
order was not ([prompt caching documentation](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)).

| Model | Change | Effect on the cache |
|---|---|---|
| Opus 5.5 | effort | 99 % read from cache (11 changes) |
| Fable 5.1 | effort | 99 % read from cache (8) |
| Opus 5 | effort | 7 % read (11) |
| Sonnet 5 | effort | 0 % read (9) |
| any | to a new model | cache cold in 13 of 20 switches |
| any | back to a model already used | cache cold in 10 of 11 |

### Escalation

The only measured rung is `medium` against `xhigh`; the rest comes from the effort ladder Anthropic
published for Opus 5.5, or is the skill's own call.

| Rung | Origin | Data |
|---|---|---|
| Opus 5.5 starts at `medium` | measured + prior | Opus 5.5 `medium` matched Opus 5.5 `xhigh` on 6 of 6 tasks; `xhigh` spent 1.2× to 2.3× the tokens |
| `medium` → `high` | prior | Anthropic's effort ladder for Opus 5.5 |
| failed at `xhigh` → main loop | the skill's call | the vendor recommends switching to Fable 5.1 |
| never above Opus in a subagent | prior | [Opus 5.5 page](https://www.anthropic.com/claude-opus-5-5): at or above Fable 5.1 on the benchmarks it lists, at 40 % of the price per token |

### A new skill's first run

Sending the first run to a blind subagent is a recommendation measured without a control. Three blind
runs found what the author had missed — 3 defects in one, 17 gaps in another —, and no run by the author
was set beside them for comparison. The catalog ships the agent for it, `delegation:blind-run` (Sonnet
`medium`): it follows the skill or procedure exactly as written, without having seen the session that
wrote it, and returns where the text fell short.

## How this was measured

The count stops at the commit that created the public catalog with the skill's table, on 2026-09-28.
Nothing recorded after it is included, because it did not inform the table.

| Source | What it gave |
|---|---|
| Readings log of an observation tool the author keeps | the paired tests and the verified real use, by model, effort and kind of work |
| Delegation log from Claude Code hooks | the most recent real use, with the model that ran and the verdict on each delegation |
| Session transcripts | the real-use tokens, linked to each delegation by agent id |
| Results of the test runs | the test tokens, by kind of work and arm |
| An earlier delegation log, kept by hand | the oldest real use: transcription, translation, the search on Opus 5 as the session's model, the planner on the session's model, and contesting the premise |

In the tests, a correct result covers the whole answer key with no false claim; the results match the
published tables of each experiment. The tests ran in fresh headless Claude Code sessions, and a blind
Opus 5.5 judge scored each result against a key written beforehand.

The instrument has two limits. The hand-kept log records no tokens, so four rows have none. And the
delegation log only started recording tokens in the last days of the window, so the real-use tokens come
from the transcripts.

## Corrections to the skill

The readings point to eight places where the skill should change at the next table update.

| Where | What the skill says today | What the readings show | Correction |
|---|---|---|---|
| Fact-sheet row and the `delegation:fact-sheet` agent | Opus `medium` | Sonnet held 11 of 14 in real use, at a third of the tokens | measure Sonnet more; consider Sonnet as the default, in the row and in the agent |
| Review row | Opus `medium` | `low` got 4 of 5 with 16 % fewer tokens | keep `medium`; measure `low` more |
| Classification row | Opus `low` | Sonnet passed at the edge, with similar tokens | measure Sonnet more |
| Step 0b | the raising order given as advice | the order was never tested | mark it as a hypothesis |
| Fallback bridge | Opus starts at `high` | the measured rows start at `medium` | align on `medium` |
| Step 4 | the gate triggers escalation | two escalations came from review with the gate green | add review as a trigger |
| Translation row | `medium` | effort never recorded | state the effort as unmeasured |
| Transcription row | `haiku` only | prose comes back paraphrased | restore "prose with caution" |

## Rejected, and what would reopen it

- **Marking each row's origin inside the skill.** The skill ships its table as a default to tune, and
  this page carries the provenance. Reopens when a row changes.
- **Cost in money.** The usage ran on a subscription; tokens and ratios describe consumption without
  suggesting spending that never happened. Reopens if a measurement runs on billed API usage.
- **Counting readings after the cut-off.** They did not inform the published table. Reopens at the next
  table update, which should use them.
- **Using the observation tool's automatic verdict.** With these samples it only says the n is small,
  which the table shows in more detail. Reopens when the samples grow.

## Open

- No kind of work has more than 5 paired tasks per arm, and each task ran once.
- Transcription, translation, design and contesting the premise have no tokens recorded.
- Opus 5.5's `high` rung and the token cost of a model switch in the main loop were not measured.
- The main-loop hypotheses were not run as experiments.
- The paired tests ran in headless sessions, not inside subagents, with tasks and keys written by Opus 5.5
  and judged by the same model family.
- The 7.9× per agent compares Opus 5 with Sonnet 5. With Opus 5.5 the price per token is 2× Sonnet's, and
  the token ratio varies by kind of work (0.6× when locating, 3.0× for fact sheets); the topology census
  was not rerun on Opus 5.5.
- There are 98 new readings, after the cut-off, in quarantine: they have not been through this analysis
  and will enter the next table update.
