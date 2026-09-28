// SPDX-License-Identifier: Apache-2.0
// mine-delegations.test.mjs — decisions about "lands": which repository a call's work targets when the
// repository path handed to the miner absorbs nested repositories underneath it.
//
// Builds a temporary "projects" directory (transcripts) and a temporary repository tree (nested .git
// directories, a .git file standing in for a linked worktree) and runs the script as a subprocess against
// both, via --projects=<dir>.

import { test } from "node:test"
import assert from "node:assert/strict"
import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { execFileSync } from "node:child_process"

const here = path.dirname(fileURLToPath(import.meta.url))
const script = path.join(here, "mine-delegations.mjs")

function mkTmp(prefix) {
  return fs.mkdtempSync(path.join(os.tmpdir(), prefix))
}

function writeSession(projectsDir, sessionId, records) {
  const dir = path.join(projectsDir, "proj")
  fs.mkdirSync(dir, { recursive: true })
  const lines = records.map((r) => JSON.stringify(r)).join("\n")
  fs.writeFileSync(path.join(dir, `${sessionId}.jsonl`), lines + "\n")
}

function toolUse(id, name, input) {
  return { timestamp: "2026-09-20T00:00:00Z", message: { content: [{ type: "tool_use", id, name, input }] } }
}

function run(repoDir, projectsDir, extraArgs = []) {
  const out = execFileSync(
    process.execPath,
    [script, repoDir, `--projects=${projectsDir}`, ...extraArgs],
    { encoding: "utf8" },
  )
  return out
}

function runJson(repoDir, projectsDir, extraArgs = []) {
  return JSON.parse(run(repoDir, projectsDir, ["--json", ...extraArgs]))
}

// --- Build a repository tree ------------------------------------------------------------------------
//
// repo/                        <- repoDir, the repository path handed to the miner
//   .git/                      <- makes repo itself a git repo (irrelevant to nested detection)
//   packages/
//     alpha/
//       .git/                  <- nested repo, label "packages/alpha" (2 levels down)
//     beta/
//       .git/                  <- nested repo, label "packages/beta" (2 levels down)
//   deep/
//     x/
//       y/
//         .git/                <- nested repo, label "deep/x/y" (3 levels down)
//   too-deep/
//     a/
//       b/
//         c/
//           .git/              <- 4 levels down: NOT a nested repo
//   node_modules/
//     pkg/
//       .git/                  <- inside node_modules: skipped entirely
//   packages/
//     alpha-wt/                <- a .git FILE, a linked worktree owned by packages/alpha
//
// A worktree owned by a repository outside repoDir gets no label.

function buildRepoTree() {
  const repoDir = mkTmp("mine-repo-")
  fs.mkdirSync(path.join(repoDir, ".git"))
  fs.mkdirSync(path.join(repoDir, "packages", "alpha", ".git"), { recursive: true })
  fs.mkdirSync(path.join(repoDir, "packages", "beta", ".git"), { recursive: true })
  fs.mkdirSync(path.join(repoDir, "deep", "x", "y", ".git"), { recursive: true })
  fs.mkdirSync(path.join(repoDir, "too-deep", "a", "b", "c", ".git"), { recursive: true })
  fs.mkdirSync(path.join(repoDir, "node_modules", "pkg", ".git"), { recursive: true })

  // A linked worktree owned by packages/alpha (points at packages/alpha/.git/worktrees/wt1).
  fs.mkdirSync(path.join(repoDir, "packages", "alpha-wt"))
  fs.writeFileSync(
    path.join(repoDir, "packages", "alpha-wt", ".git"),
    `gitdir: ${path.join(repoDir, "packages", "alpha", ".git", "worktrees", "wt1")}\n`,
  )

  // A linked worktree owned by the repository itself (repoDir/.git/worktrees/main-wt) -> label ".".
  fs.mkdirSync(path.join(repoDir, "self-wt"))
  fs.writeFileSync(
    path.join(repoDir, "self-wt", ".git"),
    `gitdir: ${path.join(repoDir, ".git", "worktrees", "main-wt")}\n`,
  )

  // A linked worktree owned by something outside repoDir entirely -> no label.
  const outside = mkTmp("mine-outside-")
  fs.mkdirSync(path.join(repoDir, "outside-wt"))
  fs.writeFileSync(
    path.join(repoDir, "outside-wt", ".git"),
    `gitdir: ${path.join(outside, ".git", "worktrees", "wtx")}\n`,
  )

  return repoDir
}

