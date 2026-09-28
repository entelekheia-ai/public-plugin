# Subagent frontmatter — what each field buys, and the hook recipes

Read this at Step 4, while writing a definition. Every field below is one Claude Code documents for a
subagent in `.claude/agents/<name>.md`; a field it does not recognise is ignored without an error, so a
misspelt key is a rule that silently does not exist. `claude plugin validate <dir>/.claude/agents`
checks that the frontmatter parses.

## Fields

| Field | Set it when | What to know |
|---|---|---|
| `name` | always | Every `.claude/agents/` from the session's directory up to the repository root is loaded, and a name defined twice loads once. Prefix it with the repository (`<repo>-reviewer`), so a session that loads several repositories' agents never collides. |
| `description` | always | The dispatcher matches on it. Open with the scope ("<repo> repository only (…)"), then the triggers, then what never to use it for. |
| `model` | always | Pins the model. **A `model` passed on the call overrides it**, so a caller omits `model` except to escalate on purpose. The transcript's `message.model` is the model that ran; an IDE label can disagree with it. |
| `effort` | the routing asks for a level | The only way an effort level reaches a subagent dispatched through the Agent tool. The call cannot carry one. |
| `tools` | always, as an allowlist | Everything not listed is out, MCP tools included. Leaving `Agent` out is how "launch no subagent" becomes true rather than asked for. A reviewer gets no `Edit` or `Write`. Add `LSP` where finding callers matters. |
| `disallowedTools` | an agent with no `tools` allowlist | With an allowlist it adds nothing. With a specifier (`Bash(git push *)`) it removes the whole tool, so it cannot block one command — a hook does. |
| `isolation: worktree` | the agent works on a checkout of its own, read-only or throwaway | The worktree branches from the default branch, not from the caller's HEAD, and starts with no dependencies and nothing built. It is removed automatically only when it ends clean **and on its branch**: a detached HEAD left behind keeps it. Wrong for agents that must share one tree with siblings or build on the caller's uncommitted work. **Claude Code refuses, inside it, every command it cannot prove stays in the worktree**: a git command chained with `&&` or `;`, a `git` a shell hook rewrote into a wrapper, a variable as a program's argument, text naming git piped into another program. Each refusal costs the agent a turn, so the body tells it to run one git command per call as `/usr/bin/git` with literal paths. |
| `omitClaudeMd: true` | the brief and the repository's own map are everything the agent needs | Drops the inherited user and project `CLAUDE.md`. A session opened at a parent folder otherwise hands the agent that parent's map. Tell the agent to read the repository's agent instructions file (`AGENTS.md`, `CLAUDE.md`) itself. |
| `maxTurns` | always | A cost ceiling: at the limit the agent returns marked partial and can be resumed. Set it at about 1.5× the longest run measured for the role (`agent-runs.mjs <definition.md>` prints turns per run). |
| `hooks` | a rule in the body is deterministic | See below. |
| `color` | optional | `red`, `blue`, `green`, `yellow`, `purple`, `orange`, `pink`, `cyan`. |
| `memory` | rarely | A per-agent store outside the repository, tool-managed. Where learnings already have a routed home, it becomes a third copy nobody reviews. |
| `skills` | a skill the agent must follow from its first turn | Injects the whole skill body at start. |
| `permissionMode` | rarely | `plan` blocks the builds a reviewer needs to run. |
| `background`, `initialPrompt`, `mcpServers` | rarely | Background is already the default; `initialPrompt` applies only to `--agent` main sessions; the `tools` allowlist already excludes MCP. |

## Hooks

Frontmatter hooks exist only while that agent runs. Three facts decide how to use them:

- **They run only once the folder holding the agent file is trusted — and a subagent dispatched from a
  `claude -p` session in a trusted folder runs them.** Measured 2026-09-26 on Claude Code 2.1.280 (CLI): a
  headless run's subagent had a `PreToolUse` hook refuse one of its commands with exit 2. So a headless
  test exercises the hook too, and a false positive there costs the agent a turn. The prose rule still
  stays beside each hook as the fallback for an untrusted folder. Test the hook commands with
  `scripts/extract-hooks.mjs` before the run, with inputs that must pass as well as ones that must block.
