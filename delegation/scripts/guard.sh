#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# PreToolUse hook for the whole session, because Claude Code ignores a plugin agent's own `hooks:` field.
# It acts only inside this plugin's read-only agents: the payload's `agent_type` names the subagent a
# tool call came from, and guard.mjs hands the call to git-read-only.mjs with that agent's mode. Every
# other tool call — the main loop's, another agent's — leaves here at the `case`, before node starts.
in=$(cat)
case "$in" in
  *'"agent_type"'*'delegation:'*) ;;
  *) exit 0 ;;
esac
if ! command -v node >/dev/null 2>&1; then
  echo "delegation: node is not on PATH, so this agent's read-only guard cannot run; the call is refused." >&2
  exit 2
fi
printf '%s' "$in" | node "$(dirname "$0")/guard.mjs"