test("a call whose prompt names a nested repository lands there, not at the parent", () => {
  const repoDir = buildRepoTree()
  const projectsDir = mkTmp("mine-projects-")
  const alpha = path.join(repoDir, "packages", "alpha")
  writeSession(projectsDir, "sess0001", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Work only in ${alpha}/ and fix the bug there.`,
      subagent_type: "general-purpose",
      description: "fix alpha bug",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("fix alpha bug"))
  assert.ok(line, "expected the call line in --calls output")
  assert.match(line, /packages\/alpha/, "the lands column should name the nested repository, not '.'")
})

test("a call whose prompt names only the parent repository lands at '.'", () => {
  const repoDir = buildRepoTree()
  const projectsDir = mkTmp("mine-projects-")
  writeSession(projectsDir, "sess0002", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Work only in ${repoDir}/ and fix the root README.`,
      subagent_type: "general-purpose",
      description: "fix root readme",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("fix root readme"))
  assert.ok(line)
  const cols = line.trim().split(/\s+/)
  // index cluster target lands ...
  assert.equal(cols[2], "yes")
  assert.equal(cols[3], ".")
})

test("a non-targeting call lands at '-'", () => {
  const repoDir = buildRepoTree()
  const projectsDir = mkTmp("mine-projects-")
  const elsewhere = mkTmp("mine-elsewhere-")
  writeSession(projectsDir, "sess0003", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Work only in ${elsewhere}/ and fix something unrelated.`,
      subagent_type: "general-purpose",
      description: "unrelated fix",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("unrelated fix"))
  assert.ok(line)
  const cols = line.trim().split(/\s+/)
  assert.equal(cols[2], "no")
  assert.equal(cols[3], "-")
})

test("a 4-levels-deep .git directory is not detected as a nested repository", () => {
  const repoDir = buildRepoTree()
  const projectsDir = mkTmp("mine-projects-")
  const tooDeep = path.join(repoDir, "too-deep", "a", "b", "c")
  writeSession(projectsDir, "sess0004", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Work only in ${tooDeep}/ and fix things.`,
      subagent_type: "general-purpose",
      description: "too deep fix",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("too deep fix"))
  assert.ok(line)
  const cols = line.trim().split(/\s+/)
  // not a recognised nested repository -> falls back to the default "."
  assert.equal(cols[3], ".")
})

test("a .git directory inside node_modules is never a nested repository", () => {
  const repoDir = buildRepoTree()
  const projectsDir = mkTmp("mine-projects-")
  const pkg = path.join(repoDir, "node_modules", "pkg")
  writeSession(projectsDir, "sess0005", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Work only in ${pkg}/ and fix things.`,
      subagent_type: "general-purpose",
      description: "node modules fix",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("node modules fix"))
  assert.ok(line)
  const cols = line.trim().split(/\s+/)
  assert.equal(cols[3], ".")
})

test("a call naming a linked worktree lands at the label of the worktree's owner repository", () => {
  const repoDir = buildRepoTree()
  const projectsDir = mkTmp("mine-projects-")
  const alphaWt = path.join(repoDir, "packages", "alpha-wt")
  writeSession(projectsDir, "sess0006", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Work only in ${alphaWt}/ and fix things there.`,
      subagent_type: "general-purpose",
      description: "alpha worktree fix",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("alpha worktree fix"))
  assert.ok(line)
  const cols = line.trim().split(/\s+/)
  assert.equal(cols[3], "packages/alpha")
})

// A dedicated, small fixture for the self-worktree test below: a nested repo whose label is short enough
// that its own absolute path is SHORTER than the self-owned worktree directory's absolute path. That gap
// is what lets a correct worktree-owner resolution (which competes using the worktree directory's own,
// longer, path) win a tie against the nested repo, while a generic "the repository's path is a literal
// prefix of the mentioned text" fallback (which would only have the repository's own, shorter, path to
// compete with) loses that same tie. Without this gap, both mechanisms produce the same answer and the
// test cannot tell worktree-owner resolution apart from that fallback.
function buildSelfWorktreeTieTree() {
  const repoDir = mkTmp("mine-repo-tie-")
  fs.mkdirSync(path.join(repoDir, ".git"))
  fs.mkdirSync(path.join(repoDir, "n", ".git"), { recursive: true }) // nested repo, label "n"
  fs.mkdirSync(path.join(repoDir, "self-wt")) // longer than "n" once joined to repoDir
  fs.writeFileSync(
    path.join(repoDir, "self-wt", ".git"),
    `gitdir: ${path.join(repoDir, ".git", "worktrees", "main-wt")}\n`,
  )
  return repoDir
}

