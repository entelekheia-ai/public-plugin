---
name: release-promote
description: Run the beta→stable promotion ceremony for a repo on the stable+beta channel policy — preconditions (forward-port ancestry, canaries green against @beta), the promotion PR, pre-mode exit, and post-promotion re-entry. Use when the maintainer decides a milestone means the accumulated beta channel should become the next stable release. Not for fixes — patches go straight to stable by policy.
argument-hint: "<repo-path>"
user-invocable: true
user_invocable: true
---

# /release-promote — promote the beta channel to stable

**Before starting, read your notes for this skill**, where they exist — `~/.agents/skill-notes/release-promote.md`,
then `.agents/skill-notes/release-promote.md`, then `.agents/skill-notes/release-promote.local.md`. Where
two disagree, the more specific one wins. They hold what earlier runs taught; see the last section for
how they are written.

Policy: `release:release-channels-adopt` inlines the channel policy this skill promotes against — read
its "The channel policy" section before first use (this skill works read alone even without that one
installed). Promotion is a **rare, deliberate event** triggered by a milestone the maintainer defines, not
by cadence. The maintainer merging the promotion PR *is* the human sign-off — this skill's job is to put
real evidence in front of that merge.

**A bug fix takes a different path.** Fixes land on `main` and release as stable patches directly (the
policy's escape hatch); the forward-port workflow carries them into `beta`. Stop here if that is what
brought you.

**This is an event skill.** Each promotion is its own ceremony against its own milestone; running this
again after the channel re-arms is not a repair of the last run, it correctly produces the next
promotion's own PR and its own evidence dossier.

## Step 0 — Preconditions (all must hold before any PR)

`cd` into the target repo by absolute path first.

1. **Forward-port ancestry** — beta must contain everything stable has, or this promotion regresses
   fixes:

   ```text
   git fetch origin
   git merge-base --is-ancestor origin/main origin/beta && echo OK || echo 'STOP: merge main into beta first'
   ```

2. **Canaries green against `@beta`** (library repos) — dispatch each consumer repo's canary workflow
   with `--channel beta` and wait for green; collect the run URLs. For an app repo, the equivalent is the
   maintainer's stated soak on the channel build; for a plugin, its self-checks.
3. **Changelog review** — read the accumulated `.changeset/*.md` files (they are the release notes about
   to be minted). Anything contract-breaking that was never declared is a red flag: write the missing
   changeset now, on the beta branch.

## Step 1 — Exit pre-release mode and version

On a branch cut from `beta`:

```text
npx changeset pre exit          # removes .changeset/pre.json
npx changeset version           # consumes changesets → final (non -beta.N) versions + changelogs
```

Then run whatever syncs versions living outside `package.json` (Cargo.toml, committed generated version
constants, the lockfile — the version-sync step `release:release-channels-adopt`'s Stage C installs, if it
is) and the repo's build + full test suite locally. Never tag past red — a failing or *hanging* test is a
stop, not a formality.

## Step 2 — The promotion PR

Open a PR from that branch into `main`. The PR body is the evidence dossier:

- the canary run URLs (green, against `beta`),
- the ancestry check output,
- the version diff summary (old stable → new stable, one number if the repo is lockstep),
- the milestone that triggered this promotion.

The maintainer merges it. Nobody else, nothing automatic.

## Step 3 — Release and re-arm

1. The merge to `main` drives the repo's stable release flow: the Version Packages PR, or your own
   dependency-ordered publish procedure — whatever Stage C of adoption installed; if the repo is still on
   manual publishing, run it now.
2. Verify: registry shows the new versions on the stable dist-tag; provenance attestations present;
   GitHub Release has real presentation copy in English, not a raw changelog dump.
3. **Re-arm the beta channel:** merge `main` back into `beta`, then on `beta`
   `npx changeset pre enter beta` and commit the new `.changeset/pre.json`. The channel is now
   accumulating toward the next milestone.
4. Flip/point consumer canaries back at both channels as configured (a canary matrix of
   `latest` + `beta` needs no change).

## Verify before reporting done

- [ ] Ancestry check ran and passed *before* the PR was opened.
- [ ] Every gate artifact in the PR body is a link to a real run, not a claim.
- [ ] Stable versions live on the registry; beta branch re-entered pre mode.
- [ ] No fix was smuggled through this ceremony that should have been a direct stable patch.

## ⟳ After every use: note what this run taught

**Never edit this file** — it is an installed copy, and the next update overwrites it without a word.
Write what the run taught to a notes file instead, one dated line per point, in the narrowest scope that
fits:

- **local** — `.agents/skill-notes/release-promote.local.md`, kept out of git (add `*.local.md` to that
  folder's ignore rules if it is not there yet). The default.
- **repo** — `.agents/skill-notes/release-promote.md`, committed, read by everyone who works in this
  repository.
- **user** — `~/.agents/skill-notes/release-promote.md`, true for you in every project.

Then ask the user whether a note should go back into the skill itself, through the flow they use for it
— an issue, a pull request, an edit in the plugin's own repository. When you do not know that flow, ask.

What is worth noting, in this skill:

- Step 1's ordering (`pre exit` before `version`, version-sync steps, the full test run) is the part most
  likely to need rewriting after a real promotion — note exactly what changed and why.
- A precondition in Step 0 that did not actually block the PR when it should have, or blocked one that was
  fine.
- Anything the evidence dossier in Step 2 was missing that the maintainer asked for before merging.

If a use produced no edits and no note, say so in the session — that is signal too.
