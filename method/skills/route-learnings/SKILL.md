---
name: route-learnings
description: 'Fires when a piece of work ends with nothing to close it, when a session is about to be compacted mid-flight, or when your durable-facts store has grown past its budget: harvest what was learned, run each candidate through a promotion test, and route only what survives to the surface built for that kind of fact — instead of appending everything to one memory file. Use at the end of a piece of cross-repo work, when a plan or task closes without a repository-level ceremony, before compacting a session, or when a facts tier is over budget.'
argument-hint: "[harvest | compact | consolidate | <the learning, in a phrase>]"
user-invocable: true
user_invocable: true
---

# /route-learnings — the ceremony for what a repository's own closure cannot route

If your repository already has its own closure ceremony (a task or plan close), it routes what the work
inside that repository taught. Work that spans repositories, or ends with no such ceremony to run, has no
destination for what it learned. This skill is that destination.

Claude Code's own memory — CLAUDE.md and auto memory — appends whatever it is told to one place. This
skill does the opposite on purpose: it filters each candidate through a promotion test, places what
survives by what kind of fact it is, and discharges the source it came from.

**It is a filter before it is a writer. Most candidates must be rejected.** A base that accepts everything
makes an agent worse on the problems the base was built from, because small over-generalisations compound.
Rejecting is the normal outcome of a run.

**Usage:** `/route-learnings` (harvest and route) · `/route-learnings compact` (the pre-compaction run) ·
`/route-learnings consolidate` (the convergence pass) · `/route-learnings <a phrase>` (route one known fact).

**This skill has modes of two kinds.** Harvest and compact are an **event skill**: each run captures what
the work taught since the last one and writes it as new, dated entries, and a second run adds the next
batch. Consolidate is **target-state**: there is a correct, budget-sized shape for a facts tier, the pass
converges the disk toward it, and a second run over a base that has not drifted changes nothing.

---

## Name which run this is, before starting

The three are not the same job, and "done" means something different in each.

| Trigger | What just happened | What this run owes |
|---|---|---|
| **A record closed** | a task dossier closed in a repository, a plan shipped, or cross-repo work ended with no repository to close in | Route what it taught. Steps 1–5. Demotion asked out loud. |
| **Context is about to be lost** — the session is about to be compacted mid-flight, or `/route-learnings compact` | Nothing ended; the session is being truncated | The pre-compaction section below, **then** Steps 1–5. |
| **The tier is over budget** | your own index says so, or enough has accumulated to review | [`references/consolidating-the-base.md`](references/consolidating-the-base.md), with convergence as the point. |

**Two can fire at once, and the run then owes both.** A closure ceremony can run in one repository while
the maintainer also asks, in the same breath, for the session to be compacted next. Read as a
single-answer question, the pre-compaction obligations are the ones dropped, because routing feels like
the whole job — it is the visible half. That combination has surfaced an in-progress plan sitting with no
tracks marked done while more had already shipped, which only the pre-compaction branch looks for. Name
every trigger that applies.

If your repo has its own closure ceremony (task or plan close), run this skill from it — that ceremony is
what hands this skill whatever the closing record could not route on its own.

### If the run is pre-compaction

**Compaction happens mid-flight, while work is unfinished**, and the only copy of that state is the
context about to be discarded. Routing learnings is necessary and insufficient. Before compacting:

- **Bring every in-progress plan's living sections current** — its progress record, and any decisions or
  surprises the session owes it. Write them into the plan as well as here: they are different surfaces
  with different readers, and after compaction nobody can reconstruct them.
- **Ask whether anything changed what a repository's `AGENTS.md` claims about itself.**
- **Name, in chat, the files the successor must read first — ordered, each with why.** A fresh session
  explores and finds things one hop away; **a compacted session trusts the retelling instead of
  re-exploring**. A source that was never named is a source it will not open, and it will re-derive
  whatever that source contained. Put the entry that explains everything downstream of it first.
- **Write the same list into the open plan as a "Read these first" section**, because this session's chat
  will be gone too. If the plan is genuinely self-contained, say so instead of adding the section.

When the request is phrased as "update the docs, plan and instructions before compacting", that sentence
is the scope — this skill is the vehicle rather than the boundary.

**Invoked right after a compaction instead?** The harvest source is then the summary and the transcript,
and Step 2 matters more than usual: a summary is a lossy retelling, and a "learning" recalled from one may
be something the summary compressed wrong.

