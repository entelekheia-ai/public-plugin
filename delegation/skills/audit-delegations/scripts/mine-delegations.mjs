#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0
// mine-delegations.mjs — find the delegations that recur in one repository's past sessions, and how much
// of each delegation's prompt is the same text written again.
//
//   node mine-delegations.mjs <repo-path> [--days=N] [--threshold=0.25] [--generic=0.3] [--all-targets] [--json]
//   node mine-delegations.mjs <repo-path> --calls                 # every call, one line each, with its index
//   node mine-delegations.mjs <repo-path> --show=<cluster> [--session=<id>]   # a cluster's full prompts
//   node mine-delegations.mjs <repo-path> --prompt=<i>[,<j>...]   # the full prompts of the named calls
//
// Population: every main-session transcript under ~/.claude/projects/*/ (or --projects=<dir>) that either
// wrote a file inside <repo-path> (Edit, Write, NotebookEdit) or dispatched an Agent call whose prompt
// names the repository's path. A session is counted by what it touched, never by the directory it was
// opened from, because sessions that edit a repository are often opened at a parent folder.
//
// Target: a session that wrote the repository also delegates work aimed elsewhere. A call **targets** the
// repository when its prompt names the repository's absolute path or its folder name as a word. Only
// targeting calls are clustered, unless --all-targets; `--calls` lists every call with the flag.
//
// Unit: the sentence, normalised (lowercased; paths, hashes and numbers replaced by placeholders; articles
// dropped), ignoring sentences under 20 characters. A sentence is **fixed** when prompts from two or more
// sessions carry it: text written again rather than written for the task. A fixed sentence carried by more
// than --generic (default 0.3) of all calls is **generic** — the caller's house phrases ("do the work
// yourself; launch no subagent") — and is left out of the clustering, because it joins roles that share
// nothing else. Generic sentences are still counted in the fixed share and listed on their own.
//
// Clustering: calls whose sets of non-generic fixed sentences reach a Jaccard similarity of --threshold
// join one cluster, transitively.
//
// What it cannot see: a rule restated in other words, or in another language. The fixed share is a floor,
// and the paraphrased half of a brief is found by reading the prompts.
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
const repoArg = args.find((a) => !a.startsWith("--"))
if (!repoArg) {
  console.error("usage: mine-delegations.mjs <repo-path> [--days=N] [--threshold=0.25] [--generic=0.3] [--all-targets] [--lands=<label>] [--json|--calls|--show=<n>|--prompt=<i>]")
  process.exit(2)
}
const repoDir = path.resolve(repoArg).replace(/\/+$/, "")
if (!fs.existsSync(repoDir)) {
  console.error(`mine-delegations.mjs: repository path does not exist: ${repoDir}`)
  process.exit(2)
}
const repo = repoDir + "/"
const repoName = path.basename(repoDir)
const days = Number(opt("days", "0"))
const threshold = Number(opt("threshold", "0.25"))
const genericShare = Number(opt("generic", "0.3"))
const allTargets = args.includes("--all-targets")
const projects = opt("projects", path.join(os.homedir(), ".claude", "projects"))
const since = days > 0 ? Date.now() - days * 86_400_000 : 0
const nameWord = new RegExp(`(^|[^\\w/-])${repoName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}($|[^\\w-])`, "i")
const landsFlag = args.some((a) => a.startsWith("--lands=")) ? opt("lands", "") : null

// --- Nested repositories and linked worktrees ---------------------------------------------------------
//
// A directory below repoDir, at most 3 levels down, skipping node_modules and .git, that holds a .git
// directory is a nested repository; its label is its path relative to repoDir. Symlinked directories are
// followed (by stat, not by the directory entry's own type), guarded against a symlink cycle by the chain
// of realpaths from repoDir down to the current directory — never by a global "already seen" set, which
// would wrongly skip a second, sibling symlink that happens to alias a realpath some other branch already
// walked. A nested repository reached only through such an alias still gets its own candidate at the link
// path, labelled with the real target's label when the real target lies inside the repository (so the two
// names fold into one canonical entity), else with the link path's own relative path. A directory holding a
// .git file is a linked worktree: its gitdir: line may be
// relative, resolved against the directory holding the .git file; when it points into
// <X>/.git/worktrees/<n>, it gives the worktree's owner X, and the worktree is labelled with X's label (or
// "." when X is repoDir itself) — a worktree whose owner is outside repoDir gets no label at all. A gitdir
// pointing into <X>/.git/modules/<name> is a submodule instead: the directory holding the .git file is
// itself a nested repository, labelled by its own path relative to repoDir.

