# delegation

## 0.2.0

### Minor Changes

- e0826d0: The `plan-scout`, `blind-run` and `reviewer` agents, and the read-only guard they share, shipped as the plugin's own `PreToolUse` hook because Claude Code ignores a plugin agent's `hooks:` field.
- 5358e9f: `audit-delegations` mines your past sessions for delegations briefed again and again and turns each recurring role into a tested subagent; the `miner` agent does its mining, read-only.
- b6dce54: Add the `fact-sheet` agent, so a plan or design can rest on a read-only census of the current code, every claim addressed by `file:line`.
- 0185931: First release: the `route-work` skill.
- 77fe664: Add the `hand-off` and `work-a-task` skills and the `implementer` agent, so the whole prepare-dispatch-verify-commit-review-merge loop for delegated work — not only where it runs — has a home in this plugin.

### Patch Changes

- dbb5756: `blind-run` follows any written procedure — a README's quickstart, a setup guide, a runbook, a plan track's spec — not only a skill; `plan-scout` also fires before building something that has no plan.
- 05f1f78: `audit-delegations` and `miner` count the distinct tasks a long session carried, keep a renamed agent as one role, and send a role that already has a definition to `review`; `implementer` changes no state outside the worktree that outlives the run.
- 7eff100: `implementer` says how to build a fixture git repository the read-only guard lets through: in a script run with `sh`.
- 9108398: `audit-delegations` and `miner` state one evidence rule, the distinct task, with a test for telling a fan-out from separate tasks; `--calls` prints each call to the minute.
