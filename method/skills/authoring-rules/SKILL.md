---
name: authoring-rules
description: Write or rewrite an always-on agent rule — a rules file, such as `.claude/rules/<name>.md` — so it carries only what changes behaviour — obligations in RFC 2119 terms, no history, no supporting numbers, no section a versioned README or skill already owns. Use when creating a rule, when editing one, when a rule has grown past its job, or when prose in a rule describes machinery that should be a guard.
argument-hint: "[rule-file]"
user-invocable: true
user_invocable: true
---

# Authoring a rule

**Before starting, read your notes for this skill**, where they exist — `~/.agents/skill-notes/authoring-rules.md`,
then `.agents/skill-notes/authoring-rules.md`, then `.agents/skill-notes/authoring-rules.local.md`. Where two
disagree, the more specific one wins. They hold what earlier runs taught; see the last section for how
they are written.

**This is a target-state skill.** A second run repairs what drifted from the correct shape — relocated
sections, RFC 2119 obligations, no history, no supporting numbers.

A rule is loaded into **every session** that matches its `paths:` (or every session at all, when it has
none). Its cost is paid on every turn; its benefit is paid only when it changes what someone does. Write
for that ratio.

## The premise

This skill's premise, and not open for re-argument here — only its application is:

> A final artifact text **MUST** carry only what is relevant to the task it governs. Historical narrative,
> asides, and supporting numbers **MUST** be removed. It **MUST** be direct, clear and concise — most
> strictly where it sets rules of behaviour — and it **MUST** use RFC 2119 key words to state obligation.

This applies more strictly than a governance style guide agreeing only on *prescriptive, not descriptive*
and *never narrate history* — such as vibe-ops's own governance style guide, one optional reference among
others — where that guide does not also require RFC 2119 key words.

## Step 1 — Relocate the sections a versioned source already owns

**Do this first.** It is the largest available reduction and it is not a judgement call.

For each section, ask: **does a versioned README, skill, or script already own this?** If yes, delete the
section and leave a one-line pointer. Do not paraphrase it shorter. Relocation beats compression by a wide
margin whenever a section only restates something already versioned and linked elsewhere.

You **MUST** confirm the destination actually holds the content before deleting it here. Grep the target;
do not assume.

## Step 2 — Cut what leaves behaviour unchanged

Remove, in this order:

| Remove | Keep instead |
|---|---|
| How the rule came to exist; what the old design did; what broke once | The obligation itself |
| Counts, sizes, dates and measurements that argue *for* the rule | Nothing — the argument belongs in the RFC or plan |
| A mechanism explained past the point of acting on it | The one clause that makes the obligation legible |
| A procedure of more than ~3 steps | A pointer to the skill or script that owns it |

**Nothing is deleted, it is relocated.** Material cut from a rule **MUST** land in the RFC or plan that
argues for it, so the decision stays checkable. A rule states; an RFC argues.

## Step 3 — State obligations in RFC 2119 terms

Apply these conventions to the rule's own text:

- An obligation **MUST** be stated with a bolded RFC 2119 key word — **MUST**, **SHOULD**, **MAY** — meant
  literally. Text that only describes a practice **MUST** be cut, or rewritten as an obligation.
- Every **SHOULD** **MUST** name the case where it does not apply.
- An obligation **MUST** name the destination whenever one exists: *«**SHOULD** go to X rather than Y»*,
  not *«**SHOULD NOT** use Y»*.
- **MUST NOT** and **SHOULD NOT** **MUST** be reserved for a pure prohibition — one with no alternative
  destination to name. Reaching for a negative form is the signal to look for the positive one first.

This pass also finds duplicates the eye does not: two sections stating the same obligation in different
words collapse the moment both are written as the same key word.

## Step 4 — Name when the rule is inapplicable

A rule that is silently inapplicable most of the time reads as ignorable, and is then ignored when it
*does* apply. A correct, always-on rule can lose to the reflex it means to intercept far more often than
it is wrong, and nothing tells the reader which unless the rule says so. State the boundary explicitly:
**this is the rule being inapplicable, not the rule being ignored.**

## Step 5 — Make the trigger recognizable, not classifiable

Route on something observable **before** the action — a command shape about to be typed, a file about to
be written. A rule keyed to a category ("is this an architecture question?") can only fire after the reflex
it is meant to intercept has already fired.

## Step 6 — Prose or guard?

If the rule is mechanically checkable, prose is the weaker half. Say so in the rule, and open the guard
with a skill that pairs prose, gate and fixture, such as vibe-ops's `/new-signal`, if you have one;
otherwise write the prose, the guard and a fixture proving it fires yourself. A rule describing machinery
that nothing enforces **SHOULD** name that gap rather than imply enforcement.

## Frontmatter — and when the rule actually loads