const escapeRegex = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")

// A path boundary: not a "word" character of a path, and not a '.' that is itself followed by one — so
// "/x." and "/x," and "(/x)" and "/x:" all end a mention of "/x", but "/x-y" and "/x.md" do not.
const boundaryRegex = (abs) => new RegExp(`${escapeRegex(abs)}(?![A-Za-z0-9_-])(?!\\.[A-Za-z0-9_-])`, "g")

const nestedRepos = [] // { abs, label }
const worktreeDirs = [] // { abs, gitdir }

// realpathSync resolves every symlink in the path, including any the OS itself puts ahead of repoDir (e.g.
// /var -> /private/var on macOS). Comparing a resolved `real` against the unresolved `repoDir` would then
// spuriously fail a plain string-prefix check even for a target genuinely inside the repository, so the
// "is the real target inside the repository" check below is done against this resolved form instead.
let repoDirReal = repoDir
try {
  repoDirReal = fs.realpathSync(repoDir)
} catch {
  // repoDir itself is unreachable; walk() below will simply find nothing
}

const walk = (dir, depth, ancestors) => {
  let names
  try {
    names = fs.readdirSync(dir)
  } catch {
    return
  }
  for (const name of names) {
    if (name === "node_modules" || name === ".git") continue
    const full = path.join(dir, name)
    let st
    try {
      st = fs.statSync(full) // follows symlinks
    } catch {
      continue
    }
    if (!st.isDirectory()) continue
    let real
    try {
      real = fs.realpathSync(full)
    } catch {
      real = full
    }
    // A cycle: this directory's realpath is one of its own ancestors' along the current branch of the
    // walk. Skip it entirely — recursing would repeat forever, bounded here only by the depth cap. A
    // sibling branch that happens to alias the same realpath (two symlinks pointing at one target) is not
    // a cycle and must not be skipped: `ancestors` carries only the chain from repoDir down to `dir`,
    // never anything a different branch already visited.
    if (ancestors.has(real)) continue
    const gitPath = path.join(full, ".git")
    let gitStat
    try {
      gitStat = fs.statSync(gitPath)
    } catch {
      gitStat = null
    }
    if (gitStat?.isDirectory()) {
      let label = path.relative(repoDir, full)
      if (real !== full && real !== repoDirReal && real.startsWith(repoDirReal + path.sep)) {
        // Reached only through a symlink whose real target lies inside the repository: fold this alias
        // into the real target's own label instead of minting a new one for the link path.
        label = path.relative(repoDirReal, real)
      }
      nestedRepos.push({ abs: full, label })
    } else if (gitStat?.isFile()) {
      worktreeDirs.push({ abs: full, gitdir: gitPath })
    }
    if (depth < 3) walk(full, depth + 1, new Set([...ancestors, real]))
  }
}
{
  walk(repoDir, 1, new Set([repoDirReal]))
}

const ownerLabelFor = (owner) => {
  if (owner === repoDir) return "."
  const hit = nestedRepos.find((n) => n.abs === owner)
  return hit ? hit.label : null
}

