---
name: release-channels-adopt
description: Install a stable+beta release-channel policy into a target repo, by repo type — declaration layer + changesets config for a package publisher, registry canary CI for a consumer, gate definition for an app or plugin. Use when bringing a JS/TS repository onto a stable+beta channel policy, or when repairing a partial adoption. Repo-neutral — the target repo and its type are arguments, never assumptions.
argument-hint: "<repo-path> [publisher|consumer|app|plugin]"
user-invocable: true
user_invocable: true
---

# /release-channels-adopt — bring a repo onto the channel policy

**Before starting, read your notes for this skill**, where they exist — `~/.agents/skill-notes/release-channels-adopt.md`,
then `.agents/skill-notes/release-channels-adopt.md`, then `.agents/skill-notes/release-channels-adopt.local.md`.
Where two disagree, the more specific one wins. They hold what earlier runs taught; see the last section
for how they are written.

This skill installs the channel policy below into a target repo. In one line: a stable channel and a
persistent beta channel; contract/behavior changes pass through beta, fixes go straight to stable; a
forward-port guarantee keeps beta ahead of stable; the promotion gate is real signal (consumer canaries,
maintainer soak), never "was published to the channel". The full policy is inlined in its own section
below — read it before first use. `release:release-promote` and `release:release-first-publish` (this
plugin's other two skills, optional, named here only as `release:<skill>`) point back at that section
rather than repeating it.

This skill installs the *layer that matches the repo's role*. A repo can have more than one role (a
publisher is usually also a consumer of its own dogfood examples) — install each applicable layer.

**This is a target-state skill.** There is a correct set of layers for a repo's role, and running this
again against a repo that already has some of them installed is a repair — it adds the missing layer
rather than duplicating what is already there.

## The channel policy

- **Channels.** A stable channel (npm `latest`, or an app's own stable line) and a persistent **beta**
  channel. A third, ad-hoc tier serves experiments — snapshot releases (`0.0.0-<tag>-<timestamp>` under a
  dist-tag nobody installs by default) rather than a long-lived alpha branch. The policy minimum is stable
  plus beta; a repo type with a real audience for a third channel (desktop auto-update) may keep one.
- **What passes through beta.** Contract- or behavior-changing work goes through the beta channel first;
  fixes go straight to stable. Phrased without semver labels so it survives a 0.x → 1.x transition.
- **Forward-port guarantee.** A fix that lands on stable must reach beta before the next promotion, or the
  promotion regresses the fix. Enforce it mechanically — an automatic merge-back (each push to the stable
  branch opens or updates a PR merging it into beta; a conflict turns the PR red and visible) — never by
  memory.
- **Promotion.** A deliberate, rare event: a PR from beta into stable, merged only by the maintainer, with
  gate evidence in front of them. No fixed cadence — cadence measures user exposure a small project does
  not have.
- **The gate has content per repo type**, because landing on a channel proves nothing by itself:

  | Repo type | Promotion gate |
  |---|---|
  | Library | Consumer canary CI green against the registry's `@beta` artifacts |
  | App | Maintainer dogfooding the channel build (soak) plus end-to-end checks |
  | Plugin / tooling | Self-check scripts plus real use across the repos that depend on it |

- **Change intent is declared when the change is made, not at release time.** A `.changeset/*.md` file
  written at PR time, when the context is fresh, authored by a human or an agent — changesets does not
  parse commit messages. Enforcement is mechanical: a CI check (`changeset status --since <base>`) or the
  changeset-bot. A release-closing step may act as a backstop, verifying a changeset exists for
  contract-affecting work and writing one if missing, but it is never the primary author. The generated
  changelog replaces any hand-written one.

## Step 0 — Identify target and type

1. **Target repo path** — from the argument, else ask. `cd` into it by absolute path before any git/npm
   command — operate on the target repo by absolute path throughout.
2. **Type** — from the argument, else infer and confirm:
   - **publisher** — publishes packages to a registry (npm/crates/marketplace).
   - **consumer** — depends on another repository's *published* packages (check for `file:` links or
     registry deps on scopes another repository publishes).
   - **app** — ships a runnable artifact to end users (Electron app, deployed site).
   - **plugin** — tooling consumed by the maintainer's own sessions (e.g. a Claude Code plugin).
   **Classify by what the repo does today, never by what it is expected to become.** A repo-type table can
   list a repo under Library because it is intended to be consumed by another project someday. But if it
   has no remote, no registry presence and no current consumer, every ingredient of the Library gate is
   missing, and the App layer is what actually fits. A repo whose future type is written down will be
   mis-routed by anyone reading that table as current state.
3. Read the target repo's own `AGENTS.md` / governance before writing anything — its conventions win over
   this skill's defaults.

## Publisher layer (npm) — declaration first, automation later

