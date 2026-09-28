#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0
// Prints the workspace's publishable packages in dependency order — a dependency always before the
// package that needs it.
//
// `npm publish` validates nothing about dependencies: it will happily publish a package whose declared
// dependency does not exist. That is precisely why the order matters. Publishing out of order leaves a
// window in which the package IS on the registry and `npm install` of it fails — for every consumer, and
// for the workflow's own next `npm ci`. This order alone narrows that window to registry propagation
// delay, not zero: a caller that publishes a dependent right after this script names its dependency as
// done still has to wait for the dependency's packument to actually answer before that publish is safe —
// this script only says which package to wait for next, not how long.
//
//   node publish-order.mjs [repo-root]            names, one per line, in order
//   node publish-order.mjs [repo-root] --paths    directories instead of names
//   node publish-order.mjs [repo-root] --json     full records (name, version, dir, needs, repository)
//   node publish-order.mjs [repo-root] --allow-cycles   order anyway, cycles reported to stderr
//   node publish-order.mjs --help                 print usage and exit 0
//
// Reads `workspaces` from the root package.json. Skips `"private": true` packages, which never reach a
// registry — except that a *public* package depending on a private one is refused (exit 1, naming the
// edge): that private package never reaches the registry either, so the dependency can never resolve for
// a consumer. A root `package.json` with no `workspaces` field is treated as a single-package repo: the
// root package alone is the order. A cycle exits 1 by default: no order avoids the broken window, so it
// is a decision to take deliberately rather than a step to walk past.

import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs'
import { join, resolve, relative } from 'node:path'

const USAGE = `Usage: publish-order.mjs [repo-root] [--paths|--json] [--allow-cycles] [--help]

Prints the workspace's publishable packages in dependency order — a dependency always
before the package that needs it.

  (no flag)       names, one per line, in order
  --paths         directories instead of names
  --json          full records: name, version, dir, needs, repository
  --allow-cycles  order anyway, cycles reported to stderr
  --help          print this message and exit 0
`

const args = process.argv.slice(2)

if (args.includes('--help') || args.includes('-h')) {
  console.log(USAGE)
  process.exit(0)
}

const KNOWN_FLAGS = new Set(['--paths', '--json', '--allow-cycles'])
const flags = new Set(args.filter((a) => a.startsWith('--')))
for (const f of flags) {
  if (!KNOWN_FLAGS.has(f)) {
    console.error(`unknown flag: ${f}\n\n${USAGE}`)
    process.exit(2)
  }
}

const root = resolve(args.find((a) => !a.startsWith('--')) ?? '.')

/** Read and parse a package.json, exiting with one line — never a stack trace — on either failure. */
function read(f) {
  let raw
  try {
    raw = readFileSync(f, 'utf8')
  } catch (e) {
    console.error(`cannot read ${f}: ${e.code === 'ENOENT' ? 'no such file' : e.message}`)
    process.exit(1)
  }
  try {
    return JSON.parse(raw)
  } catch (e) {
    console.error(`cannot parse ${f}: ${e.message}`)
    process.exit(1)
  }
}

/** Every directory under `base` (recursively) that holds a package.json — the resolution for a `/**` glob. */
function walkForPackages(base, depth = 0) {
  if (depth > 12) return [] // guards a symlink loop rather than claiming to resolve one
  const out = []
  if (existsSync(join(base, 'package.json'))) out.push(base)
  for (const d of readdirSync(base)) {
    if (d === 'node_modules' || d.startsWith('.')) continue
    const sub = join(base, d)
    if (statSync(sub).isDirectory()) out.push(...walkForPackages(sub, depth + 1))
  }
  return out
}

/**
 * Expand the `workspaces` globs the way npm's own resolution does for the two shapes this script
 * supports: a trailing `/*` is one level, a trailing `/**` is any depth. A glob npm supports that isn't
 * one of those two shapes is refused in words rather than mis-resolved silently. `null` means the
 * manifest has no `workspaces` field at all — a single-package repo, not an error.
 */