const worktreeLandCandidates = [] // { abs, label } — resolved linked worktrees, owner inside repoDir
for (const wt of worktreeDirs) {
  let content
  try {
    content = fs.readFileSync(wt.gitdir, "utf8")
  } catch {
    continue
  }
  const line = content.split("\n").find((l) => l.trim().startsWith("gitdir:"))
  if (!line) continue
  let gitdirPath = line.slice(line.indexOf(":") + 1).trim()
  // A relative gitdir: line is relative to the directory holding the .git file itself (wt.abs), not to
  // that directory's parent.
  if (!path.isAbsolute(gitdirPath)) gitdirPath = path.resolve(wt.abs, gitdirPath)
  gitdirPath = gitdirPath.replace(/\/+$/, "")
  const moduleMatch = gitdirPath.match(/^(.*)\/\.git\/modules\/.+$/)
  if (moduleMatch) {
    // A submodule: the directory holding the .git file is a nested repository of its own.
    nestedRepos.push({ abs: wt.abs, label: path.relative(repoDir, wt.abs) })
    continue
  }
  const m = gitdirPath.match(/^(.*)\/\.git\/worktrees\/[^/]+$/)
  if (!m) continue
  const owner = m[1].replace(/\/+$/, "")
  const label = ownerLabelFor(owner)
  if (label !== null) worktreeLandCandidates.push({ abs: wt.abs, label })
}

// landCandidates: every path that competes for a mention, the repository itself included — sorted by
// descending path length so the longest candidate at a given text position claims it first, which is how
// a mention of a nested repository's path is kept from also being counted as a mention of "."
const landCandidates = [
  ...nestedRepos.map((n) => ({ abs: n.abs, label: n.label })),
  ...worktreeLandCandidates,
]
const allCandidates = [{ abs: repoDir, label: "." }, ...landCandidates].sort((a, b) => b.abs.length - a.abs.length)

const landsFor = (prompt) => {
  const claimed = new Set() // text positions already attributed to a longer candidate
  const tally = new Map() // label -> { count, maxLen }
  for (const cand of allCandidates) {
    const re = boundaryRegex(cand.abs)
    let m
    while ((m = re.exec(prompt))) {
      if (!claimed.has(m.index)) {
        claimed.add(m.index)
        const cur = tally.get(cand.label) ?? { count: 0, maxLen: 0 }
        cur.count += 1
        cur.maxLen = Math.max(cur.maxLen, cand.abs.length)
        tally.set(cand.label, cur)
      }
      if (re.lastIndex === m.index) re.lastIndex += 1 // guard a zero-width match
    }
  }
  if (!tally.size) return null // no mention at all
  return [...tally.entries()].sort((a, b) => b[1].count - a[1].count || b[1].maxLen - a[1].maxLen)[0][0]
}

const normalise = (sentence) =>
  sentence
    .trim()
    .toLowerCase()
    .replace(/(?:\/[\w.@+-]+){2,}\/?/g, "<path>")
    .replace(/\b[0-9a-f]{7,40}\b/g, "<sha>")
    .replace(/\d+/g, "<n>")
    .replace(/[*`_>#-]+/g, " ")
    .replace(/\b(the|a|an|this|that|these|those)\b/g, " ")
    .replace(/\s+/g, " ")
    .trim()

const sentences = (prompt) =>
  prompt
    .split(/\n+|(?<=[.!?;])\s+(?=[A-Z*`(])/)
    .map((s) => ({ raw: s.trim(), key: normalise(s) }))
    .filter((s) => s.key.length >= 20)

const alias = (model) => model.replace(/^claude-(opus|sonnet|haiku|fable)-.*$/, "$1")

const calls = []
const sessions = new Set()
for (const dir of fs.readdirSync(projects)) {
  const full = path.join(projects, dir)
  if (!fs.statSync(full).isDirectory()) continue
  for (const file of fs.readdirSync(full)) {
    if (!file.endsWith(".jsonl")) continue
    let text
    try {
      text = fs.readFileSync(path.join(full, file), "utf8")
    } catch {
      continue
    }
    if (!text.includes(repoDir)) continue
    let touched = false
    let first
    const seen = new Set()
    const found = []
    for (const raw of text.split("\n")) {
      if (!raw) continue
      let rec
      try {
        rec = JSON.parse(raw)
      } catch {
        continue
      }
      if (!first && rec.timestamp) first = Date.parse(rec.timestamp)
      const content = rec.message?.content
      if (!Array.isArray(content)) continue
      for (const block of content) {
        if (block.type !== "tool_use" || seen.has(block.id)) continue
        seen.add(block.id)
        const input = block.input ?? {}
        if (["Edit", "Write", "NotebookEdit"].includes(block.name)) {
          const p = input.file_path ?? input.notebook_path ?? ""
          if (p.startsWith(repo)) touched = true
        }
        if ((block.name === "Agent" || block.name === "Task") && typeof input.prompt === "string") {
          const targets = input.prompt.includes(repoDir) || nameWord.test(input.prompt)
          if (input.prompt.includes(repoDir)) touched = true
          found.push({
            session: file.slice(0, 8),
            date: rec.timestamp?.slice(0, 10) ?? "",
            type: input.subagent_type ?? "general-purpose",
            model: input.model ? alias(input.model) : "(definition or inherited)",
            description: input.description ?? "",
            prompt: input.prompt,
            targets,
            lands: targets ? (landsFor(input.prompt) ?? ".") : "-",
          })
        }
      }
    }
    if (!touched || (since && first < since)) continue
    sessions.add(file.slice(0, 8))
    calls.push(...found)
  }
}
calls.forEach((c, i) => (c.index = i + 1))

