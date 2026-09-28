// SPDX-License-Identifier: Apache-2.0
// agent-runs.test.mjs — decisions about which runs belong to a definition, what counts as a refusal and
// who refused it, and where the report is read from.
//
// Builds a temporary "projects" directory: one main session that dispatches the agent (written twice, as
// a resumed session rewrites its history), and the subagent's own transcript nested under subagents/.

import { test } from "node:test"
import assert from "node:assert/strict"
import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { execFileSync } from "node:child_process"

const here = path.dirname(fileURLToPath(import.meta.url))
const script = path.join(here, "agent-runs.mjs")

const jsonl = (records) => records.map((r) => JSON.stringify(r)).join("\n") + "\n"
const assistant = (id, content) => ({ message: { role: "assistant", id, content } })
const user = (content) => ({ message: { role: "user", content } })
const use = (id, name, input) => ({ type: "tool_use", id, name, input })
const err = (id, text) => ({ type: "tool_result", tool_use_id: id, is_error: true, content: text })

function fixture(fresh) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "agent-runs-"))
  const proj = path.join(root, "proj")
  const def = path.join(root, "demo-agent.md")
  fs.writeFileSync(def, "---\nname: demo-agent\nmodel: sonnet\nmaxTurns: 4\n---\nbody\n")
  const main = jsonl([
    { timestamp: "2026-09-26T10:00:00Z", message: { role: "assistant", content: [use("call1", "Agent", { subagent_type: "demo-agent", prompt: "p" })] } },
    user([{ type: "tool_result", tool_use_id: "call1", content: "Async agent launched.\nagentId: abc123" }]),
    { message: { role: "assistant", content: [use("call2", "Agent", { subagent_type: "other-agent", prompt: "p" })] } },
  ])
  fs.mkdirSync(path.join(proj, "sess", "subagents"), { recursive: true })
  fs.writeFileSync(path.join(proj, "sess.jsonl"), main)
  fs.writeFileSync(path.join(proj, "sess-resumed.jsonl"), main)
  fs.writeFileSync(path.join(proj, "sess", "subagents", "agent-abc123.jsonl"), jsonl([
    assistant("m1", [use("t1", "Bash", { command: "git stash" })]),
    user([err("t1", "PreToolUse:Bash hook error: [node guard.mjs demo-agent]: demo-agent: this git command is not read-only and is refused: git stash")]),
    assistant("m1", [use("t2", "Bash", { command: "git checkout x && git diff" })]),
    user([err("t2", "This agent is isolated in the worktree /w, but this command is too complex to verify")]),
    assistant("m2", [use("t3", "Bash", { command: "npm test" })]),
    user([err("t3", "Exit code 1\n3 tests failed")]),
    assistant("m3", [use("t4", "Edit", { file_path: "/w/.claude/agents/x.md" })]),
    user([err("t4", "Claude requested permission to use Edit, but you haven't granted it yet.")]),
    assistant("m4", [{ type: "text", text: "Files changed: a.ts\nRulings: none" }]),
  ]))
  const sub = path.join(proj, "sess", "subagents", "agent-abc123.jsonl")
  if (!fresh) { const past = new Date(Date.now() - 86400000); fs.utimesSync(sub, past, past) }
  return { projects: root, def }
}

// `before` goes ahead of the definition (applies to all), `after` behind it (applies to that one).
function runJson(after = [], { before = [], fresh = false } = {}) {
  const { projects, def } = fixture(fresh)
  return JSON.parse(execFileSync("node", [script, `--projects=${projects}`, "--days=3650", "--json", ...before, def, ...after], { encoding: "utf8" }))
}

test("a call counted once across a resumed session's two files, and only for the named definition", () => {
  const runs = runJson()
  assert.equal(runs.length, 1)
  assert.equal(runs[0].name, "demo-agent")
  assert.equal(runs[0].agentId, "abc123")
})

test("each refusal is classified by who refused it; an ordinary failure is not a refusal", () => {
  const [r] = runJson()
  assert.deepEqual(r.refusals.map((x) => x.kind), ["hook", "isolation", "permission"])
  assert.match(r.refusals[0].message, /^demo-agent: this git command/)
})

test("turns count distinct assistant messages, and the report is the subagent's last text", () => {
  const [r] = runJson()
  assert.equal(r.turns, 4)
  assert.equal(r.words, 5)
  assert.equal(r.bash, 3)
  assert.equal(r.edits, 1)
})

test("flags: turns near maxTurns, a report over its cap, a missing required section", () => {
  const [r] = runJson(["--cap-words=3", "--expect=Questions"])
  assert.deepEqual(r.flags, ["turns 4/4", "report 5w > 3", "missing /Questions/"])
})

test("a cap in lines is measured in lines", () => {
  const [r] = runJson(["--cap-lines=1"])
  assert.deepEqual(r.flags, ["turns 4/4", "report 2L > 1"])
})

test("options written before any definition apply to every definition", () => {
  const [r] = runJson([], { before: ["--expect=Questions"] })
  assert.deepEqual(r.flags, ["turns 4/4", "missing /Questions/"])
})

test("a transcript still being written is flagged running and judged on nothing else", () => {
  const [r] = runJson(["--cap-words=3"], { fresh: true })
  assert.equal(r.running, true)
  assert.deepEqual(r.flags, ["running?"])
})