Install in stages; each stage is independently valuable. **Stage A never changes how the repo publishes
today** — manual flows continue while `.changeset` files accumulate.

**On a greenfield repo, Stage A installs but cannot be verified.** `changeset status` resolves the base
branch through the remote and fails with *"Failed to find where HEAD diverged from main"* when the repo
has no commits or no remote — so the enforcement check below is written but unproven, and the checklist's
verification against an existing wrong commit is deferred rather than passed, for lack of any commit to
point it at. Say so; do not report the gate as working. Re-run the verification at the first push.

**Stage A — declaration layer:**

1. `npm install --save-dev @changesets/cli` (pin the stable 2.x line, not `3.0.0-next`) and
   `npx changeset init`.
2. Edit `.changeset/config.json`:
   - `access: "public"` (if packages are public);
   - `fixed`: one group of all the repo's lockstep-published packages, if the repo's policy is one
     platform version (a monorepo releasing a set of packages in lockstep, for example). **A plugin
     architecture inverts this default** — a
     plugin whose version is chained to the core can be released only by whoever owns the core, so a repo
     whose whole premise is third-party extensions omits the `fixed` group entirely;
   - `ignore`: packages released on their own track (e.g. a VS Code extension not on registry pins).
3. Adopt the habit: every PR that changes a published package's contract carries a `.changeset/*.md`.
   Changesets does **not** read commit messages — the file is authored at PR time, by the human or the
   agent working the PR.
4. Enforcement: a CI check that fails a PR touching package sources without a changeset
   (`npx changeset status --since origin/main`), or the changeset-bot. **Verify it with a commit that is
   already wrong** rather than a synthetic PR. A repo adopting Stage A usually has recent commits that
   touched a package without declaring anything, and the gate going red on one of those, then green once
   a changeset covers it, is the same evidence for none of the setup.
   **Stage the changeset before reading the result** — `changeset status --since` resolves through git, so
   an untracked file reports as no changeset at all, in the words used for having written none: *"Some
   packages have been changed but no changesets were found. Run `changeset add` to resolve this error."*
   It reads as *the file I just wrote is malformed*, and neither `--help` nor the README mentions git. CI
   never sees it, because everything there is committed — only the local check before a commit does.
5. Migrate `CHANGELOG.md` files to the changesets-generated format outright (collapse prior history to a
   summary line; no adapter preserving the old format).
   **First establish that the `CHANGELOG.md` is even in scope.** A repo can ship more than one product
   from one tree, and only the npm workspaces are changesets' business — a root `CHANGELOG.md` that belongs
   to a product living outside `workspaces` is never touched by `changeset version`, so this step is empty
   for it and there is no changelog to migrate. Say that explicitly in the repo's governance. A reader who
   finds an unconverted `CHANGELOG.md` beside a `.changeset/` directory will otherwise read it as an
   adoption that was abandoned halfway.

**Stage B — beta channel** (requires Stage A): create the long-lived `beta` branch; on it,
`npx changeset pre enter beta` and commit `.changeset/pre.json`. Add the forward-port workflow: on every
push to `main`, open/update a PR merging `main` into `beta` (a conflict = red, visible PR). Clean up any
fossil dist-tags (needs local `npm login` — OIDC covers only `npm publish`).

**Stage C — automated stable flow** (at a natural release moment): `changesets/action` (stable v1.x)
opening the Version Packages PR; `version-script` syncing any versions living outside `package.json`
(Cargo.toml, committed generated constants, lockfile); `publish-script` publishing **in dependency order**
if the repo uses exact pins (plain `changeset publish` is concurrent and order-blind) — and, between one
publish and the next, waiting for the published package to answer on the registry
(`npm view <name>@<version> version`, retried for a few minutes) before publishing whatever depends on it,
since a dependent published before its dependency's packument has propagated fails `npm install` in that
window; retire per-package tag workflows and re-point registry Trusted Publishers at the new workflow
file. Provenance under OIDC from a public repo is automatic — no `--provenance` flag needed.

## Consumer layer — registry canary

The point: test the **published artifact**, not the workspace symlink — packaging defects (missing files,
scheme leaks) are invisible through `file:` links.

1. **Write a swap script** in the target repo (`scripts/canary-install.mjs` or similar — this skill does
   not ship one, the target repo owns it). Its contract: a `--channel <latest|beta>` flag; it replaces the
   repo's `file:` links to another repository's published packages with registry installs at the given dist-tag, then
   runs `npm install`; and it is reversible — run it only in a throwaway checkout (CI), never against the
   maintainer's working copy.
2. A workflow, scheduled + `workflow_dispatch`, that runs the swap and then the repo's **existing** test
   suite. It starts on `--channel latest`; flip (or matrix) to `beta` once the publisher's beta channel
   exists.