let pool = calls.filter((c) => allTargets || c.targets)
if (landsFlag !== null) pool = pool.filter((c) => c.targets && c.lands === landsFlag)
const split = new Map(pool.map((c) => [c, sentences(c.prompt)]))
const sessionsOf = new Map()
const callsOf = new Map()
for (const c of pool) {
  for (const s of new Set(split.get(c).map((x) => x.key))) {
    if (!sessionsOf.has(s)) sessionsOf.set(s, new Set())
    sessionsOf.get(s).add(c.session)
    callsOf.set(s, (callsOf.get(s) ?? 0) + 1)
  }
}
const isFixed = (key) => sessionsOf.get(key)?.size >= 2
const isGeneric = (key) => isFixed(key) && callsOf.get(key) / pool.length > genericShare
const sets = new Map(
  pool.map((c) => [c, new Set(split.get(c).filter((s) => isFixed(s.key) && !isGeneric(s.key)).map((s) => s.key))]),
)

const parent = new Map(pool.map((c) => [c, c]))
const find = (c) => (parent.get(c) === c ? c : (parent.set(c, find(parent.get(c))), parent.get(c)))
for (let i = 0; i < pool.length; i++) {
  for (let j = i + 1; j < pool.length; j++) {
    const a = sets.get(pool[i])
    const b = sets.get(pool[j])
    if (!a.size || !b.size) continue
    let inter = 0
    for (const l of a) if (b.has(l)) inter++
    if (inter / (a.size + b.size - inter) >= threshold) parent.set(find(pool[i]), find(pool[j]))
  }
}

const groups = new Map()
for (const c of pool) {
  const root = find(c)
  if (!groups.has(root)) groups.set(root, [])
  groups.get(root).push(c)
}

const clusters = [...groups.values()]
  .filter((members) => members.length >= 2)
  .map((members) => {
    const counts = new Map()
    let total = 0
    let fixedChars = 0
    for (const c of members) {
      for (const l of sets.get(c)) counts.set(l, (counts.get(l) ?? 0) + 1)
      total += c.prompt.length
      for (const s of split.get(c)) if (isFixed(s.key)) fixedChars += s.raw.length
    }
    const tally = (key) =>
      Object.entries(members.reduce((acc, c) => ((acc[c[key]] = (acc[c[key]] ?? 0) + 1), acc), {}))
        .sort((x, y) => y[1] - x[1])
        .map(([k, n]) => `${k} ×${n}`)
    const landsTally = Object.entries(
      members.reduce((acc, c) => ((acc[c.lands] = (acc[c.lands] ?? 0) + 1), acc), {}),
    )
      .sort((x, y) => y[1] - x[1])
      .map(([label, n]) => ({ label, n }))
    return {
      members,
      size: members.length,
      sessions: new Set(members.map((c) => c.session)).size,
      fixed: total ? fixedChars / total : 0,
      types: tally("type"),
      models: tally("model"),
      lands: landsTally,
      calls: members.map((c) => `#${c.index} ${c.date} ${c.session} ${c.description}`),
      topLines: [...counts.entries()]
        .filter(([, n]) => n >= 2)
        .sort((x, y) => y[1] - x[1])
        .slice(0, 12)
        .map(([l, n]) => ({ n, line: l.slice(0, 160) })),
    }
  })
  .sort((a, b) => b.sessions - a.sessions || b.size - a.size)
