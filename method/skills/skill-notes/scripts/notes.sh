#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# notes.sh — installs, checks and removes the skill-notes contract. Every write is one file per call,
# made only after the person at the keyboard agreed to it; the skill asks, this script writes.
#
#   notes.sh status [repo-dir]     where the contract is installed, and whether the repository has a notes folder
#   notes.sh block                 print the block, for a harness whose instructions are a settings field
#   notes.sh install <file>        add the block to <file>, or bring an older copy of it up to date
#   notes.sh remove <file>         take the block out of <file>
#   notes.sh init-repo [repo-dir]  create <repo>/.agents/skill-notes/ with *.local.md kept out of git
#
# The block sits between two marker lines, so install is idempotent and remove leaves the rest of the
# file untouched.
set -eu

BEGIN='<!-- skill-notes:begin -->'
END='<!-- skill-notes:end -->'

block() {
	cat <<'EOF'
<!-- skill-notes:begin -->
Before running any skill, read its notes where they exist: `~/.agents/skill-notes/<skill>.md`, then `.agents/skill-notes/<skill>.md`, then `.agents/skill-notes/<skill>.local.md` (`<skill>` is the skill's folder name; the more specific file wins where two disagree).
After a run that taught something, append one dated line to `.agents/skill-notes/<skill>.local.md` (create the folder, keep `*.local.md` out of git), and never edit a skill you do not own — an installed copy is overwritten on its next update.
<!-- skill-notes:end -->
EOF
}

# The user-level instruction file of each harness that has one, one per line: "<harness>\t<path>".
targets() {
	printf 'Claude Code\t%s\n' "$HOME/.claude/CLAUDE.md"
	printf 'Codex CLI\t%s\n' "${CODEX_HOME:-$HOME/.codex}/AGENTS.md"
	printf 'Gemini CLI\t%s\n' "$HOME/.gemini/GEMINI.md"
	printf 'Copilot CLI\t%s\n' "${COPILOT_HOME:-$HOME/.copilot}/copilot-instructions.md"
}

has_block() { [ -f "$1" ] && grep -qF "$BEGIN" "$1"; }

current_block() { [ -f "$1" ] && awk -v b="$BEGIN" -v e="$END" '$0==b{p=1} p{print} $0==e{p=0}' "$1"; }

strip_block() {
	# drop the block, and the blank lines it leaves at the end of the file
	awk -v b="$BEGIN" -v e="$END" '$0==b{skip=1; next} $0==e{skip=0; next} skip{next}
		/^$/{held=held "\n"; next} {printf "%s%s\n", held, $0; held=""}' "$1"
}

cmd_status() {
	repo=${1:-.}
	echo "== user-level instruction files"
	targets | while IFS="$(printf '\t')" read -r harness path; do
		dir=$(dirname "$path")
		if [ ! -d "$dir" ]; then state="harness folder absent — not in use here"
		elif [ ! -f "$path" ]; then state="no file yet"
		elif ! has_block "$path"; then state="file present, no contract"
		elif [ "$(current_block "$path")" = "$(block)" ]; then state="contract current"
		else state="contract present, older text"; fi
		printf '  %-12s %s\n      %s\n' "$harness" "$path" "$state"
	done
	echo "  Cursor, Copilot in VS Code: instructions are a settings field, not a file — 'notes.sh block' prints the text to paste"
	echo "== notes folder in $repo"
	folder="$repo/.agents/skill-notes"
	if [ ! -d "$folder" ]; then echo "  $folder — absent"
	elif grep -qxF '*.local.md' "$folder/.gitignore" 2>/dev/null; then echo "  $folder — present, *.local.md ignored"
	else echo "  $folder — present, *.local.md NOT ignored"; fi
}

cmd_install() {
	f=${1:?usage: notes.sh install <file>}
	if [ ! -d "$(dirname "$f")" ]; then
		echo "notes.sh: $(dirname "$f") does not exist — that harness is not in use here; not creating it" >&2
		exit 1
	fi
	if has_block "$f"; then
		if [ "$(current_block "$f")" = "$(block)" ]; then echo "already current: $f"; return; fi
		tmp=$(mktemp); strip_block "$f" >"$tmp"; { cat "$tmp"; printf '\n'; block; } >"$f"; rm -f "$tmp"
		echo "updated: $f"
	else
		{ [ -s "$f" ] && printf '\n'; block; } >>"$f"
		echo "added: $f"
	fi
}

cmd_remove() {
	f=${1:?usage: notes.sh remove <file>}
	has_block "$f" || { echo "no contract in $f"; return; }
	tmp=$(mktemp); strip_block "$f" >"$tmp"; cat "$tmp" >"$f"; rm -f "$tmp"
	echo "removed: $f"
}

cmd_init_repo() {
	folder="${1:-.}/.agents/skill-notes"
	mkdir -p "$folder"
	if grep -qxF '*.local.md' "$folder/.gitignore" 2>/dev/null; then echo "already set up: $folder"
	else printf '*.local.md\n' >>"$folder/.gitignore"; echo "set up: $folder (*.local.md ignored)"; fi
}

case "${1:-}" in
	status) shift; cmd_status "$@" ;;
	block) block ;;
	install) shift; cmd_install "$@" ;;
	remove) shift; cmd_remove "$@" ;;
	init-repo) shift; cmd_init_repo "$@" ;;
	*) sed -n '3,10p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
