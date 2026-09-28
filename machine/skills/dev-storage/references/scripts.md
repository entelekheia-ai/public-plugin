# Storage policy for a development machine

A dev machine fills up with bytes that no one chose to keep: package caches, compiler output,
downloaded SDKs, simulator runtimes. All of it is regenerable, none of it is worth backing up, and
deleting it by hand is a chore that gets done once and then never again.

This directory holds the policy as a script rather than as prose, because a policy that has to be
remembered is a policy that decays.

**The commands below run from the skill folder** — the `${CLAUDE_SKILL_DIR}` SKILL.md names, which
resolves to wherever this skill is installed. `dev-storage/scripts/…` resolves only from one specific
parent folder, so a command copied verbatim from here can fail to find the script; SKILL.md's own
"Running it" section gives the braced, resolved form.

```sh
scripts/dev-storage.sh report              # where the disk went
scripts/dev-storage.sh exclude             # keep it out of Time Machine
scripts/dev-storage.sh reclaim             # delete it, then thin snapshots
scripts/dev-storage.sh reclaim --deep      # also drop builds untouched for 60 days
scripts/dev-storage.sh all                 # exclude + reclaim + report
```

`DEV_ROOT` selects the scan root; it defaults to `~/Development` as one example, and is meant to be
overridden to wherever projects actually live.

A read-only companion answers the other question — *what is Time Machine still carrying that it
should not?*

```sh
sudo scripts/tm-report.sh [output-file]     # writes a report, changes nothing
```

It never deletes and never edits an exclusion; it produces the evidence you read before running
`exclude`. The backup-side sections (enumerating backups, and `tmutil compare` for a file-level list
of what changed since the last one) need **Full Disk Access**, which macOS grants per application
rather than per user — so `sudo` alone may not lift it, and the report says so in place rather than
failing. The source-side sections work regardless, and those are what determine what enters the
backup from here on.

It runs in six phases with progress on screen, and two facts about macOS shape how:

- **`tmutil isexcluded` took 45 seconds for a single path here.** It is the obvious tool — it knows
  every exclusion mechanism and inherits to children — and calling it per candidate is what made
  the first version of the report appear to hang. Reading the exclusion state locally costs ~1.4ms.
- **There are two exclusion mechanisms, and reading one gives a confidently wrong answer.** Plain
  `tmutil addexclusion` sets an xattr — Apple's *sticky*, location-independent kind, which follows
  the item when moved and is inherited by copies. `tmutil addexclusion -p` instead records a
  *fixed-path* entry in `SkipPaths` in the Time Machine plist, which excludes whatever sits at that
  path. Neither list contains the other. Measured once: a large directory excluded only via
  `SkipPaths` and another excluded only via the xattr; a check that read either alone would have
  reported one of them as unprotected.

**Spotlight was the wrong instrument for both whole-machine questions, and has been dropped.** It
looked ideal — one query instead of one process per candidate — but `mdfind` indexes **no dotfiles at
all** and returns **zero** exclusions under `~/Library`, which is where they actually are. It is also
per-user, so under `sudo` it queries root's index. Every one of those failures returns an empty
result rather than an error. Both questions are now answered directly: a batched
`find -maxdepth 5 -type d -exec xattr -p … {} +` finds every exclusion in seconds, and `find -mtime`
fanned across cores finds what changed.

Two traps in the tools themselves:

- **macOS `du` reports 512-byte blocks unless given `-k`.** Every figure comes out exactly doubled,
  which reads as entirely plausible. Every script here passes `-k`.
- **`xattr -p` given a single path prints the bare value with no path prefix.** In a batched scan
  that means whichever directory lands alone in the final batch parses as garbage and vanishes from
  the list. Passing `/` as a sentinel first argument guarantees the prefixed form.

## Rank by what changed, not by what exists

The report orders candidates by **bytes changed in the window**, and this is not a refinement of
ordering by size — it is a different answer. A static 100 GB directory is copied once and then costs
nothing; a 1 GB cache rebuilt nightly costs every night. Measured once: the largest directory by size
changed almost nothing, while a directory far down the size list was the most expensive one to back up.

Two things follow for anyone reading the output:

- **`SIZE` is gross and `CHANGED` is net.** Sizes include already-excluded children because `du`
  cannot prune; churn has them pruned out. Counting them was not a rounding error — it put a large directory
  at the top of the list on the strength of an already-excluded child.
- **`CHANGED = ?` means unknown, not zero.** That walk hit `SIZE_TIMEOUT`. Those rows sort to the top
  deliberately; re-run with a larger `SIZE_TIMEOUT` instead of drawing a conclusion.

## What was already spent

**An exclusion only applies to future backups.** Everything excluded today is still sitting in every
backup taken before today, and no amount of excluding will remove it. That is a separate question
with a separate tool:

```sh
sudo scripts/tm-inventory.sh              # what regenerable junk is inside the backup
sudo DEEP=1 scripts/tm-inventory.sh       # also walk the tree for what the list missed
```

`DEEP` must come after `sudo`, not before — macOS's default sudoers has `env_reset`, which strips
`DEEP=1 sudo ...` before the script ever sees it.

Also read-only. It never deletes and never runs `tmutil delete`; it prints the commands for a human
to review, because removing something from a backup is irreversible.

Two `tmutil` subcommands carry its design, and both are easy to miss:

- **`tmutil uniquesize <path>`** — the space a path occupies that is *not* shared with other backups,
  which is what deleting it would actually free. This matters because backups on an APFS destination
  are snapshots sharing blocks: `du` across them counts the same block once per backup and overstates
  wildly. Any tool that reports backup usage with `du` is lying.
