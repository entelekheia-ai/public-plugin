// SPDX-License-Identifier: Apache-2.0
// measure.js — read your own Claude Code transcripts and count how each delegation to a subagent chose
// its model: what was asked, what actually ran, at which effort, and whether a `[route-work]` line
// opened its prompt with the decision.
//
// Usage:
//   node measure.js [--root DIR] [--projects DIR] [--since ISO] [--until ISO] [--days N]
//                   [--scope workspace|all] [--format table|artifact] [--out DIR]
//
//   --root DIR       the project whose sessions to read (default: the current directory)
//   --projects DIR   where Claude Code keeps transcripts (default: ~/.claude/projects)
//   --scope          workspace (default) reads only transcripts of --root and the folders under it;
//                    all reads every project on this machine
//   --format table   (default) a human report: per kind of delegation, the model asked for and the one
//                    that ran, with counts, tokens and wall time, then the announcement audit
//   --format artifact  one JSON line per finding, for a tool that collects them
//
// Counted: every Agent tool call whose subagent type is built in (Explore, Plan, general-purpose), and
// every agent( call site in a Workflow script. A plugin agent that fixes its own model is listed and not
// counted. Everything is deduplicated by tool_use id, because a resumed session repeats its history.
//
// The `[route-work]` declaration is read from the first line of the Agent tool_use's own `input.prompt` —
// the call's own transcript keeps that text verbatim, so declared and asked are read off the same record
// that made the call, exactly, even when several calls run in parallel. A Workflow `agent()` site carries
// no prompt of its own for the audit to read, so its `topology=`/`relieves=` are read from the script's
// `meta.description` instead.

const fs = require('node:fs')
const path = require('node:path')
const os = require('node:os')

const TOOL = 'route-work@1'
const PRODUCER = 'route-work'
const BUILTIN_TYPES = new Set(['Explore', 'Plan', 'general-purpose', 'claude'])

function parseArgs(argv) {
  const args = {
    root: process.cwd(),
    projects: path.join(os.homedir(), '.claude', 'projects'),
    since: null,
    until: null,
    days: 30,
    scope: 'workspace',
    format: 'table',
    out: null,
  }
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i]
    const next = () => {
      i += 1
      if (i >= argv.length) throw new Error(`${a} needs a value`)
      return argv[i]
    }
    switch (a) {
      case '--root': args.root = path.resolve(next()); break
      case '--projects': args.projects = path.resolve(next()); break
      case '--since': args.since = next(); break
      case '--until': args.until = next(); break
      case '--days': args.days = Number(next()); break
      case '--scope': args.scope = next(); break
      case '--format': args.format = next(); break
      case '--out': args.out = path.resolve(next()); break
      case '-h': case '--help':
        process.stdout.write(fs.readFileSync(__filename, 'utf8').split('\n').filter((l) => l.startsWith('//')).map((l) => l.slice(3)).join('\n') + '\n')
        process.exit(0)
        break
      default: throw new Error(`unknown option ${a}`)
    }
  }
  if (!['workspace', 'all'].includes(args.scope)) throw new Error(`--scope must be workspace or all, got ${args.scope}`)
  if (!['artifact', 'table'].includes(args.format)) throw new Error(`--format must be artifact or table, got ${args.format}`)
  if (!Number.isFinite(args.days) || args.days <= 0) throw new Error(`--days must be a positive number, got ${args.days}`)
  const until = args.until ? new Date(args.until) : new Date()
  const since = args.since ? new Date(args.since) : new Date(until.getTime() - args.days * 86400e3)
  if (Number.isNaN(until.getTime())) throw new Error(`--until is not a date: ${args.until}`)
  if (Number.isNaN(since.getTime())) throw new Error(`--since is not a date: ${args.since}`)
  return { ...args, since, until }
}

// Claude Code names a project directory after its cwd with every path separator and dot turned into a
// dash, and worktrees or nested repos under the same root share that prefix.
function slugOf(dir) {
  return dir.replace(/[/.]/g, '-')
}