test("a call naming a worktree owned by the repository itself lands at '.'", () => {
  const repoDir = buildSelfWorktreeTieTree()
  const projectsDir = mkTmp("mine-projects-")
  const selfWt = path.join(repoDir, "self-wt")
  const nested = path.join(repoDir, "n")
  assert.ok(selfWt.length > nested.length, "fixture assumption: the self-worktree path is the longer one")
  writeSession(projectsDir, "sess0007", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      // The nested repo is mentioned once too, so "." is not simply the default for an unmentioned call —
      // resolving the self-owned worktree correctly is what makes "." win this tie.
      prompt: `Work only in ${selfWt}/ and fix things there. Compare once against ${nested}/.`,
      subagent_type: "general-purpose",
      description: "self worktree fix",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("self worktree fix"))
  assert.ok(line)
  const cols = line.trim().split(/\s+/)
  assert.equal(cols[3], ".")
})

test("a call naming a worktree owned outside the repository path gets no label, and lands at '.' only when nothing else is mentioned", () => {
  const repoDir = buildRepoTree()
  const projectsDir = mkTmp("mine-projects-")
  const outsideWt = path.join(repoDir, "outside-wt")
  writeSession(projectsDir, "sess0008", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Work only in ${outsideWt}/ and fix things there.`,
      subagent_type: "general-purpose",
      description: "outside worktree fix",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("outside worktree fix"))
  assert.ok(line)
  const cols = line.trim().split(/\s+/)
  assert.equal(cols[3], ".")
})

// A dedicated fixture, matching buildSelfWorktreeTieTree's shape but with the worktree owned OUTSIDE
// repoDir instead of by repoDir itself: a nested repo short enough ("n") that its own absolute path is
// SHORTER than the outside-owned worktree directory's absolute path. If the outside worktree were (wrongly)
// given its own "." candidate the way a self-owned worktree correctly is, that candidate's longer path
// would win this tie over the nested repo; since the outside worktree gets no label at all, only the
// generic "repository path is a literal prefix" fallback competes for "." here, using the repository's own
// (shorter) path — so the nested repo wins the tie instead.
function buildOutsideWorktreeTieTree() {
  const repoDir = mkTmp("mine-repo-tie-out-")
  fs.mkdirSync(path.join(repoDir, ".git"))
  fs.mkdirSync(path.join(repoDir, "n", ".git"), { recursive: true }) // nested repo, label "n"
  const outside = mkTmp("mine-outside-")
  fs.mkdirSync(path.join(repoDir, "outside-wt")) // longer than "n" once joined to repoDir
  fs.writeFileSync(
    path.join(repoDir, "outside-wt", ".git"),
    `gitdir: ${path.join(outside, ".git", "worktrees", "wtx")}\n`,
  )
  return repoDir
}

test("a call naming a worktree owned outside the repository path, plus one nested mention, lands at the nested label — the outside worktree itself never competes", () => {
  const repoDir = buildOutsideWorktreeTieTree()
  const projectsDir = mkTmp("mine-projects-")
  const outsideWt = path.join(repoDir, "outside-wt")
  const nested = path.join(repoDir, "n")
  assert.ok(outsideWt.length > nested.length, "fixture assumption: the outside worktree path is the longer one")
  writeSession(projectsDir, "sess0008b", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      // One mention each: if the outside worktree were (wrongly) given its own, longer, "." candidate the
      // way a self-owned worktree is, "." would win this tie instead of the nested repo.
      prompt: `Work only in ${outsideWt}/ and fix things there. Compare once against ${nested}/.`,
      subagent_type: "general-purpose",
      description: "outside worktree plus nested",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("outside worktree plus nested"))
  assert.ok(line)
  const cols = line.trim().split(/\s+/)
  assert.equal(cols[3], "n")
})

test("lands counts a path followed by a backtick, a quote or end of text, not only a slash", () => {
  const repoDir = buildRepoTree()
  const projectsDir = mkTmp("mine-projects-")
  const alpha = path.join(repoDir, "packages", "alpha")
  writeSession(projectsDir, "sess0009", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt:
        `Read \`${alpha}\` then check "${alpha}" then note ${alpha}\nand finally ${alpha}`,
      subagent_type: "general-purpose",
      description: "quoting variants",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("quoting variants"))
  assert.ok(line)
  const cols = line.trim().split(/\s+/)
  assert.equal(cols[3], "packages/alpha")
})

