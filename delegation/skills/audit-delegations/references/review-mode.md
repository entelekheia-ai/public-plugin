# `review` — repair existing definitions against their runs

Read this when the skill is invoked as `review <definition>…`, or when a run of an existing subagent
surprised. The other steps of the skill decide whether a role deserves a definition; this mode keeps a
definition that already exists true to what its runs do. It is target-state like the rest of the skill:
a second review over newer runs repairs what drifted since the first.

The unit is the definition, and the evidence is its runs. A definition read on its own looks complete —
what it forgot shows up only as a turn spent on a refusal, a report past its cap, or a rule restated in
every brief.

## R1 — Measure the runs

```sh
node ${CLAUDE_SKILL_DIR}/scripts/agent-runs.mjs --refusals [--days=30] \
  <implementer.md> --cap-lines=50 --expect='Rulings' \
  <reviewer.md> --cap-words=900 --expect='Declined to judge'
```

Pass every definition of the family in one call — an implementer and its reviewer, and the sibling
definition of the same role in another repository — so the comparison in R3 reads one output. Each
definition is followed by its own options: the cap its body states, in the unit the body uses
(`--cap-words` or `--cap-lines`), and one `--expect` per section the body calls required, copied from the
body's heading word for word — a paraphrase flags every report as missing it.

A run flagged `running?` is still writing its transcript, and the review you are running is one of
them: read none of its numbers.

Each line of the output selects a repair:

| The output shows | The repair |
|---|---|
| `[isolation]` refusals | the body is missing how to phrase commands inside a worktree-isolated agent: one git command per call, `/usr/bin/git`, literal paths (`references/frontmatter.md`, `isolation`) |
| `[hook]` refusals of a command the body **tells the agent to run** | a contradiction: the body or the hook is wrong. Decide which from what the rule protects, and fix that side |
| `[hook]` refusals of a command that reads | the hook has a false positive: fix the hook with a test that fails first |
| `[hook]` refusals of a write the body forbids | the hook did its job; the body may need to say *why*, if the agent retried |
| `[permission]` refusals | a path the agent was never going to get, usually under `.claude/`: the body says to report the text instead of retrying |
| `turns n/max` flagged | the ceiling is too low for the role, or the runs loop: read the transcript before raising `maxTurns` |
| `report Nw > cap` | a cap stated without a rule for what to cut; the body says to cut evidence, never a finding or a ruling |
| `missing /Rulings/` | a required section the report skipped; check whether a background dispatch lost the report before blaming the body |

A run with `no transcript` was dispatched in a session whose subagent files are gone; leave it out rather
than read its stub.

**A refusal is evidence about the hook as it stood that day.** Before repairing a `[hook]` line, compare
its date with the last change to the hook — the definition's frontmatter, and the script behind it
(`git log -1 --format=%cs -- <path>`). A refusal older than that change came from code that no longer
runs; replay its command against the current hook (R4's extraction) and repair only what still fires.

A required section missing from a report is two different findings. When the report carries the content
under another heading, or as a closing remark, the body does not say *where* the content goes; when the
content is absent, the body does not say it is owed. Open the report before choosing the repair.

## R2 — Read what the counts cannot

Open the briefs of the last few dispatches (`mine-delegations.mjs <repo> --prompt=<i>` finds them). A
rule every brief restates belongs in the definition; a rule the definition carries and briefs still
restate means the body says it where the agent does not look. A brief that asked for what the body
forbids — a ranking from an agent that must not recommend — and a report that complied means the body
states the prohibition without saying what to do when the brief breaks it. Then open two reports and check each
section against what the caller did next — a section the caller never read is a cut, a question the
caller had to ask the agent back is a missing section.

## R3 — Compare sibling definitions

Two definitions of one role in two repositories drift apart one improvement at a time. Diff their bodies
section by section: every rule one has and the other lacks is either carried across, adapted to the
other repository's shape, or answered with why it stays out. A shared script behind both — a hook parser
copied into each repository — is compared byte for byte, and a fix to one copy goes to the other in the
same pass.

## R4 — Apply, then prove each hook

Edit each definition. For every hook you changed, extract it and feed one input it must refuse and one it
must pass, as in Step 6:

```sh
node ${CLAUDE_SKILL_DIR}/scripts/extract-hooks.mjs <definition.md> <tmp-dir>
printf '%s' '<hook input JSON>' | sh <tmp-dir>/<Event>-<n>.sh; echo "exit=$?"
```

A hook backed by a script with its own suite runs that suite too, with the new case written first and
seen failing.

Commit each repository through its own gate. The next review reads the runs made after this commit; a
refusal kind that does not drop there means the repair missed.