function listTranscripts(projectsDir, root, scope) {
  if (!fs.existsSync(projectsDir)) return []
  const prefix = slugOf(root)
  const out = []
  for (const entry of fs.readdirSync(projectsDir, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue
    if (scope === 'workspace' && !entry.name.startsWith(prefix)) continue
    walk(path.join(projectsDir, entry.name), out)
  }
  return out
}

function walk(dir, out) {
  let entries
  try { entries = fs.readdirSync(dir, { withFileTypes: true }) } catch { return }
  for (const e of entries) {
    const f = path.join(dir, e.name)
    if (e.isDirectory()) walk(f, out)
    else if (e.name.endsWith('.jsonl')) out.push(f)
  }
}

// Every `agent(` call site in a Workflow script, with whether its argument list names a model. The
// argument list is cut at the balancing parenthesis so a `model:` in a LATER call is never credited to
// an earlier site that has none.
function workflowSites(script) {
  const sites = []
  const re = /\bagent\s*\(/g
  let m
  while ((m = re.exec(script)) !== null) {
    let depth = 1
    let i = m.index + m[0].length
    for (; i < script.length && depth > 0; i += 1) {
      const c = script[i]
      if (c === '(') depth += 1
      else if (c === ')') depth -= 1
    }
    const argText = script.slice(m.index + m[0].length, i - 1)
    sites.push({ hasModel: /\bmodel\s*:/.test(argText) })
  }
  return sites
}

// A value may be wrapped in backticks when the line was written inside inline code; the backticks are
// punctuation of the prose, so they are skipped rather than captured.
function readField(text, k) {
  const m = text.match(new RegExp(`\\b${k}=\`?([^\\s\`]+)`))
  return m ? m[1] : null
}

// The `[route-work]` declaration, read from the FIRST line of the Agent tool_use's own `input.prompt` — the
// skill's Step 3 has every prompt open with it, so the call's own transcript carries what was decided and
// there is nothing to age or lose track of, unlike a line written loose in a reply that a later call might
// or might not be the one meant. A prompt whose first line does not open with `[route-work]` was not
// declared, and is reported as such rather than guessed at from a line deeper in the text.
function parseAnnouncement(prompt) {
  if (!prompt) return null
  const firstLine = String(prompt).split('\n', 1)[0].trim()
  if (!/^\[route-work\]/.test(firstLine)) return null
  return {
    raw: firstLine,
    shape: readField(firstLine, 'shape'),
    model: readField(firstLine, 'model'),
    effort: readField(firstLine, 'effort'),
    topology: readField(firstLine, 'topology'),
    relieves: readField(firstLine, 'relieves'),
  }
}

// A Workflow `agent()` site carries no prompt of its own for the audit to read, so a widening's rationale
// lives in the script's own `meta.description` instead (the skill's Step 3). Read topology=/relieves= out
// of that description if the script declares one; fall back to the whole script text so a description
// written without the `meta.description =` shape Node expects is still found.
function workflowAnnouncement(script) {
  const m = script.match(/description\s*:\s*(['"`])([\s\S]*?)\1/)
  const text = m ? m[2] : script
  const topology = readField(text, 'topology')
  const relieves = readField(text, 'relieves')
  if (!topology && !relieves) return null
  return { raw: text.trim(), topology, relieves }
}

// `sonnet`, `claude-sonnet-5` and `claude-opus-4-8` all have to compare, so the join is on the family name
// both spellings contain. A model this cannot place returns null and is never reported as a mismatch.
function modelFamily(name) {
  if (!name) return null
  const m = String(name).match(/\b(fable|mythos|opus|sonnet|haiku)\b/)
  return m ? m[1] : null
}

function kindOf(subagentType) {
  if (!subagentType) return 'untyped'
  if (subagentType === 'Explore') return 'explore'
  if (subagentType === 'Plan') return 'plan'
  if (subagentType === 'general-purpose' || subagentType === 'claude') return 'general-purpose'
  return 'plugin'
}

function inWindow(ts, since, until) {
  if (!ts) return false
  const t = new Date(ts).getTime()
  return t >= since.getTime() && t < until.getTime()
}

function collect(files, since, until) {
  const agentCalls = new Map() // tool_use id -> delegation
  const workflows = new Map() // tool_use id -> { ts, sites }
  const agentModel = new Map() // agentId -> { model: count }
  const agentEffort = new Map() // agentId -> effort of the first subagent assistant record that carries one
  const resultsById = new Map() // tool_use id -> toolUseResult
  for (const f of files) {
    let text
    try { text = fs.readFileSync(f, 'utf8') } catch { continue }
    for (const line of text.split('\n')) {
      if (!line) continue
      // A cheap substring gate before the JSON parse: the lines this needs are the delegation calls, the
      // Workflow calls, and anything carrying an agentId — the Agent tool's own result (toolUseResult)
      // and the subagent's transcript lines, which are how "asked" gets joined to "ran".
      const quick = line.includes('"Agent"') || line.includes('"Task"') || line.includes('"Workflow"') ||
        line.includes('"agentId"')
      if (!quick) continue
      let o
      try { o = JSON.parse(line) } catch { continue }
      if (o.isSidechain && o.type === 'assistant' && o.agentId && o.message && o.message.model) {
        const m = agentModel.get(o.agentId) || {}
        m[o.message.model] = (m[o.message.model] || 0) + 1
        agentModel.set(o.agentId, m)
      }
      // The reasoning level Claude Code resolved for the subagent's model, written as a top-level `effort`
      // field on every assistant record of its transcript. Only the first one seen is kept.
      if (o.isSidechain && o.type === 'assistant' && o.agentId && o.effort != null && !agentEffort.has(o.agentId)) {
        agentEffort.set(o.agentId, o.effort)
      }
      const content = o.message && o.message.content
      if (!Array.isArray(content)) continue
      for (const b of content) {
        if (b.type === 'tool_use' && (b.name === 'Agent' || b.name === 'Task')) {
          if (agentCalls.has(b.id) || !inWindow(o.timestamp, since, until)) continue
          const input = b.input || {}
          agentCalls.set(b.id, {
            id: b.id,
            ts: o.timestamp,
            kind: kindOf(input.subagent_type),
            subagentType: input.subagent_type || '(none)',
            asked: input.model || null,
            description: input.description || '',
            announced: parseAnnouncement(input.prompt),
            agentId: null,
            ran: null,
            ranEffort: null,
            tokens: null,
            durationMs: null,
          })
        } else if (b.type === 'tool_use' && b.name === 'Workflow') {
          if (workflows.has(b.id) || !inWindow(o.timestamp, since, until)) continue
          const script = (b.input && b.input.script) || ''
          workflows.set(b.id, { ts: o.timestamp, sites: workflowSites(script), announced: workflowAnnouncement(script) })
        } else if (b.type === 'tool_result' && o.toolUseResult && agentCalls.has(b.tool_use_id)) {
          if (!resultsById.has(b.tool_use_id)) resultsById.set(b.tool_use_id, o.toolUseResult)
        }
      }
    }
  }
  for (const [id, r] of resultsById) {
    const d = agentCalls.get(id)
    d.agentId = r.agentId || null
    d.tokens = typeof r.totalTokens === 'number' ? r.totalTokens : null
    d.durationMs = typeof r.totalDurationMs === 'number' ? r.totalDurationMs : null
    const am = d.agentId && agentModel.get(d.agentId)
    d.ran = am ? Object.entries(am).sort((a, b) => b[1] - a[1])[0][0] : null
    d.ranEffort = (d.agentId && agentEffort.get(d.agentId)) || null
  }
  return { agentCalls: [...agentCalls.values()], workflows: [...workflows.values()] }
}

function tally({ agentCalls, workflows }) {
  const counted = agentCalls.filter((d) => d.kind !== 'plugin')
  const findings = {}
  const bump = (rule) => { findings[rule] = (findings[rule] || 0) + 1 }
  const audit = { announced: 0, unannounced: 0, mismatch: [], announcedNoModel: 0, effortAnnounced: 0, effortMismatch: [] }
  for (const d of counted) {
    if (!d.asked) bump(`${d.kind}-model-inherited`)
    if (!d.announced) {
      audit.unannounced += 1
      bump('delegation-unannounced')
      continue
    }
    audit.announced += 1
    if (d.announced.effort) audit.effortAnnounced += 1
    if (!d.announced.model) audit.announcedNoModel += 1
    // The join the rule exists for: what the line decided against what the transcript shows billed.
    const said = modelFamily(d.announced.model)
    const ran = modelFamily(d.ran)
    if (said && ran && said !== ran) {
      audit.mismatch.push({ id: d.id, subagentType: d.subagentType, said, ran, asked: d.asked })
      bump('announced-model-mismatch')
    }
    // Audit only — the Agent tool takes no effort argument, so this is never a finding rule, just what the
    // announcement line said against the reasoning level the subagent transcript shows actually ran.
    if (d.announced.effort && d.ranEffort && d.announced.effort !== d.ranEffort) {
      audit.effortMismatch.push({ id: d.id, subagentType: d.subagentType, said: d.announced.effort, ran: d.ranEffort })
    }
  }
  let sites = 0
  for (const w of workflows) {
    for (const s of w.sites) {
      sites += 1
      if (!s.hasModel) bump('workflow-agent-model-inherited')
      if (w.announced) audit.announced += 1
      else { audit.unannounced += 1; bump('delegation-unannounced') }
    }
  }
  return { examined: counted.length + sites, findings, counted, sites, audit }
}

function artifactLines({ examined, findings }, since, until, producedAt) {
  const header = {
    schemaVersion: 1,
    kind: 'gate',
    producer: PRODUCER,
    tool: TOOL,
    moment: 'window',
    producedAt,
    population: { unit: 'delegation', examined },
    window: { since: since.toISOString(), until: until.toISOString() },
  }
  const lines = [JSON.stringify(header)]
  for (const rule of Object.keys(findings).sort()) {
    lines.push(JSON.stringify({ kind: 'finding', rule, count: findings[rule] }))
  }
  return lines.join('\n') + '\n'
}

function table(data, t, since, until) {
  const rows = new Map()
  for (const d of data.agentCalls) {
    const key = `${d.subagentType} | asked=${d.asked || 'inherit'} | ran=${d.ran || '?'} | ranEffort=${d.ranEffort || '?'}`
    const r = rows.get(key) || { n: 0, tok: 0, tokN: 0, ms: 0, msN: 0, plugin: d.kind === 'plugin' }
    r.n += 1
    if (d.tokens) { r.tok += d.tokens; r.tokN += 1 }
    if (d.durationMs) { r.ms += d.durationMs; r.msN += 1 }
    rows.set(key, r)
  }
  const out = []
  out.push(`window ${since.toISOString()} → ${until.toISOString()}`)
  out.push(`delegations examined: ${t.examined} (${t.counted.length} Agent calls of a built-in type + ${t.sites} Workflow agent() sites; plugin-typed calls listed below but not counted)`)
  out.push('')
  out.push(pad('subagent | asked | ran | effort', 62) + pad('n', 6) + pad('avg tokens', 12) + pad('avg min', 9) + 'counted')
  for (const [k, r] of [...rows].sort((a, b) => b[1].n - a[1].n)) {
    out.push(
      pad(k, 62) + pad(String(r.n), 6) + pad(r.tokN ? String(Math.round(r.tok / r.tokN)) : '-', 12) +
      pad(r.msN ? (r.ms / r.msN / 60000).toFixed(1) : '-', 9) + (r.plugin ? 'no' : 'yes'),
    )
  }
  out.push('')
  const wfSites = data.workflows.reduce((s, w) => s + w.sites.length, 0)
  const wfNoModel = data.workflows.reduce((s, w) => s + w.sites.filter((x) => !x.hasModel).length, 0)
  out.push(`workflows: ${data.workflows.length} scripts, ${wfSites} agent() sites, ${wfNoModel} without model:`)
  out.push('')
  out.push('announcements ([route-work] lines joined to the calls they govern):')
  const a = t.audit
  const pct = (n) => (t.examined ? ` (${Math.round((100 * n) / t.examined)}%)` : '')
  out.push(`  covered by a line:      ${a.announced}${pct(a.announced)}`)
  out.push(`  covered by none:        ${a.unannounced}${pct(a.unannounced)}`)
  out.push(`  line without model=:    ${a.announcedNoModel}`)
  out.push(`  line naming an effort:  ${a.effortAnnounced}  (announced; the call carried none — see ranEffort)`)
  out.push(`  announced != ran:       ${a.mismatch.length}`)
  for (const m of a.mismatch) out.push(`    ${m.subagentType}: said ${m.said}, asked ${m.asked || 'inherit'}, ran ${m.ran}`)
  out.push(`  announced effort != ran: ${a.effortMismatch.length}`)
  for (const m of a.effortMismatch) out.push(`    ${m.subagentType}: said ${m.said}, ran ${m.ran}`)
  out.push('')
  out.push('findings:')
  for (const rule of Object.keys(t.findings).sort()) out.push(`  ${pad(rule, 36)}${t.findings[rule]}`)
  if (Object.keys(t.findings).length === 0) out.push('  (none)')
  return out.join('\n') + '\n'
}

function pad(s, n) {
  return s.length >= n ? s + ' ' : s + ' '.repeat(n - s.length)
}

function main() {
  const args = parseArgs(process.argv.slice(2))
  const files = listTranscripts(args.projects, args.root, args.scope)
  const data = collect(files, args.since, args.until)
  const t = tally(data)

  if (args.format === 'table') {
    process.stdout.write(table(data, t, args.since, args.until))
    return 0
  }

  if (t.examined <= 0) {
    process.stderr.write(`route-work: no delegations between ${args.since.toISOString()} and ${args.until.toISOString()} — nothing written\n`)
    return 0
  }

  const producedAt = new Date().toISOString().replace(/\.\d{3}Z$/, 'Z')
  const text = artifactLines(t, args.since, args.until, producedAt)
  if (!args.out) {
    process.stdout.write(text)
    return 0
  }
  fs.mkdirSync(args.out, { recursive: true })
  const name = `${PRODUCER}.${producedAt.replace(/:/g, '')}.${process.pid}.jsonl`
  const final = path.join(args.out, name)
  const tmp = `${final}.tmp`
  fs.writeFileSync(tmp, text)
  fs.renameSync(tmp, final)
  process.stdout.write(`${final}\n`)
  return 0
}

if (require.main === module) {
  try {
    process.exit(main())
  } catch (error) {
    process.stderr.write(`route-work: ${error instanceof Error ? error.message : String(error)}\n`)
    process.exit(2)
  }
}

module.exports = { workflowSites, workflowAnnouncement, kindOf, collect, tally, artifactLines, slugOf, listTranscripts, parseAnnouncement, modelFamily }