## Do not add automatic capture

**Do not build a hook that harvests learnings from transcripts.** It is the obvious missing piece and it
is refused: the events that could carry it fire only where the work is already over, so the harvesting is
a transcript re-read — it refills the context the compaction was performed to empty, and re-analyses
material that was already analysed for free while the work was happening.

Capture stays **attached to the work, while the work is happening**: a dossier's surprises section, or
this skill at the end of a piece of cross-repo work. Worse at catching everything, better at everything
else — the entry is written by whoever was surprised, with the evidence in hand.

## Step 1 — Harvest candidates

Gather without judging; judgement is Steps 2 and 3. Draw from whichever apply:

- **This session** — what was discovered that nobody knew at the start. The strongest source, because the
  evidence is still in context.
- **A plan or dossier carrying an open surprises/decisions section.** Search wherever this repository (or
  workspace) keeps its plans for that heading — for example `grep -l "Observation:" docs/plans/*.md`,
  with your own heading and folder — and read every one still open.
- **A repository closure that just ran.** A repository's own closure ceremony, if it has one, routes to
  *that repository's* surfaces, and its routing has no row for a fact spanning repositories — a
  repository's `AGENTS.md` must stand alone, so it may not name a sibling repository or the workspace
  around it. Whatever it classified as "true of any repository", or had nowhere to put, is this skill's
  input. **Ask what was rejected, not only what was kept.**
- **Personal notes**, when the user asks for a sweep. One-directional: the committed file gets the *fact*,
  never the private note it came from.

**State the candidate count before filtering.** A run that promotes everything it harvested did not
filter.

**Expect a thin harvest after work that used the skill destination, and read it as that destination
working.** It is terminal and fires *during* the work — the fact is written into the procedure at the
moment it is learned, so by the time this runs there is nothing left to promote. A harvest ending with no
entry is then the system in its intended state.

## Step 2 — Verify each candidate before believing it

**Check every candidate against the repositories as they are now**, before the promotion test. A learning
is a claim about the world, and the world moved since it was written. Run the check the fact implies — the
dependency is still declared that way, the flag still exists, the file is still at that path, the guard
still absent.

**A falsified candidate becomes a finding.** If it contradicts something already written down, say so, and
fix the written copy.

**Verify the mechanism, not only the claim — and hardest for what *this* session just learned.** The
dangerous case is a fact discovered minutes ago where the observation is solid and the *explanation* was
inferred from the fix working. Those are different evidence: a symptom vanishing tells you about the fix
rather than about the cause, and from inside the session that made the change they are indistinguishable.

So before writing an entry that explains *why*, **reproduce the mechanism in isolation** — a scratch file,
the smallest input that should trigger it. If it does not reproduce, the entry is not written even though
the observation may still be true. A learning is trusted exactly where it is hardest to re-derive, so a
confident wrong mechanism sends the next reader hunting something that was never there.

## Step 3 — The three questions that eliminate

Ask them, in order, of any candidate that survived Step 2, and each one can end the candidate.

1. **Recurrence** — would it burn a fresh agent *more than once*? A one-off is an anecdote. **Ask it of the
   mechanism, not of the count.** Read as "how many times has this already happened?", the question
   rejects exactly the facts whose mechanism guarantees a recurrence that has not arrived yet.

2. **Non-discoverability** — **is there an easily searchable place that already answers this?** Name the
   surface and run the lookup: the code, a doc, a knowledge graph if the repo has one, `grep`,
   `--help`/`man`, or a plain web search. If one of them returns the answer, do not write it down.

   **Ask it of the consequence, not of the fact.** A lookup returns what *is*; the cost almost always lands
   on what *is absent* — a silent failure, a green-but-wrong result. One `package.json` says
   `exports → ./dist` in a single grep, and says nothing about a *stale* dist being green and silent, which
   is the whole entry. Conversely, if the consequence follows from ordinary knowledge of the tool the
   moment you see the fact, the lookup plus the model's own training has answered it: seeing a dependency
   pinned to an exact version is enough to know a publish does not reach that consumer, so that entry was
   two copies of one line.

   **Run the lookup; do not estimate it.** A lookup actually run turns up real gaps that guessing misses:
   `man du` never states its 512-byte default, `npm run --help` never states execution order between
   scripts, `man mdfind` never mentions that it skips dotfiles by default. Guessing here deletes working
   facts.

   **The question is about the reader arriving, not about the source being legible.** Short, clear code
   nobody is ever prompted to open is undiscoverable in the sense that matters. The discriminator: does
   normal use produce an *anomaly that triggers investigation*? A wrong result that looks exactly like
   success sends nobody anywhere.

