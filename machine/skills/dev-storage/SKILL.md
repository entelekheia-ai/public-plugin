---
name: dev-storage
description: Reclaim disk on this development machine and keep it reclaimed — report where the space went, exclude regenerable caches and build output from Time Machine, delete them, and thin the APFS snapshots that otherwise pin every freed block, on a monthly cadence. Use when the disk is filling, after cloning repositories, or on that cadence.
disable-model-invocation: true
user-invocable: true
user_invocable: true
---

# Dev storage

**Before starting, read your notes for this skill**, where they exist — `~/.agents/skill-notes/dev-storage.md`,
then `.agents/skill-notes/dev-storage.md`, then `.agents/skill-notes/dev-storage.local.md`. Where two disagree, the
more specific one wins. They hold what earlier runs taught; see the last section for how they are written.

**macOS only.** Every command here drives Time Machine (`tmutil`) and APFS local snapshots directly.
On Linux there is nothing this skill can do — no exclusion mechanism and no local-snapshot thinning
exist there — so treat it as inapplicable rather than adapting it; use the platform's own
backup-exclusion tooling instead.

Free disk on a dev machine, and stop it filling again. Everything this touches is **regenerable by
the tool that owns it** — package caches, compiler output, downloaded SDKs. Source and `.git` are
never touched.

**This skill's delta is Time Machine exclusion of regenerable development output and snapshot
thinning, on a cadence — not disk cleanup in general.** For everything else (browser caches, system
junk, application leftovers unrelated to development), use a general-purpose macOS cleanup skill.

**This is a target-state skill.** The disk has a correct shape — regenerable caches gone, Time
Machine exclusions in place, local snapshots thinned — and every subcommand converges toward it:
`exclude` is stated idempotent below, and re-running `reclaim` after nothing new has accumulated
simply finds nothing left to delete. `report` is this skill's survey-without-writing mode, not a
separate skill.

The policy is a script, not a checklist: [`scripts/dev-storage.sh`](scripts/dev-storage.sh) — read its
[reference](references/scripts.md) before deviating from it.

## The trap — read this before reporting a result

**On APFS, deleting a cache frees nothing while a Time Machine local snapshot still references its
blocks.** macOS takes an hourly local snapshot and keeps about a day of them. So the deletion
succeeds, `df` reports the identical number it did before, and the obvious reading — "the cleanup
didn't work" — is wrong.

Measured once: tens of gigabytes of Xcode device support, DerivedData and package caches removed →
**zero bytes** freed, with same-day snapshots holding everything. Thinning them released a large
amount at once.

Two rules follow, and the script encodes both:

- **Never report free space between the delete and the thin.** The number is meaningless there.
  `reclaim` ends with the thin; read `df` only after it.
- **`thinlocalsnapshots` does not need `sudo`** for local snapshots. Don't ask for a password.

## Running it

```sh
${CLAUDE_SKILL_DIR}/scripts/dev-storage.sh report            # where the disk went
${CLAUDE_SKILL_DIR}/scripts/dev-storage.sh exclude           # keep it out of Time Machine — changes system state, no sudo
${CLAUDE_SKILL_DIR}/scripts/dev-storage.sh reclaim           # delete, then thin — changes system state, no sudo
${CLAUDE_SKILL_DIR}/scripts/dev-storage.sh reclaim --deep    # also drop builds untouched for 60 days
${CLAUDE_SKILL_DIR}/scripts/dev-storage.sh all               # exclude + reclaim + report
```

`report`, `tm-report.sh` and `tm-inventory.sh` are read-only and never need `sudo` for their
source-side sections; `tm-report.sh`/`tm-inventory.sh` need `sudo` only to read the backup-side
sections, and those additionally need Full Disk Access granted to the terminal — see
[the reference](references/scripts.md) for the split.

```sh
sudo ${CLAUDE_SKILL_DIR}/scripts/tm-report.sh [output-file]      # what Time Machine is still carrying
sudo ${CLAUDE_SKILL_DIR}/scripts/tm-inventory.sh [output-file]   # what regenerable junk is already inside a backup
```

`DEV_ROOT` overrides the scan root; it has no assumed value beyond the example default
`~/Development` the script ships with — set it to wherever your own projects actually live before
running anything.

**`report` is always the first step, never `reclaim` or `exclude` directly.** It is a preview, not
just a survey: alongside the top consumers, it prints the exact build directories `exclude` would add
and the ones `reclaim --deep` would remove for being stale. Show that output to the user before
running either command — a plain `reclaim` must never delete a cache the user has not seen named
first.

## Tuning the lists without editing the installed copy

The defaults in `GLOBAL_CACHES` and `BUILD_DIRS` are a starting point, not a claim that they cover
this machine. Add or remove a path through `~/.config/dev-storage/config` (or `$DEV_STORAGE_CONFIG`
for a different file), `KEY=value` per line:

```text
DEV_STORAGE_EXTRA=/path/to/a/cache/this/machine/has
DEV_STORAGE_EXTRA=some-build-dir-name
DEV_STORAGE_SKIP=/path/to/leave/alone
DEV_STORAGE_SKIP=coverage
```

A value containing `/` is treated as a full cache path (added to or removed from `GLOBAL_CACHES`); a
bare value is treated as a build-directory name (added to or removed from `BUILD_DIRS`, still subject
to the git-ignore check below). `DEV_STORAGE_EXTRA`/`DEV_STORAGE_SKIP` are read the same way from the
environment, and either source may repeat the key for more than one entry.

## Judgment the script deliberately leaves to you

`reclaim` removes only caches whose owner rebuilds them unasked. Three things stay manual because
they are decisions, not chores:

- **Stale build directories** are listed, not deleted, unless `--deep`. "Untouched for 60 days"
  cannot distinguish an abandoned experiment from a release branch not checked out this quarter —
  `report` prints this same list (and the paths `exclude` would add) before anything runs; read that
  output aloud to the user first, every time, not just once.
- **Application data, media, cloud placeholders, `~/Downloads`.** `report` will show them when they
  are large. They are the user's files: surface the number, propose nothing, delete nothing.
- **Anything outside the regenerable set.** If you are reaching for a path the script does not
  already cover, that is the signal to ask rather than to widen the blast radius.

`exclude` is idempotent and its exclusions are **per-path**, so a directory created later is not
covered. Re-run it after cloning a repository or after a first install in a new workspace package.

## Before excluding an app's folder, look at what sits beside the cache

An application directory is usually a cache **and** something irreplaceable, mixed together with
nothing in the naming to separate them. Excluding the parent is one command and it silently drops
the irreplaceable half from every future backup — the failure is invisible until a restore.

So name cache directories **individually**. An editor's application-support folder is the worked
example: its `Cache`, `CachedData`, `CachedExtensionVSIXs` and `WebStorage` sit directly beside
`User/`, which holds settings, keybindings and snippets and is regenerated by nothing.

Run the check both ways — it is `du -sh -x <app-dir>/*` and it takes seconds:

- It caught one editor, where excluding the parent would have been a real loss.
- It cleared a suspicion aimed the same way at another vendor's folder: only an updater and a
  downloaded test browser, no browser profile anywhere.

One in two, once measured. That is a good enough hit rate to never skip it.

## The biggest offender is rarely called a cache

Searching for directories named `cache` finds the easy half. The expensive half is **large mutable
state an application keeps under `Application Support`** — nothing in the name says "disposable", and
Time Machine copies the whole thing every time a byte changes (a mutating sparse disk image is the
sharpest case: it never shrinks from cleaning inside it, only from being excluded or reset). When
`report` shows something large that the exclusion list does not cover, ask what *writes* to it and how
often — not whether its name sounds temporary.

## An exclusion is forward-only

Excluding a directory does **not** remove it from the backups already taken. When someone asks why
the destination is still full after a cleanup, that is the answer, and no amount of re-running
`exclude` will change it.

`${CLAUDE_SKILL_DIR}/scripts/tm-inventory.sh` is the tool for what was already spent — read-only, and
it prints `tmutil delete -p` commands rather than running them, because deleting from a backup is
irreversible. Never run those for the user without them reading the list first.

**Check each path's exclusion status directly; never infer it from a sibling.** "Dotfolders are
skipped by Time Machine by default" is a plausible assumption, and false. A global
tool-install directory and a repository's generated build output both stay `[Included]` until
excluded by name. They look covered only because *other* dotfolders were excluded by an earlier
run, which is evidence about those paths and about no others. `tmutil isexcluded <path>` is the only
answer.

**A newly-found regenerable path usually belongs to two lists, not one.** `${CLAUDE_SKILL_DIR}/scripts/tm-inventory.sh`
keeps its own `CANDIDATES`, separate from `dev-storage.sh`'s `GLOBAL_CACHES`, and adding to one does not
add to the other — so a `tm-inventory` report showing a path as absent can mean it was already excluded,
or that the probe never asked. A per-repository path such as a generated output directory cannot go in
`CANDIDATES` at all; only `DEEP=1`'s full tree walk reaches it.

Two things to state correctly when this comes up:

- **Never report backup usage from `du`.** Backups on an APFS destination are snapshots sharing
  blocks, so `du` counts the same block once per backup. `tmutil uniquesize <path>` gives the space
  that is *not* shared — the only number that predicts what deleting frees.
- **A low `uniquesize` argues for excluding, not for ignoring.** It means the path is identical
  across the other backups, so deleting it from one frees nothing — it says nothing about whether
  the path is cheap, and it keeps entering every future backup until excluded at the source.
- **Time Machine copies changed blocks, not whole files**, on APFS destinations. So a large file
  rewritten in place is cheap, while a large file *replaced* by a new one is a full copy retained in
  history. The axis is replaced-versus-modified, not large-versus-small — a rotating set of
  downloaded model weights is the worst case, and a mutating VM image is nearly the cheapest.

