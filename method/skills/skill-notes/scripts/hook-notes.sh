#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# PostToolUse hook, matcher "Skill". Right after a skill loads, hand the model the notes earlier runs
# wrote for it — user (~/.agents/skill-notes/<skill>.md), repo (.agents/skill-notes/<skill>.md) and local
# (.agents/skill-notes/<skill>.local.md) — as additionalContext beside the skill's own text. A written
# instruction asking the model to go and read them was measured to be ignored; handing over the text is
# what makes a skill by any author follow its notes. Silent when no notes file exists, when jq is
# missing, or when the payload names no skill: a hook must never block the skill it serves.
in=$(cat)
command -v jq >/dev/null 2>&1 || exit 0
skill=$(printf '%s' "$in" | jq -r '.tool_input.skill // empty' 2>/dev/null | sed 's/^.*://; s/^\///; s/[[:space:]].*$//')
case $skill in '' | */* | .*) exit 0 ;; esac
cwd=$(printf '%s' "$in" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] || cwd=$PWD
notes=
for f in "$HOME/.agents/skill-notes/$skill.md" "$cwd/.agents/skill-notes/$skill.md" "$cwd/.agents/skill-notes/$skill.local.md"; do
	[ -f "$f" ] && notes="$notes
--- $f
$(cat "$f")"
done
[ -n "$notes" ] || exit 0
ctx="Notes the person's own earlier runs wrote for the skill \"$skill\" — user scope, then repository, then local; where two disagree, the more specific wins. Apply them over the skill's own text:$notes"
jq -n --arg c "$ctx" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
exit 0