3. **Not already enforced** — does a test, type, lint rule or hook already make the mistake impossible?
   Then **write the guard, not the prose.** **The test is "would its absence be visible?", never "is there
   a guard?"** A guard that skips silently leaves the written instruction load-bearing, because the
   instruction is then the only thing telling a reader to check the guard fired at all.

**A candidate that fails any of the three is dropped, out loud.** It does not fall through to a lesser tier
because it "might be useful". Filing rejects one tier down is what carries a facts tier past its budget,
and it is why the tier below rots.

## Step 4 — Place what survived

Two questions, asked in this order. They are independent, and answering only one leaves the fact homeless.

**First: which repository?** A facts tier exists per repository, so the folder is part of the address. A
fact about one repository's own work goes to **that repository**; a fact that no single repository can
hold — the toolchain regardless of repo, or how these repositories relate — goes to the **workspace
root**, because a repository's own files must make sense to someone who cloned just that repository.
With a single repository the first answer is always "this one", and a fact no repository can hold goes
to your own notes.

**Then: what is the fact?** Each destination below is a **role**, not a fixed folder name — map it onto
whatever your own repository already uses for that role. **A destination is reached on its own merits.**
A candidate that survived Step 3 still reaches nothing when no destination admits it, and saying so is a
complete outcome.

**Inside one repository, several surfaces can hold a fact, ranked roughly by how automatically they
load** — its `AGENTS.md`, a path-scoped rule, an always-on rule. If your setup already has its own ranking
for these, read that before placing a fact that stays in a repository; the roles below only add the two
facts no single repository can hold, plus the per-repository address a tier gains once it exists in more
than one place.

### A durable-facts store — admitted by `scope:`

**The admission test is `scope:`: what is this fact true *of*?** A language, a tool, a library, or how the
maintainer prefers to work. Something with no path of its own — a package, a CLI, a habit. If the honest
answer is a path inside a repository, this is a log entry instead.

Write each entry with the fields the destination needs to admit it: a `scope:`, an `attempted:` date, the
fact stated as a **claim** in the title ("`npm` OIDC covers `publish` only"), never a topic ("npm auth"),
and the evidence and where it applies in the body. An entry records what was known on its `attempted:`
date, not a current truth; the next pass re-verifies it. If a closely related entry exists, **refine it instead
of adding a near-duplicate** — near-duplicates are how a base stops being readable.

