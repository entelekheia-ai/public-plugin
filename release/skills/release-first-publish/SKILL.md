---
name: release-first-publish
description: Take a repository from never-published to publishing itself from CI through npm trusted publishing — the debut publish that no automation can perform, the trusted-publisher declarations, and the release workflow that replaces both. Use when a repo's packages have never reached a registry, when a publish fails with a 404 or ENEEDAUTH or "OIDC permission denied" that names nothing, when a monorepo's packages must reach npm in an order, or when a repo still publishes with a stored NPM_TOKEN and should not. Repo-neutral — the target repo is an argument, never an assumption.
argument-hint: "<repo-path>"
user-invocable: true
user_invocable: true
---

# /release-first-publish — from never-published to publishing itself

**Before starting, read your notes for this skill**, where they exist — `~/.agents/skill-notes/release-first-publish.md`,
then `.agents/skill-notes/release-first-publish.md`, then `.agents/skill-notes/release-first-publish.local.md`.
Where two disagree, the more specific one wins. They hold what earlier runs taught; see the last section
for how they are written.

The channel *policy* is installed by `release:release-channels-adopt` and promoted by
`release:release-promote` — this plugin's other two skills, named only as `release:<skill>`, both
optional. This skill works read alone even without either installed. It covers the one moment neither
can: **the debut.** A trusted publisher is declared on a package that
already exists, so the first version of every package is published by a human at a terminal, and the
automation only becomes possible afterwards. Everything here exists because that ordering is inverted
from how it reads.

Working model of trusted publishing, in one line: the workflow proves its identity to npm with a
short-lived OIDC token GitHub mints for the run, npm compares the token's claims against a declaration
you made on npmjs.com, and **no token is stored anywhere**.

**This is a target-state skill.** There is a correct end state — every package published at least
once, a trusted publisher declared for each, a workflow that releases without a stored token — and
running this again against a repository already there finds nothing left to debut, which is a
repair converging to nothing, never a duplicate. One moment inside that convergence breaks the
pattern: the debut `npm publish` for each package happens exactly once and cannot be undone, so
Step 2 is a one-shot act nested inside an otherwise repeatable procedure.

> ⚠️ A step here is only as good as the last run that met the registry. **Read `npm help <cmd>` before
> writing a step, never `npm <cmd> --help`** — the flag prints a usage block and the man page carries the
> preconditions, the account requirements and the rate limits, and a step written off the usage block
> states a mechanism it inferred from a symptom. Pay the closing **note what this run taught** clause
> every time.

## Step 0 — The six preconditions npm never checks

npm validates none of these when you save a trusted publisher, and the errors they produce name none of
them. Check all six before writing anything; each one is a run that fails for a reason you will not find
by reading the failure.

| # | Precondition | How to check | If it fails |
|---|---|---|---|
| 1 | **The repository is public** | `gh repo view <owner>/<repo> --json visibility` | A private repo answers `E403 OIDC permission denied for this action` no matter how right everything else is — every claim matching the trusted publisher, Node 24, `registry-url` set — and the message names neither visibility nor a claim, so the search goes to the publisher form, Node and `.npmrc` instead. Make it public, or publish with a granular npm token stored as the `NPM_TOKEN` secret (which `changesets/action` picks up) and stop here. |
| 2 | **Every package declares `repository.url` matching the GitHub repo** | `--json` output of `publish-order.mjs`, or read the manifests | npm refuses the OIDC publish. This is the most common cause of the "404 that lies". |
| 3 | **No dependency cycle among the packages** | `node publish-order.mjs <repo>` | Every order publishes one member before its dependency, so that member sits on npm un-installable until the cycle's last package lands. Workspaces hide this by symlink through every local build and test. Break each cycle **in code** — extract the shared piece, or move the weaker edge to a dynamic load. |
| 4 | **The scope exists and you can publish to it** | `npm org ls <scope>` or `npm access list packages <scope>` | A scope you do not own fails at the first publish, after you have already versioned everything. |
| 5 | **Node ≥ 22.14 and npm ≥ 11.5.1**, in CI *and* at your terminal | `node -v && npm -v` | Below either, the OIDC exchange never happens and npm reports a 404. Pin `node-version: '24'` in the workflow. |
| 6 | **The debut version is decided** | ask | `0.0.1` placeholders that were never published are not a version choice. Decide before publishing; a published version cannot be recalled. |
| 7 | **What each package ships is what you think it ships** | `npm pack --dry-run --json` per package | Reading `files` answers a different question: npm adds `package.json`, `README` and the licence whatever `files` says, and drops what `.npmignore` or a nested `.gitignore` excludes. A tarball short a `dist/` publishes green and fails at the consumer's first import, and a published version can only be superseded. The command returns one JSON object per package with `files[].path` — the tarball's real manifest. Its `--help` describes `--json` as "output JSON data, rather than the normal output" and never says the output is that manifest, so the capability stays invisible to whoever reads the help looking for it. **Any tool that needs to know whether a file is published shells out to this** rather than re-implementing `files` plus `.npmignore` plus npm's always-include set — a re-implementation is wrong in some corner, and wrong in the direction that says a missing file ships. |