function workspaceDirs(rootPkg) {
  const globs = Array.isArray(rootPkg.workspaces) ? rootPkg.workspaces : (rootPkg.workspaces?.packages ?? [])
  if (!rootPkg.workspaces) return null
  const out = []
  for (const glob of globs) {
    if (glob.endsWith('/**')) {
      const base = join(root, glob.slice(0, -3))
      if (!existsSync(base)) continue
      out.push(...walkForPackages(base))
    } else if (glob.endsWith('/*')) {
      const base = join(root, glob.slice(0, -2))
      if (!existsSync(base)) continue
      for (const d of readdirSync(base)) {
        const dir = join(base, d)
        if (statSync(dir).isDirectory() && existsSync(join(dir, 'package.json'))) out.push(dir)
      }
    } else if (glob.includes('*')) {
      console.error(
        `unsupported workspaces glob: "${glob}" — only a trailing "/*" (one level) or "/**" (any depth) ` +
          `is resolved here; write out the directories explicitly, or narrow the glob to one of those shapes.`
      )
      process.exit(1)
    } else {
      const dir = join(root, glob)
      if (existsSync(join(dir, 'package.json'))) out.push(dir)
    }
  }
  // A glob that matches nothing is not an npm error, so it is one here.
  if (out.length === 0) {
    console.error(`no package.json under any of: ${globs.join(', ')}`)
    process.exit(1)
  }
  return out
}

const rootPkg = read(join(root, 'package.json'))
const dirs = workspaceDirs(rootPkg)
const workspacePaths = dirs ?? [root] // no `workspaces` field: the root package is the whole order

const allPkgs = new Map() // name -> record, private packages included
for (const dir of workspacePaths) {
  const json = read(join(dir, 'package.json'))
  allPkgs.set(json.name, { name: json.name, version: json.version, dir, json, private: json.private === true })
}

const pkgs = new Map([...allPkgs].filter(([, p]) => !p.private))

// A public package cannot depend on a private one: it never reaches the registry, so the dependency can
// never resolve for a consumer who installs the public package. Name the edge and stop — this is not a
// case any order can paper over.
for (const [name, p] of pkgs) {
  const all = { ...p.json.dependencies, ...p.json.peerDependencies, ...p.json.optionalDependencies }
  for (const dep of Object.keys(all)) {
    const target = allPkgs.get(dep)
    if (target?.private) {
      console.error(`${name} depends on ${dep}, which is "private": true — a public package cannot depend on a package that never reaches the registry`)
      process.exit(1)
    }
  }
}

/** Internal edges only — a registry dependency is already published by definition. */
const needs = (name) => {
  const { json } = pkgs.get(name)
  const all = { ...json.dependencies, ...json.peerDependencies, ...json.optionalDependencies }
  return Object.keys(all).filter((d) => pkgs.has(d))
}

// Every cycle, not just the first: each one is a separate code change, and finding them one run at a
// time turns a single reading of the graph into a week of them.
const order = []
const cycles = new Map() // canonical key -> readable trail
const state = new Map() // undefined | 'visiting' | 'done'
function visit(name, trail) {
  if (state.get(name) === 'done') return
  if (state.get(name) === 'visiting') {
    const loop = trail.slice(trail.indexOf(name)).concat(name)
    // Rotation-independent key, so one cycle reached from three entry points is reported once.
    cycles.set([...loop.slice(0, -1)].sort().join('|'), loop.map((n) => n.replace(/^@[^/]+\//, '')).join(' -> '))
    return
  }
  state.set(name, 'visiting')
  for (const dep of needs(name)) visit(dep, [...trail, name])
  state.set(name, 'done')
  order.push(name)
}
for (const name of [...pkgs.keys()].sort()) visit(name, [])

if (cycles.size > 0) {
  console.error(`${cycles.size} dependency cycle(s) — every order publishes one member before its dependency:\n`)
  for (const trail of cycles.values()) console.error(`  ${trail}`)
  console.error('\nnpm workspaces resolve these by symlink and never complain, so a cycle survives every')
  console.error('local build and test. The registry has no symlinks: whichever member goes first is on npm')
  console.error('and un-installable until the last one lands. Publishing is still possible — correctness in')
  console.error('between is not. Break each cycle in code (extract the shared piece, or move the weaker edge')
  console.error('to a dynamic load), or re-run with --allow-cycles having decided the window is acceptable.')
  if (!flags.has('--allow-cycles')) process.exit(1)
  console.error('\n--allow-cycles: order below is a best effort, not a safe sequence.\n')
}

const records = order.map((name) => {
  const p = pkgs.get(name)
  return { name: p.name, version: p.version, dir: relative(root, p.dir), needs: needs(name), repository: p.json.repository ?? null }
})

if (flags.has('--json')) console.log(JSON.stringify(records, null, 2))
else if (flags.has('--paths')) for (const r of records) console.log(r.dir)
else for (const r of records) console.log(r.name)
