// vibeops.config.mjs — this repository's OWN declaration.
//
// `vibe-ops config` walks every ancestor directory looking for a config file, so a checkout of this
// repository inside a larger folder that has its own `vibeops.config` would inherit that file's ops and
// settings. The merge is per key (`ops`, `settings.*`), never whole-file, so a key this file does not
// mention would still be inherited. Every ops key a parent folder may compose is therefore named here
// and turned off (`false`), and `settings.exposure.disabled` is an empty ledger, so this repository
// always composes only the gates declared in `.vibe-ops/ops.json` and keeps every exposure check armed.

export default {
  ops: {
    // Ops a parent folder may compose, none of which apply to this catalog.
    entelekheia: false,
    "readme-governance": false,
    "agents-md-governance": false,
    "skill-governance": false,

    // This repository's own gates. Relative, deliberately: `opsSpecifier` resolves a relative path
    // against the repository being checked, which is always this one.
    skills: "./.vibe-ops/ops.json",
  },

  settings: {
    // The built-in `exposure` ops ships armed by default and stays armed here. An empty ledger, not an
    // absent key: `settings` merges per top-level key, so leaving `exposure` out would let a parent
    // folder's `disabled` entries show through.
    exposure: {
      disabled: {},
    },
  },
};
