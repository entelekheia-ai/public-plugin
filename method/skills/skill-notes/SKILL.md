---
name: skill-notes
description: 'Let every skill you use learn from your runs without anyone editing it: install a short notes contract in the user-level instruction file of each coding agent you use, give a repository its notes folder, add the contract to a skill of your own, or gather a skill''s notes into a proposal for its maintainer. Use when you want skills from other authors to remember what your runs taught them, when a skill keeps making the same mistake here, when a plugin update wiped a fix you made inside its skill, or "/skill-notes install|adopt|propose|audit".'
argument-hint: '[install | adopt <skill-folder> | propose <skill> | audit]'
user-invocable: true
user_invocable: true
---

# Give every skill a place to learn, outside the skill

**Before starting, read your notes for this skill**, where they exist — `~/.agents/skill-notes/skill-notes.md`,
then `.agents/skill-notes/skill-notes.md`, then `.agents/skill-notes/skill-notes.local.md`. Where two
disagree, the more specific one wins. They hold what earlier runs taught; see the last section for how they
are written.

A skill you installed is a copy: its next update overwrites whatever you changed inside it, without a word.
So a skill cannot learn from your runs by being edited. It can learn from a file it reads: notes kept beside
the work, in three scopes — **user** (`~/.agents/skill-notes/<skill>.md`, true for you everywhere), **repo**
(`.agents/skill-notes/<skill>.md`, committed, read by everyone working in the repository) and **local**
(`.agents/skill-notes/<skill>.local.md`, kept out of git, the default) — where `<skill>` is the skill's
folder name. A skill written with that contract reads them itself. This skill makes every other skill do the
same, with two lines in the instruction file each coding agent loads for every session.

**This is a target-state skill.** The target is: the contract installed in the instruction file of every
agent you use and agreed to, the current repository with its notes folder, and nothing written anywhere you
did not agree to. Running it again repairs a file whose contract text is older and changes nothing else;
`audit` reports and writes nothing.

Every write goes through `scripts/notes.sh`, one file per call, and only after you said yes to that file.
It needs a POSIX shell and `awk`; no other tool.

## The contract — what gets installed

```sh
sh ${CLAUDE_SKILL_DIR}/scripts/notes.sh block
```

prints it: two sentences between two marker lines. Before running any skill, read its three notes files,
most specific winning, with `<skill>` the folder name without any `<plugin>:` prefix; after a run that
taught something, append one dated line to the local one, creating the folder if needed; and never edit an
installed copy of a skill, while a skill whose source the person keeps stays theirs to edit. The markers make installing twice a no-op and
removing it exact.

## Step 1 — See where things stand

```sh
sh ${CLAUDE_SKILL_DIR}/scripts/notes.sh status [repo-dir]
```

It lists the user-level instruction file of each agent that has one — Claude Code (`CLAUDE.md` in
`CLAUDE_CONFIG_DIR`, default `~/.claude`),
Codex CLI (`AGENTS.md` in `CODEX_HOME`, default `~/.codex`), Gemini CLI (`~/.gemini/GEMINI.md`), Copilot
CLI (`copilot-instructions.md` in `COPILOT_HOME`, default `~/.copilot`) — with one state each: *folder
absent* (that agent is not in use here), *no file yet*, *file present, no contract*, *contract current* or
*contract present, older text*, or *markers damaged* (a begin marker without its end, two blocks, a
marker inside a code block — the script refuses such a file and names the line, so fix it by hand); for
Codex it also says when an `AGENTS.override.md` would be read instead; and whether the repository has `.agents/skill-notes/` with `*.local.md`
ignored. In `audit` mode, report this and stop.

## Step 2 — Install the contract where the person agrees

Ask, in one question, which of the files whose state is not *contract current* and whose agent is in use
should get the contract — list each path with its state, and show the block itself so the person sees
exactly what goes in. A file the person does not name is left alone. Then, one call per agreed file:

```sh
sh ${CLAUDE_SKILL_DIR}/scripts/notes.sh install <file>
```

It prints `added`, `updated` (an older copy of the block replaced) or `already current`, and refuses a file
whose agent folder does not exist rather than creating it — an agent that is not installed does not need
instructions. Two agents take their user instructions where no fixed path reaches: **Cursor** keeps them in a settings
field (Settings → Rules → User Rules), and **Copilot in VS Code** in a user instructions file VS Code
creates in the profile from the Command Palette ("Chat: New Instructions File"), under a name chosen then.
For either, print the block and tell the person where to paste it; do not look for a file to write.

