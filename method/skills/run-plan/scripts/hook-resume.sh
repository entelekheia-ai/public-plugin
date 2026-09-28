#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# SessionStart hook, matcher "compact". While a plan run is in progress in this session,
# tells the model where it stood; stdout on exit 0 reaches the model.
JQ=$(command -v jq || true)
[ -n "$JQ" ] || exit 0
sid=$("$JQ" -r '.session_id // empty' 2>/dev/null)
state="$HOME/.claude/plan-runs/$sid.json"
[ -n "$sid" ] && [ -f "$state" ] || exit 0
plan=$("$JQ" -r '.plan // "?"' "$state")
running=$("$JQ" -r '[.tracks[]? | select(.status == "running") | .track] | join(", ")' "$state")
next=$("$JQ" -r '[.tracks[]? | select(.status == "runnable") | .track][0] // "none"' "$state")
parked=$("$JQ" -r '[.tracks[]? | select(.status == "parked")] | length' "$state")
routed=$("$JQ" -r '.learnings_routed // false' "$state")
echo "A plan run was in progress before this compaction: plan $plan."
[ -n "$running" ] && echo "Track in progress: $running — check its worktree and notes before dispatching anything."
echo "Next runnable track: $next. Parked tracks: $parked."
echo "Read $state and the plan before acting."
[ "$routed" = true ] || echo "What this run learned before compaction was not written down yet: do that with whatever practice this repository uses, set learnings_routed to true in the state file, then continue."
echo "Invoke the run-plan skill again to restore its full text, then continue at its Step 4."
exit 0