3. The canary lives in the consumer repo — no cross-repo tokens. Before a promotion, the maintainer
   dispatches it manually and links the green run in the promotion PR.

## App layer — gate definition

Apps don't have downstream suites; the maintainer *is* the channel's user. Install the discipline, not
CI: document in the repo's governance (a) which channel the maintainer runs day-to-day (that soak is the
gate), (b) the forward-port rule between its release channels, (c) change-intent declaration feeding the
app changelog (same `.changeset` file format works even without npm publishing).

**(a) and (b) assume the app already has more than one channel** — they were written for an app that
already ships side-by-side channel builds. An app with a **single line of work** (no beta build, nothing published, often
no remote) cannot answer either, and inventing a channel to have one to document is the wrong outcome.
There, the App layer reduces to (c) alone, and the honest governance line is that the repo has one channel
and no soak gate *yet*. Say that explicitly rather than leaving the reader to wonder which two thirds of
this layer were skipped. Revisit (a) and (b) when a second channel actually exists.

**Configuration for the non-publishing case**, which the Publisher-layer Stage A above does not cover:
take `changeset init`'s output and remove nothing — `access`, `fixed`, `linked` and `ignore` are all inert
with one unpublished package. Two facts about private packages, both counter-intuitive and both worth
verifying rather than assuming, since either one, taken on faith, produces a wrong write-up:

- **A `"private": true` package is versioned and changelogged by default.** No configuration is required.
  `@changesets/config` (verified at 2.31.1) resolves `privatePackages` to `{ version: true, tag: false }`
  when the key is absent — read it in `node_modules/@changesets/config/dist/changesets-config.cjs.js`,
  the `const privatePackages =` branch, whose final `else` is those two values; a throwaway private package
  on the stock `changeset init` config went `1.0.0 → 1.1.0` with a `CHANGELOG.md`. Writing that block out explicitly is a *pin*, not a fix — fine to do, but do not
  justify it as one.
- **`privatePackages: false` is the setting that breaks this case**, disabling versioning and tagging
  together. That is the one to avoid, not the one to add.

**Adoption is complete only once `changeset version` has run** — until then `.changeset/*.md` files
accumulate and no `CHANGELOG.md` exists, which looks identical to a broken install. Either run it for real
at the first change worth recording, or state in the repo's governance that it has never been run and that
the missing `CHANGELOG.md` is expected. **Adopting before the first release is strictly cheaper**: Stage
A's changelog-migration step disappears entirely, because there is no prior history to collapse.

## Plugin layer — self-check gate

The gate is the plugin's own check scripts plus real use across the other repos. Install: change-intent
declaration + a pre-release checklist item "used in anger since last release?".

**A Claude Code plugin keeps its version in `.claude-plugin/plugin.json` and in its marketplace entry, and
changesets bumps only `package.json`.** Give each plugin folder a `"private": true` `package.json` that
holds the version, list the folders as npm `workspaces`, and chain a sync script after `changeset version`
that copies each version into both manifests. Done this way in a catalog repository of several small
plugins; verified against `claude plugin validate --strict` on the synced manifests.

## Verify before reporting done

- [ ] The installed layer matches the repo's actual role(s); nothing installed "for later".
- [ ] Publisher Stage A: an existing commit that touched a package without declaring anything goes red;
      once a changeset covers it, green.
- [ ] Consumer: canary run green against `latest`, and its logs prove registry tarballs (not `file:`).
- [ ] Target repo's `AGENTS.md` updated to name the new layer (its own convention for where).
- [ ] Nothing here contradicted the target repo's own governance; where it did, the repo won and this
      skill gets a note below.

## ⟳ After every use: note what this run taught

**Never edit this file** — it is an installed copy, and the next update overwrites it without a word.
Write what the run taught to a notes file instead, one dated line per point, in the narrowest scope that
fits:

- **local** — `.agents/skill-notes/release-channels-adopt.local.md`, kept out of git (add `*.local.md` to
  that folder's ignore rules if it is not there yet). The default.
- **repo** — `.agents/skill-notes/release-channels-adopt.md`, committed, read by everyone who works in this
  repository.
- **user** — `~/.agents/skill-notes/release-channels-adopt.md`, true for you in every project.

Then ask the user whether a note should go back into the skill itself, through the flow they use for it
— an issue, a pull request, an edit in the plugin's own repository. When you do not know that flow, ask.

What is worth noting, in this skill:

- A missing step, a wrong default, or a repo shape this skill didn't fit — the adoption stages above are
  a target state, and a real repo is where the gaps show up.
- A repo-type call that was harder than the table above suggests, and which signal actually settled it.
- A false claim about changesets' own behavior that a run disproved (or confirmed) by reading its source
  or reproducing the error, so the next run does not re-derive it from scratch.

If a use produced no edits and no note, say so in the session — that is signal too.
