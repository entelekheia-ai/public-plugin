# AGENTS.md — public-plugin

The `entelekheia` Claude Code marketplace: small plugins, one folder each, installable with
`claude plugin marketplace add entelekheia-ai/public-plugin` or, skills only, `npx skills add entelekheia-ai/public-plugin`.

| Folder | Plugin | Holds |
|---|---|---|
| `.claude-plugin/marketplace.json` | — | The catalog. Local plugins by relative path; `vibe-ops` by `git-subdir` from its own repository |
| `delegation/` | `delegation` | Where delegated work runs, on which model, and how it crosses the hand-off |
| `method/` | `method` | Carry a plan through its remaining tracks unattended, paced against the usage limit and the context window |

## Rules

- **Every file here is public.** A skill or agent names no machine path, private repository, internal tool or
  measurement of its author's machine; it ships its defaults as a recommendation to tune.
- **A skill works without the plugin's agents.** `npx skills` installs skills only, so an agent a skill
  mentions is optional to it, never required.
- **The plugin name is the prefix.** An agent in `delegation/agents/reviewer.md` is `delegation:reviewer`;
  never repeat the group in the file name.
- **`ref:` identifiers appear only in READMEs and in scripts that locate packages, versions or excerpts** —
  never inside a SKILL.md or an agent definition, where a model would read them as something to produce.
- Before a commit: `vibe-ops check` from the repo root (`vibe-ops` must be on PATH). It composes this
  repository's own gates from `.vibe-ops/ops.json`, one per line: `manifest-versions` — every workspace's
  `package.json`, `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json` and marketplace entry agree
  on its version, and the catalog and the workspaces list the same plugins; `plugin-validate` — `claude
  plugin validate --strict` passes on the catalog root and on each plugin folder (SKIP when `claude` is
  not on PATH); `license-text` — LICENSE is the Apache-2.0 text verbatim, except the appendix's own
  copyright line; `private-name-everywhere` — the built-in `classification` gate over every file, not
  only the Markdown the built-in `exposure` ops covers: no file names a term on the operator's own deny-list,
  a path given in `VIBE_OPS_DENYLIST` (`label<TAB>pattern` per line), never committed; `skill-frontmatter` — every
  `*/skills/*/SKILL.md` names its own folder, carries a description, and agrees with itself about
  `user-invocable`/`user_invocable`.

## Releases

- **A plugin's version lives in its `package.json`**, which exists only so changesets can bump it. Never edit
  the version in `plugin.json` or `marketplace.json` by hand: `npm run version` applies the pending
  changesets and `scripts/sync-versions.mjs` copies each version into both. `vibe-ops check` catches drift
  between them (`manifest-versions`) but cannot repair it: `vibe-ops check` never forwards `--fix` to a
  composed ops, and a local ops declared by a relative path — this repository's own — cannot be addressed
  by name for the ops runner's own `--fix` either. `scripts/sync-versions.mjs` stays the repair.
- **Every change to a plugin carries a changeset** (`npx changeset`), written when the change is made. A new
  plugin folder is added to `workspaces` in the root `package.json` and to the catalog in the same change.
- **`changeset version` has not run yet**, so no plugin has a `CHANGELOG.md`; that is expected until the
  first release.
- **Before a release, each plugin being released has been used on real work since its last release.**
  The catalog has no downstream test suite; that use is the gate.

## License rules

- New `.md` documents need **no license header** — the root [`LICENSE`](LICENSE) covers the repository.
- Non-code example/fixture files need no header either.
- Source files (`*.js *.mjs`) carry a one-line SPDX header at the top:

  ```
  // SPDX-License-Identifier: Apache-2.0
  ```

  Follow the existing pattern in the file's neighbors; don't invent a different header style.
