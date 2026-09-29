# AGENTS.md — skills

The `entelekheia` Claude Code marketplace: small plugins, one folder each, installable with
`claude plugin marketplace add entelekheia-ai/skills` or, skills only, `npx skills add entelekheia-ai/skills`.

| Folder | Plugin | Holds |
|---|---|---|
| `.claude-plugin/marketplace.json` | — | The catalog. Local plugins by relative path; `vibe-ops` by `git-subdir` from its own repository |
| `delegation/` | `delegation` | Where delegated work runs, on which model, and how it crosses the hand-off |
| `method/` | `method` | Carry a plan through its remaining tracks unattended, paced against the usage limit and the context window; route what the work taught to the surface built for it |
| `publishing/` | `publishing` | The workflow that publishes an item into this catalog: `publish`, and the `extraction-auditor` and `edit-applier` agents |
| `machine/` | `machine` | Keep a development machine working: `dev-storage` (macOS disk and Time Machine), `repair-agent-host` (VS Code agents panel) |
| `release/` | `release` | Release channels for npm packages: `release-channels-adopt`, `release-promote`, `release-first-publish` |

## Rules

- A skill or agent **MUST NOT** name a machine path, private repository, internal tool or measurement of
  its author's machine; it **SHOULD** ship its defaults as a recommendation to tune instead.
- A skill **MUST** work without the plugin's agents: an agent it mentions **MUST** be optional to it, never
  required — `npx skills` installs skills only.
- An agent's name **MUST** carry its plugin as a prefix (an agent in `delegation/agents/reviewer.md` is
  `delegation:reviewer`) and **MUST NOT** repeat the group name in the file name.
- A skill **MAY** name one of the author's own public products as an example or an option beside others —
  `vibe-ops` as a plugin example, or as a manager built on deterministic gates; `ref-id` as the option when
  something needs one stable identifier — and **SHOULD**, where it fits. It **MUST NOT** make one an
  instruction the skill depends on. A product whose repository is private, or that has nothing to do with
  the skill's subject, **MUST NOT** be named at all: name the category instead ("an observability tool",
  "a graph viewer").
- A `ref:` identifier **MUST** appear only in a README or in a script that locates a package, version or
  excerpt. It **MUST NOT** appear inside a SKILL.md or an agent definition, where a model would read it as
  something to produce.
- Before a commit, `vibe-ops check` **MUST** pass from the repo root (`vibe-ops` **MUST** be on PATH). It
  composes this repository's own gates from `.vibe-ops/ops.json`; each gate's header comment in
  `.vibe-ops/gates/<name>/index.mjs` states what it checks and why. `private-name-everywhere` is the
  built-in `classification` gate, with no file here: it reads the operator's deny-list from the path in
  `VIBE_OPS_DENYLIST` (`label<TAB>pattern` per line), which is never committed.

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

  ```js
  // SPDX-License-Identifier: Apache-2.0
  ```

  Follow the existing pattern in the file's neighbors; don't invent a different header style.