clusters.forEach((cl, k) => cl.members.forEach((c) => (c.cluster = k + 1)))

const generic = [...callsOf.entries()]
  .filter(([k]) => isGeneric(k))
  .sort((x, y) => y[1] - x[1])
  .map(([k, n]) => ({ n, line: k.slice(0, 160) }))

const show = Number(opt("show", "0"))
const promptIndexes = opt("prompt", "")
  .split(",")
  .map(Number)
  .filter((n) => n > 0)
const onlySession = opt("session", "")

if (promptIndexes.length) {
  for (const n of promptIndexes) {
    const c = calls[n - 1]
    if (!c) {
      console.error(`no call #${n}: there are ${calls.length}`)
      process.exit(2)
    }
    console.log(`\n===== #${c.index} ${c.date} ${c.session} [${c.type} / ${c.model}] ${c.description}\n${c.prompt}`)
  }
} else if (show) {
  const cluster = clusters[show - 1]
  if (!cluster) {
    console.error(`no cluster ${show}: there are ${clusters.length}`)
    process.exit(2)
  }
  for (const c of cluster.members) {
    if (onlySession && c.session !== onlySession) continue
    console.log(`\n===== #${c.index} ${c.date} ${c.session} [${c.type} / ${c.model}] ${c.description}\n${c.prompt}`)
  }
} else if (args.includes("--calls")) {
  console.log("index  cluster  target  lands            date        session   type / model                          chars  description")
  for (const c of calls) {
    const kind = `${c.type} / ${c.model}`.slice(0, 36).padEnd(36)
    console.log(
      `#${String(c.index).padEnd(5)} ${String(c.cluster ?? "-").padEnd(8)} ${(c.targets ? "yes" : "no").padEnd(7)} ` +
        `${c.lands.padEnd(16)} ${c.date}  ${c.session}  ${kind}  ${String(c.prompt.length).padStart(5)}  ${c.description}`,
    )
  }
} else {
  const targetingCalls = calls.filter((c) => c.targets)
  const landsAll = Object.entries(
    targetingCalls.reduce((acc, c) => ((acc[c.lands] = (acc[c.lands] ?? 0) + 1), acc), {}),
  )
    .sort((x, y) => y[1] - x[1])
    .map(([label, n]) => ({ label, n }))
  const summary = {
    repo: repoDir,
    sessions: sessions.size,
    calls: calls.length,
    targeting: targetingCalls.length,
    clustered: pool.length,
    oneOff: pool.length - clusters.reduce((s, c) => s + c.size, 0),
    threshold,
    genericShare,
    generic,
    lands: landsAll,
    clusters: clusters.map(({ members, ...rest }) => rest),
  }
  if (args.includes("--json")) {
    console.log(JSON.stringify(summary, null, 2))
  } else {
    console.log(
      `${summary.repo}: ${summary.sessions} sessions, ${summary.calls} Agent calls, ${summary.targeting} targeting this ` +
        `repository, ${clusters.length} clusters of 2+, ${summary.oneOff} one-off calls ` +
        `(threshold ${threshold}; --calls lists every call, one-off ones included)`,
    )
    if (generic.length) {
      console.log(`\ngeneric sentences, left out of clustering (carried by >${Math.round(genericShare * 100)}% of calls):`)
      for (const { n, line } of generic.slice(0, 10)) console.log(`  ${n}× ${line}`)
    }
    clusters.forEach((c, k) => {
      console.log(`\n## cluster ${k + 1}: ${c.size} calls in ${c.sessions} sessions, ${Math.round(c.fixed * 100)}% of prompt text fixed`)
      console.log(`types: ${c.types.join(", ")} | models: ${c.models.join(", ")}`)
      console.log(`lands: ${c.lands.map(({ label, n }) => `${label} ×${n}`).join(", ")}`)
      for (const d of c.calls) console.log(`  - ${d}`)
      console.log("  fixed sentences, by how many of these calls carry each:")
      for (const { n, line } of c.topLines) console.log(`    ${n}× ${line}`)
    })
  }
}
