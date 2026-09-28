#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# What is inside the Time Machine destination that should never have gone there,
# and what would actually be freed by removing it.
#
#   sudo tm-inventory.sh [output-file]
#   sudo DEEP=1 tm-inventory.sh      # also walk the backup tree
#
# macOS only — it drives Time Machine (tmutil). Needs sudo for the backup-side
# walk; changes no state either way (see READ-ONLY below).
#
# DEEP must come AFTER sudo, not before: macOS's default sudoers has env_reset,
# which strips `DEEP=1 sudo ...` before the script ever sees it. `sudo DEEP=1 ...`
# passes it as part of the command sudo runs, which survives the reset.
#
# READ-ONLY. It never deletes and never runs `tmutil delete`. It prints the exact
# commands for you to review and run yourself, because deleting from a backup is
# irreversible and this script has no business deciding that.
#
# Why this exists as a separate tool from tm-report.sh: an exclusion only applies
# to future backups. Everything excluded yesterday is still sitting in every
# backup taken before then, and no amount of excluding will remove it. This is
# the only tool here that looks at what was already spent.
#
# Two tmutil subcommands carry the whole design:
#
#   uniquesize  the space a path occupies that is NOT shared with other backups —
#               i.e. what deleting it would really free. Backups on an APFS
#               destination are snapshots sharing blocks, so `du` over them
#               counts the same block once per backup and wildly overstates.
#   delete -p   removes one path from the backups, rather than a whole backup.
#               That is what makes "drop the browser cache out of my history"
#               possible without losing the history itself.
#
# Both need Full Disk Access (granted per application, to your terminal — sudo
# does not substitute) and `delete` additionally needs root.

set -u

if ! command -v tmutil >/dev/null 2>&1; then
	echo "tmutil not found on PATH — this script is macOS-only" >&2
	exit 2
fi

