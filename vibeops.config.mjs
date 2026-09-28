// vibeops.config.mjs — this repository's OWN declaration, not the workspace root's.
//
// public-plugin is a public repository with its own `.git`, checked out inside the entelekheia
// workspace on disk. Without a file here, `vibe-ops config` walks every ancestor directory looking for
// one and finds the workspace root's `vibeops.config.mjs` — which names an absolute machine path for
// `ops.entelekheia`, composes three ops meant for that private workspace (`readme-governance`,
// `agents-md-governance`, `skill-governance`), and disables `exposure/file-path` because THAT
// repository is the deliberate private layer of a two-layer research split. None of that is true here:
// this is the public layer, so `file-path` must stay armed, and this repository composes only the
// gates declared below it in `.vibe-ops/ops.json`.
//
// The merge is per-key (`ops`, `settings.*`), never whole-file, so a key this file does not mention
// would still be inherited from the ancestor file. Every key the ancestor sets that does not belong
// here is therefore named explicitly and turned off (`false` for `ops`, an empty ledger for
// `settings.exposure.disabled`) rather than left to inherit by accident.

export default {
  ops: {
    // The workspace root's own ops, none of which apply to a public plugin catalog: its absolute-path
    // local ops, and the three internal governance packages meant for the private workspace's docs.
    entelekheia: false,
    "readme-governance": false,
    "agents-md-governance": false,
    "skill-governance": false,

    // This repository's own gates. Relative, deliberately: `opsSpecifier` resolves a relative path
    // against the repository BEING CHECKED, and that repository is always this one — public-plugin
    // composes its own detectors, unlike the workspace root, which every inheriting sub-repository
    // would resolve this same relative path against ITSELF.
    "public-plugin": "./.vibe-ops/ops.json",
  },

  settings: {
    // The built-in `exposure` ops ships armed by default (`DEFAULT_OPS` in vibe-ops-core) and stays
    // armed here — this file only makes sure the ancestor's disablement of `file-path` does not reach
    // this repository. An empty ledger, not an absent key: `settings` merges per top-level key, so
    // leaving `exposure` out entirely would still let the ancestor's `disabled.file-path` show through.
    exposure: {
      disabled: {},
    },
  },
};
