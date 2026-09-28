#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Between two tracks of a plan run: reads a usage reading and prints one verdict on the first
# line, which selects the next step of the run-plan skill (Step 8).
#   continue                        start the next track
#   record-learnings                context is past CTX_ROUTE: write down what the run has learned, then continue
#   wait <epoch> <HH:MM>            the 5-hour window is past LIMIT_WAIT: stop at a clean state and wait
#   unknown <reason>                nothing fresh to read, or jq is missing: treat as record-learnings, and say so in the report
# Environment: CTX_ROUTE (default 60), LIMIT_WAIT (default 85), STALE_SECS (default 900),
# RUN_PLAN_CONTEXT_WINDOW (default 200000, tokens — set this to your model's real context window).
#
# Context: ~/.claude/usage/sessions/<session id>.json when it is fresh, otherwise this session's
# own transcript — the last main-loop turn's input tokens over RUN_PLAN_CONTEXT_WINDOW. The
# transcript is what a run in the VS Code extension and a headless run read, since neither writes
# a session usage file. 5-hour window: only ~/.claude/usage/rate_limits.json records it, and
# nothing ships that file by default — it needs a statusline script on your own setup that writes
# it on every render. Without one the limit reads as unknown and the context alone decides.
JQ=$(command -v jq || true)
DIR="$HOME/.claude/usage"
CTX_ROUTE=${CTX_ROUTE:-60}
LIMIT_WAIT=${LIMIT_WAIT:-85}
STALE_SECS=${STALE_SECS:-900}
CONTEXT_WINDOW=${RUN_PLAN_CONTEXT_WINDOW:-200000}
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
    resets_hhmm=$(date -d @"$resets" +%H:%M 2>/dev/null || date -r "$resets" +%H:%M)
    echo "wait $resets $resets_hhmm"
    echo "5h window at ${used}% (threshold ${LIMIT_WAIT}%)"
    exit 0
  fi
  limit_note="5h window at ${used:-?}%"
else
  limit_note="no fresh rate_limits.json (needs a statusline script on your setup that writes it)"
fi

from_transcript() { # prints "<percent> <tokens>", or nothing
  t=$(ls "$HOME"/.claude/projects/*/"$sid".jsonl 2>/dev/null | head -n 1)
  [ -n "$t" ] || return 0
  tokens=$(grep '"type":"assistant"' "$t" | tail -n 40 | "$JQ" -r '
    select(.isSidechain != true and .message.usage != null and .message.model != "<synthetic>")
    | (.message.usage | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0))' 2>/dev/null | tail -n 1)
  [ -n "$tokens" ] || return 0
  echo "$((tokens * 100 / CONTEXT_WINDOW)) $tokens"
}

ctx=; ctx_src=
ctx_file="$DIR/sessions/$sid.json"
if [ -n "$sid" ] && [ -n "$(fresh "$ctx_file")" ]; then
  ctx=$("$JQ" -r '.context_window.used_percentage // empty | floor' "$ctx_file")
  ctx_src="statusline"
fi
if [ -z "$ctx" ] && [ -n "$sid" ]; then
  reading=$(from_transcript)
  if [ -n "$reading" ]; then
    set -- $reading
    ctx=$1; ctx_src="transcript, $2 of $CONTEXT_WINDOW tokens"
  fi
fi

if [ -z "$ctx" ]; then
  echo "unknown context unreadable for session ${sid:-<unset>}; $limit_note"
elif [ "$ctx" -ge "$CTX_ROUTE" ]; then
  echo "record-learnings"
  echo "context at ${ctx}% (threshold ${CTX_ROUTE}%, $ctx_src); $limit_note"
else
  echo "continue"
  echo "context at ${ctx}% ($ctx_src); $limit_note"
fi