test("a tie in mention count goes to the longest path", () => {
  const repoDir = buildRepoTree()
  const projectsDir = mkTmp("mine-projects-")
  const alpha = path.join(repoDir, "packages", "alpha")
  const deep = path.join(repoDir, "deep", "x", "y")
  writeSession(projectsDir, "sess0010", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Compare ${alpha}/ against ${deep}/ once each.`,
      subagent_type: "general-purpose",
      description: "tie break case",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("tie break case"))
  assert.ok(line)
  const cols = line.trim().split(/\s+/)
  assert.ok(alpha.length > deep.length, "fixture assumption: packages/alpha's absolute path is the longer one")
  assert.equal(cols[3], "packages/alpha", "packages/alpha's absolute path is longer, so it wins the tie")
})

test("--lands=<label> restricts the one-off count and clustering to that label", () => {
  const repoDir = buildRepoTree()
  const projectsDir = mkTmp("mine-projects-")
  const alpha = path.join(repoDir, "packages", "alpha")
  // Two sessions each with a call landing in packages/alpha, one call landing at "."
  writeSession(projectsDir, "sessA0001", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Fix the parser bug. Work only in ${alpha}/ and run its tests before returning.`,
      subagent_type: "general-purpose",
      description: "alpha call one",
    }),
  ])
  writeSession(projectsDir, "sessB0002", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Fix the parser bug. Work only in ${alpha}/ and run its tests before returning.`,
      subagent_type: "general-purpose",
      description: "alpha call two",
    }),
    toolUse("t3", "Agent", {
      prompt: `Fix the root config. Work only in ${repoDir}/ and run its tests before returning.`,
      subagent_type: "general-purpose",
      description: "root call",
    }),
  ])

  const withoutFlag = runJson(repoDir, projectsDir)
  assert.equal(withoutFlag.targeting, 3)

  const withFlag = runJson(repoDir, projectsDir, ["--lands=packages/alpha"])
  assert.equal(withFlag.targeting, 3, "targeting is a global count, unaffected by --lands")
  assert.equal(withFlag.clustered, 2, "clustering pool narrows to the packages/alpha calls")
  // Hand count: the two alpha calls' only shared fixed sentence is carried by both of the 2 calls in this
  // --lands-narrowed pool, so it is >30% of the pool (the default --generic share) and is treated as
  // generic — left out of clustering. With no other fixed sentence between them, neither call joins a
  // cluster, so both are one-off.
  assert.equal(withFlag.oneOff, 2)
})

test("--json exposes a top-level lands array over targeting calls, sorted by count descending", () => {
  const repoDir = buildRepoTree()
  const projectsDir = mkTmp("mine-projects-")
  const alpha = path.join(repoDir, "packages", "alpha")
  const beta = path.join(repoDir, "packages", "beta")
  writeSession(projectsDir, "sess0011", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Work only in ${alpha}/.`,
      subagent_type: "general-purpose",
      description: "alpha one",
    }),
    toolUse("t3", "Agent", {
      prompt: `Work only in ${alpha}/.`,
      subagent_type: "general-purpose",
      description: "alpha two",
    }),
    toolUse("t4", "Agent", {
      prompt: `Work only in ${beta}/.`,
      subagent_type: "general-purpose",
      description: "beta one",
    }),
  ])

  const json = runJson(repoDir, projectsDir)
  assert.ok(Array.isArray(json.lands))
  assert.deepEqual(json.lands[0], { label: "packages/alpha", n: 2 })
  assert.ok(json.lands.find((l) => l.label === "packages/beta" && l.n === 1))
})

