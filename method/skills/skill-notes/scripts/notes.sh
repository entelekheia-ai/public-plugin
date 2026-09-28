#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# notes.sh — installs, checks and removes the skill-notes contract. Every write is one file per call,
# made only after the person at the keyboard agreed to it; the skill asks, this script writes.
#
#   notes.sh status [repo-dir]     where the contract is installed, and whether the repository has a notes folder
#   notes.sh block                 print the block, for an agent whose user instructions you paste by hand
#   notes.sh install <file>        add the block to <file>, or bring an older copy of it up to date
#   notes.sh remove <file>         take the block out of <file>
#   notes.sh init-repo [repo-dir]  create <repo>/.agents/skill-notes/ with *.local.md kept out of git
#
# The block sits between two marker lines. The script touches a file only when it holds no marker, or
# exactly one begin marker followed by one end marker, both outside any fenced code block; anything else
# is refused, with the line numbers, and the file is left as it was.
set -eu

BEGIN='<!-- skill-notes:begin -->'
END='<!-- skill-notes:end -->'
TMP=
trap 'rm -f "$TMP"' EXIT INT TERM

block() {
	cat <<'EOF'
<!-- skill-notes:begin -->
Before running any skill, read its notes where they exist: `~/.agents/skill-notes/<skill>.md`, then `.agents/skill-notes/<skill>.md`, then `.agents/skill-notes/<skill>.local.md` — `<skill>` is the skill's folder name, without any `<plugin>:` prefix; where two disagree, the more specific file wins.
After a run that taught something, append one dated line to `.agents/skill-notes/<skill>.local.md` (create the folder, keep `*.local.md` out of git), and never edit an installed copy of a skill — a plugin's cache or a skills install folder is overwritten on its next update; a skill whose source the person keeps is theirs to edit.
<!-- skill-notes:end -->
EOF
}

# The user-level instruction file of each agent that has one, one per line: "<agent>\t<path>".
targets() {
	printf 'Claude Code\t%s\n' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/CLAUDE.md"
	printf 'Codex CLI\t%s\n' "${CODEX_HOME:-$HOME/.codex}/AGENTS.md"
	printf 'Gemini CLI\t%s\n' "$HOME/.gemini/GEMINI.md"
	printf 'Copilot CLI\t%s\n' "${COPILOT_HOME:-$HOME/.copilot}/copilot-instructions.md"
}

# scan <file> — prints "none", "one", or "bad: <reason>". Line endings (CRLF) are ignored; a marker inside
# a fenced code block is a person's own example and makes the file "bad" rather than being removed.
scan() {
	[ -f "$1" ] || { echo none; return; }
	awk -v b="$BEGIN" -v e="$END" '
		{ sub(/\r$/, "") }
		/^[ \t]*(```|~~~)/ { fence = !fence; next }
		$0 == b { if (fence) { bad = "marker inside a code block at line " NR; exit } ; nb++; if (open) { bad = "second begin marker at line " NR; exit } ; open = 1; bl = NR; next }
		$0 == e { if (fence) { bad = "marker inside a code block at line " NR; exit } ; if (!open) { bad = "end marker without a begin at line " NR; exit } ; open = 0; ne++; next }
		END {
			if (bad) print "bad: " bad
			else if (open) print "bad: begin marker at line " bl " has no end marker"
			else if (nb > 1) print "bad: " nb " blocks"
			else if (nb == 1) print "one"
			else print "none"
		}' "$1"
}

current_block() { awk -v b="$BEGIN" -v e="$END" '{ sub(/\r$/, "") } $0==b{p=1} p{print} $0==e{p=0}' "$1"; }

# The file without the block, and without the blank lines the block leaves at its end. Called only on "one".
strip_block() {
	awk -v b="$BEGIN" -v e="$END" '{ line = $0; sub(/\r$/, "", line) }
		line==b{skip=1; next} line==e{skip=0; next} skip{next}
		line==""{held=held $0 "\n"; next} {printf "%s%s\n", held, $0; held=""}' "$1"
}

refuse_bad() {
	echo "notes.sh: $1: $2 — left unchanged; fix the markers by hand, then run again" >&2
	exit 1
}

write_from_tmp() {
	cat "$TMP" >"$1" 2>/dev/null || { echo "notes.sh: cannot write $1" >&2; exit 1; }
}

cmd_status() {
	repo=${1:-.}
	echo "== user-level instruction files"
	targets | while IFS="$(printf '\t')" read -r agent path; do
		dir=$(dirname "$path")
		s=$(scan "$path")
		if [ ! -d "$dir" ]; then state="agent folder absent — not in use here"
		elif [ ! -f "$path" ]; then state="no file yet"
		elif [ "$s" = none ]; then state="file present, no contract"
		elif [ "${s#bad}" != "$s" ]; then state="markers damaged ($s) — the script will refuse this file"
		elif [ "$(current_block "$path")" = "$(block)" ]; then state="contract current"
		else state="contract present, older text"; fi
		printf '  %-12s %s\n      %s\n' "$agent" "$path" "$state"
		if [ "$agent" = "Codex CLI" ] && [ -f "$dir/AGENTS.override.md" ]; then
			echo "      $dir/AGENTS.override.md exists — Codex reads it instead of AGENTS.md"
		fi
	done
	echo "  Cursor (Settings → Rules → User Rules) and Copilot in VS Code (a user instructions file VS Code"
	echo "  creates from the Command Palette): paste the text 'notes.sh block' prints"
	echo "== notes folder in $repo"
	folder="$repo/.agents/skill-notes"
	if [ ! -d "$folder" ]; then echo "  $folder — absent"
	elif grep -qxF '*.local.md' "$folder/.gitignore" 2>/dev/null; then echo "  $folder — present, *.local.md ignored"
	else echo "  $folder — present, *.local.md NOT ignored"; fi
}

cmd_install() {
	f=${1:?usage: notes.sh install <file>}
	[ -d "$(dirname "$f")" ] || { echo "notes.sh: $(dirname "$f") does not exist — that agent is not in use here; not creating it" >&2; exit 1; }
	if [ -e "$f" ] && [ ! -w "$f" ]; then echo "notes.sh: cannot write $f" >&2; exit 1; fi
	s=$(scan "$f")
	case $s in
	bad*) refuse_bad "$f" "${s#bad: }" ;;
	one)
		if [ "$(current_block "$f")" = "$(block)" ]; then echo "already current: $f"; return; fi
		TMP=$(mktemp); strip_block "$f" >"$TMP"; { [ -s "$TMP" ] && printf '\n'; block; } >>"$TMP"
		write_from_tmp "$f"; echo "updated: $f" ;;
	none)
		TMP=$(mktemp); [ -f "$f" ] && cat "$f" >"$TMP"; { [ -s "$TMP" ] && printf '\n'; block; } >>"$TMP"
		write_from_tmp "$f"; echo "added: $f" ;;
	esac
}

cmd_remove() {
	f=${1:?usage: notes.sh remove <file>}
	s=$(scan "$f")
	case $s in
	none) echo "no contract in $f" ;;
	bad*) refuse_bad "$f" "${s#bad: }" ;;
	one)
		[ -w "$f" ] || { echo "notes.sh: cannot write $f" >&2; exit 1; }
		TMP=$(mktemp); strip_block "$f" >"$TMP"; write_from_tmp "$f"; echo "removed: $f" ;;
	esac
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
