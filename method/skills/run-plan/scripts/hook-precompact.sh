#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# PreCompact hook. While a plan run is in progress in this session, its stdout is
# appended to the compaction instructions, so the summary keeps what the resume needs.
# Exits 0 in every case: blocking an automatic compaction would let the context overflow.
JQ=$(command -v jq || true)
[ -n "$JQ" ] || exit 0
sid=$("$JQ" -r '.session_id // empty' 2>/dev/null)
state="$HOME/.claude/plan-runs/$sid.json"
[ -n "$sid" ] && [ -f "$state" ] || exit 0
unanswered=$("$JQ" -r '[.questions[]? | select(.answer == null or .answer == "")] | .[] | "- " + .text' "$state")
cat <<EOF
A plan run (the run-plan skill) is in progress (state file: $state). Preserve verbatim in the summary:
the plan path, the repository and worktree, each finished track with its commit, the track in
progress and how far it got, each parked track with its question, the path of every open task file,
the name of every skill this run invoked (routing, hand-off, publishing, …), and — one line each —
anything learned since the last time it was written down that has not been written down yet.
End the summary's next step with this, as its first action: invoke the
Skill tool with skill "method:run-plan" and args "continue" — the skill's full text does not survive
the compaction, and a summary that only says "continue at Step 4" gets followed from memory.
EOF
if [ -n "$unanswered" ]; then
  echo "Unanswered questions in the state file's questions[]:"
  printf '%s\n' "$unanswered"
fi
exit 0
