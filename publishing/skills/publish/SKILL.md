---
name: publish
description: 'Take skills, subagents or rules you wrote for your own setup and make them publishable — inventory what you have, compare each against what is already public, audit each file for private data, internal dependencies, internal evidence and the conventions of your own workflow, triage with you, generalize, verify mechanically and by a blind review, and release into a plugin catalog. Use when deciding which of your own skills or agents are worth sharing, when a private skill is about to become public, or "/publish <item or folder>".'
argument-hint: '[item, folder or "inventory"]'
user-invocable: true
user_invocable: true
---

# Publish your own skills and agents, without shipping what only you have

**Before starting, read your notes for this skill**, where they exist — `~/.agents/skill-notes/publish.md`,
then `.agents/skill-notes/publish.md`, then `.agents/skill-notes/publish.local.md`. Where two disagree, the
more specific one wins. They hold what earlier runs taught; see the last section for how they are written.

A skill written for your own setup leans on things a stranger will not have: paths on your machine, names
of your private repositories, a script only you wrote, a measurement only your sessions produced. Removing
them by hand is easy to do and easy to do wrong — the dangerous losses are not the private names you strip
but the load-bearing pieces that go with them, so the published skill reads well and silently no longer
works. This skill is the path from "mine" to "published" that catches both.

**This is a target-state skill.** The target is: every item you chose to publish is in your catalog,
passes its gates and a blind review, and every item you chose not to publish has its reason written
down. Running it again over the same items repairs what drifted; it never publishes an item twice.

It assumes a **catalog** — a repository that holds your published plugins, with a marketplace manifest
and some mechanical checks. The minimum is a git repository with `.claude-plugin/marketplace.json` at its
root listing each plugin, one folder per plugin with its own `.claude-plugin/plugin.json` and its
`skills/<name>/SKILL.md` (and `agents/*.md`, if it ships agents), plus the check Step 0 describes.

## Step 0 — The catalog can catch a leak mechanically

Before the first item moves, the catalog must be able to fail on its own when a private term reaches a
published file. That is one check, and it matters more than any other in this skill:

- **A deny-list outside the repository** — a file only you hold, one term or pattern per line, naming
  your private repositories, your username, internal product and project names, machine paths. It is
  never committed anywhere public.
- **A scan of every file the catalog ships** against that list — not only Markdown: scripts, JSON
  manifests and hook files carry names too. Any governance or secret-scanning tool that reads a list from
  a path works; so does a `grep -rnf` in a pre-commit hook.