test("a cluster in --json carries the same lands shape for its own members", () => {
  const repoDir = buildRepoTree()
  const projectsDir = mkTmp("mine-projects-")
  const alpha = path.join(repoDir, "packages", "alpha")
  writeSession(projectsDir, "sessC0001", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Fix the parser bug. Work only in ${alpha}/ and run its tests before returning.`,
      subagent_type: "general-purpose",
      description: "cluster call one",
    }),
  ])
  writeSession(projectsDir, "sessD0002", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Fix the parser bug. Work only in ${alpha}/ and run its tests before returning.`,
      subagent_type: "general-purpose",
      description: "cluster call two",
    }),
  ])

  // --generic=1 keeps the shared fixed sentence from being written off as generic in this small pool
  // (its default 0.3 share is measured against pool size, and a 2-call pool makes any shared sentence
  // look universal).
  const json = runJson(repoDir, projectsDir, ["--generic=1"])
  assert.ok(json.clusters.length >= 1)
  const cluster = json.clusters[0]
  assert.ok(Array.isArray(cluster.lands))
  assert.deepEqual(cluster.lands[0], { label: "packages/alpha", n: 2 })
})

test("the default text output prints a lands line per cluster after types/models", () => {
  const repoDir = buildRepoTree()
  const projectsDir = mkTmp("mine-projects-")
  const alpha = path.join(repoDir, "packages", "alpha")
  writeSession(projectsDir, "sessE0001", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Fix the parser bug. Work only in ${alpha}/ and run its tests before returning.`,
      subagent_type: "general-purpose",
      description: "text call one",
    }),
  ])
  writeSession(projectsDir, "sessF0002", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Fix the parser bug. Work only in ${alpha}/ and run its tests before returning.`,
      subagent_type: "general-purpose",
      description: "text call two",
    }),
  ])

  const text = run(repoDir, projectsDir, ["--generic=1"])
  const lines = text.split("\n")
  const modelsIdx = lines.findIndex((l) => l.startsWith("types:"))
  assert.ok(modelsIdx >= 0)
  assert.match(lines[modelsIdx + 1], /^lands: packages\/alpha ×2/)
})

// --- Path-boundary characters (a candidate path may be followed by more than a slash/quote/whitespace) --

test("a path mention ending in a period, comma, parenthesis or colon counts, but a hyphen continuation or a dotted extension does not", () => {
  const repoDir = buildRepoTree()
  const projectsDir = mkTmp("mine-projects-")
  const alpha = path.join(repoDir, "packages", "alpha")
  writeSession(projectsDir, "sess0012", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt:
        `See ${alpha}. Then (${alpha}) then ${alpha}: then ${alpha}, done. ` +
        `Not ${alpha}-x nor ${alpha}.md though.`,
      subagent_type: "general-purpose",
      description: "boundary punctuation",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("boundary punctuation"))
  assert.ok(line)
  const cols = line.trim().split(/\s+/)
  // Four of the six mentions end the path cleanly (., ), :, ,); the other two continue the path's own
  // word characters (-x) or its own extension (.md) and are not mentions of packages/alpha at all. If the
  // four clean mentions were missed, the repository's own path (the only other thing left to compete)
  // would win instead, landing at "." rather than at packages/alpha.
  assert.equal(cols[3], "packages/alpha")
})

test("a hyphen continuation of the path's own name is never counted as a mention, on its own", () => {
  // The only mention anywhere in the prompt is "alpha-x" — a real, unrelated word that merely starts with
  // the nested repository's path. If the hyphen half of the boundary lookahead were missing, this alone
  // would be (wrongly) counted as a mention of packages/alpha, outweighing the repository's own path and
  // landing there instead of at ".". The combined test elsewhere always mixes this in with genuine clean
  // mentions, so a missing hyphen-guard doesn't flip its answer; this fixture isolates it.
  const repoDir = buildRepoTree()
  const projectsDir = mkTmp("mine-projects-")
  const alpha = path.join(repoDir, "packages", "alpha")
  writeSession(projectsDir, "sess0012b", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Not ${alpha}-x though, that is a different thing entirely and no path is named.`,
      subagent_type: "general-purpose",
      description: "hyphen only mention",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("hyphen only mention"))
  assert.ok(line)
  const cols = line.trim().split(/\s+/)
  assert.equal(cols[3], ".")
})

test("a dotted-extension continuation of the path's own name is never counted as a mention, on its own", () => {
  // The only mention anywhere in the prompt is "alpha.md" — a file name that merely starts with the
  // nested repository's path. If the dot half of the boundary lookahead were missing, this alone would be
  // (wrongly) counted as a mention of packages/alpha, landing there instead of at ".".
  const repoDir = buildRepoTree()
  const projectsDir = mkTmp("mine-projects-")
  const alpha = path.join(repoDir, "packages", "alpha")
  writeSession(projectsDir, "sess0012c", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Not ${alpha}.md though, that is a different thing entirely and no path is named.`,
      subagent_type: "general-purpose",
      description: "dot extension only mention",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("dot extension only mention"))
  assert.ok(line)
  const cols = line.trim().split(/\s+/)
  assert.equal(cols[3], ".")
})

