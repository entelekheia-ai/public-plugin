# method

## 0.2.0

### Minor Changes

- b6dce54: Add the `authoring-rules` skill, so writing or rewriting an always-on agent rule has a home in this plugin.
- 56c46d0: First release: the `run-plan` skill.
- 5193b75: route-learnings: consolidation gains a convergence rule, the kept and kept-blocked outcomes, link and decision handling, and a place for what a judge flags; skills learn from notes files instead of being edited.
- dc643b7: Add the `route-learnings` skill: harvest what recent work taught and route each surviving fact to the surface built for it.
- f345a1b: `method` ships a `PostToolUse` hook on the Skill tool that hands any skill the notes written for it as it loads; a written instruction to read them was measured to be ignored.
- 9f389e8: `skill-notes` installs a short notes contract in each coding agent's user-level instructions, so skills from any author learn from your runs without being edited; it also gives a repository its notes folder, adds the contract to a skill of your own, and gathers a skill's notes into a proposal for its maintainer.
- ef7e2aa: `run-plan continue` resumes a run after a compaction; the resume hook shows the user that command and tells the model to invoke the skill as its first act, and the pre-compaction hook asks the summary to name it.

### Patch Changes

- 949d3cc: `authoring-rules` says what it governs in a rules section of an AGENTS.md, applies its steps bullet by bullet, and confirms a relocation against each item's own file.
- e0826d0: The compaction hooks quote `${CLAUDE_PLUGIN_ROOT}`, so an install path with a space no longer turns them off.
- b55be67: `route-learnings` speaks of a task record, not the author's dossier.
- 25ea5bc: `run-plan continue` invokes again every other skill the run was using, and speaks of a task file instead of a dossier.
- c3e3741: `state.sh track` keeps every `commit=` given in one call, and the example shows adding a track that landed before `init`.
- 7abc6d6: run-plan: a context reading above 100% of the configured window reports unknown and names the variable to fix.
