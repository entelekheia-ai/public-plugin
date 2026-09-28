// SPDX-License-Identifier: Apache-2.0
// Copy each plugin's package.json version — the one changesets bumps — into its
// .claude-plugin/plugin.json (and .codex-plugin/plugin.json, when present) and into its entry in the root marketplace.json.
import { existsSync, readFileSync, writeFileSync } from 'node:fs'

const read = (p) => JSON.parse(readFileSync(p, 'utf8'))
const write = (p, v) => writeFileSync(p, JSON.stringify(v, null, 2) + '\n')

const marketplacePath = '.claude-plugin/marketplace.json'
const marketplace = read(marketplacePath)

for (const dir of read('package.json').workspaces) {
  const { version } = read(`${dir}/package.json`)
  const pluginPath = `${dir}/.claude-plugin/plugin.json`
  const plugin = read(pluginPath)
  plugin.version = version
  write(pluginPath, plugin)
  const codexPath = `${dir}/.codex-plugin/plugin.json`
  if (existsSync(codexPath)) {
    const codex = read(codexPath)
    codex.version = version
    write(codexPath, codex)
  }
  const entry = marketplace.plugins.find((p) => p.name === plugin.name)
  if (!entry) throw new Error(`${plugin.name} is not listed in ${marketplacePath}`)
  entry.version = version
}

write(marketplacePath, marketplace)
