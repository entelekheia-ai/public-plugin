#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Between two tracks of a plan run: reads what Claude Code's own statusline recorded and prints
# one verdict on the first line, which selects the next step of the run-plan skill (Step 7).
#   continue                        start the next track
#   route-learnings                 context is past CTX_ROUTE: write down what the run has learned, then continue
#   wait <epoch> <HH:MM>            the 5-hour window is past LIMIT_WAIT: stop at a clean state and wait
#   unknown <reason>                nothing fresh to read, or jq is missing: continue, and say so in the report
# Environment: CTX_ROUTE (default 60), LIMIT_WAIT (default 85), STALE_SECS (default 900).
# The files this reads are written by a Claude Code statusline that records usage — this script does
# not ship or configure one. A resumed session reuses its id, so a file older than STALE_SECS is
# treated as absent rather than stale data from an earlier session.
JQ=$(command -v jq || true)
DIR="$HOME/.claude/usage"
CTX_ROUTE=${CTX_ROUTE:-60}
LIMIT_WAIT=${LIMIT_WAIT:-85}
STALE_SECS=${STALE_SECS:-900}
now=$(date +%s)
sid=${CLAUDE_CODE_SESSION_ID:-}

if [ -z "$JQ" ]; then
  echo "unknown jq not found on PATH"
  exit 0
fi

fresh() { # <file> -> prints the file's `at` if fresh, nothing otherwise
  [ -f "$1" ] || return 0
  at=$("$JQ" -r '.at // 0' "$1" 2>/dev/null)
  [ -n "$at" ] && [ $((now - at)) -le "$STALE_SECS" ] && echo "$at"
}

rl="$DIR/rate_limits.json"
if [ -n "$(fresh "$rl")" ]; then
  used=$("$JQ" -r '.five_hour.used_percentage // empty | floor' "$rl")
  resets=$("$JQ" -r '.five_hour.resets_at // empty' "$rl")
  if [ -n "$used" ] && [ -n "$resets" ] && [ "$used" -ge "$LIMIT_WAIT" ] && [ "$resets" -gt "$now" ]; then
    echo "wait $resets $(date -r "$resets" +%H:%M)"
    echo "5h window at ${used}% (threshold ${LIMIT_WAIT}%)"
    exit 0
  fi
  limit_note="5h window at ${used:-?}%"
else
  limit_note="no fresh rate_limits.json"
fi

ctx_file="$DIR/sessions/$sid.json"
if [ -n "$sid" ] && [ -n "$(fresh "$ctx_file")" ]; then
  ctx=$("$JQ" -r '.context_window.used_percentage // empty | floor' "$ctx_file")
  if [ -n "$ctx" ] && [ "$ctx" -ge "$CTX_ROUTE" ]; then
    echo "route-learnings"
    echo "context at ${ctx}% (threshold ${CTX_ROUTE}%); $limit_note"
    exit 0
  fi
  ctx_note="context at ${ctx:-?}%"
else
  ctx_note="no fresh context file for session ${sid:-<unset>}"
fi

case "$limit_note$ctx_note" in
  *"no fresh"*) echo "unknown $limit_note; $ctx_note" ;;
  *) echo "continue"; echo "$limit_note; $ctx_note" ;;
esac
