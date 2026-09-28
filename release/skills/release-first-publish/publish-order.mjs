#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0
// Prints the workspace's publishable packages in dependency order — a dependency always before the
// package that needs it.
//
// `npm publish` validates nothing about dependencies: it will happily publish a package whose declared
// dependency does not exist. That is precisely why the order matters. Publishing out of order leaves a
// window in which the package IS on the registry and `npm install` of it fails — for every consumer, and
// for the workflow's own next `npm ci`. In dependency order, every intermediate state of the registry is
// installable.
//
//   node publish-order.mjs [repo-root]            names, one per line, in order
//   node publish-order.mjs [repo-root] --paths    directories instead of names
//   node publish-order.mjs [repo-root] --json     full records, for a wrapper script
//   node publish-order.mjs [repo-root] --allow-cycles   order anyway, cycles reported to stderr
//
// Reads `workspaces` from the root package.json. Skips `"private": true` packages, which never reach a
// registry. A cycle exits 1 by default: no order avoids the broken window, so it is a decision to take
// deliberately rather than a step to walk past.

import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs'
import { join, resolve, relative } from 'node:path'

const args = process.argv.slice(2)
const flags = new Set(args.filter((a) => a.startsWith('--')))
const root = resolve(args.find((a) => !a.startsWith('--')) ?? '.')

const read = (f) => JSON.parse(readFileSync(f, 'utf8'))

/** Expand the `workspaces` globs the one way npm's own resolution does: a trailing `*` is one level. */
function workspaceDirs(rootPkg) {
  const globs = Array.isArray(rootPkg.workspaces) ? rootPkg.workspaces : (rootPkg.workspaces?.packages ?? [])
  const out = []
  for (const glob of globs) {
    if (glob.endsWith('/*')) {
      const base = join(root, glob.slice(0, -2))
      if (!existsSync(base)) continue
      for (const d of readdirSync(base)) {
        const dir = join(base, d)
        if (statSync(dir).isDirectory() && existsSync(join(dir, 'package.json'))) out.push(dir)
      }
    } else {
      const dir = join(root, glob)
      if (existsSync(join(dir, 'package.json'))) out.push(dir)
    }
  }
  // A glob that matches nothing is not an npm error, so it is one here.
  if (out.length === 0) throw new Error(`no package.json under any of: ${globs.join(', ')}`)
  return out
}

const rootPkg = read(join(root, 'package.json'))
const pkgs = new Map()
for (const dir of workspaceDirs(rootPkg)) {
  const json = read(join(dir, 'package.json'))
  if (json.private === true) continue
  pkgs.set(json.name, { name: json.name, version: json.version, dir, json })
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
  return { name: p.name, version: p.version, dir: relative(root, p.dir), needs: needs(name) }
})

if (flags.has('--json')) console.log(JSON.stringify(records, null, 2))
else if (flags.has('--paths')) for (const r of records) console.log(r.dir)
else for (const r of records) console.log(r.name)
