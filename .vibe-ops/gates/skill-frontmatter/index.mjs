// SPDX-License-Identifier: Apache-2.0
//
// A `SKILL.md`'s frontmatter is missing what an installer needs to name it, describe it, or decide
// whether a person can invoke it directly.
//
// WHY IT EXISTS. `npx skills add` and Claude Code's own plugin loader both read a skill's identity out
// of its frontmatter, not out of its folder name — so a `name:` that drifts from the folder, or a
// missing `description`, breaks silently at install time rather than at review time. Both invocability
// flags exist because `npx skills` (which reads `user_invocable`) and Claude Code's own plugin loader
// (which reads `user-invocable`) are two readers of the same fact; one of them missing, or the two
// disagreeing, is invisible to whichever reader does not look for it.
//
// FOUR RULES, ONE PER FIELD. `skill-frontmatter-name`: `name` is missing, or differs from the skill's
// own folder name. `skill-frontmatter-description`: `description` is missing or empty.
// `skill-frontmatter-invocable-missing`: `user-invocable` or `user_invocable` is absent.
// `skill-frontmatter-invocable-mismatch`: both are present and disagree.

import { readFileSync } from "node:fs";
import path from "node:path";

/** The frontmatter block between the leading `---` fences, as a flat key → raw-value map. No YAML
 *  dependency: every value this gate reads is a bare scalar, and a nested structure is not this gate's
 *  business to parse. */
export function parseFrontmatter(text) {
  const match = /^---\r?\n([\s\S]*?)\r?\n---/.exec(text);
  if (match === null) return undefined;
  const fields = {};
  for (const line of match[1].split("\n")) {
    const m = /^([A-Za-z0-9_-]+):\s*(.*)$/.exec(line);
    if (m === null) continue;
    fields[m[1]] = m[2].trim().replace(/^["']|["']$/g, "");
  }
  return fields;
}

export default {
  definition: {
    id: "skill-frontmatter",
    version: 1,
    summary: "every SKILL.md names its own folder, carries a description, and agrees with itself about invocability",
    defaultPaths: ["*/skills/*/SKILL.md", "skills/*/SKILL.md"],
  },

  async run({ repoRoot, files }) {
    if (files.length === 0) {
      return { findings: [], skipped: "no SKILL.md in this population" };
    }

    const findings = [];
    let examined = 0;

    for (const file of files) {
      examined += 1;
      const folder = path.basename(path.dirname(file));
      const text = readFileSync(path.join(repoRoot, file), "utf8");
      const fm = parseFrontmatter(text);
      if (fm === undefined) {
        findings.push({ rule: "skill-frontmatter-name", file, evidence: "no frontmatter block found", level: "fail" });
        continue;
      }

      if (fm.name === undefined || fm.name !== folder) {
        findings.push({
          rule: "skill-frontmatter-name",
          file,
          evidence: `name ${JSON.stringify(fm.name)} does not match its folder "${folder}"`,
          level: "fail",
        });
      }

      if (fm.description === undefined || fm.description.length === 0) {
        findings.push({ rule: "skill-frontmatter-description", file, evidence: "no description", level: "fail" });
      }

      const hyphen = fm["user-invocable"];
      const underscore = fm["user_invocable"];
      if (hyphen === undefined || underscore === undefined) {
        findings.push({
          rule: "skill-frontmatter-invocable-missing",
          file,
          evidence: `user-invocable=${JSON.stringify(hyphen)} user_invocable=${JSON.stringify(underscore)} — both are required`,
          level: "fail",
        });
      } else if (hyphen !== underscore) {
        findings.push({
          rule: "skill-frontmatter-invocable-mismatch",
          file,
          evidence: `user-invocable=${hyphen} but user_invocable=${underscore}`,
          level: "fail",
        });
      }
    }

    return { findings, examined };
  },
};
