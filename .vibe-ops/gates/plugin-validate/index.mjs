// SPDX-License-Identifier: Apache-2.0
//
// `claude plugin validate --strict` disagrees with the catalog or one of its plugins.
//
// WHY IT EXISTS. This was `npm run validate`, run by hand before a commit and by nobody else — a
// script nothing calls at a gate is a script that stops the schema from drifting the day someone
// forgets to run it. Folding it into `vibe-ops check` is what makes it part of the same commit gate as
// everything else this repository checks.
//
// POPULATION. The repository root (the catalog itself) plus every folder the root `package.json`
// declares under `workspaces` — read directly, the same way `manifest-versions` does, because the
// binary being validated is `claude` and not any one file; `files.length === 0` only decides there is
// nothing declared to validate against.
//
// SKIPPED WHEN `claude` IS NOT ON PATH. A contributor without the Claude Code CLI installed must not
// have their commit blocked by a check this repository cannot even run for them — the same reasoning
// `model-lineup`'s docs probe uses for an unreachable network.
//
// A FAILURE CARRIES THE CLI'S OWN OUTPUT, because `claude plugin validate --strict`'s own message is
// already the fix — re-stating it in different words would be a second, possibly out-of-date, copy.

import { existsSync, readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import path from "node:path";

function readJSON(file) {
  try {
    return JSON.parse(readFileSync(file, "utf8"));
  } catch {
    return undefined;
  }
}

function claudeOnPath() {
  try {
    execFileSync("sh", ["-c", "command -v claude"], { encoding: "utf8" });
    return true;
  } catch {
    return false;
  }
}

export default {
  definition: {
    id: "plugin-validate",
    version: 1,
    summary: "`claude plugin validate --strict` passes on the catalog root and on every plugin folder",
    defaultPaths: ["package.json", "*/.claude-plugin/plugin.json"],
  },

  async run({ repoRoot, files }) {
    if (files.length === 0) {
      return { findings: [], skipped: "no plugin manifest in this population" };
    }
    if (!claudeOnPath()) {
      return { findings: [], skipped: "the `claude` binary is not on PATH" };
    }

    const rootPkg = readJSON(path.join(repoRoot, "package.json"));
    const workspaces = Array.isArray(rootPkg?.workspaces) ? rootPkg.workspaces.map((w) => w.replace(/^\.\//, "")) : [];
    const targets = [".", ...workspaces];

    const findings = [];
    let examined = 0;

    for (const target of targets) {
      const dir = path.resolve(repoRoot, target);
      if (!existsSync(dir)) continue;
      examined += 1;
      try {
        execFileSync("claude", ["plugin", "validate", target === "." ? repoRoot : dir, "--strict"], {
          cwd: repoRoot,
          encoding: "utf8",
          stdio: ["ignore", "pipe", "pipe"],
        });
      } catch (error) {
        const output = [error.stdout, error.stderr].filter(Boolean).join("\n").trim() || error.message;
        findings.push({
          rule: "plugin-invalid",
          file: target === "." ? undefined : `${target}/.claude-plugin/plugin.json`,
          evidence: `claude plugin validate ${target} --strict: ${output}`,
          level: "fail",
        });
      }
    }

    return { findings, examined };
  },
};
