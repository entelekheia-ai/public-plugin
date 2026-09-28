// SPDX-License-Identifier: Apache-2.0
// guard.mjs — reads a PreToolUse payload on stdin and, when it comes from one of this plugin's
// read-only agents, runs git-read-only.mjs on it in that agent's mode. Any other payload is allowed.
//
//   plan-scout, reviewer, fact-sheet,  git read-only subcommands only; Write/Edit only under a temporary
//   miner                              directory
//   blind-run, implementer             git read-only subcommands only; each writes where its brief says

import { spawnSync } from "node:child_process"
import { readFileSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const MODES = {
  "delegation:plan-scout": ["--writes-under-tmp"],
  "delegation:reviewer": ["--writes-under-tmp"],
  "delegation:fact-sheet": ["--writes-under-tmp"],
  "delegation:blind-run": [],
  "delegation:implementer": [],
  "delegation:miner": ["--writes-under-tmp"],
}

const raw = readFileSync(0, "utf8")
let agent
try {
  agent = JSON.parse(raw)?.agent_type
} catch {
  process.exit(0)
}
if (typeof agent !== "string" || !Object.hasOwn(MODES, agent)) process.exit(0)

const script = path.join(path.dirname(fileURLToPath(import.meta.url)), "git-read-only.mjs")
const name = agent.slice("delegation:".length)
const run = spawnSync(process.execPath, [script, name, ...MODES[agent]], {
  input: raw,
  stdio: ["pipe", "inherit", "inherit"],
})
if (run.error) {
  console.error(`${name}: the read-only guard could not start (${run.error.message}); the call is refused.`)
  process.exit(2)
}
process.exit(run.status ?? 2)
