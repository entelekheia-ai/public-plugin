#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# The run's state file, ~/.claude/plan-runs/<session id>.json, written only through here:
# every write stamps `at` from the clock and replaces the file atomically. Only this script
# writes it — never Write, Edit or a heredoc: a hand-written file has been seen to carry an `at`
# the model invented, hours ahead of the clock, and `learnings_routed: true` set before any
# track ran.
#   init <plan> <repo> <worktree> <branch> <base>   create it; learnings_routed starts false;
#                                                    refuses if the file already exists (resume it, don't restart)
#   track <name> [status=..] [by=..] [depends=A,B] [task=..] [commit=<sha>]
#                                                   add the track or update it; commit= appends.
#                                                   status is one of: runnable, waiting (depends
#                                                   on a track not yet done), running, done,
#                                                   parked, halt — one parked status covers both a
#                                                   track blocked on a decision and one blocked on
#                                                   anything else
#   question <text> [track=..] [options=A|B|C] [recommend=..]
#                                                   append an open question to questions[] — the
#                                                   fallback for a plan file that may not be edited.
#                                                   answer starts null
#   answer <index> <text>                          set questions[<index>].answer (0-based, in
#                                                   append order)
#   routed true|false                               set learnings_routed
#   show                                            print the file
#   path                                            print its path
#   delete                                          remove it (no track left)
# The session id is $CLAUDE_CODE_SESSION_ID. Exits 1 with a message on any misuse, and — for every
# command but path and delete — when jq is not on PATH.
JQ=$(command -v jq || true)
sid=${CLAUDE_CODE_SESSION_ID:-}
[ -n "$sid" ] || { echo "state.sh: CLAUDE_CODE_SESSION_ID is unset" >&2; exit 1; }
DIR="$HOME/.claude/plan-runs"
f="$DIR/$sid.json"
now=$(date +%Y-%m-%dT%H:%M:%S%z)

need_jq() { [ -n "$JQ" ] || { echo "state.sh: jq is not on PATH — install jq to use run-plan's state file" >&2; exit 1; }; }

write() { # <jq filter> [jq args...] — applies the filter to the file and stamps `at`
  filter=$1; shift
  "$JQ" "$@" --arg at "$now" "$filter | .at = \$at" "$f" > "$f.tmp" && mv "$f.tmp" "$f" \
    || { rm -f "$f.tmp"; echo "state.sh: write failed" >&2; exit 1; }
}
need() { [ -f "$f" ] || { echo "state.sh: no state file at $f — run init first" >&2; exit 1; }; }

cmd=${1:-}; [ $# -gt 0 ] && shift
case "$cmd" in
  init)
    need_jq
    [ $# -eq 5 ] || { echo "usage: state.sh init <plan> <repo> <worktree> <branch> <base>" >&2; exit 1; }
    [ -f "$f" ] && { echo "state.sh: $f already exists — resume from it, or delete it first" >&2; exit 1; }
    mkdir -p "$DIR"
    "$JQ" -n --arg plan "$1" --arg repo "$2" --arg wt "$3" --arg branch "$4" --arg base "$5" --arg at "$now" \
      '{plan: $plan, repo: $repo, worktree: $wt, branch: $branch, base: $base,
        learnings_routed: false, at: $at, tracks: [], questions: []}' > "$f.tmp" && mv "$f.tmp" "$f"
    ;;
  track)
    need_jq; need
    [ $# -ge 1 ] || { echo "usage: state.sh track <name> [status=..] [by=..] [depends=A,B] [task=..] [commit=..]" >&2; exit 1; }
    name=$1; shift
    status=; by=; depends=; task=; commit=; has_depends=
    for kv in "$@"; do
      case "$kv" in
        status=*) status=${kv#status=}
          case "$status" in runnable|waiting|running|done|parked|halt) ;;
            *) echo "state.sh: unknown status '$status'" >&2; exit 1 ;; esac ;;
        by=*) by=${kv#by=} ;;
        depends=*) depends=${kv#depends=}; has_depends=1 ;;
        task=*) task=${kv#task=} ;;
        commit=*) commit=${kv#commit=} ;;
        *) echo "state.sh: unknown field '$kv'" >&2; exit 1 ;;
      esac
    done
    write '
      (if any(.tracks[]; .track == $name) then . else
        .tracks += [{track: $name, status: "runnable", by: "implementer", depends_on: [], task: null, commits: []}] end)
      | .tracks |= map(if .track != $name then . else
          (if $status != "" then .status = $status else . end)
          | (if $by != "" then .by = $by else . end)
          | (if $hasdep == "1" then .depends_on = ($depends | split(",") | map(select(. != ""))) else . end)
          | (if $task != "" then .task = $task else . end)
          | (if $commit != "" and (.commits | index($commit) | not) then .commits += [$commit] else . end)
        end)' \
      --arg name "$name" --arg status "$status" --arg by "$by" --arg depends "$depends" \
      --arg hasdep "$has_depends" --arg task "$task" --arg commit "$commit"
    ;;
  question)
    need_jq; need
    [ $# -ge 1 ] || { echo "usage: state.sh question <text> [track=..] [options=A|B] [recommend=..]" >&2; exit 1; }
    text=$1; shift
    track=; options=; recommend=
    for kv in "$@"; do
      case "$kv" in
        track=*) track=${kv#track=} ;;
        options=*) options=${kv#options=} ;;
        recommend=*) recommend=${kv#recommend=} ;;
        *) echo "state.sh: unknown field '$kv'" >&2; exit 1 ;;
      esac
    done
    write '.questions += [{text: $text, track: $track, options: ($options | split("|") | map(select(. != ""))), recommend: $recommend, answer: null}]' \
      --arg text "$text" --arg track "$track" --arg options "$options" --arg recommend "$recommend"
    ;;
  answer)
    need_jq; need
    [ $# -eq 2 ] || { echo "usage: state.sh answer <index> <text>" >&2; exit 1; }
    idx=$1; text=$2
    case "$idx" in ''|*[!0-9]*) echo "state.sh: index must be a non-negative integer" >&2; exit 1 ;; esac
    count=$("$JQ" '.questions | length' "$f") || { echo "state.sh: could not read $f" >&2; exit 1; }
    [ "$idx" -lt "$count" ] || { echo "state.sh: no question at index $idx (have $count)" >&2; exit 1; }
    write '.questions[($idx | tonumber)].answer = $text' --arg idx "$idx" --arg text "$text"
    ;;
  routed)
    need_jq; need
    case "${1:-}" in true|false) ;; *) echo "usage: state.sh routed true|false" >&2; exit 1 ;; esac
    write '.learnings_routed = ($v == "true")' --arg v "$1"
    ;;
  show) need_jq; need; cat "$f" ;;
  path) echo "$f" ;;
  delete) rm -f "$f" ;;
  *) echo "usage: state.sh init|track|question|answer|routed|show|path|delete ..." >&2; exit 1 ;;
esac