Then read the target repo's own `AGENTS.md` and governance. Its conventions win over this skill's defaults.

## Step 1 — Version the debut, then publish

**If you use changesets** — `release:release-channels-adopt` sets it up before the debut (its Stage A), so
the debut is the last release that is not reproducible. Two defaults are easy to get backwards there:

- `changeset init`'s output needs **no** `privatePackages` block. Changesets versions private packages by
  default (`{version: true, tag: false}`); the config that breaks the case is `privatePackages: false`.
- `fixed` groups the packages that release in lockstep. A repo whose premise is third-party extensions
  takes **no** `fixed` group — a plugin chained to the core cannot be released by anyone who does not own
  the core.

Set the debut version by writing one changeset covering every package (`major`/`minor` as decided in
precondition 6), running `npx changeset version`, and committing. The versions in the manifests are now
the versions you are about to publish, and the CHANGELOG is generated rather than hand-written.

**Otherwise — a repository that versions by hand** — decide the debut version directly (precondition 6),
write it into every package's `package.json` yourself, and commit a first `CHANGELOG.md` entry by hand.
Nothing past this point depends on changesets: `publish-order.mjs` and the debut loop in Step 2 read
`package.json`, not `.changeset/`. A public trusted-publishing skill or npm's own trusted-publishing docs
cover the equivalent of this step for a single-package repo that never needed a monorepo tool at all —
reach for one of those instead where changesets is more machinery than the repo needs.

## Step 2 — The debut publish, from a terminal, in dependency order

**Only a human can do this**, and `npm login` is not the whole of it. An account with 2FA enforced on
publish answers `EOTP: This operation requires a one-time password` at the first package — `npm whoami`
still succeeds, which is why the wall arrives later than expected.

**Ask which second factor the account carries before planning the run**, because it decides who can run
the loop at all. Where the factor is a code from an authenticator app, `--otp=` takes it, and **one code
covers the whole run**: npm honours a code for a short window, and prompting per package outlives the
code the run started with. Where the factor is a passkey or a security key (WebAuthn, Touch ID), **there
is no code and `--otp=` has nothing to carry** — npm prints a browser URL and waits for a confirmation
only the person present can give. That account's whole loop runs in the maintainer's own interactive
terminal: the agent prepares, verifies and hands over the command, the maintainer runs it and pastes the
output back.

```sh
cd <repo> && npm login          # maintainer, interactive, 2FA
npm run build && npm test       # the debut passes the same gates every later release will

# The order is not alphabetical and not the workspace order. npm publish validates nothing about
# dependencies — it is the window between publishes that must stay installable, for consumers and
# for this workflow's own next `npm ci`.
node <skill-dir>/publish-order.mjs . --paths | while read -r dir; do
  ( cd "$dir" && npm publish --access public ) || break
done
```

`--access public` is required on the first publish of a **scoped** package; without it npm defaults to
restricted and a paid plan. It is harmless afterwards.

**A package meant to be globally installed (a CLI) needs every same-scope dependency bundled.**
`npm i -g` cannot hoist, so a dependency under the same `@scope` that is missing from
`bundleDependencies` is never extracted, and every command dies on `Cannot find package`. Declare
`bundleDependencies` for each same-scope dependency before the debut, and confirm locally with
`npm i --install-strategy=nested` rather than trusting a workspace-local `npm ci`, which hides the
gap by symlink. Bundle all of a scope or none of it: the bundled tree already occupies
`node_modules/<scope>/`, so where npm cannot hoist it treats that directory as materialised and extracts
neither half. The global install usually fails first with `node-gyp-build: command not found` from a
native dependency's install script, which sends the search toward node-gyp and away from the cause; the
tell is bundled packages arriving intact while the regular same-scope ones hold nothing but a
`node_modules/`.

**GitHub Packages is not a fallback registry for an arbitrary scope.** `npm.pkg.github.com` accepts an
npm package only when its scope equals the repository owner's login — `@acme/x` from the org `acme-org` is
refused with `E403 … Permission permission_denied: The requested installation does not exist`, with the
right token and `packages: write` granted. The message reads as an auth problem; the fix
is a different package name for every consumer, so compare scope and owner before choosing it.

**A partial failure is normal and safe to resume.** The loop stops at the first failure; the packages
already published stay published. Fix the cause, re-run the loop — `npm publish` on a version that
already exists fails with `E403 cannot publish over previously published version`, which is the loop
skipping what is done, not a new problem. Never bump a version to get past it: that publishes a version
whose content nobody reviewed.

Verify before moving on, rather than reading the loop's output. **Check the packument, not only the
version document** — the two propagate separately. For several minutes after a publish,
`registry.npmjs.org/<name>/<version>` answers 200 with a real tarball while `registry.npmjs.org/<name>`
is still 404, and `npm install` fails for everyone, the publisher included. A check that reads only the
version document reports a green debut nobody can install yet.

**And check every package, every time — propagation is per package and finishes out of order.** A watcher
polling one package goes green while a sibling published in the same run has not landed, so the install
that follows dies on the sibling and the retry minutes later succeeds with nothing else changed. Sampling
one of N is not a reading of N; the loop below is cheap, so run the whole list:

```sh
node <skill-dir>/publish-order.mjs . --json \
  | node -e 'const p=JSON.parse(require("fs").readFileSync(0));(async()=>{for(const{name,version}of p){
      const v=await fetch(`https://registry.npmjs.org/${name}/${version}`);
      const k=await fetch(`https://registry.npmjs.org/${name}`);
      console.log(v.ok&&k.ok?"ok   ":v.ok?"wait ":"MISS ",name,version,
        v.ok&&!k.ok?"— published; packument still propagating, npm install fails until it lands":"")}})()'
```

## Step 3 — Declare one trusted publisher per package

Now the packages exist, so the declaration is possible. **Use `npm trust`, not the website** — npm 11 ships
the whole operation as a command, so N packages is a shell loop rather than N forms:

```sh
npm trust github <package> --file release.yml --repo <owner>/<repo> \
  --allow-publish --allow-stage-publish -y
