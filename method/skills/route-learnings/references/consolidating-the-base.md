# Consolidating a durable-facts tier

Read this when `/route-learnings consolidate` runs, or when your own index reports the base over budget.
The harvest and the routing are in `SKILL.md`; this file is the convergence pass and nothing else.

**This pass is target-state.** There is a correct, budget-sized shape for the tier, the work is making the
disk match it, and a second run over a base that has not drifted changes nothing.

Pick a budget that fits your own base and keep it in one place your index reads from, rather than in this
sentence — a number chosen once tends to need raising later, as a base earns more entries that all pass
the promotion test and a permanently-lit alarm stops being an alarm.

## Contents

- [The seven outcomes](#the-seven-outcomes) — what a pass does to one entry
- [Moving a batch of entries into a skill](#moving-a-batch-of-entries-into-a-skill)
- [What the pass owes when it ends](#what-the-pass-owes-when-it-ends)

## The seven outcomes

Each entry gets exactly one. Six of them shrink the base; only **rewritten** leaves it the same size.

### Expired — the tool moved

A tool-fact entry whose version has moved: re-verify, or delete it. An unverifiable claim about an old
version is worse than no entry.

**"The version moved" is not one thing**, and applying it flat either deletes working facts or demands
re-verifications that find nothing. Weigh what would invalidate *that* claim: a claim about a documented
interface survives a patch bump; a claim about observed behaviour with no documented contract is
vulnerable to any bump and is usually cheap to re-check. For a tool that releases nightly, the verification
date carries the trust and the pinned version is close to decorative.

### Falsified — the re-check disproved it and handed you a replacement

Rewrite in place. State what is true now, say plainly that the previous claim was measured false and at
which version, and carry forward any decision the old entry drove so it can be re-taken.

Measured once: a re-check of a tool's constrained-output support found the earlier exclusion void at the
newer version — a different engine now honoured a schema it could not have invented — and the fresh probe
found a *different* hazard in its place. A delete-or-keep binary would have recorded neither.

**Rewrite only when the re-check hands you a replacement hazard.** When it hands you nothing, the next
outcome governs. The two are easy to confuse because both start with a claim that stopped being true; they
differ by whether anything still bites afterwards.

### It no longer breaks here — delete, even though every sentence is true

An entry exists to warn that something breaks or costs something **today**. It is never the history of a
thing that used to break. When re-verification finds the breakage gone — the premise void, the environment
moved, the third party fixed it — delete the entry.

The reflex to re-scope it ("still true on a machine that…") preserves a warning nobody can act on and
spends budget a live warning needs.

**The test is the premise, not the prose.** Ask what would have to be true for the entry to bite someone
here this week. Measured once: an entry warning that a compiler toolchain shipped no test runner was
accurate, well-evidenced, and void, because the local toolchain had since moved to one that did. It was
first rewritten to say "the premise no longer holds on this machine", which is a history entry wearing a
learning's clothes, and then deleted.

**Two things that look like this case and are not:**

- An entry whose breakage is held off by a **workaround someone could remove** still bites — if a local
  config file is the only thing standing between a repo and a known regression, a cleanup that deletes that
  file brings the breakage back, so the entry stays.
- An entry whose **prescription already lives somewhere permanent** needs no entry to survive — if a
  committed build file already enforces the fix, the entry that once explained why costs nothing to delete.

### Merge — two entries are one claim

**Start where the cross-links are densest.** A cluster whose members keep explaining how they differ is
where a split claim hides.

Then apply the test that rejects most of them: **could one honest H1 head both bodies?** Sharing a tool, a
subsystem or an incident is not sharing a claim, and a wrong merge buries a claim inside another one, which
is worse than two files.

**Expect to reject nearly all of them.** Measured once: dozens of candidate pairs considered across one
base, none merged, and in every dense cluster the cross-reference turned out to be doing its job — "this
is a different fact from that" — rather than papering over a duplicate. A pass that merges freely read
titles, not claims.

### Contradiction — two entries cannot both be true

A finding, never a merge. Resolve it by checking the repositories, and say which one was wrong.

### Graduated — it belongs to one repository now

Two destinations, and they are different moves:

- A fact that has become true of exactly one repository moves into **that repository**.
- A fact whose recurrence is addressed by a **path** moves down to the trap/debt log, keeping its evidence
  and gaining a `path:` and a `kind:`.

Expect the second to be the largest category on the first pass over a base that has not been split by
`scope:` against `path:` before — until then, a trap had two destinations: here, or nowhere. **Re-ask the
path question of every entry, not only of the ones that look wrong** — a well-written learning that is
actually a trap reads exactly like a good learning, which is why it was filed here.

### Absorbed by a skill — the procedure moved, and the entry may not have

An entry whose "how to apply" section is the whole entry is a procedure. Its content moves into the skill
that owns that moment, rewritten as the instruction, by the batch procedure below.

**Ask the moment question of every entry**, the same way the row above asks the path question: a
prescription filed as a tool fact reads exactly like a tool fact, because the fact half is true. Where
several entries answer with the **same** moment, that is one skill and one pass over all of them.

## Moving a batch of entries into a skill

Doing this by feel loses facts quietly. Four steps, in this order:

1. **Enrich the skill first, and by its scope rather than by a list.** Read every entry and pull in
   everything that belongs to that skill's moment — not the subset someone already flagged as missing.
   Doing this after the reduction means reducing twice.
2. **Then reduce each entry against the enriched skill, with a mechanical stopping rule**: an entry is done
   when **every sentence in it would be lost if the file were deleted**. Sentence by sentence, ask whether
   the skill now carries it; if it does, it goes. When nothing is left, the entry is deleted — never padded
   back up to justify the file.
3. **Have the reduction judged by a reader who did not write the skill.** The author cannot do it: they
   filled the skill's gaps from memory and cannot tell which sentences are on the page from which are in
   their head. Measured once, on one wave of absorptions: the author's own estimate of how much had been
   absorbed was wrong on most entries in the first batch, in the direction of believing more had been
   absorbed than had.
4. **Require the removal list, quoted, and read that instead of the rewritten text.** One line per removed
   sentence with where it now lives. It is shorter than the diff and it is where a silent loss shows.

**Expect an entry to survive the skill that took a bite of it.** Measured once, over a batch of entries
routed into two skills: none were fully absorbed on the first pass, and what each kept was of one of two
kinds — the exact text of a misleading error, or the mechanism by which the wrong approach *appears to
work* on the author's own machine. Those are consulted, never performed, so no skill has a moment for them.

**Write the skill's factual claims from the entry, never from a report about the entry** — including a
report you wrote yourself. That same wave put a sentence into a skill stating a piece of tool behaviour
that turned out to be the opposite of what the source entry, and the tool's own config, actually showed.

**Check what points at an entry before deleting it, and expect two kinds.** A markdown link breaks a link
checker, or your own gate, and is found for you. A bare slug in prose dangles in silence and is found only
by `grep`. A quoted slug inside a historical account is neither — it is evidence that the string was
written, and it stays.

## What the pass owes when it ends

- **Regenerate the index in the same breath as each deletion, if your setup keeps one.** Holding it until
  the end of a batch leaves the index pointing at a file that is gone, which can fail a gate and block a
  commit in the meantime. Regenerating twice costs nothing.
- **Report what was deleted and why.** Deletion is the point of this pass, not a side effect.
- **Record a hard call where the work is happening** — a rejection that was close, two entries that turned
  out to be one fact, a promotion that looked obvious and failed the lookup. Write it with the entry and
  the verdict quoted, and let closure route it.

A prescription for how this ceremony should behave belongs in `SKILL.md` or in this file, applied directly.
Only a prescription that cannot be applied yet becomes a track in a plan, naming what unblocks it. Sending
every hard call instead to one permanent plan's evidence section, and letting it accumulate there, has been
tried and cost real time later: determining which had already been acted on took a file-by-file comparison,
because an append-only section has no discharged state.