## Package managers move install speed, not disk space

Migrating npm → pnpm/bun is a plausible-sounding response to a full disk, and it is the wrong lever:
the duplication a hardlinked store recovers is a small fraction of what `reclaim` returns by thinning
snapshots. Migrate for install speed if you want it, but do not let it delay `reclaim`, and do not
count it as a disk fix.

One real cost worth naming: **bun's cache has no prune command and only grows.** Measured once, it
reached several gigabytes on a machine where every repository resolved through
`package-lock.json` — a cache serving nothing. The script drops it only when no `bun.lock` exists
anywhere under `DEV_ROOT`.

## Read `tm-report.sh` by its churn column, and mistrust a zero

The report ranks by **bytes changed in the window, not by size**, because that is what a backup costs.
The two orderings can disagree almost completely: a machine's largest directory by size can change
little, while the top of the churn list sits nowhere near the top of the size list.

Reading it correctly means knowing what each column already accounts for:

- **`SIZE` is gross, `CHANGED` is net.** The size is the whole subtree including children that are
  already excluded; the churn has those pruned out. A row can look enormous and be nearly free
  precisely because the expensive part of it is already excluded.
- **`CHANGED = ?` means unmeasured.** That walk hit `SIZE_TIMEOUT` and was abandoned, so the true number
  stays unknown — treat it as neither zero nor small. Those rows sort to the top on purpose. Re-run with
  a larger `SIZE_TIMEOUT` rather than concluding anything from them.
- **Churn can exceed size.** Normal, and informative: it means files were rewritten more than once in
  the window. Combined with a low `FILES` count it identifies a big archive being replaced wholesale, which
  is the expensive case — block-level delta copying does not save you when the whole file is rewritten.

**Every zero in a storage script deserves one spot check before it is believed.** Four separate bugs
in this report each produced a confident, plausible zero rather than an error, once found: an
unindexed dotfile tree, an abandoned walk, a path containing a space, and an exclusion nested deeper
than the scan looked. None of them failed; each just reported that nothing had changed. Cross-check
one row with a direct `find <dir> -type f -mtime -7 | wc -l` before acting on it.

## ⟳ After every use: note what this run taught

**Never edit this file** — it is an installed copy, and the next update overwrites it without a word.
Write what the run taught to a notes file instead, one dated line per point, in the narrowest scope that
fits:

- **local** — `.agents/skill-notes/dev-storage.local.md`, kept out of git (add `*.local.md` to that
  folder's ignore rules if it is not there yet). The default.
- **repo** — `.agents/skill-notes/dev-storage.md`, committed, read by everyone who works in this
  repository.
- **user** — `~/.agents/skill-notes/dev-storage.md`, true for you in every project.

Then ask the user whether a note should go back into the skill itself, through the flow they use for it
— an issue, a pull request, an edit in the plugin's own repository. When you do not know that flow, ask.

What is worth noting, in this skill:

- The scripts' own `GLOBAL_CACHES`/`BUILD_DIRS`/`CANDIDATES` lists are a claim of completeness, and
  never edited directly — they are installed copies. **The edits worth making go into the config
  file**, `~/.config/dev-storage/config` (or `$DEV_STORAGE_CONFIG`): `DEV_STORAGE_EXTRA=<path or
  build-dir name>` per line to add, `DEV_STORAGE_SKIP=<path or name>` per line to leave alone. Every
  new tool installed on a machine arrives with storage nobody chose, and it will not be named `cache`.
  This skill has already been wrong once in exactly that way: the VM bundle was the single largest
  unexcluded consumer and was absent from the defaults until `report` surfaced it. When that happens,
  add the path to the config *and* say what class of thing it was, so the next gap is recognized
  before it costs gigabytes.
- The opposite failure is worse and quieter: **a path added that was not actually regenerable.**
  Nothing complains, the backup simply stops covering something that mattered, and it is discovered
  only when it is needed. Before adding a path to `DEV_STORAGE_EXTRA`, name the process that rebuilds
  that directory unasked. If you cannot name it, it does not belong there — propose it to the user
  instead.
- A run that produces a figure contradicting one already written into this skill or its reference is
  worth noting — a stale measurement in a document that exists to stop the wrong lever being pulled
  will eventually aim someone at the wrong lever.
- A gap that recurs across machines rather than on one is a workspace fact, not a skill fix — route it
  with `/route-learnings` instead of growing this file.
- **A path added to the config is read by `dev-storage.sh`; `tm-inventory.sh`'s own `CANDIDATES`
  list is separate and installed, not configurable the same way.** When a run adds a path to
  `DEV_STORAGE_EXTRA`, check whether `tm-inventory.sh`'s report should have found it too before
  closing — that gap is worth an upstream edit, since its list has no config-file override yet.
- If a run needed no edits, say so — a sweep where the list already covered everything is signal too.
