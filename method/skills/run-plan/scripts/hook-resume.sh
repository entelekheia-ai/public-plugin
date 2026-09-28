#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# SessionStart hook, matcher "compact". While a plan run is in progress in this session, it answers
# in JSON with two messages: `systemMessage` tells the user the one command that resumes the run, and
# `additionalContext` tells the model to make that invocation its first act. A compacted session trusts
# its summary and skips a skill it only remembers, so the resume is written as an order, not a hint.
JQ=$(command -v jq || true)
[ -n "$JQ" ] || exit 0
sid=$("$JQ" -r '.session_id // empty' 2>/dev/null)
state="$HOME/.claude/plan-runs/$sid.json"
[ -n "$sid" ] && [ -f "$state" ] || exit 0
plan=$("$JQ" -r '.plan // "?"' "$state")
running=$("$JQ" -r '[.tracks[]? | select(.status == "running") | .track] | join(", ")' "$state")
next=$("$JQ" -r '[.tracks[]? | select(.status == "runnable") | .track][0] // "none"' "$state")
waiting=$("$JQ" -r '[.tracks[]? | select(.status == "waiting")] | length' "$state")
parked=$("$JQ" -r '[.tracks[]? | select(.status == "parked")] | length' "$state")
halt=$("$JQ" -r '[.tracks[]? | select(.status == "halt")] | length' "$state")
unanswered=$("$JQ" -r '[.questions[]? | select(.answer == null or .answer == "")] | length' "$state")
routed=$("$JQ" -r '.learnings_routed // false' "$state")
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cmd="/method:run-plan continue"

context="A plan run was in progress before this compaction: plan $plan.
FIRST ACT, before reading files or answering: invoke the Skill tool with skill \"method:run-plan\" and args \"continue\". The skill's full text is not in this context any more — the summary is a retelling of it, and a step it skips is a step that will not happen."
[ -n "$running" ] && context="$context
Track in progress: $running — check its worktree and notes before dispatching anything."
context="$context
Next runnable track: $next. Waiting tracks: $waiting. Parked tracks: $parked. Halted tracks: $halt. Unanswered questions: $unanswered.
State file: $state. If the plan has a \"Read these first\" section, read it, in order, then invoke again every other skill the run was using before the compaction (routing, hand-off, publishing — the summary names them), and only then go to Step 4."
[ "$routed" = true ] || context="$context
What this run learned before compaction was not written down yet: do that with whatever practice this repository uses, then run: sh \"$dir/state.sh\" routed true"

user="Plan run in progress — next: $next. To resume it, send: $cmd"
[ -n "$running" ] && user="Plan run in progress — $running was running when the context was compacted. To resume it, send: $cmd"

"$JQ" -n --arg ctx "$context" --arg msg "$user" \
  '{systemMessage: $msg, hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
exit 0