Per [the Claude Code memory docs](https://code.claude.com/docs/en/memory#organize-rules-with-claude/rules/):

| Field | Use it for |
|---|---|
| `description` | Ignored by Claude Code — `paths` is the only field it reads from a rule. Kept for the human reader and for your own tooling: what the rule asserts, in one sentence. |
| `paths` | YAML list of globs. **Its presence makes the rule conditional.** |

Any other field is ignored without error, so nothing else belongs on a rule. `model:` **MUST NOT** be set
on any shipped rule or skill — it silently overrides the user's own session choice.

**Omitting `paths` is what makes a rule always-on.** A rule with no `paths` is loaded at launch, in every
session, at the same priority as `.claude/CLAUDE.md`. Adding `paths` does the opposite: it withholds the
rule until Claude **reads** a file matching a glob. That read has to come from a tool use — writing the
file alone does not trigger it. So a rule scoped to the very artifact it governs can miss the creation of a
new one.

Choose by cost against that gap:

- `paths` **SHOULD** be used whenever the governed files are overwhelmingly *edited* rather than created,
  since an edit is preceded by a read and the rule arrives in time. Always-on is the exception, for a
  guardrail whose violation is unrecoverable or whose only trigger is a first write.
- The residual gap **MUST** be accepted knowingly: a path-scoped rule is absent while its first file is
  being created from nothing. This skill's position — for rules governing rule text, that gap costs less
  than the always-on context paid on every turn of every session.

```yaml
---
description: One sentence.
paths:
  - "src/api/**/*.ts"
---
```

Claude Code auto-loads `.claude/rules/*.md` directly, with that optional `paths:` frontmatter to scope it.
If a canonical copy of the rule also lives elsewhere for another harness — `.agents/rules/`, for example —
mirror it into `.claude/rules/` with a relative symlink, and never fork the text between the two copies.
In that case:

- Discovery is recursive over `.claude/rules/**/*.md`, and a symlinked rule is supported — the docs
  themselves prescribe `ln -s` for sharing rules.
- A path-scoped rule now matches when the target file is reached through a symlinked path to the project
  directory (Claude Code ≥ v2.1.198). Below that version a path-scoped rule reached by symlink **MAY**
  silently never fire.
- A `.claude/rules/` symlink whose target sits outside the working directory is treated like an external
  import: it loads only after external imports are approved for the project, and even then only a rule
  with no `paths` loads.

When a rule is suspected of not loading, the [`InstructionsLoaded`](https://code.claude.com/docs/en/hooks#instructionsloaded)
hook **SHOULD** be used to log which instruction files loaded and when, rather than inferring it from
behaviour.

## Placement, and the optional bridge

Write the rule directly at `.claude/rules/<name>.md` when Claude Code is the only harness that needs to
reach it.

When another harness also needs the same text, keep the real file at its canonical path —
`.agents/rules/<name>.md`, for example — and reach it from `.claude/rules/` through a **relative
symlink**:

```sh
ln -s ../../.agents/rules/<name>.md .claude/rules/<name>.md
```

Never put the real file under `.claude/` in that case — it becomes invisible to the other harness's own
tooling and drifts.

## Before finishing

- [ ] Every pointer added in Step 1 resolves, and the destination really contains the content.
- [ ] No count, date or measurement remains that argues for the rule rather than states it.
- [ ] Every **SHOULD** names its exception.
- [ ] `paths` is present unless the rule is deliberately always-on, and, when a symlink bridge is in use,
      its globs cover both the canonical path and the `.claude/rules/` symlink, at the root and nested.
- [ ] Your Markdown linter is clean on the file.
- [ ] When a symlink bridge is in use, it exists and is relative.
- [ ] Any repository map naming the rule (`AGENTS.md`) is current.
- [ ] Effectiveness is checked by a count of a measurable signal — a tool-usage log, for example — not by
      re-reading the rule.

## ⟳ After every use: note what this run taught

**Never edit this file** — it is an installed copy, and the next update overwrites it without a word.
Write what the run taught to a notes file instead, one dated line per point, in the narrowest scope that
fits:

- **local** — `.agents/skill-notes/authoring-rules.local.md`, kept out of git (add `*.local.md` to that
  folder's ignore rules if it is not there yet). The default.
- **repo** — `.agents/skill-notes/authoring-rules.md`, committed, read by everyone who works in this
  repository.
- **user** — `~/.agents/skill-notes/authoring-rules.md`, true for you in every project.

Then ask the user whether a note should go back into the skill itself, through the flow they use for it
— an issue, a pull request, an edit in the plugin's own repository. When you do not know that flow, ask.

What is worth noting, in this skill:

- A Step 1 relocation that turned out wrong — the destination didn't actually hold the content, or held a
  *weaker* version of what was cut — since that failure is silent until an agent acts wrongly with the
  rule loaded.
- A rewrite that left Step 2's table incomplete: material that fit no row and was kept out of doubt, or a
  row that licensed cutting something load-bearing.
- A rewrite that came out reading better but, measured afterward by a count rather than a re-read, moved
  behaviour no further than before — and which of Steps 3–5 turned out to be the actual gap: when a
  rewritten rule changes nothing, the defect sits in Step 4 (the boundary) or Step 5 (the guard), not in
  the wording. A rule that reads better and measures the same is still broken.
- A gap that spans several rules or skills, rather than one — route it with `/route-learnings` (the
  `method` plugin ships it) instead of growing this file.