// --- Symlinked directories in the walk ------------------------------------------------------------------

test("the walk follows a symlinked directory to find a nested repository behind it", () => {
  const repoDir = mkTmp("mine-repo-sym-")
  fs.mkdirSync(path.join(repoDir, ".git"))
  fs.mkdirSync(path.join(repoDir, "real-nested", ".git"), { recursive: true })
  fs.symlinkSync(path.join(repoDir, "real-nested"), path.join(repoDir, "link-to-real"), "dir")

  const projectsDir = mkTmp("mine-projects-")
  const viaLink = path.join(repoDir, "link-to-real")
  writeSession(projectsDir, "sess0013", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Work only in ${viaLink}/ and fix things there.`,
      subagent_type: "general-purpose",
      description: "symlinked nested fix",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("symlinked nested fix"))
  assert.ok(line)
  const cols = line.trim().split(/\s+/)
  // The real target ("real-nested") lies inside the repository, so the link path's own candidate is
  // labelled with the real target's label, folding the two names into one canonical entity.
  assert.equal(cols[3], "real-nested")
})

test("a nested repository reached only through a sibling symlink still gets its own candidate, even though another branch already walked the same realpath first", () => {
  // a-link sorts before "real" in readdir order, so the old global "already visited this realpath"
  // guard would register a-link's realpath first and then skip "real" itself when the walk reached it —
  // losing the direct mention of the real path entirely (falling back to ".").
  const repoDir = mkTmp("mine-repo-sym2-")
  fs.mkdirSync(path.join(repoDir, ".git"))
  fs.mkdirSync(path.join(repoDir, "real", ".git"), { recursive: true })
  fs.symlinkSync(path.join(repoDir, "real"), path.join(repoDir, "a-link"), "dir")
  assert.ok("a-link" < "real", "fixture assumption: a-link sorts before real in readdir order")

  const projectsDir = mkTmp("mine-projects-")
  const real = path.join(repoDir, "real")
  writeSession(projectsDir, "sess0013b", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Work only in ${real}/ and fix things there.`,
      subagent_type: "general-purpose",
      description: "real path after earlier sibling link",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("real path after earlier sibling link"))
  assert.ok(line)
  const cols = line.trim().split(/\s+/)
  assert.equal(cols[3], "real")
})

test("a symlink whose target is an ancestor of it (a cycle) is skipped, never registered as a spurious nested repository", () => {
  const repoDir = mkTmp("mine-repo-cycle-")
  fs.mkdirSync(path.join(repoDir, ".git"))
  fs.mkdirSync(path.join(repoDir, "a"))
  // "back" points at the repository root itself — an ancestor of "a" in the walk. Recursing into it would
  // repeat forever; it must be skipped outright, not mined as if it were a nested repository at "a/back".
  fs.symlinkSync(repoDir, path.join(repoDir, "a", "back"), "dir")

  const projectsDir = mkTmp("mine-projects-")
  const cyclePath = path.join(repoDir, "a", "back")
  writeSession(projectsDir, "sess0013c", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Work only in ${cyclePath}/ and fix things there.`,
      subagent_type: "general-purpose",
      description: "cycle back to repository root",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("cycle back to repository root"))
  assert.ok(line)
  const cols = line.trim().split(/\s+/)
  // With the cycle correctly skipped, no candidate exists for "a/back"; the mention falls through to the
  // repository's own path, landing at ".". A missing or wrong cycle guard registers "a/back" as if it were
  // its own nested repository instead, and the mention would land there.
  assert.equal(cols[3], ".", "the cycle must not create a spurious label such as 'a/back'")
})

// --- A .git file's gitdir: may be relative, or may point into .git/modules/... (a submodule) -------------

test("a linked worktree's gitdir line may be relative, resolved against the directory holding the .git file", () => {
  const repoDir = buildRepoTree()
  const projectsDir = mkTmp("mine-projects-")
  fs.mkdirSync(path.join(repoDir, "rel-wt"))
  const target = path.join(repoDir, "packages", "alpha", ".git", "worktrees", "wt2")
  const relTarget = path.relative(path.join(repoDir, "rel-wt"), target)
  fs.writeFileSync(path.join(repoDir, "rel-wt", ".git"), `gitdir: ${relTarget}\n`)

  const relWt = path.join(repoDir, "rel-wt")
  writeSession(projectsDir, "sess0014", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Work only in ${relWt}/ and fix things there.`,
      subagent_type: "general-purpose",
      description: "relative gitdir worktree fix",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("relative gitdir worktree fix"))
  assert.ok(line)
  const cols = line.trim().split(/\s+/)
  assert.equal(cols[3], "packages/alpha")
})