- **Proof the scan fires — and reaches every directory.** Point it at a temporary list holding a word you
  know appears **only inside a dot-directory** (a plugin's `.claude-plugin/plugin.json` is the usual one)
  and watch it fail, then remove the temporary list. A glob like `**/*` skips dot-directories in most
  tools, and those are exactly where every plugin manifest lives: a scan proven on an ordinary file can
  still be blind to all of them. A deny-list that loaded zero patterns — wrong separator,
  CRLF line endings, only comments — can report clean while checking nothing. Check it counts entries.

Also useful, not required: `claude plugin validate <path> --strict` on the catalog and on each plugin, and
`npx skills add <catalog> --list` to see what a skills-only install would get.

## Step 1 — Inventory, with each item's one line

List every candidate: skills (`**/SKILL.md`), subagent definitions, always-on rules. **Enumerate with a
command, never from memory or a truncated listing** — `find <root> -name SKILL.md`, `ls -la` of each
skill's folder — and keep the full file list of each item: its scripts, references and hooks travel with
it. For each, one line: what it does, and the moment it fires.

## Step 2 — Compare each against what is already public

For each item, find the closest public equivalent: the official plugin marketplace, widely used skill
collections, the plugins already installed on this machine, community catalogs. Without network access,
compare against the installed plugins alone and say so next to the verdict — "distinctive" then means
"nothing installed here does this", which is weaker. Classify:

- **distinctive** — nothing public does this;
- **partly covered** — a public skill covers most of it;
- **common** — a public skill does it directly.

Then the **delta test** for anything not distinctive: can you state in one sentence what yours does that
the public one does not, and is that sentence the core of your skill rather than a paragraph inside it?
If yes, the item is a candidate, **cut to that delta**, with a description that names the moment the
public one does not cover. If no, drop it. Two skills with near descriptions compete for one trigger, and
the shallower one can win — a published overlap costs the user the better skill.

Group the survivors by theme into small plugins. The plugin name becomes the prefix of everything inside
it (`<plugin>:<skill>`), so file names never repeat the group.

## Step 3 — Audit each item, by file

Give the `extraction-auditor` agent (this plugin ships it) each item's **complete file list**, and with it
what the agent cannot know on its own: the terms that are private to you (the categories of your
deny-list, or the names themselves if you are comfortable passing them), the public equivalents Step 2
found, and which of your own public products may stay as a reference. Or do the audit yourself with the
same five categories. Every hit comes with `file:line` and the quoted text:

- **A — private data.** Machine paths, usernames, email addresses, names of private repositories, internal
  project or plan numbers.
- **B — dependencies a stranger will not have.** A CLI, script, MCP server, hook, other skill or agent the
  item calls or names, that does not ship with it. For each: bundle it, make it optional with the fallback
  stated, or drop the step.
- **C — internal evidence.** Dated measurements, run ids, costs, counts from your own sessions. Decide per
  item whether it is load-bearing — the reason a rule exists — and keep it in abstract form ("measured
  once: …"), or remove it.
- **D — overlap** with the public equivalent from Step 2, and the one-sentence delta.
- **W — your own workflow.** Your folder layout (`project/tasks/`, `docs/plans/`), your record templates
  and their section names, your numbering (`NNN-slug`, `Plan-012`), your own word for a common thing (a
  "dossier" for what others call a task, story or ticket), and the tool that writes them. None of it is
  private, so the deny-list never catches it, yet a reader who organises work differently must translate
  every line. Keep the behaviour and name the role — "a task file: a task, story or ticket, wherever the
  repository keeps them" — with your layout as one example at most, and your tool, if it is public, as an
  optional backend.

**The brief is the least-checked artifact in the whole flow.** If you hand the audit to an agent, list the
files by command output, not by hand: a file missing from the brief is a file the audit never sees, and a
generalized skill that lost a script it needed passes every mechanical gate.

## Step 4 — Triage with the maintainer, in one batch

For each item: **publish as is**, **publish after edits** (with an effort size), **split**, or **drop** —
with the reason. Ask them in one batch, your recommendation first. Two rules decide most cases:

- **Your own public products may be named as a reference or an option, never as a requirement.** A skill
  can point at a tool you maintain as one example among others, or as an optional richer backend. It never
  makes that tool an instruction the skill depends on.
- **A private product, or one unrelated to the skill's subject, is not named at all.** Say its category
  instead ("an observability tool", "a graph viewer").

Write each decision where it will be read later — the catalog's own decision record, or the plan driving
the publication. A decision that lives only in the conversation is lost at the next compaction.

## Step 5 — Generalize

Apply the audit's verdicts, split by what each edit needs:

- **Mechanical edits** — a name, a path, a block to delete, each with its exact old and new text: triage
  the auditor's edit list, then hand it to the `edit-applier` agent (it runs on a small, cheap model) or
  apply it yourself. Accept the result **by diff**: every changed line must belong to an entry of the
  list, and every entry reported as not applied gets looked at.
- **Rewrites** — a paragraph to generalize, a description to redraft: do them yourself, or give them to a
  capable implementer with the audit and your triage. A small model rewriting prose is where the
  generalization goes wrong quietly; read any prose it produced in full.
- **Wiring the plugin into the catalog** — manifests, a workspace entry, the marketplace entry, a
  changeset: deterministic, so a script or your own hands, not an agent.

What a published item must hold:

- **An agent's guard moves out of its frontmatter.** Claude Code ignores `hooks`, `mcpServers` and
  `permissionMode` on a plugin agent, with no warning, so a guard written there ships as nothing. Ship it as
  the plugin's own `hooks/hooks.json` `PreToolUse` hook that acts only when the payload's `agent_type`
  names the agent — `<plugin>:<agent>` for a plugin agent — and lets every other call through. A plugin
  agent's `skills:` preload names a skill in the same scoped form, `<plugin>:<skill>`. Prove both after
  installing: dispatch the agent to attempt a command its guard must refuse, and ask it to quote the first
  line of the preloaded skill without reading any file.
- **It works without the plugin's agents.** A skills-only install (`npx skills add`) carries no agents and
  no hooks; where a skill mentions an agent, it says what to do without it. State what a hookless install
  loses.
- **Its description names the distinct moment**, not the topic.
- **Frontmatter that survives more than one parser**: `name` equal to its folder, a `description`, and
  both `user-invocable` and `user_invocable` with the same value — parsers disagree on the spelling, and
  `claude plugin validate --strict` accepts both.
- **Every script it runs ships with it**, carries the catalog's license header if it has one, finds its tools on `PATH` (never a
  fixed `/usr/bin/…`), and degrades with a clear message when a tool is missing.
- **Paths a command runs** start from the skill-directory variable (`CLAUDE_SKILL_DIR`, written with
  `${` `}` around it in a real path), which resolves in a plugin install and a skills-only one alike —
  never a path relative to wherever the user happens to be. Keep the plugin-root variable
  (`CLAUDE_PLUGIN_ROOT`) for files outside the skill's folder (a plugin's hooks), and say what a
  skills-only install loses there. A Markdown link to a file inside the skill stays relative
  (`references/x.md`): it works in Claude Code, on GitHub and in other harnesses, where the variable is
  never substituted.
