#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0
// extract-hooks.mjs — write every hook command of one agent definition to its own file, so each can be run
// against a simulated hook input. A project agent's frontmatter hooks run only once its folder is trusted;
// they do run in a subagent of a `claude -p` session, unless that session passes disableAllHooks, so test
// each command here first — a false positive live costs the agent a turn.
//
//   node extract-hooks.mjs <agent.md> <out-dir>
//
// Prints one line per command: `<out-dir>/<event>-<n>.sh  matcher=<matcher>`. Run one with
//
//   printf '%s' '<hook input JSON>' | sh <out-dir>/<event>-<n>.sh; echo "exit=$?"
//
// Exit 2 blocks (its stderr reaches the agent); exit 0 lets the call through. Supports the `command: |`
// block form, the one-line `command: "..."` / `command: '...'` forms and a plain unquoted one-liner; any
// other `command:` line is reported and the exit code is 1, never skipped in silence.

import fs from "node:fs"
import path from "node:path"

const [file, out] = process.argv.slice(2)
if (!file || !out) {
  console.error("usage: extract-hooks.mjs <agent.md> <out-dir>")
  process.exit(2)
}
const frontmatter = fs.readFileSync(file, "utf8").split(/\n---\s*\n/)[0].split("\n")
fs.mkdirSync(out, { recursive: true })

const indent = (line) => line.match(/^\s*/)[0].length
let inHooks = false
let event = ""
let matcher = "*"
const counts = {}
for (let i = 0; i < frontmatter.length; i++) {
  const line = frontmatter[i]
  if (/^hooks:\s*$/.test(line)) {
    inHooks = true
    continue
  }
  if (!inHooks) continue
  if (/^\S/.test(line)) break
  const ev = line.match(/^ {2}(\w+):\s*$/)
  if (ev) {
    event = ev[1]
    matcher = "*"
    continue
  }
  const m = line.match(/matcher:\s*["']?([^"']*)["']?\s*$/)
  if (m) matcher = m[1]
  const block = line.match(/^(\s*)command:\s*\|\s*$/)
  const inline = line.match(/^\s*command:\s*(["'])(.*)\1\s*$/)
  const plain = line.match(/^\s*command:\s*([^|>"'\s].*?)\s*$/)
  let body
  if (block) {
    const lines = []
    const base = frontmatter[i + 1] ? indent(frontmatter[i + 1]) : 0
    for (let k = i + 1; k < frontmatter.length; k++) {
      const next = frontmatter[k]
      if (next.trim() && indent(next) < base) break
      lines.push(next.slice(base))
    }
    body = lines.join("\n").replace(/\s+$/, "") + "\n"
  } else if (inline) {
    body = inline[2] + "\n"
  } else if (plain) {
    body = plain[1] + "\n"
  } else {
    if (/^\s*command:/.test(line)) {
      console.error(`unsupported command form, not extracted: ${line.trim()}`)
      process.exitCode = 1
    }
    continue
  }
  counts[event] = (counts[event] ?? 0) + 1
  const target = path.join(out, `${event}-${counts[event]}.sh`)
  fs.writeFileSync(target, body)
  console.log(`${target}  matcher=${matcher}`)
}