- **`tmutil delete -p <path>`** — removes one path from the backup history without deleting whole
  backups. That is what makes "drop the browser cache out of my history, keep the history" possible.

### Why size is the wrong axis, and what replaces it

On an APFS destination **Time Machine copies only the changed blocks of a changed file**, not the
whole file — and it finds them through FSEvents. So the cost of a directory is not its size, and not
even its changed bytes:

| Pattern | Delta helps? | Real cost |
|---|---|---|
| Large file modified **in place** (VM image, database) | A lot | only the changed blocks |
| Large file **replaced** by a new one (a downloaded model) | Not at all | full copy, retained in history |
| Many small files **rebuilt** (package caches) | Not at all — they are new files | full copy of all of them |
| Many small files, stable | — | ~nothing |

The axis is therefore **replaced versus modified in place**, not large versus small. A rotating
library of model weights is the worst case there is: every swap is a new file, delta buys nothing,
and each one is retained. A 5 GB VM image rewritten daily is nearly the cheapest.

## The trap this exists to close

**On APFS, deleting a cache frees nothing while a Time Machine local snapshot still references its
blocks.** macOS takes an hourly local snapshot and keeps roughly a day of them, so a cleanup done in
the morning is invisible until the evening — `df` reports the same number it did before, and the
obvious conclusion is that the cleanup did not work.

Measured once: removing tens of gigabytes of Xcode device support, DerivedData, and package caches
moved free space by **zero bytes**. Same-day snapshots were holding every block. Thinning them
released the space at once — a large jump in a single step.

Two consequences, both encoded in the script:

- `reclaim` always ends by thinning snapshots. The deletion is the setup; the thin is the payoff.
- `exclude` is the actual fix, because a directory Time Machine never captures never pins anything.

`tmutil thinlocalsnapshots` does not need `sudo` for local snapshots.

## What is excluded, and why that is safe

Two groups, both regenerable by the tool that owns them. Only regenerable *subfolders* are named —
never an application root that also holds non-regenerable state (a browser profile, editor settings,
an Xcode Archive) beside its cache:

| Group | Paths |
|---|---|
| Global caches | `~/Library/Developer/Xcode/DerivedData`, `~/Library/Developer/Xcode/iOS DeviceSupport`, `~/Library/Caches`, `~/Library/pnpm/store`, `~/.npm`, `~/.bun`, `~/.cache`, `~/.rustup`, `~/.cargo/{registry,git}`, `~/go/pkg`, `~/.local/pipx`, `~/.local/share/claude` (Claude Code self-updater), plus whatever a `~/.config/dev-storage/config` or `DEV_STORAGE_EXTRA` names for this machine |
| Build output under `DEV_ROOT` | `node_modules`, `target`, `.next`, `.turbo`, `.vite`, `release`, `out`, `coverage`, `dist`, `__pycache__` — but a name match alone never qualifies one: it must also sit inside a git repository whose own `.gitignore` covers it (`git check-ignore`) |

Source code is never excluded — only what a build produces from it, and only once the repository's
own ignore rules agree it is build output. A folder named `release`, `out`, `dist` or `coverage` that
is *tracked* (not ignored) is source, never touched. A repository's `.git` is backed up normally, so
history is never at risk.

**A build directory's staleness is judged by the newest file inside it, never by the folder's own
mtime.** A directory's mtime changes only when an entry is added or removed at its top level, so an
actively-edited tree with an old top-level mtime would otherwise read as abandoned.

**`~/Library/Developer`, a whole browser's `Application Support/<vendor>` folder, and
`Application Support/Code` as a whole are deliberately not in the list.** The first also holds
`Xcode/Archives` (never regenerable); the second mixes a browser's cache with its profile, history and
passwords, and its actual cache already lives under `~/Library/Caches` instead; the third holds
`Code/User` (settings, keybindings, snippets). Naming the parent would silently drop the
non-regenerable half from every future backup.

**Exclusions are per-path and do not apply to directories created later.** Re-run `exclude` after
cloning a repository or after the first install in a new package. It is idempotent.

## What the script deliberately will not do

`reclaim` deletes only caches whose owner rebuilds them without being asked. Build directories are
*reported* when stale but removed only under `--deep`, because "untouched for 60 days" is a good
heuristic and not a guarantee — a release branch you have not checked out this quarter looks
identical to an abandoned experiment.

The bun cache is the one conditional case. Bun has no prune command, so its cache only grows; the
script drops it entirely when no `bun.lock` exists anywhere under `DEV_ROOT`, and leaves it alone
otherwise. This is not hypothetical — measured once, that cache grew to several gigabytes on a
machine where every repository resolved through `package-lock.json` instead.

Out of scope on purpose, because none of it is regenerable and all of it is a judgment call: cloud
storage placeholders, media libraries, `~/Downloads`, and application data such as VM bundles.
`report` will show you the disk; what to do about your own files is not a script's decision.

## Suggested cadence

- `exclude` — after cloning a repo or adding a workspace package.
- `reclaim` — monthly, or whenever free space gets uncomfortable.
- `reclaim --deep` — quarterly, after glancing at what it lists.

## sudo and system state

- `dev-storage.sh exclude` and `dev-storage.sh reclaim` need no `sudo` and change system state: they
  add Time Machine exclusions and delete cache directories and local snapshots.
- `tm-report.sh` and `tm-inventory.sh` are read-only and change nothing; run with `sudo` only to read
  the backup-side sections, which additionally need Full Disk Access granted to the terminal.