test("a gitdir pointing into <repo>/.git/modules/<name> makes the directory holding the .git file a nested repository, labelled by its own path", () => {
  const repoDir = buildRepoTree()
  const projectsDir = mkTmp("mine-projects-")
  fs.mkdirSync(path.join(repoDir, ".git", "modules", "vendor-sub"), { recursive: true })
  fs.mkdirSync(path.join(repoDir, "vendor-sub"))
  fs.writeFileSync(
    path.join(repoDir, "vendor-sub", ".git"),
    `gitdir: ${path.join(repoDir, ".git", "modules", "vendor-sub")}\n`,
  )

  const sub = path.join(repoDir, "vendor-sub")
  writeSession(projectsDir, "sess0015", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Work only in ${sub}/ and fix things there.`,
      subagent_type: "general-purpose",
      description: "submodule fix",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("submodule fix"))
  assert.ok(line)
  const cols = line.trim().split(/\s+/)
  assert.equal(cols[3], "vendor-sub")
})

// --- The repository itself competes for mentions ----------------------------------------------------

test("the repository's own path competes for mentions: three repo mentions outweigh one nested mention, landing at '.'", () => {
  const repoDir = buildRepoTree()
  const projectsDir = mkTmp("mine-projects-")
  const alpha = path.join(repoDir, "packages", "alpha")
  writeSession(projectsDir, "sess0016", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Look at ${repoDir}, then ${repoDir} again, then ${repoDir} once more, and only mention ${alpha} once.`,
      subagent_type: "general-purpose",
      description: "repo outweighs nested",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("repo outweighs nested"))
  assert.ok(line)
  const cols = line.trim().split(/\s+/)
  assert.equal(cols[3], ".")
})

test("a tie in mention count between the repository itself and a nested repository goes to the nested (longer) path", () => {
  const repoDir = buildRepoTree()
  const projectsDir = mkTmp("mine-projects-")
  const alpha = path.join(repoDir, "packages", "alpha")
  writeSession(projectsDir, "sess0017", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Look at ${repoDir} once, and at ${alpha} once.`,
      subagent_type: "general-purpose",
      description: "tie repo vs nested",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("tie repo vs nested"))
  assert.ok(line)
  const cols = line.trim().split(/\s+/)
  assert.equal(cols[3], "packages/alpha")
})

test("a targeting call that names no path at all still lands at '.'", () => {
  const repoDir = buildRepoTree()
  const projectsDir = mkTmp("mine-projects-")
  const repoName = path.basename(repoDir)
  writeSession(projectsDir, "sess0018", [
    toolUse("t1", "Edit", { file_path: path.join(repoDir, "README.md") }),
    toolUse("t2", "Agent", {
      prompt: `Fix the ${repoName} bug without naming any path at all in this instruction text here.`,
      subagent_type: "general-purpose",
      description: "no path mention",
    }),
  ])

  const calls = run(repoDir, projectsDir, ["--calls"])
  const line = calls.split("\n").find((l) => l.includes("no path mention"))
  assert.ok(line)
  const cols = line.trim().split(/\s+/)
  assert.equal(cols[2], "yes")
  assert.equal(cols[3], ".")
})