- **Explain those variables without their braces.** Claude Code substitutes the braced form everywhere
  in a skill's text when it loads it, so a sentence *about* the variable reaches the model as a machine
  path — and prints the user's own path wherever the text is echoed.
- **No note addressed to its author.** Review comments pasted into the text read to a model as orders.
- **It learns without being edited.** An installed copy is overwritten on update, so a published skill
  never asks the model to edit itself: it reads notes files at the start (user, then repo, then local, under
  `.agents/skill-notes/`) and writes what a run taught to the local one at the end, then asks whether a
  note should go back to the skill through the user's own flow.

For a plugin that other harnesses should install too, add the manifest they read beside the Claude one
(for Codex, `.codex-plugin/plugin.json` listing the plugin's skills).

## Step 6 — Verify: the gates, then a blind review

1. **Make the checks see the new files.** Many checks read only what git tracks; stage the files before
   running them, or an untracked file is simply never examined.
2. **Run the catalog's gates** — the deny-list scan, manifest validation, frontmatter checks — and `npx
   skills add <catalog> --list` to confirm every skill is found.
3. **A blind review before the commit.** A reviewer on a strong model that saw none of the session that
   wrote the item — the `delegation:reviewer` agent if you have the `delegation` plugin, or any reviewer — given the item and its private original, asked three things: did the generalization
   drop anything load-bearing (a step, a guard, a script, a state field); is every step performable by a
   stranger; is the claimed delta over the public equivalent real and concrete. **The gates check what can
   be matched; only a reader catches a skill that no longer works.** Accept each finding only after
   reproducing it, fix, and review the fix's range again until a pass finds nothing blocking. If you
   cannot start a subagent, the same review in a fresh session given only the item and its original
   serves; a review in the session that wrote the item does not, because its author fills the gaps
   without noticing.
4. **The first real use is the last review.** When the item is used on real work for the first time —
   ideally by an agent given nothing but the item, such as `delegation:blind-run` — ask for the places it fell short as a named result,
   and fold them back in.

## Step 7 — Release

- Record the change the way the catalog versions its plugins (a changeset, a changelog entry).
- **Set the version.** A new plugin starts at its first version (`0.1.0`, or whatever the catalog's
  others started at). A changed one is **bumped**: an installed plugin keeps its own copy of the files, so
  without a new version `claude plugin update` reports "already at the latest version" and every session
  keeps loading the old text, with nothing telling you so.
- **Commit**, then tag if the catalog tags releases: `claude plugin tag <plugin-path>` writes
  `<name>--v<version>` on the current commit, and refuses while changes are uncommitted — forcing it tags
  the previous commit with the new version.
- **Stop before the push.** Publishing the branch is the maintainer's act.

## Checklist

- [ ] The catalog failed on a deny-list term planted inside a dot-directory, and its deny-list loaded a
      non-zero count
- [ ] Every item's file list came from a command, and the audit saw all of it
- [ ] No published item speaks in your own workflow — its folder names, templates, section names or
      numbering — where a role name would do (W)
- [ ] Every item not published has its reason written down
- [ ] Every published item works without the plugin's agents and hooks, or says what it loses
- [ ] The files were staged before the gates ran
- [ ] A blind review found nothing blocking, after its findings were reproduced and fixed
- [ ] The version was set (first release) or bumped (a change), so installed copies can update
- [ ] The release was committed before it was tagged
- [ ] Nothing was pushed

## ⟳ After every use: note what this run taught

**Never edit this file** — it is an installed copy, and the next update overwrites it without a word.
Write what the run taught to a notes file instead, one dated line per point, in the narrowest scope that
fits:

- **local** — `.agents/skill-notes/publish.local.md`, kept out of git (add `*.local.md` to that folder's
  ignore rules if it is not there yet). The default.
- **repo** — `.agents/skill-notes/publish.md`, committed, read by everyone who works in this repository.
- **user** — `~/.agents/skill-notes/publish.md`, true for you in every project.

Then ask the user whether a note should go back into the skill itself, through the flow they use for it
— an issue, a pull request, an edit in the plugin's own repository. When you do not know that flow, ask.

What is worth noting, in this skill:
