// SPDX-License-Identifier: Apache-2.0
//
// LICENSE is not the Apache-2.0 text verbatim.
//
// WHY IT EXISTS. A public plugin catalog's licence is the one document nobody reads until a dispute,
// which is exactly when a hand-edited stray character in it matters most. The normalization below
// exists because the ONE line the Apache-2.0 template asks every adopter to fill in — the appendix's
// `Copyright [yyyy] [name of copyright owner]` — is deliberately not verbatim in an adopted copy; every
// other line must be.
//
// NORMALIZATION. Inside the appendix (from the line containing `APPENDIX` onward), the FIRST line
// matching `/^\s*Copyright \d{4} .+$/` is replaced with the template's own placeholder,
// `   Copyright [yyyy] [name of copyright owner]`, before hashing. A copyright line outside the
// appendix is not touched — Apache-2.0 carries none, so one there is itself a divergence the hash below
// will catch.
//
// THE PIN. `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30` is the sha256 of the
// canonical Apache-2.0 text with that substitution applied — verified by applying this same
// normalization to this repository's own LICENSE at the time this gate was written, which matched
// (2026-09-28). A hash that stops matching means either LICENSE drifted or the pin needs revisiting;
// this gate cannot tell which, and says so in the finding.

import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";

export const PINNED_SHA256 = "cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30";
const COPYRIGHT_LINE = /^\s*Copyright \d{4} .+$/;

/** The Apache-2.0 text with the appendix's copyright line reduced to the template placeholder. */
export function normalize(text) {
  const lines = text.split("\n");
  let inAppendix = false;
  let replaced = false;
  return lines
    .map((line) => {
      if (line.includes("APPENDIX")) inAppendix = true;
      if (inAppendix && !replaced && COPYRIGHT_LINE.test(line)) {
        replaced = true;
        return "   Copyright [yyyy] [name of copyright owner]";
      }
      return line;
    })
    .join("\n");
}

export function normalizedSha256(text) {
  return createHash("sha256").update(normalize(text)).digest("hex");
}

export default {
  definition: {
    id: "license-text",
    version: 1,
    summary: "LICENSE is the Apache-2.0 text verbatim, except the appendix's own copyright line",
    defaultPaths: ["LICENSE"],
  },

  async run({ repoRoot, files }) {
    if (!files.includes("LICENSE")) {
      return { findings: [], skipped: "no LICENSE in this population" };
    }

    const text = readFileSync(`${repoRoot}/LICENSE`, "utf8");
    const digest = normalizedSha256(text);

    if (digest !== PINNED_SHA256) {
      return {
        findings: [
          {
            rule: "license-text-drift",
            file: "LICENSE",
            evidence:
              `LICENSE, normalized (appendix copyright line reduced to the template placeholder), hashes to ` +
              `${digest} — the canonical Apache-2.0 text hashes to ${PINNED_SHA256}. Either LICENSE has ` +
              `drifted from the canonical text, or this gate's pin is stale.`,
            level: "fail",
          },
        ],
        examined: 1,
      };
    }

    return { findings: [], examined: 1 };
  },
};
