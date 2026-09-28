# The release workflow — shape and traps

Read this when writing a repository's `release.yml` for the first time, or when editing or debugging one
that already publishes. It stands on its own: nothing below assumes the reader arrived through a
particular skill. Two shapes follow — one built on changesets, one by hand for a repo that versions its
packages by hand (Step 1's other branch in the skill this reference belongs to). Changesets is optional;
nothing below the by-hand shape depends on it.

## The changesets shape

Model: [`ref-id/.github/workflows/release.yml`](https://github.com/entelekheia-ai/ref-id/blob/main/.github/workflows/release.yml). It
releases for real, and it carries fixes that a workflow written from the npm docs lacks. Copy its shape,
not its steps: its Rust and SwiftPM halves belong to that repository.

```yaml
name: release                    # this filename is what the trusted publisher declares — renaming it breaks every package
on: { push: { branches: [main] } }
concurrency: release-${{ github.ref }}
permissions:
  contents: write                # the Version Packages PR and the release tag
  pull-requests: write
  id-token: write                # the OIDC token. Without it: a 404 that explains nothing.
jobs:
  release:
    runs-on: ubuntu-latest       # a self-hosted runner is not supported by trusted publishing
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }             # changesets compares against the base branch
      - uses: actions/setup-node@v4
        with:
          node-version: '24'
          registry-url: https://registry.npmjs.org   # required even with no token: it writes the .npmrc
      - run: npm ci
      - run: npm run build && npm test       # the gate. A published version cannot be recalled.
      - uses: changesets/action@v1
        id: changesets
        with:
          version: npm run version
          publish: npm run release           # publishes in dependency order — see below
          title: 'Version Packages'
        env: { GITHUB_TOKEN: '${{ secrets.GITHUB_TOKEN }}' }
```

**What `version:` and `publish:` name.** `changesets/action` does not ship these — they are `npm run
<name>` scripts the repository's own `package.json` declares, and the action only shells out to whichever
script name is configured above. A repository adopting this shape adds, or already has:

```jsonc
{
  "scripts": {
    // consumes pending changesets into version bumps + changelogs, then syncs any version that lives
    // outside package.json (Cargo.toml, a committed generated constant, the lockfile) — whatever that
    // repo needs; `changeset version` alone if nothing else does
    "version": "changeset version && node scripts/sync-versions.mjs",
    // publishes every package in dependency order — the same loop the by-hand shape below runs directly,
    // wrapped in a script name so the action can invoke it as `publish:`. CI has no `${CLAUDE_SKILL_DIR}`
    // (that variable exists only inside a session with the skill loaded), so `publish-order.mjs` reaches
    // the workflow as a file the repository commits — copied in wherever the repo keeps release tooling,
    // `scripts/publish-order.mjs` below is one choice, not a required path
    "release": "node scripts/publish-order.mjs . --paths | while read -r dir; do ( cd \"$dir\" && npm publish --access public ); done"
  }
}
```

## The by-hand shape — no changesets, versioned and tagged directly

For a repository that versions its packages by hand (writes the debut version into every `package.json`
itself, per Step 1's other branch): no Version Packages PR, no `changesets/action`, nothing above applies.
The workflow triggers on a `v*` tag push (a maintainer decides the version and pushes the tag, which is
now the versioning ceremony) or on `workflow_dispatch` for a manual re-run, builds and tests, then runs the
same dependency-order publish loop Step 2 uses interactively:

```yaml
name: release
on:
  push: { tags: ['v*'] }
  workflow_dispatch: {}
concurrency: release-${{ github.ref }}
permissions:
  id-token: write                # the OIDC token — provenance is automatic under it, no --provenance flag
  contents: read
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '24'
          registry-url: https://registry.npmjs.org
      - run: npm ci
      - run: npm run build && npm test       # the gate. A published version cannot be recalled.
      - run: |
          node scripts/publish-order.mjs . --paths | while read -r dir; do
            ( cd "$dir" && npm publish --access public )
          done
```

Both shapes' workflows read `publish-order.mjs` from a path inside the checkout, not from
`${CLAUDE_SKILL_DIR}` — that variable is only set inside a session with the skill loaded, and the workflow
runs with no plugin installed. Commit a copy into the repository (`scripts/` above, or wherever the repo
keeps release tooling) as part of adopting this shape.

There is no "did this run release" derivation to make here — the workflow only runs on a tag someone
pushed deliberately, or a manual dispatch, so a green run published what the tag names. The rest of this
file — the OIDC/tag/provenance traps below, and reading every registry after — applies to this shape as
much as to the changesets one; only the two `published`-output traps in point 2 are changesets-specific.

## What this shape gets right, and the npm documentation does not show

1. **`changeset publish` is concurrent and order-blind.** With exact or caret pins between the repo's own
   packages, it can publish a dependent before its dependency. Point `publish:` at a script that walks
   the packages in dependency order. `publish-order.mjs`, in the skill folder this reference belongs to
   (in CI, a copy the repository commits, since the workflow runs with no plugin installed), prints that
   order.
2. **`--no-git-tag` silently disables every conditional step after it.** `changesets/action@v1` derives
   its `published` output by grepping stdout for `New tag:` lines (`src/run.ts:101-165`, 1.9.0), so a run
   that published every package reports `published=false` and the release looks green with half of it
   skipped. The action's `main` branch has since moved to a `CHANGESETS_OUTPUT` file, so re-read this
   on a major bump. A repo reaches for `--no-git-tag`
   when the action's `git push` of the tag is refused. That happens when the tagged commit touches a
   workflow file and the token is `GITHUB_TOKEN`, which carries no `workflows` permission. If you take that route, derive "did this run release"
   from the registry itself: the version exists on npm and the `v<version>` tag does not exist yet.
   `ref-id` does this in its `released` step. Never derive it from
   `steps.changesets.outputs.published`.
   **That derivation has two traps of its own. The first version of `ref-id`'s step fell into the first
   one:**
   - **Poll npm; a single `npm view` right after the publish reads nothing.** The registry does not list
     a version it accepted seconds ago — a step that queries once in the same second the publish returns
     answers "not released" and silently skips the tag and every other registry, and nothing fails to
     make that visible. Listing has taken as long as six attempts fifteen seconds apart in practice, so
     poll for three minutes before answering "no".
   - **Run the step only when `steps.changesets.outputs.hasChangesets == 'false'`, and read the version
     from `$GITHUB_SHA`** (`git show "$GITHUB_SHA:<path>/package.json"`), never from the working tree.
     With changesets pending, the action leaves the Version Packages branch checked out one version
     ahead. A version read from disk then names a release nobody made, and a publish step gated on it
     would ship unreleased code.
3. **OIDC authenticates `npm publish` and nothing else.** `npm dist-tag add` in the same job fails `E401`
   next to a green publish. The version is then public on the wrong channel, and the run cannot be
   retried. Tag at publish time with `--tag`, or move tags from an authenticated session outside the
   workflow.
4. **Provenance is automatic** under OIDC from a public repo. Do not add `--provenance`.
5. **Annotate every tag the workflow creates, and read the exit code.** Where `tag.gpgsign` is set — a
   machine-wide `git config` the workflow never sees — a lightweight `git tag` refuses with
   `fatal: no tag message?`. That message names neither signing nor the setting, and it reads like a
   malformed command. Pass `-a -m`, which succeeds with signing on or off. Reach for `-a -m` rather than
   `--no-sign`: the workaround overrides an operator preference the machine declared deliberately, and
   the annotated tag is the better artefact anyway, since it records who tagged and when. Guard it where
   the failure lands: the tag step runs after the publish step, so a non-zero exit there leaves the
   registry ahead of the repository, with no tag to release from.
   **This binds every tool that creates a tag, not only a release workflow.** `tag.gpgsign` is an
   operator preference that no repository declares and no clone inherits, so the same code passes on one
   machine and fails on the next. It bites tooling rather than people, because a person reads the error
   and a program often discards the exit code — a script that creates a branch and tags it can report
   success with a real branch and no tag at all, if it never checks `git tag`'s exit code.

## After a release: read every registry, not the run

A green run is not a complete release. The step that decides whether to publish the second registry and
the tag can answer "no" without failing, and the run stays green. After the Version Packages pull
request merges, check that every registry the workflow publishes to answers the same version, and that
the `v<version>` tag exists:

```sh
npm view <package> dist-tags.latest
cargo search <crate> --limit 1            # when the workflow publishes a crate
git ls-remote --tags origin "refs/tags/v<version>"
```

A registry behind the others is a partial release. A rerun of the workflow finishes it, but only on a
commit with no pending changeset, because only there does the `released` step run at all.