REAL_USER=${SUDO_USER:-$(id -un)}
H=$(dscl . -read "/Users/$REAL_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
[ -d "$H" ] || H=$HOME

OUT=${1:-$H/tm-inventory-$(date +%Y%m%d-%H%M).txt}
DEEP=${DEEP:-0}
WALK_TIMEOUT=${WALK_TIMEOUT:-900}
MIN_MB=${MIN_MB:-200}
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

TMPD=$(mktemp -d) || exit 1
trap 'rm -rf "$TMPD"' EXIT INT TERM
DRAFT="$TMPD/report"
: >"$DRAFT"

TOTAL_PHASES=5
PHASE=0
[ -t 2 ] && TTY=1 || TTY=0
T0=$(date +%s)
COLS=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
BW=$((COLS - 14))
[ "$BW" -lt 20 ] && BW=20

elapsed() { echo $(($(date +%s) - T0)); }
phase() {
	PHASE=$((PHASE + 1))
	printf '\n[%d/%d] %ss  %s\n' "$PHASE" "$TOTAL_PHASES" "$(elapsed)" "$1" >&2
}
note() { printf '      %s\n' "$1" >&2; }
beat() { [ "$TTY" = 1 ] && printf '\r      %ss  %-*.*s' "$(elapsed)" "$BW" "$BW" "$1" >&2; }
beatdone() {
	if [ "$TTY" = 1 ]; then
		printf '\r      %-*.*s\n' "$((COLS - 6))" "$((COLS - 6))" "$1" >&2
	else note "$1"; fi
}
say() { printf '%s\n' "$*" >>"$DRAFT"; }
rule() {
	say ""
	say "=== $* ==="
}

say "Time Machine — destination inventory"
say "host $(hostname -s)   user $REAL_USER   $(date)"
say "READ-ONLY: nothing is deleted by this script."

# --- 1. locate ------------------------------------------------------------------
phase "Locating the destination and the backups"
DEST=$(tmutil destinationinfo 2>/dev/null | awk -F': +' '/Mount Point/{print $2; exit}')
say ""
say "destination: ${DEST:-unknown}"

tmutil listbackups >"$TMPD/backups" 2>&1
if grep -qi 'full disk access\|operation not permitted' "$TMPD/backups"; then
	note "BLOCKED: no Full Disk Access."
	rule "Blocked"
	say "This report needs Full Disk Access for the terminal."
	say "System Settings -> Privacy & Security -> Full Disk Access."
	say "sudo does NOT substitute: the permission is per application, not per user."
	mv "$DRAFT" "$OUT" && chown "$REAL_USER" "$OUT" 2>/dev/null
	printf '\nreport (blocked) at: %s\n' "$OUT" >&2
	exit 1
fi

NBK=$(grep -c . "$TMPD/backups" 2>/dev/null || echo 0)

# `listbackups` enumerates every backup the destination knows about, but only the
# mounted ones exist as paths — /Volumes/.timemachine mounts them on demand and
# the newest is routinely absent. Taking `tail -1` therefore hands you a path that
# is not there, which reads as "unexpected structure" rather than "not mounted".
# So walk newest-first and take the first one that is actually reachable, after
# giving the automounter a chance by stat'ing its mount point.
LATEST=""
SKIPPED_UNMOUNTED=0
while IFS= read -r b; do
	[ -n "$b" ] || continue
	if [ ! -d "$b" ]; then
		ls "$(dirname "$b")" >/dev/null 2>&1 # nudge the automounter
	fi
	if [ -d "$b" ]; then
		LATEST=$b
		break
	fi
	SKIPPED_UNMOUNTED=$((SKIPPED_UNMOUNTED + 1))
	beat "not mounted, trying the previous one: $(basename "$(dirname "$b")")"
done <<EOF
$(sort -r "$TMPD/backups")
EOF

if [ -z "$LATEST" ]; then
	note "none of the $NBK backups is mounted and reachable"
	rule "No backup reachable"
	say "listbackups knows $NBK backups, but none is mounted right now."
	say "Snapshots appear under /Volumes/.timemachine on demand; opening the"
	say "backup in the Time Machine app usually mounts them."
	mv "$DRAFT" "$OUT" && chown "$REAL_USER" "$OUT" 2>/dev/null
	exit 1
fi
[ "$SKIPPED_UNMOUNTED" -gt 0 ] &&
	note "$SKIPPED_UNMOUNTED more recent backup(s) not mounted — using the newest reachable one"
note "$NBK backups; using: $(basename "$(dirname "$LATEST")")"

# The mounted snapshots are visible in `mount` even without Full Disk Access,
# which is the cheapest way to confirm the layout rather than assume it.
say "backups: $NBK"
say "oldest: $(head -1 "$TMPD/backups")"
say "newest: $(tail -1 "$TMPD/backups")"
say "analyzed:   $LATEST"
[ "$SKIPPED_UNMOUNTED" -gt 0 ] &&
	say "($SKIPPED_UNMOUNTED more recent backup(s) were not mounted)"
say ""
say "--- dates ---"
sed -n 's|.*/\([0-9-]*\)\.backup/.*|\1|p' "$TMPD/backups" >>"$DRAFT"
say ""
say "If every date is from the same day, the destination carries no old"
say "history: the junk this report looks for would be small, and excluding"
say "at the source already fixes the future."
say ""
say "--- snapshots mounted right now ---"
mount | grep -i timemachine >>"$DRAFT" 2>/dev/null || say "(none mounted)"

# --- 2. find the user's home inside the latest backup ---------------------------
phase "Locating the home directory inside the backup"
# Discover rather than assume: the volume directory inside a backup is named after
# the source volume ("Macintosh HD - Data" and friends), which is not ours to guess.
BHOME=$(find "$LATEST" -maxdepth 4 -type d -path "*/Users/$REAL_USER" 2>/dev/null | head -1)
if [ -z "$BHOME" ]; then
	note "did not find Users/$REAL_USER inside $LATEST"
	rule "Unexpected structure"
	say "Did not locate the user's home inside the latest backup."
	say "Top-level contents:"
	find "$LATEST" -maxdepth 1 -mindepth 1 2>&1 | head -20 >>"$DRAFT"
	mv "$DRAFT" "$OUT" && chown "$REAL_USER" "$OUT" 2>/dev/null
	exit 1
fi
note "home in the backup: $BHOME"
say ""
say "home inside the backup: $BHOME"

# --- 3. targeted probe of the categories we already know are regenerable --------
# Cheap and precise: ask about the paths whose answer we can act on, instead of
# walking the whole tree to rediscover them.
#
# Only regenerable subfolders are named here, never an application root that also
# holds non-regenerable state (a browser profile, editor settings, an Xcode
# Archive) — see dev-storage.sh's GLOBAL_CACHES comment for why.
phase "Regenerable categories present in the backup"
CANDIDATES="
Library/Developer/Xcode/DerivedData
Library/Developer/Xcode/iOS DeviceSupport
Library/Caches
Library/Application Support/Claude/vm_bundles
Library/Application Support/com.apple.wallpaper
Library/Application Support/Code/Cache
Library/Application Support/Code/CachedData
Library/Application Support/Code/CachedExtensionVSIXs
Library/Application Support/Code/WebStorage
Library/Application Support/Code/DawnWebGPUCache
Library/Application Support/Code/GPUCache
Library/Application Support/Code/logs
Library/Application Support/Figma/DesktopProfile
.npm
.bun
.cache
.rustup
.cargo/registry
.vscode/extensions
go/pkg
.local/pipx
.local/share/claude
"
: >"$TMPD/found"
n=0
while IFS= read -r rel; do
	[ -n "$rel" ] || continue
	n=$((n + 1))
	beat "checking $rel"
	p="$BHOME/$rel"
	[ -e "$p" ] || continue
	# uniquesize is the honest number: space not shared with other backups.
	# Its exact output format could not be verified while writing this (the call
	# only works on a path inside a backup, which needs Full Disk Access), so
	# take the first integer anywhere in the output and keep the raw line when
	# there is none — a silent 0 would read as "nothing to gain here".
	raw=$(tmutil uniquesize "$p" 2>&1 | head -1)
	us=$(printf '%s' "$raw" | grep -oE '[0-9]{4,}' | head -1)
	if [ -z "$us" ]; then
		printf '%s\t%s\n' "$rel" "$raw" >>"$TMPD/unparsed"
		continue
	fi
	printf '%s\t%s\n' "$us" "$rel" >>"$TMPD/found"
done <<EOF
$CANDIDATES
EOF
beatdone "$(grep -c . "$TMPD/found" 2>/dev/null || echo 0) of $n categories present in the backup"

rule "Regenerable data sitting inside the backup"
say "'unique' = space NOT shared with other backups, i.e. what deleting it"
say "would really free. du over snapshots counts the same block once per"
say "backup and grossly overstates; that is why uniquesize is used instead."
say ""
say "HOW TO READ A LOW VALUE: it means this path is identical across the"
say "other backups, so deleting it from ONE backup frees nothing. It does NOT"
say "mean it is cheap: it keeps entering every future backup until excluded"
say "at the source. A low number here argues for excluding, not for ignoring."
say ""
say "A category ABSENT from this list is good news: it means it is already"
say "excluded and never reached the backup."
say ""
if [ -s "$TMPD/found" ]; then
	# Print the raw byte count beside the MB. Rounding alone turns "a few KB",
	# "exactly zero" and "parsed the wrong field" into the same 0.0, which is
	# three very different conclusions wearing one number.
	sort -rn "$TMPD/found" |
		awk -F'\t' '{printf "%9.1f MB  (%s bytes)  %s\n", $1/1048576, $1, $2}' >>"$DRAFT"
else
	say "(none of the known categories was found)"
fi

if [ -s "$TMPD/unparsed" ]; then
	say ""
	say "--- uniquesize returned a format this script did not recognize ---"
	say "Report these lines to fix the parsing; do not treat them as zero."
	cat "$TMPD/unparsed" >>"$DRAFT"
fi

# --- 4. optional deep walk ------------------------------------------------------
phase "Backup tree walk${DEEP:+ (DEEP=$DEEP)}"
if [ "$DEEP" != 1 ]; then
	note "skipped — use DEEP=1 to find categories the list did not predict"
	rule "Deep walk"
	say "Not run. DEEP=1 walks the backup tree to find what the category list"
	say "did not predict. Costs I/O on the backup volume."
else
	du -kx -d 3 "$BHOME" 2>/dev/null >"$TMPD/tree.part" &
	WP=$!
	W0=$(date +%s)
	while kill -0 "$WP" 2>/dev/null; do
		w=$(($(date +%s) - W0))
		[ "$w" -ge "$WALK_TIMEOUT" ] && {
			kill "$WP" 2>/dev/null
			note "abandoned after ${WALK_TIMEOUT}s"
			break
		}
		beat "walking the backup tree (${w}s of ${WALK_TIMEOUT}s)"
		sleep 2
	done
	beatdone "walk finished"
	rule "Largest items inside the backup (logical size)"
	say "WARNING: this is the LOGICAL size, not the space occupied. Blocks"
	say "shared between backups appear here in full. Use the section above"
	say "(uniquesize) to know what would actually be freed."
	say ""
	awk -v m="$MIN_MB" '$1/1024 >= m' "$TMPD/tree.part" 2>/dev/null | sort -rn | head -40 |
		awk '{printf "%8dM  %s\n", $1/1024, substr($0, index($0, "\t") + 1)}' >>"$DRAFT"
fi

# --- 5. the commands, for a human to read and run -------------------------------
phase "Assembling the commands for review"
rule "Suggested commands — NOT run by this script"
say "Deleting from a backup cannot be undone. Read every line before running it."
say "'delete -p' removes one path from the history without deleting whole backups."
say ""
if [ -s "$TMPD/found" ]; then
	sort -rn "$TMPD/found" | while IFS="$(printf '\t')" read -r us rel; do
		[ "${us:-0}" -gt 104857600 ] || continue # only above 100MB unique
		say "# frees ~$((us / 1048576)) MB"
		say "sudo tmutil delete -p \"$BHOME/$rel\""
		say ""
	done
else
	say "(nothing above the threshold)"
fi
say "After deleting, confirm the source is excluded so it does not come back:"
say "  $SCRIPT_DIR/dev-storage.sh exclude"

mv "$DRAFT" "$OUT" || {
	printf 'could not write to %s\n' "$OUT" >&2
	exit 1
}
chown "$REAL_USER" "$OUT" 2>/dev/null || true
printf '\nreport saved to: %s\n' "$OUT" >&2
printf 'lines: %s\n' "$(grep -c . "$OUT")" >&2
