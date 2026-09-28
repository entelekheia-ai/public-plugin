// SPDX-License-Identifier: Apache-2.0
// guard.test.mjs — pipes PreToolUse payloads through `sh guard.sh` exactly as the plugin's hook runs it,
// and checks which agent each call is attributed to and in which mode: `node --test delegation/scripts/`.
import { test } from "node:test"
import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { mkdtempSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import path from "node:path"
import { fileURLToPath } from "node:url"

const guard = path.join(path.dirname(fileURLToPath(import.meta.url)), "guard.sh")
// The shell itself, by absolute path, so a test may hand guard.sh a PATH that lacks it.
const sh = spawnSync("sh", ["-c", "command -v sh"], { encoding: "utf8" }).stdout.trim()

function run(payload, env = process.env) {
  const input = typeof payload === "string" ? payload : JSON.stringify(payload)
  return spawnSync(sh, [guard], { input, env, encoding: "utf8" }).status
}

const bash = (command, agent) => ({ ...(agent && { agent_id: "a1", agent_type: agent }), tool_name: "Bash", tool_input: { command } })
const write = (file_path, agent) => ({ agent_id: "a1", agent_type: agent, tool_name: "Write", tool_input: { file_path } })

const cases = [
  ["main loop may commit", bash("git commit -m x"), 0],
  ["main loop that mentions an agent name passes", bash("echo delegation:reviewer && git push"), 0],
  ["another plugin's agent passes", bash("git commit -m x", "other:reviewer"), 0],
  ["an unknown delegation agent passes", bash("git commit -m x", "delegation:__proto__"), 0],
  ["reviewer may read git", bash("git log --oneline -3", "delegation:reviewer"), 0],
  ["reviewer may not commit", bash("git commit -m x", "delegation:reviewer"), 2],
  ["reviewer may not write into a checkout", write("/work/repo/a.md", "delegation:reviewer"), 2],
  ["reviewer may write under /tmp", write("/tmp/probe/a.md", "delegation:reviewer"), 0],
  ["plan-scout may not stash", bash("cd /x && git stash", "delegation:plan-scout"), 2],
  ["plan-scout may not write into a checkout", write("/work/repo/a.md", "delegation:plan-scout"), 2],
  ["blind-run may write where its brief says", write("/work/repo/a.md", "delegation:blind-run"), 0],
  ["blind-run may not push", bash("git push", "delegation:blind-run"), 2],
  ["implementer may not commit", bash("git commit -m x", "delegation:implementer"), 2],
  ["implementer may write into a checkout", write("/work/repo/a.md", "delegation:implementer"), 0],
]

for (const [name, payload, expected] of cases) {
  test(name, () => assert.equal(run(payload), expected))
}

test("pretty-printed payload is still attributed", () => {
  assert.equal(run(JSON.stringify(bash("git commit -m x", "delegation:reviewer"), null, 2)), 2)
})

test("a delegation agent's call is refused when node is not on PATH", () => {
  const bin = mkdtempSync(path.join(tmpdir(), "guard-nonode-"))
  // Only `cat` and `dirname` on PATH: the prefilter runs, `command -v node` fails.
  for (const tool of ["cat", "dirname"]) {
    const found = spawnSync("sh", ["-c", `command -v ${tool}`], { encoding: "utf8" }).stdout.trim()
    writeFileSync(path.join(bin, tool), `#!/bin/sh\nexec ${found} "$@"\n`, { mode: 0o755 })
  }
  const env = { PATH: bin }
  assert.equal(run(bash("git log", "delegation:reviewer"), env), 2)
  assert.equal(run(bash("git commit -m x"), env), 0)
})
