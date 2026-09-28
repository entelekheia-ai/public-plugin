#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0
// agent-runs.mjs — how the runs of existing subagent definitions actually went: turns against the
// definition's ceiling, the refusals each run hit and where they came from, and the report against its cap.
//
//   node agent-runs.mjs [--days=30] [--projects=<dir>] [--refusals] [--json] \
//                       <definition.md> [--cap-words=N | --cap-lines=N] [--expect=<regex>]... \
//                       [<definition.md> [its own options]...]
//
// Each positional argument is an agent definition (`.claude/agents/<name>.md`); its frontmatter gives the
// `name` the dispatches are matched on and the `maxTurns` a run is measured against. Definitions from
// several repositories may be passed together, which is how two sibling definitions are compared.
// --cap-words, --cap-lines and --expect belong to the definition written just before them, because each
// body states its own cap and its own required sections; written before any definition, they apply to all.
//
// Population: every Agent call under ~/.claude/projects/ (or --projects) whose `subagent_type` is one of
// the names, in transcripts modified within --days. A call is counted once by its tool_use_id, since a
// resumed session rewrites its whole history into a new file. The call's result names the agent id, which
// finds the subagent's own transcript (`agent-<id>.jsonl`, at any depth — Workflow runs nest them).
//
// Per run: turns (distinct assistant messages), Bash and Edit/Write calls, the report (the subagent's
// last assistant text — a background dispatch returns only a stub to the caller, so the call's result is
// not the report), and every refused tool call, classified by who refused it:
//   hook       a PreToolUse hook — the definition's frontmatter, or a settings hook
//   isolation  Claude Code's worktree isolation, which refuses a command it cannot prove stays inside
//   permission the permission system
// An ordinary failing command (a test that fails, a missing file) is not a refusal and is not counted.
//
// Flags: a run at 90 % of maxTurns or more, a report over its cap, a report missing an --expect pattern
// (a required section, copied from the body's own heading, e.g. --expect='Rulings'). A run whose
// transcript changed in the last 10 minutes is flagged `running?` and left out of the medians: its last
// text is a progress note, not a report — the review running this script is itself one such run.
// --refusals prints each refusal's date, command and message, which is what tells a rule the body should
// state from a hook that fires on the wrong input.
//
// Read-only. It prints; it writes nothing.

import fs from "node:fs"
import os from "node:os"
import path from "node:path"

const args = process.argv.slice(2)
const opt = (name, fallback) => {
  const hit = args.find((a) => a.startsWith(`--${name}=`))
  return hit ? hit.slice(name.length + 3) : fallback
}
const flag = (name) => args.includes(`--${name}`)

// Walk the arguments in order: a per-definition option attaches to the definition before it.
const global = { capWords: 0, capLines: 0, expects: [] }
const defs = []
for (const a of args) {
  if (!a.startsWith("--")) { defs.push({ file: a, capWords: 0, capLines: 0, expects: [] }); continue }
  const target = defs.at(-1) || global
  if (a.startsWith("--cap-words=")) target.capWords = Number(a.slice(12))
  else if (a.startsWith("--cap-lines=")) target.capLines = Number(a.slice(12))
  else if (a.startsWith("--expect=")) target.expects.push(new RegExp(a.slice(9), "i"))
}
if (defs.length === 0) {
  console.error("usage: agent-runs.mjs [--days=30] [--refusals] [--json] <definition.md> [--cap-words=N|--cap-lines=N] [--expect=<regex>]... [...]")
  process.exit(2)
}

const days = Number(opt("days", "30"))
const projects = opt("projects", path.join(os.homedir(), ".claude", "projects"))
const since = Date.now() - days * 86400000

function frontmatter(file) {
  const text = fs.readFileSync(file, "utf8")
  const m = text.match(/^---\n([\s\S]*?)\n---/)
  if (!m) throw new Error(`${file}: no frontmatter`)
  const field = (k) => (m[1].match(new RegExp(`^${k}:\\s*(.+)$`, "m")) || [])[1]?.trim()
  const name = field("name")
  if (!name) throw new Error(`${file}: no name in frontmatter`)
  return { name, maxTurns: Number(field("maxTurns") || 0), file }
}
const agents = new Map(defs.map((d) => {
  const fm = frontmatter(d.file)
  return [fm.name, { ...fm, capWords: d.capWords || global.capWords, capLines: d.capLines || global.capLines,
    expects: [...global.expects, ...d.expects] }]
}))

function walk(dir, out = []) {
  let entries
  try { entries = fs.readdirSync(dir, { withFileTypes: true }) } catch { return out }
  for (const e of entries) {
    const p = path.join(dir, e.name)
    if (e.isDirectory()) walk(p, out)
    else if (e.name.endsWith(".jsonl")) out.push(p)
  }
  return out
}

function records(file) {
  const out = []
  for (const line of fs.readFileSync(file, "utf8").split("\n")) {
    if (!line) continue
    try { out.push(JSON.parse(line)) } catch {}
  }
  return out
}

const text = (content) =>
  typeof content === "string" ? content : (content || []).map((b) => b.text || "").join("\n")