npm trust list <package>          # read it back
```

**That loop belongs to whoever holds the second factor, and a logged-in terminal is not enough.** Two
conditions gate `npm trust` before any flag does, and `npm help trust` states both: 2FA **must** be
enabled on the account — enable it if it is not, or trust commands are unavailable — and a granular
access token carrying the bypass-2FA option does not work. Every subcommand is gated, `list` included:
a read answers `EOTP` and a browser URL.

**The first request opens the browser flow, and the npm website then offers to skip 2FA for the next
five minutes.** Taking that offer is what lets a bulk run proceed unprompted — roughly eighty packages
per window with a two-second sleep between calls, which npm recommends against rate limiting. A run that
does not take it pays one confirmation per command. `--otp=` is absent from the trust usage entirely, so
an account whose factor is a passkey has nothing to pass and the whole loop belongs in the maintainer's
own terminal. `--dry-run` prints what would be created and is worth one call before the loop.

Four fields decide the declaration, and none is validated against reality on save:

| Field | Flag | The trap |
|---|---|---|
| Organization and repository | `--repo <owner>/<repo>` | the GitHub owner, not the npm scope — they differ more often than not |
| Workflow filename | `--file release.yml` | **filename only**, with the extension, no `.github/workflows/` path. The file must already exist on the default branch. |
| Environment | `--env` | omit it. Pass it **only** if the job declares `environment:`; a value the job does not carry fails every run. |
| Allowed actions | `--allow-publish` | **without this flag the connection permits only `npm stage publish`**, and a workflow running plain `npm publish` — the shape in Step 4 — is refused by a declaration that reads as correct. Omit it deliberately if the repo wants staged publishing, which is the stronger posture (a maintainer approves each release with 2FA) at the cost of a manual step per release, and change the workflow to match. |

**Read every declaration back before reporting done.** `npm trust list` is one call per package and the
loop can do it; a wrong field is otherwise silent until a release fails weeks later. **Budget the read-back
into the handover, never as an agent's own step** — it is gated by the same second factor as the
declaration it reads, so on a passkey account it costs another pass through the maintainer's terminal.
**One authentication covers the whole run when the skip window is taken**, so reading back every package
costs what reading back three costs — read them all.

**Pick which packages to read back first from provenance, which costs no login at all.** npm attests a
version only when CI published it, so fetching each version document off the registry separates *debuted
from a terminal* from *released by the workflow*. A package with no attested version has never exercised
its declaration — the one place a missing declaration could hide. **It orders the read-back and never
replaces it.** The ordinary reason a package has no attested version is that no changeset has bumped it
since its debut, so rule that out first: a package the workflow was never asked to publish proves nothing
about its declaration.

**The website is the fallback, and it costs far more.** Through npmjs.com → the package → **Settings** →
**Trusted Publisher**, each save is gated by the account's second factor, and where that factor is a
security key (WebAuthn, Touch ID, a passkey) only the person present can answer it — so the run becomes N
handovers rather than one loop, with an agent filling forms in between. Each package is its own form and
its own confirmation, so the browser's cost grows with the package count while the command's stays flat.
Reach for the browser only where `npm trust` is unavailable — npm older than 11, or a registry that does
not implement it.

## Step 4 — The release workflow

**Read [`references/release-workflow.md`](references/release-workflow.md) now, and write the repository's
`release.yml` from it.** It holds the workflow's shape and the five things that shape gets right against
the npm docs. It also holds the two traps in deriving "did this run release": poll npm rather than asking
once, and read the version from `$GITHUB_SHA`, only when no changeset is pending. Name the file what the
trusted publisher declared in Step 3, and point `publish:` at the dependency-order loop from Step 2.

Once a release has gone through green, read every registry the workflow publishes to, as the reference's
last section shows. Then revoke any publish token the repo used to have.

## Verify before reporting done

- [ ] Every package resolves on the registry at the debut version — checked by the fetch loop, not by reading publish output.
- [ ] Each published tarball's file list was read from `npm pack --dry-run --json` **before** the publish, not inferred from `files`.
- [ ] `publish-order.mjs` exits 0 (no cycles) and its order is what the publish script actually walks.
- [ ] Each trusted publisher was **read back** after saving; workflow filename matches the file on the default branch, character for character.
- [ ] One real release has run green through the workflow, **and every registry it publishes to answers that version, with the `v<version>` tag present**. A green run can still be a partial release. **Until both have happened, the setup is written, not working** — say exactly that rather than reporting the pipeline as done.
- [ ] Any pre-existing publish token is revoked, and no `NPM_TOKEN` secret remains referenced.
- [ ] The target repo's `AGENTS.md` names how it releases now.
- [ ] Every claim this run corrected was rewritten in the step it governs, with no dated entry beside it.

## ⟳ After every use: note what this run taught

**Never edit this file** — it is an installed copy, and the next update overwrites it without a word.
Write what the run taught to a notes file instead, one dated line per point, in the narrowest scope that
fits:

- **local** — `.agents/skill-notes/release-first-publish.local.md`, kept out of git (add `*.local.md` to
  that folder's ignore rules if it is not there yet). The default.
- **repo** — `.agents/skill-notes/release-first-publish.md`, committed, read by everyone who works in this
  repository.
- **user** — `~/.agents/skill-notes/release-first-publish.md`, true for you in every project.

Then ask the user whether a note should go back into the skill itself, through the flow they use for it
— an issue, a pull request, an edit in the plugin's own repository. When you do not know that flow, ask.

A procedure written from documentation encodes what a registry *says* it does; only a real run measures
it. Every time this skill runs, write down what actually happened at each step that differed from what
this file said — the error text verbatim, the field that was wrong, the command that did nothing — and
note whether the claim it contradicts was **wrong** (the step needs a correction, in the present tense, no
changelog of who found it or when — a fact genuinely version-bound names the version, `npm -v` is
something a reader can check, a past date is not), **absent** (the step is missing a line entirely), or
**held** (nothing to change, except where the bullet list below already called that claim untested — then
say so, so the caller can fold the answer in and drop the bullet).

What is worth noting, in this skill:

- **`repository.url` mismatch → misleading 404** (Step 0, precondition 2) is read off npm's documentation,
  not yet reproduced on purpose. The first run that triggers it deliberately should confirm the error text.
- **The Node ≥ 22.14 / npm ≥ 11.5.1 floor** (Step 0, precondition 5) is documentation only too — confirm
  what actually happens just below it, not just that the OIDC exchange fails somehow.
- **Reading a saved trusted publisher back** (Step 3) — note whether a run finally catches a real
  divergence, or whether it keeps coming back clean and the cost stops being worth it.
- **Absent provenance as a suspicion sensor** (Step 3) — note whether a run ever finds it pointing at a
  genuinely missing declaration, versus ruling out a suspicion that was never real.
- **Resuming a partial debut publish** (Step 2) has never been exercised on a run that actually died
  mid-list — note the first time it is, and whether the loop actually resumes cleanly.
- A fact about npm or GitHub Actions that any repo publishing there would hit, not just the one this run
  targeted, is worth routing past this skill's own notes file to wherever this workspace keeps cross-repo
  facts.

If a use produced no edits and no note, say so in the session — that is signal too.

Verified against: npm 11.19.1 and Node 26.9.0 on macOS, `changesets/action@v1`, npm trusted publishing
over GitHub Actions OIDC, as of 2026-09-22.