The contract takes effect in the next session of each agent, since the instruction file is read at start.

## Step 3 — Give the repository its notes folder

When the current directory is a repository and Step 1 found no notes folder, or one without `*.local.md`
ignored, ask, then:

```sh
sh ${CLAUDE_SKILL_DIR}/scripts/notes.sh init-repo [repo-dir]
```

It creates `.agents/skill-notes/` with a `.gitignore` holding `*.local.md`, so local notes never reach a
commit while repo notes can. A skill following the contract creates the folder on its own the first time it
writes, but only this step also keeps the local files out of git from the start.

## `adopt <skill-folder>` — the contract inside a skill you own

For a skill you wrote and keep editing yourself — your own `SKILL.md`, never an installed copy — the
contract can live in the skill instead of in the agent's instructions, so it travels with the skill to
anyone you share it with. Two edits, each with its exact text:

1. Right after the H1, the paragraph that opens this file under its title ("Before starting, read your
   notes for this skill…"), with `skill-notes` replaced by the skill's folder name.
2. At the end, the "After every use: note what this run taught" section that closes this file, with the same
   replacement, and under its last line the few things a run of *that* skill is most likely to teach.

Show both edits and apply them only after the person agrees. Where a subagent that applies a decided edit
list exists (such as `publishing:edit-applier`), it can apply them and you accept the result by diff; otherwise apply them yourself.

## `propose <skill>` — send the notes back to whoever maintains the skill

Notes are local by design; the fix they describe belongs in the skill. To carry it there:

1. Read the skill's three notes files, and list each dated line with its scope.
2. Drop the lines that only hold for this machine or this repository, and merge the ones that say the same
   thing. What remains is a claim about the skill itself.
3. Draft the proposal: which step of the skill each point corrects, the evidence the note recorded, and the
   text you would put there.
4. Ask the person how the maintainer takes changes — an issue, a pull request, a message, a direct edit if
   the skill is their own — and deliver it that way, or hand them the draft. Never open an issue or a pull
   request without that answer.

Once the maintainer has taken a point, the note that carried it is deleted: a note that the skill now says
itself is a second copy that drifts.

## What a hookless or skills-only install loses

Nothing: this skill ships no hooks and no agents, and the contract is plain text any agent reads.

## Checklist

- [ ] `status` ran first, and its states were shown to the person
- [ ] The block was shown before any file was written, and only the files the person named were written
- [ ] No folder was created for an agent that is not in use
- [ ] Cursor and Copilot in VS Code got the block to paste, not a file write
- [ ] The repository has `.agents/skill-notes/` with `*.local.md` ignored, if the person agreed
- [ ] A proposal went to a maintainer only through the flow the person named

## ⟳ After every use: note what this run taught

**Never edit this file** — it is an installed copy, and the next update overwrites it without a word.
Write what the run taught to a notes file instead, one dated line per point, in the narrowest scope that
fits:

- **local** — `.agents/skill-notes/skill-notes.local.md`, kept out of git (add `*.local.md` to that
  folder's ignore rules if it is not there yet). The default.
- **repo** — `.agents/skill-notes/skill-notes.md`, committed, read by everyone who works in this
  repository.
- **user** — `~/.agents/skill-notes/skill-notes.md`, true for you in every project.

Then ask the user whether a note should go back into the skill itself, through the flow they use for it
— an issue, a pull request, an edit in the plugin's own repository. When you do not know that flow, ask.

What is worth noting, in this skill:

- An agent whose user-level instruction file lives somewhere this skill does not list, or moved: name the
  agent, the path, and where that path is documented.
- A skill that ignored its notes although the contract was installed — which agent, and whether the notes
  file existed under the skill's folder name or another.

Verified against: Claude Code user memory (`~/.claude/CLAUDE.md`), Codex CLI (`AGENTS.md` in
`CODEX_HOME`), Gemini CLI (`~/.gemini/GEMINI.md`), GitHub Copilot CLI custom instructions
(`~/.copilot/copilot-instructions.md`), and Cursor's User Rules as a settings field — each from its
documentation, 2026-09-28.