**By default, one file per entry at `docs/learnings/<slug>.md`**, the slug being the claim shortened, from
the template in [`references/entry-templates.md`](references/entry-templates.md). If your repository
already keeps such a store — a governance folder, a notes directory — use it instead; the admission test
is what matters, not the folder. If your setup carries a richer backend
for this kind of record — one optional example is [vibe-ops](https://github.com/entelekheia-ai/vibe-ops),
which can supply a template and an index of trap and debt entries — use its template
and commands; otherwise write the entry directly, and regenerate whatever index your setup keeps, if any,
in the same breath, never by hand.

### A trap or a debt — admitted by `path:`

**The admission test is `path:`: where does someone meet this again?** Name the file, folder or package.
If you cannot, the fact has no locatable place to recur, and it is a decision (an ADR) or nothing.

**The path also chooses the repository** — a path inside one repository sends the entry to that
repository's own trap/debt log, and only a path that is the workspace's own (its scripts, its shared
config, its root instruction file) belongs to the root.

**By default it goes to `docs/learnings/traps/<slug>.md`**, from the template in
[`references/entry-templates.md`](references/entry-templates.md), or to your repository's own log if it
has one. Without a tool to write these
for you, write the entry by hand, one file per entry named by a short slug (never a number), with: a
`path:` where it recurs, a `kind:` (below), the date, **what was attempted, what happened, the mechanism
— or "not established" when the cause is not known, which is better than a guess — and the evidence**.
No `status:` field; an attempt that was reverted and worked says so.

**`kind:` is `trap` or `debt`, and the choice is the user's.** A trap says *do not do this again*. Debt
says *we know, and we chose to live with it*. They fire on the same path and say opposite things, so it is
never inferred from the tone of the story — ask.

**The discriminator against a durable-facts entry is the path, not the tense.** Past-tense phrasing is a
hint rather than the test: a present-tense fact whose recurrence is addressed by a path in this repository
is a log entry.

**Two things every entry in either destination owes, regardless of which:** the evidence that makes the
claim checkable, and nothing framed as a decision the team made on purpose — that belongs to an ADR
instead, never to a fact log.

### A skill — admitted by the moment it fires

**The admission test is the moment**, the exact sibling of the path test. Name the moment at which the
procedure fires — *about to write a rule*, *about to close a plan*, *about to delegate*. If you cannot
name one, the fact is not a skill: a prescription that must be true before anyone starts is a **rule**, and
a prescription with no doer at all is a durable-facts entry or nothing.

**Which skills this may edit.** Only skills you own locally: a project's own (`.claude/skills/`,
`.agents/skills/`) or your user-level ones (`~/.claude/skills/`). **Never edit the installed copy of a
plugin's skill** — the next plugin update overwrites it, and the change is lost without a word. When the
fact belongs to a plugin's skill, **ask the user how they want it carried** before doing anything: an
issue needs a code host they may not use (some run Claude Code over a notes vault, with no repository at
all), and a plugin of their own has its own flow — an issue, a pull request, a direct edit in its source
repository followed by a release. Follow the flow you know they use; when you do not know it, ask. A
local skill that complements the plugin's is one option to offer.

**Three questions find the moment, name the home, and decide whether the skill is worth existing.** The
first two are not eliminating; the third is.

1. **Which phase of the work?** Building, evolving, configuring, operating, diagnosing. The phase **is**
   the moment. *Diagnosing* usually yields no skill, because the reader is looking at a strange output
   rather than performing anything.
2. **Which artifact does the hand touch in that phase?** That names the **home**. An artifact inside one
   repository sends the fact to that repository; an artifact at the workspace root keeps it here.
3. **Would the skill correct behaviour that is actually going wrong?** Only then does it exist. A clear
   moment with an obvious home can still fail this one, and that is the common case.

**A moment that fires constantly fires never.** *About to run a shell command* happens hundreds of times a
session and no skill can attach to it; those facts belong in entries, consulted at the moment of the
specific failure. Watch for this where a group looks large and cohesive — size is not the signal.

**This destination is terminal for the prescription, and only for the prescription.** A procedure routed
to a skill gets no entry restating it: it is written *there* and nowhere else. **The entry does not always
die with it, and expecting it to is the mistake** — an entry whose fact spans several moments survives
every skill that takes a bite. Send the prescription, then re-read what is left.

Two things follow, and both are the point:

- **The skill carries the text, never a link.** A skill is permanent and an entry is deletable by design,
  so a path into a facts tier dangles the moment consolidation removes the entry — silently, because the
  skill still reads as though the fact is written down somewhere. Write the sentences the procedure needs,
  with the names, paths and versions that make them believable.
- **It never reaches the budget.** A prescription filed as an entry spends budget on something no reader of
  the tier is looking for, and is read only by someone who arrived asking about the tool — the wrong door.
  Routed to the skill, it is read by the person performing the procedure.

**Rewrite the fact as the instruction.** An entry states what is true; a skill states what to do, and
skipping the translation produces a skill that reads like a bibliography. A learning saying *`bsd sed`
treats `\b` as a literal and exits 0 having changed nothing* becomes, in the skill that owns text
substitution, *use `perl -pi -e` for any boundary-anchored substitution on this machine* — with the failure
named in one clause, because an instruction whose reason is invisible is the one that gets argued away.

**Revising beats creating.** A prescription whose moment is already covered goes into that skill as a step
or a constraint, never into a new one. **Nothing hands off from one skill to another** — a hook cannot
invoke a skill, and skill-to-skill invocation is documented nowhere — so splitting a procedure across two
files means the second one does not run.

**A cluster is the strongest signal there is.** One prescription with no owner is an entry with an awkward
"how to apply"; several, all firing at the same moment, are a skill nobody has written yet — worth writing
as its own skill the moment a repository has none for that moment. Five prescriptions agreeing on a moment
is that shape; a single entry is not.

Two things a cluster does that a title does not show. **It can be mixed**, so ask the moment question of
each half of an entry: half of one candidate can fire at a different moment and belong with a different
skill instead. And **an entry whose fact a rule already states and a gate already enforces is a plain
deletion** — Step 3's third question applied backwards, needing no folding at all.

### A guard — the repository it protects

Mechanically enforceable means the prose was the wrong surface. Write the check, in the repository whose
files it reads, and **prove it fails**: run it against something broken on purpose and keep that fixture. A
guard nobody has watched fail produces output identical to a clean repository. Two more ways a guard
fails silently: it reads state it does not own, or its isolation does nothing on the user's platform —
so run a new guard until two runs in a row agree before trusting it.

### One repository's own instruction file

A fact true of exactly one repository goes to that repository's `AGENTS.md` (or `CLAUDE.md`) or one of its
rules, never to the workspace root. A path-scoped rule loads only when work touches matching files; an
always-on rule and a section of `AGENTS.md` load identically, and the split between them is organizational.

### A decision, not a claim about the world

A design, a trade-off, a mechanism we invented — it belongs to the plan or ADR that owns it. That record is
permanent, so it already has a durable home, and a second copy in a deletable tier is the one that goes
stale.

**A permanent document never links *into* a facts tier — it states the fact inline.** The link would
dangle the moment consolidation removes the entry, and dangle silently. Write the two or three sentences
the plan needs, with the evidence that carries them. That is not duplication, because **no reader sees
both**: someone reading the plan wants the decision it supports and will not open a link to get it. An
entry in a "Related" list is the one exception — a bibliography is expected to rot, and a reader scanning
it can tell a dead row from a live one.

### The user's own notes, or nowhere

A fact true of any repository anywhere, or about how the user prefers to work, is offered rather than
written. Everything else reaches nowhere. Say so and move on.

### One entry linking another

Both sides are deletable, so the "Related" exception does not carry over. **Write an entry-to-entry link
so that removing the target costs a link and never a fact:**

- **State the distinction, then link.** *"This is a different fact from X — X is about the variable being
  unset, this is about where it points when it is set"* survives X's deletion as a complete sentence. A
  bare *"see also X"* becomes a dangling clause that used to mean something.
- **Never let a link carry the fact.** A sentence like *"beware that the cache is keyed by content and
  prompt"*, written only as a link to another entry, goes dangling the moment that entry is deleted — the
  clause reads fine and means nothing. Inline what it borrowed instead, whenever the sentence would stop
  being true without the target.
- **A markdown link is easy to check** — a link checker, or your own gate, finds a broken one. **A bare
  slug named in prose dangles in silence** and is found only by `grep`. Grep for the slug, not only for
  the link, before deleting anything.

A high rate of cross-linking inside one cluster is a merge signal, and it is read during consolidation.

## Step 5 — Discharge the source

A candidate that survived came from somewhere, and **that source is always marked**. Without the marker
the next harvest picks the same entry up and promotes a duplicate.

The source keeps its full text and gains one line:

```markdown
- Observation: two honest counts of one corpus disagree by the number of bridged files.
  Evidence: …
  > Promoted to learning on YYYY-MM-DD
```

A block quote, on its own line, verbatim in that form. It is an aside about the entry rather than part of
it, and it is greppable as `^\s*> Promoted to learning on`.

**The source is never emptied, and never carries a `git show` pointer to the entry.** Two independent
reasons, and each one alone is sufficient:

- **The ordinary promotion crosses a repository boundary** — an entry leaves one repository's plan and is
  filed at the workspace root, or the reverse. A `git show` resolves against the repository it runs in, so
  a pointer of that kind names an object nobody outside that repository can resolve, and naming a path
  outside the repository it documents is worth avoiding on its own.
- **A breadcrumb-style gate, if your repo runs one, treats a pointer to a file still on disk as a defect.**
  That form exists for a file the closure *deleted*; a promoted entry is the destination and stays on
  disk, so such a gate would keep reporting *the file this breadcrumb points at is still in the working
  tree* until someone deletes the entry.

The two copies are not drift, because **no reader sees both**: someone inside the sub-repository needs the
fact and has no other way to reach it.

**A personal note** is in no repository. It gets neither pointer nor marker, and is deleted.

**A fact routed to a skill is discharged against the skill**, with a plain path to its `SKILL.md`. That
pointer is durable: a skill is permanent where an entry is deletable by design.

**The source is already gone** whenever a dossier closure deleted it, which is the ordinary case after a
repository's own closure ceremony. There is nothing to mark, and adding a marker to compensate helps
nobody: the marker exists only to stop the next harvest promoting a duplicate, and a deleted source cannot
be harvested again. Say the sources were closed out, and move on. **Check that the fact reached the
harvest at all** — a dossier deleted before this skill ran took its entries with it, so the candidates come
from the closure summary, the plan's retrospective and this session. Across sessions, whatever record the
closure left of what it deleted — a commit, a breadcrumb of its own — is the only remaining source.

**In one line: mark the source and keep its text; a personal note is deleted; a source a closure already
deleted is reported as such; a fact routed to a skill points at the skill by path.**

## Step 6 — Demotion, and the convergence pass

**Demotion runs on every trigger.** Did this work add a test, type, lint rule or hook that makes an
existing written instruction unnecessary? Then delete that instruction — in a facts tier, in an
`AGENTS.md`, or in a rule. Step 3's third question applied backwards. Without it the base only grows, and
growth costs: an always-on block passes a relevance gate as a whole, so a redundant line degrades the ones
that still matter. Ask it out loud even when the answer is "nothing".

**Consolidation runs when the tier is over budget, or on request.** Its seven outcomes and the procedure
for moving a batch of entries into a skill are in
[`references/consolidating-the-base.md`](references/consolidating-the-base.md). Read
it when this run is the consolidate mode, or when a demotion turns out to affect more than one entry.

## Checklist

- [ ] Which run this is was named out loud before starting, and every trigger that applied was named
- [ ] If a plan or dossier is closing: its surprises/decisions section was read, and each routed entry in
      it was marked
- [ ] If pre-compaction: in-progress plans' progress, surprises and decisions brought current **before**
      compacting, and the successor's reading list named in chat, ordered, each with its reason — with the
      open plan carrying its own "Read these first", or confirmed self-contained
- [ ] Candidate count stated before filtering, and most candidates were rejected
- [ ] Every promoted fact verified against the repositories as they are now; any entry explaining a
      *mechanism* was reproduced in isolation first
- [ ] Any falsified candidate that contradicted a written file was reported, and the file fixed
- [ ] Each fact was placed by both questions — which repository, then which destination — and each
      destination's own admission field was populated with a real answer rather than one invented to file
      it
- [ ] A durable-facts entry carries `scope:` and an `attempted:` date; a log entry carries `path:` and a
      `kind:` the user chose
- [ ] Nothing repo-specific landed at the root, and nothing committed names a personal-memory slug
- [ ] No permanent document gained a path link *into* a facts tier outside a "Related" bibliography — the
      fact was written inline instead
- [ ] Every source was marked `> Promoted to learning on YYYY-MM-DD` with its text kept; a personal note
      deleted; a source a closure had already deleted reported as such
- [ ] Every prescription was tested for its moment: routed into the skill that owns it, or named as a
      skill this workspace lacks — written there as an instruction, with **no** entry restating it; and
      each source entry was re-read and either reduced to what survives or deleted
- [ ] The demotion question was asked out loud, even if the answer was "nothing"
- [ ] Whatever index your setup keeps over this tier, if any, was regenerated and checked

## ⟳ After every use: review this skill

**The weakest part is Step 3, because questions are where this file hides its assumptions.** The edit
worth making is the candidate the three questions handled badly — one that passed all three and still
should not have been written, or that failed the first as "a one-off" and then recurred later. Sharpen the
question that let it through.

Three failure modes to watch for, because all three look like the skill working:

- **A run that fits none of the three triggers.** That table claims those are all of them; an invocation
  outside it is the edit.
- **A fact that had to be argued into a destination.** Step 4 places by what the fact *is*, and a fact that
  took paragraphs to place is evidence a destination is missing — never evidence you reasoned well.
- **A destination whose admission field was filled to make the entry filable.** `scope:`, `path:` and the
  moment are tests before they are metadata, and an invented answer passes every gate there is.

**A prescription for this file is applied to this file.** Filing it elsewhere to be applied later is what
produces a backlog of refinements indistinguishable from ones already landed. If a run produced no edits,
say so — a filter that fit its candidates exactly is signal too.