function classify(message) {
  if (/isolated in the worktree/i.test(message)) return "isolation"
  if (/hook error|blocked by .*hook/i.test(message)) return "hook"
  if (/permission to use|requires approval|denied by|was denied|user rejected|doesn't want to proceed/i.test(message)) return "permission"
  return null
}

const files = walk(projects).filter((f) => { try { return fs.statSync(f).mtimeMs >= since } catch { return false } })
const subagentFile = new Map()
const calls = new Map()
const agentIds = new Map()
const names = [...agents.keys()]
for (const f of files) {
  const base = path.basename(f).match(/^agent-([a-z0-9]+)\.jsonl$/)
  if (base && f.includes(`${path.sep}subagents${path.sep}`)) { subagentFile.set(base[1], f); continue }
  const raw = fs.readFileSync(f, "utf8")
  if (!names.some((n) => raw.includes(n))) continue
  for (const r of records(f)) {
    const content = r.message?.content
    if (!Array.isArray(content)) continue
    for (const b of content) {
      if (b.type === "tool_use" && b.name === "Agent" && agents.has(b.input?.subagent_type) && !calls.has(b.id))
        calls.set(b.id, { name: b.input.subagent_type, ts: r.timestamp || "", background: b.input.run_in_background !== false })
      if (b.type === "tool_result") {
        const m = text(b.content).match(/agentId:\s*([a-z0-9]+)/)
        if (m) agentIds.set(b.tool_use_id, m[1])
      }
    }
  }
}

function run(id, call) {
  const agentId = agentIds.get(id)
  const file = agentId && subagentFile.get(agentId)
  const out = { name: call.name, date: call.ts.slice(0, 10), agentId: agentId || null, transcript: Boolean(file),
    turns: 0, bash: 0, edits: 0, words: 0, lines: 0, running: false, report: "", refusals: [] }
  if (!file) return out
  out.running = Date.now() - fs.statSync(file).mtimeMs < 10 * 60000
  const seen = new Set()
  const commands = new Map()
  let last = ""
  for (const r of records(file)) {
    const content = r.message?.content
    if (!Array.isArray(content)) continue
    if (r.message.role === "assistant") {
      seen.add(r.message.id || r.uuid)
      const t = content.filter((b) => b.type === "text").map((b) => b.text).join("\n").trim()
      if (t) last = t
    }
    for (const b of content) {
      if (b.type === "tool_use") {
        if (b.name === "Bash") out.bash++
        if (/^(Edit|Write|NotebookEdit)$/.test(b.name)) out.edits++
        commands.set(b.id, b.input?.command || b.input?.file_path || JSON.stringify(b.input))
      }
      if (b.type === "tool_result" && b.is_error) {
        const message = text(b.content)
        const kind = classify(message)
        // A hook error echoes the hook's own command in brackets before what it printed: keep what it printed.
        const said = kind === "hook" && message.lastIndexOf("]: ") >= 0 ? message.slice(message.lastIndexOf("]: ") + 3) : message
        if (kind) out.refusals.push({ kind, date: String(r.timestamp || "").slice(0, 10), command: String(commands.get(b.tool_use_id) || "").replace(/\s+/g, " ").slice(0, 160), message: said.replace(/\s+/g, " ").slice(0, 240) })
      }
    }
  }
  out.turns = seen.size
  out.report = last
  out.words = last ? last.split(/\s+/).length : 0
  out.lines = last ? last.split("\n").length : 0
  return out
}

const runs = [...calls].map(([id, call]) => run(id, call)).sort((a, b) => a.name.localeCompare(b.name) || a.date.localeCompare(b.date))

function flags(r) {
  const def = agents.get(r.name)
  const f = []
  if (!r.transcript) return ["no transcript"]
  if (r.running) return ["running?"]
  if (def.maxTurns && r.turns >= 0.9 * def.maxTurns) f.push(`turns ${r.turns}/${def.maxTurns}`)
  if (def.capWords && r.words > def.capWords) f.push(`report ${r.words}w > ${def.capWords}`)
  if (def.capLines && r.lines > def.capLines) f.push(`report ${r.lines}L > ${def.capLines}`)
  for (const re of def.expects) if (!re.test(r.report)) f.push(`missing /${re.source}/`)
  return f
}

if (flag("json")) {
  console.log(JSON.stringify(runs.map((r) => ({ ...r, report: undefined, flags: flags(r) })), null, 2))
  process.exit(0)
}

const median = (xs) => { if (!xs.length) return 0; const s = [...xs].sort((a, b) => a - b); return s[Math.floor(s.length / 2)] }
for (const [name, def] of agents) {
  const mine = runs.filter((r) => r.name === name)
  const read = mine.filter((r) => r.transcript && !r.running)
  const kinds = {}
  for (const r of read) for (const x of r.refusals) kinds[x.kind] = (kinds[x.kind] || 0) + 1
  console.log(`\n${name}  (${def.file})`)
  console.log(`  runs ${mine.length} (${read.length} with a transcript) · turns median ${median(read.map((r) => r.turns))} max ${Math.max(0, ...read.map((r) => r.turns))} of maxTurns ${def.maxTurns || "unset"} · report words median ${median(read.map((r) => r.words))} max ${Math.max(0, ...read.map((r) => r.words))}`)
  console.log(`  refusals: ${Object.entries(kinds).map(([k, n]) => `${k} ${n}`).join(", ") || "none"}`)
  for (const r of mine) {
    const f = flags(r)
    console.log(`  ${r.date} ${String(r.agentId || "-").slice(0, 8).padEnd(8)} turns ${String(r.turns).padStart(3)} bash ${String(r.bash).padStart(3)} edits ${String(r.edits).padStart(3)} report ${String(r.words).padStart(4)}w/${String(r.lines).padStart(3)}L refusals ${r.refusals.length}${f.length ? "  ⚑ " + f.join("; ") : ""}`)
    if (flag("refusals")) for (const x of r.refusals) console.log(`      [${x.kind}] ${x.date} ${x.command}\n        → ${x.message}`)
  }
}