- **All hook events are supported. A `Stop` hook becomes `SubagentStop`.** Exit 2 blocks and hands the
  stderr to the agent; exit 0 lets it through.
- **`once` is ignored in agent frontmatter**, so a setup step must guard itself (compare a stamp) rather
  than rely on running once.

The hook's working directory is not guaranteed to be the repository — a session opened at a parent folder
runs it there — so a recipe reads `cwd` or the tool input from stdin, and a script it calls is addressed
through `$CLAUDE_PROJECT_DIR`, never by a relative path. A short recipe **MAY** stay inline as `node -e`;
one that must parse something **MUST** live in a tested script.

**Let git run only its read-only subcommands** (`PreToolUse`, matcher `Bash`), and optionally keep
`Write`/`Edit` inside a temporary directory (matcher `Edit|Write|NotebookEdit`, flag
`--writes-under-tmp`): the script and its test ship in the `delegation` plugin as `scripts/git-read-only.mjs`
and `scripts/git-read-only.test.mjs` — copy both into the repository at `scripts/agent-hooks/git-read-only.mjs`
and `scripts/agent-hooks/git-read-only.test.mjs`, called through
`$CLAUDE_PROJECT_DIR` with the agent's name, wrapped in the fallback shown below — never as a bare
`node` line, which fails open when the script is absent.

It parses the command — heredoc bodies removed, split on shell separators, `bash -c`, `xargs`, `sudo`,
`env` and `find -exec` unwrapped — and allows a git subcommand only from a read-only list, so an alias or
a verb nobody listed is refused rather than let through. A regex over the whole command cannot do this: a
pattern tried here let 43 of 66 state-changing commands through and refused `git merge-base`, `git stash
list` and a heredoc that mentioned a verb. Its cases are `scripts/agent-hooks/git-read-only.test.mjs`;
a repository without that script copies it with its test. It reads the command only, never the call's
`description`, which is prose and names verbs freely.

Its threat model is a cooperative agent changing git state **by accident**. Deliberate obfuscation — a
variable as the command name, `${IFS}`, text piped into a shell, git's own command-running options — is
out of scope, since Bash is otherwise unrestricted; the prose rule beside the hook is what binds there.
A parse failure refuses (exit 2). A **missing script** would make `node` exit 1, which Claude Code treats
as a non-blocking error, so the guard would disappear without a word wherever `$CLAUDE_PROJECT_DIR` lacks
it — a session opened in another repository, or a branch that predates it. The hook command therefore
tests for the script first and, when it is absent, refuses any command that mentions git (and, in the
write hook, every write) with a message naming the cause:

```yaml
command: |
  f="$CLAUDE_PROJECT_DIR/scripts/agent-hooks/git-read-only.mjs"; in=$(cat)
  if [ -f "$f" ]; then printf "%s" "$in" | node "$f" <agent-name>; exit $?; fi
  case "$in" in *git*) echo "<agent-name>: the git guard is missing …" >&2; exit 2;; esac
```

**Refuse edits to files nobody edits by hand** (`PreToolUse`, matcher `Edit|Write|NotebookEdit`): test
`tool_input.file_path` against a list of path regexes ending in the file, and exit 2 with the path. It
watches the edit tools only; say so in the body, because a shell redirect is outside it.

**Install dependencies once per lockfile** (`PreToolUse`, matcher `Bash`, `timeout: 600`): resolve the
toplevel from `cwd`, run only when it lies under `/.claude/worktrees/` (never a main checkout), hash
`package-lock.json`, and run `npm ci` only when the hash differs from a stamp kept in
`node_modules/`. It then reinstalls by itself after the agent checks out a commit with another lockfile.

**Refuse to finish on a dirty or detached worktree** (`Stop`): exit 0 when the input carries
`stop_hook_active: true` (the loop guard), otherwise run `git status --porcelain` and
`git branch --show-current` in `cwd` and exit 2 naming what is left. An isolated worktree's branch is
`worktree-<basename of the worktree>`.
