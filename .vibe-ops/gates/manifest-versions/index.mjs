// SPDX-License-Identifier: Apache-2.0
//
// A workspace's manifests disagree about its version, or the catalog and the workspaces disagree about
// which plugins exist.
//
// WHY IT EXISTS. `scripts/sync-versions.mjs` used to be the only thing keeping four files in step: the
// root `package.json`'s `workspaces` list, each plugin's own `package.json` (the file changesets
// bumps), its `.claude-plugin/plugin.json` (and `.codex-plugin/plugin.json`, when the plugin also
// ships Codex skills), and its entry in the root `.claude-plugin/marketplace.json`. The script only
// ever COPIES a version forward; nothing reported when a plugin folder existed with no entry in the
// catalog, or a catalog entry pointed at a folder that had been renamed or deleted, or a Codex manifest
// still listed a skill folder that had been removed. This gate reads all four and says which pair
// disagrees, instead of one script quietly overwriting three of them from the fourth.
//
// POPULATION. The root `package.json`'s own `workspaces` array, read directly off disk rather than
// from `files` — this gate compares several files against each other and must see all of them or none,
// and `files.length === 0` is used only to decide there is nothing declared to check at all.
//
// FOUR RULES. `manifest-version-drift`: a workspace's `package.json` version differs from its
// `.claude-plugin/plugin.json` version, or (when present) its `.codex-plugin/plugin.json` version.
// `manifest-marketplace-missing`: a workspace has no entry in `marketplace.json`, or its entry's
// version differs from the plugin's own. `manifest-marketplace-orphan`: a *local* marketplace entry
// (a relative `source`) names a folder that is not a workspace. `manifest-codex-skills-mismatch`: a
// `.codex-plugin/plugin.json`'s `skills` list does not name exactly the plugin's `skills/*/` folders.
//
// NOT FIXABLE, ON PURPOSE. `vibe-ops check` never forwards `--fix` to a composed ops, and a LOCAL ops
// — declared as a relative `./.vibe-ops/ops.json`, the shape this repository uses — cannot be
// addressed by name for the ops runner's own `--fix` either (`vibe-ops public-plugin` and
// `vibe-ops ./.vibe-ops/ops.json` both refuse). Measured against vibe-ops 0.2.0. So
// `scripts/sync-versions.mjs` stays: this gate is the detector `npm run version` had none of before,
// not a replacement for the repair.

import { existsSync, readFileSync, readdirSync } from "node:fs";
import path from "node:path";

function readJSON(file) {
  try {
    return JSON.parse(readFileSync(file, "utf8"));
  } catch {
    return undefined;
  }
}

/** `./delegation` and `delegation` name the same workspace. */
const stripDotSlash = (p) => p.replace(/^\.\//, "").replace(/\/$/, "");

export default {
  definition: {
    id: "manifest-versions",
    version: 1,
    summary:
      "every workspace's package.json, plugin.json, .codex-plugin/plugin.json and marketplace.json entry agree on its version and its existence",
    defaultPaths: ["package.json", "*/package.json", "*/.claude-plugin/plugin.json", "*/.codex-plugin/plugin.json", ".claude-plugin/marketplace.json"],
  },

  async run({ repoRoot, files }) {
    if (files.length === 0) {
      return { findings: [], skipped: "no manifest in this population" };
    }

    const rootPkg = readJSON(path.join(repoRoot, "package.json"));
    const workspaces = Array.isArray(rootPkg?.workspaces) ? rootPkg.workspaces.map(stripDotSlash) : [];
    if (workspaces.length === 0) {
      return { findings: [], skipped: "root package.json declares no workspaces" };
    }

    const marketplacePath = path.join(repoRoot, ".claude-plugin", "marketplace.json");
    const marketplace = existsSync(marketplacePath) ? readJSON(marketplacePath) : undefined;
    const plugins = Array.isArray(marketplace?.plugins) ? marketplace.plugins : [];

    const findings = [];
    let examined = 0;

    for (const dir of workspaces) {
      examined += 1;
      const pkgPath = path.join(repoRoot, dir, "package.json");
      const pkg = readJSON(pkgPath);
      if (pkg?.version === undefined) {
        findings.push({
          rule: "manifest-version-drift",
          file: `${dir}/package.json`,
          evidence: "no readable version in this workspace's package.json",
          level: "fail",
        });
        continue;
      }

      const pluginPath = path.join(repoRoot, dir, ".claude-plugin", "plugin.json");
      const plugin = existsSync(pluginPath) ? readJSON(pluginPath) : undefined;
      if (plugin?.version !== pkg.version) {
        findings.push({
          rule: "manifest-version-drift",
          file: `${dir}/.claude-plugin/plugin.json`,
          evidence: `version ${JSON.stringify(plugin?.version)} does not match ${dir}/package.json's ${pkg.version}`,
          level: "fail",
        });
      }

      const codexPath = path.join(repoRoot, dir, ".codex-plugin", "plugin.json");
      if (existsSync(codexPath)) {
        const codex = readJSON(codexPath);
        if (codex?.version !== pkg.version) {
          findings.push({
            rule: "manifest-version-drift",
            file: `${dir}/.codex-plugin/plugin.json`,
            evidence: `version ${JSON.stringify(codex?.version)} does not match ${dir}/package.json's ${pkg.version}`,
            level: "fail",
          });
        }

        const skillsDir = path.join(repoRoot, dir, "skills");
        const actualSkills = existsSync(skillsDir)
          ? readdirSync(skillsDir, { withFileTypes: true })
              .filter((e) => e.isDirectory())
              .map((e) => e.name)
              .sort()
          : [];
        const declaredSkills = Array.isArray(codex?.skills)
          ? codex.skills.map((s) => stripDotSlash(String(s)).replace(/^skills\//, "")).sort()
          : [];
        if (JSON.stringify(actualSkills) !== JSON.stringify(declaredSkills)) {
          findings.push({
            rule: "manifest-codex-skills-mismatch",
            file: `${dir}/.codex-plugin/plugin.json`,
            evidence: `skills [${declaredSkills.join(", ")}] does not name exactly ${dir}/skills/* [${actualSkills.join(", ")}]`,
            level: "fail",
          });
        }
      }

      const name = plugin?.name ?? path.basename(dir);
      const entry = plugins.find((p) => p.name === name);
      if (entry === undefined) {
        findings.push({
          rule: "manifest-marketplace-missing",
          file: ".claude-plugin/marketplace.json",
          evidence: `workspace ${dir} (plugin "${name}") has no entry in the catalog`,
          level: "fail",
        });
      } else if (typeof entry.source === "string" && entry.version !== pkg.version) {
        findings.push({
          rule: "manifest-marketplace-missing",
          file: ".claude-plugin/marketplace.json",
          evidence: `entry "${name}" version ${JSON.stringify(entry.version)} does not match ${dir}/package.json's ${pkg.version}`,
          level: "fail",
        });
      }
    }

    // The reverse direction: a local marketplace entry naming a folder that is not a workspace.
    for (const entry of plugins) {
      if (typeof entry.source !== "string") continue; // git-subdir and other remote sources are not workspaces
      const dir = stripDotSlash(entry.source);
      if (!workspaces.includes(dir)) {
        findings.push({
          rule: "manifest-marketplace-orphan",
          file: ".claude-plugin/marketplace.json",
          evidence: `entry "${entry.name}" points at "${entry.source}", which is not in the root package.json's workspaces`,
          level: "fail",
        });
      }
    }

    return { findings, examined };
  },
};
