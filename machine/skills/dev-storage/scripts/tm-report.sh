#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Collect everything needed to decide what Time Machine should stop backing up,
# into one file you can read or share.
#
#   sudo tm-report.sh [output-file]
#
# macOS only — it drives Time Machine (tmutil). Read-only, no state changed
# (see below); sudo is needed only to read the backup-side sections.
#
# Read-only: it inspects and writes a report. It never deletes and never changes
# an exclusion — that is dev-storage.sh's job, after you have read this.
#
# Run it with sudo for the backup-side sections. Be warned that sudo alone may
# not be enough: enumerating a Time Machine destination is gated by Full Disk
# Access, which macOS grants per application (your terminal), not per user. If
# the backup sections come back blocked, grant it under System Settings →
# Privacy & Security → Full Disk Access and run again. Every source-side section
# works either way, and those are the ones that decide what enters the backup
# from here on.
#
# Runs in six phases with progress on screen. Two design rules keep it quick:
#
#   Ask once, not per item. `tmutil isexcluded` answers the exclusion question
#   correctly and took 45 seconds for one path here; the two mechanisms behind it
#   are read once each instead, and joined locally.
#
#   Walk wide, not deep. Everything that must touch the disk happens in one fan-out
#   of one job per top-level directory across all cores — that job both sizes the
#   tree and lists what changed in it, so the second question costs a second pass
#   over trees already warm rather than a separate phase.
#
# It ranks by churn, not by size. What a backup costs is the bytes that moved,
# and those are two different orderings: a static 104 GB directory is copied once
# and then costs nothing, while a 1 GB cache rebuilt nightly costs every night.
#
# Knobs: COMPARE_TIMEOUT=<seconds, default 600> bounds the one step that can
# genuinely take a very long time — `tmutil compare` diffs the whole volume
# against the last backup and blocks on I/O at near-zero CPU, so it looks
# identical to a hang. SKIP_COMPARE=1 drops it entirely. MIN_MB, DAYS and
# DEV-side defaults are at the top.

set -u

if ! command -v tmutil >/dev/null 2>&1; then
	echo "tmutil not found on PATH — this script is macOS-only" >&2
	exit 2
fi

# Under sudo, $HOME is root's. Resolve the human's home before anything reads it.
REAL_USER=${SUDO_USER:-$(id -un)}
H=$(dscl . -read "/Users/$REAL_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
[ -d "$H" ] || H=$HOME

OUT=${1:-$H/tm-report-$(date +%Y%m%d-%H%M).txt}
MIN_MB=${MIN_MB:-300}
DAYS=${DAYS:-7}
NCPU=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
COMPARE_TIMEOUT=${COMPARE_TIMEOUT:-600}
SKIP_COMPARE=${SKIP_COMPARE:-0}
SIZE_TIMEOUT=${SIZE_TIMEOUT:-300}

# Nothing here asks Spotlight any more. Both questions this report used to put to
# the index — what changed, and what is excluded — were answered wrong by it: it
# holds no dotfiles at all, and it is per-user, so under sudo it queries root's
# index. Both failures return an empty result rather than an error, which reads
# exactly like a real "nothing found". The walks below answer both directly.

TMPD=$(mktemp -d) || exit 1
trap 'rm -rf "$TMPD"' EXIT INT TERM

# --- progress, always to stderr so it never lands in the report ----------------
TOTAL_PHASES=6
PHASE=0
[ -t 2 ] && TTY=1 || TTY=0

T0=$(date +%s)
elapsed() { echo $(($(date +%s) - T0)); }

phase() {
	PHASE=$((PHASE + 1))
	printf '\n[%d/%d] %ss  %s\n' "$PHASE" "$TOTAL_PHASES" "$(elapsed)" "$1" >&2
}

# A heartbeat whose text never changes is indistinguishable from a hang — which
# is exactly how this script was first reported as broken while `tmutil compare`
# sat blocked on I/O for eleven minutes. Always show the clock moving.
# Width comes from the terminal, not from a guess. A fixed 46 columns truncated
# the useful half of the message ("...blocked and") on a wide window while wasting
# nothing on a narrow one.
COLS=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
BW=$((COLS - 14))
[ "$BW" -lt 20 ] && BW=20

BEAT_LAST=0
beat() {
	if [ "$TTY" = 1 ]; then
		printf '\r      %ss  %-*.*s' "$(elapsed)" "$BW" "$BW" "$1" >&2
	else
		# Redirected to a file or a pipe: carriage returns just accumulate, so
		# emit a real line and only every 15s.
		now=$(elapsed)
		[ $((now - BEAT_LAST)) -ge 15 ] || return 0
		BEAT_LAST=$now
		printf '      %ss  %s\n' "$now" "$1" >&2
	fi
}
note() { printf '      %s\n' "$1" >&2; }
tick() { # tick <done> <total> <label>
	if [ "$TTY" = 1 ]; then
		w=$((BW - 8))
		[ "$w" -lt 12 ] && w=12
		printf '\r      %s/%s  %-*.*s' "$1" "$2" "$w" "$w" "$3" >&2
	fi
}
tickdone() {
	if [ "$TTY" = 1 ]; then
		printf '\r      %-*.*s\n' "$((COLS - 6))" "$((COLS - 6))" "$1" >&2
	else note "$1"; fi
}

# Build the report in the temp dir and move it into place only at the very end.
# Writing straight to $OUT meant an aborted run left a ~1KB file that looks like a
# report, is named like a report, and is missing every section that matters.
DRAFT="$TMPD/report"
say() { printf '%s\n' "$*" >>"$DRAFT"; }
rule() {
	say ""
	say "=== $* ==="
}
blocked() { grep -qi 'full disk access\|operation not permitted' "$1" 2>/dev/null; }

: >"$DRAFT"
say "Time Machine / storage report"
say "host $(hostname -s)   user $REAL_USER   $(date)"
say "running as $(id -un)$([ -n "${SUDO_USER:-}" ] && echo ' (via sudo)')"
say "cores $NCPU   threshold ${MIN_MB}MB   window ${DAYS}d"

# --- 1. context ----------------------------------------------------------------
phase "Disk and Time Machine context"
rule "Disk"
df -h / /System/Volumes/Data 2>/dev/null >>"$DRAFT"
rule "Backup destination"
tmutil destinationinfo >>"$DRAFT" 2>&1
say ""
tmutil status 2>/dev/null | sed -n '1,8p' >>"$DRAFT"
say "AutoBackup: $(defaults read /Library/Preferences/com.apple.TimeMachine.plist AutoBackup 2>/dev/null || echo '?')"
SNAPS=$(tmutil listlocalsnapshots / 2>/dev/null | grep -c local)
rule "Local snapshots"
say "count: $SNAPS"
say "(each one holds the blocks of everything deleted after it;"
say " 'dev-storage.sh reclaim' ends by thinning them)"
note "destination: $(tmutil destinationinfo 2>/dev/null | awk -F': ' '/Mount Point/{print $2; exit}')"
note "local snapshots: $SNAPS"

# --- 2. backup side, launched in the background --------------------------------
# The slowest step and independent of everything else, so it runs while phases
# 3-5 do their work. Collected in phase 6.
phase "Backup side (in the background)"
(
	tmutil listbackups >"$TMPD/backups" 2>&1
	if ! blocked "$TMPD/backups" && [ "$SKIP_COMPARE" != 1 ]; then
		tmutil compare -s >"$TMPD/compare" 2>&1 &
		echo $! >"$TMPD/compare.pid"
		wait $!
	fi
	: >"$TMPD/backup.done"
) &
BG=$!
note "listbackups + compare launched (pid $BG)"
if [ "$SKIP_COMPARE" = 1 ]; then
	note "compare disabled (SKIP_COMPARE=1)"
else
	note "'tmutil compare' scans the whole volume against the last backup:"
	note "takes minutes and blocks on I/O, with near-zero CPU."
	note "limit ${COMPARE_TIMEOUT}s (COMPARE_TIMEOUT=), or SKIP_COMPARE=1 to skip."
fi

# --- 3. exclusions, from both mechanisms ----------------------------------------
# macOS excludes from Time Machine two different ways, and reading only one gives
# a confidently wrong answer:
#
#   xattr  com.apple.metadata:com_apple_backup_excludeItem, set by plain
#          `addexclusion`. Apple calls this the sticky, location-independent
#          kind: it rides along when the item is moved, and a copy inherits it.
#   plist  SkipPaths in com.apple.TimeMachine.plist, set by `addexclusion -p`.
#          Fixed-path: it excludes whatever sits at that path, so it survives the
#          directory being deleted and recreated but does not follow a rename.
#
# `tmutil isexcluded` knows both and inherits to children, so it looks like the
# right tool — but it took 45 seconds for a single path on this machine, which is
# what made the first version of this script appear to hang. Reading the xattr
# directly costs ~1.4ms, so the two sources are read here and joined below.
phase "Active exclusions (xattr + SkipPaths)"
defaults read /Library/Preferences/com.apple.TimeMachine.plist SkipPaths 2>/dev/null |
	sed -n 's/^ *"\{0,1\}\(\/[^",]*\)"\{0,1\},\{0,1\} *$/\1/p' | sort >"$TMPD/skip"
NSKIP=$(grep -c . "$TMPD/skip" 2>/dev/null || echo 0)

# Read the xattr off the disk instead of asking Spotlight for it. The index is
# the wrong instrument twice over: it holds no dotfiles at all, and on this
# machine it reports nothing under ~/Library either — which is precisely where
# the exclusions live. Batched with `-exec … {} +`, testing every directory costs
# seconds and finds hundreds of exclusions where `mdfind` finds none.
#
# Five levels, not three. The exclusions this policy sets are that deep —
# `Library/Application Support/Claude/vm_bundles` is four — and a depth-3 scan
# missed it, so several GB of excluded VM image was charged to its parents' churn.
# Depth 3 costs 2s and depth 5 costs 7s against a run measured in minutes; the
# shallow version was a false economy. Anything deeper than this is still missed,
# which affects only how churn is attributed: the candidate list itself is
# filtered by `excluded()` below, which walks every ancestor for real.
#
# The `/` before `{}` is load-bearing. Given a single path, `xattr -p` prints the
# bare value with no path prefix, so a batch that happens to end with one
# directory would parse as garbage and that directory would silently drop out of
# the list. A sentinel first argument guarantees every batch has two or more, and
# `/` never carries the attribute.
find "$H" -maxdepth 5 -type d \
	-exec xattr -p com.apple.metadata:com_apple_backup_excludeItem / {} + 2>/dev/null |
	sed -n 's/^\(\/.*\): .*/\1/p' | sort -u >"$TMPD/excl"
NEXCL=$(grep -c . "$TMPD/excl" 2>/dev/null || echo 0)

# The union is what a walk must avoid entering, whichever mechanism excluded it.
sort -u "$TMPD/skip" "$TMPD/excl" >"$TMPD/prune"
note "SkipPaths: $NSKIP   xattr: $NEXCL"

# excluded <path> — true when the path or any ancestor carries the exclude xattr,
# OR sits at/under a SkipPaths entry. Both mechanisms, or the answer is wrong for
# whichever one it omits: a path excluded solely via SkipPaths would otherwise
# read as unprotected.
# Authoritative and local — no daemon, ~1.4ms, against 45s for tmutil isexcluded.
excluded() {
	p=$1
	while [ "$p" != "/" ] && [ -n "$p" ]; do
		xattr -p com.apple.metadata:com_apple_backup_excludeItem "$p" >/dev/null 2>&1 && return 0
		grep -qxF "$p" "$TMPD/skip" 2>/dev/null && return 0
		p=$(dirname "$p")
	done
	return 1
}

# --- 4. sizes, fanned out across cores ------------------------------------------
phase "Sizes by folder ($NCPU cores in parallel)"

# Skip what is already excluded before walking it. These can never reach the
# candidate list, and one of them here has been a very large directory — the
# walk was pure cost.
SKIPPED=0
: >"$TMPD/tops"
find "$H" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | while IFS= read -r d; do
	if excluded "$d"; then
		printf '%s\n' "$d" >>"$TMPD/tops.skipped"
	else
		printf '%s\n' "$d" >>"$TMPD/tops"
	fi
done
SKIPPED=$(grep -c . "$TMPD/tops.skipped" 2>/dev/null || echo 0)
NTOP=$(grep -c . "$TMPD/tops" 2>/dev/null || echo 0)
note "$NTOP to measure, $SKIPPED already excluded (will not be walked)"

# Track our own PIDs. A bare `wait` waits for EVERY background child, and this
# script has one that outlives the phase: the tmutil compare from phase 2. That
# is what made the run stop dead at "56/56" with no du left running — the sizing
# was finished and the phase was blocked on the backup job. Same reason the
# throttle counts these PIDs rather than `jobs -p`, which sees compare too and so
# permanently loses a slot.
PIDS=""
: >"$TMPD/abandoned"
alive() {
	n=0
	for p in $PIDS; do kill -0 "$p" 2>/dev/null && n=$((n + 1)); done
	echo "$n"
}
# Which directories are still being walked, so a slow one is named on screen
# instead of appearing as a stalled counter.
lagging() {
	out=""
	c=0
	for p in $PIDS; do
		kill -0 "$p" 2>/dev/null || continue
		c=$((c + 1))
		[ "$c" -gt 3 ] && {
			out="$out, ..."
			break
		}
		nm=$(awk -F'\t' -v pid="$p" '$1 == pid {print $2; exit}' "$TMPD/pidmap" 2>/dev/null)
		out="$out${out:+, }$nm"
	done
	printf '%s' "$out"
}

i=0
while IFS= read -r d; do
	i=$((i + 1))
	# macOS du reports 512-byte blocks unless given -k. Forgetting it doubles
	# every figure in the report, which reads as entirely plausible.
	# .part → rename so a finished file is distinguishable from a started one.
	#
	# Both walks happen in the same job: totals from du, and the recently-changed
	# files with their sizes. `-mtime -N` rather than `-newermt '<N> days ago'` —
	# the relative form is a GNU extension and this machine's find rejects it as an
	# invalid timestamp, which every caller was hiding behind 2>/dev/null.
	#
	# Excluded subtrees are pruned out of the churn walk. Top-level directories
	# already excluded never get here at all, but their *children* do, and those
	# dominate: ~/Library is not excluded while ~/Library/Caches is, and that one
	# child alone held thousands of the changed files in a seven-day window. Counting
	# them would rank a directory by bytes the backup is not paying for. It was
	# also most of the walk — unpruned, ~/Library ran past a 900s ceiling and was
	# killed. du keeps the whole subtree (it has no prune, and the size column is
	# documented as gross), which is why only the ranking key is corrected here.
	set --
	while IFS= read -r x; do
		case $x in "$d"/*) set -- "$@" -path "$x" -o ;; esac
	done <"$TMPD/prune"
	# A final term that cannot match, so the alternation never ends on a
	# dangling -o and the empty case stays a valid expression.
	set -- "$@" -path /dev/null/never
	(
		du -kx -d 2 "$d" 2>/dev/null >"$TMPD/sz.$i.part" && mv "$TMPD/sz.$i.part" "$TMPD/sz.$i"
		find "$d" \( "$@" \) -prune -o -type f -mtime -"$DAYS" \
			-exec stat -f '%z %N' {} + >"$TMPD/ch.$i.part" 2>/dev/null &&
			mv "$TMPD/ch.$i.part" "$TMPD/ch.$i"
	) &
	PIDS="$PIDS $!"
	printf '%s\t%s\t%s\n' "$!" "$(basename "$d")" "$d" >>"$TMPD/pidmap"
	beat "dispatching $i/$NTOP  $(basename "$d")"
	while [ "$(alive)" -ge "$NCPU" ]; do sleep 0.2; done
done <"$TMPD/tops"

# Poll rather than wait, so a slow directory is named instead of being silence.
SZ0=$(date +%s)
while [ "$(alive)" -gt 0 ]; do
	w=$(($(date +%s) - SZ0))
	if [ "$w" -ge "$SIZE_TIMEOUT" ]; then
		# Record which walks are being abandoned BEFORE killing them. Reading
		# `lagging` afterwards names nothing, because nothing is alive to name —
		# the first version of this printed an empty list.
		for p in $PIDS; do
			kill -0 "$p" 2>/dev/null || continue
			awk -F'\t' -v pid="$p" '$1 == pid {print $3; exit}' "$TMPD/pidmap"
		done >>"$TMPD/abandoned"
		for p in $PIDS; do kill "$p" 2>/dev/null; done
		note "abandoned after ${SIZE_TIMEOUT}s: $(tr '\n' ' ' <"$TMPD/abandoned")"
		break
	fi
	beat "measuring — $(alive) of $NTOP left: $(lagging) (${w}s)"
	sleep 1
done
cat "$TMPD"/sz.* 2>/dev/null | awk -v m="$MIN_MB" '$1/1024 >= m' | sort -rn >"$TMPD/sizes"
NCAND=$(grep -c . "$TMPD/sizes" 2>/dev/null || echo 0)
tickdone "$NTOP folders measured ($SKIPPED skipped), $NCAND above ${MIN_MB}MB"

# --- 5. churn -------------------------------------------------------------------
# What a backup costs is not the bytes a directory holds, it is the bytes that
# moved: a static 104 GB directory is copied once and then costs nothing, while a
# small directory rebuilt daily costs every night. So rank by churn and keep size
# as context, rather than the other way round.
#
# This used to ask Spotlight, which cannot answer it: the index contains no
# dotfiles at all. A large agent-tooling directory had thousands of files changed
# in a week and was reported static — one of the noisiest directories on the
# machine, silently inverted. The walk above costs a second pass over the same
# trees and is complete.
phase "Bytes changed by folder (${DAYS}d)"
cat "$TMPD"/ch.* 2>/dev/null >"$TMPD/changed"
NREC=$(grep -c . "$TMPD/changed" 2>/dev/null || echo 0)
note "$NREC files changed in ${DAYS}d"

# Roll each changed file's bytes into every ancestor, so a directory's churn
# covers its whole subtree — the same semantics du gives for size.
awk '{
	sz = $1
	p = substr($0, index($0, " ") + 1)
	while ((k = match(p, /\/[^\/]*$/)) > 0) {
		p = substr(p, 1, k - 1)
		if (p == "") break
		ch[p] += sz
		nf[p] += 1
	}
} END { for (d in ch) printf "%s\t%d\t%d\n", d, ch[d], nf[d] }' \
	"$TMPD/changed" >"$TMPD/churn"
CHTOT=$(awk '{s += $1} END {printf "%d", s / 1048576}' "$TMPD/changed" 2>/dev/null || echo 0)
tickdone "$NREC files, ${CHTOT}MB changed in ${DAYS}d"

# --- 6. join and write ----------------------------------------------------------
phase "Assembling the report"

rule "Backups at the destination (needs Full Disk Access)"
WAIT0=$(date +%s)
TIMED_OUT=0
while [ ! -f "$TMPD/backup.done" ]; do
	w=$(($(date +%s) - WAIT0))
	if [ "$w" -ge "$COMPARE_TIMEOUT" ]; then
		# Bound it rather than wait forever: a full-volume compare can outlast
		# any reasonable session, and the rest of the report is already complete.
		[ -f "$TMPD/compare.pid" ] && kill "$(cat "$TMPD/compare.pid")" 2>/dev/null
		kill "$BG" 2>/dev/null
		TIMED_OUT=1
		break
	fi
	beat "waiting for compare (${w}s of ${COMPARE_TIMEOUT}s, blocked on I/O)"
	sleep 1
done
if [ "$TIMED_OUT" = 1 ]; then
	tickdone "compare aborted after ${COMPARE_TIMEOUT}s — rest of the report intact"
else
	tickdone "backup side finished in $(($(date +%s) - WAIT0))s"
fi

if blocked "$TMPD/backups"; then
	say "BLOCKED — grant Full Disk Access to the terminal and run again."
	say "System Settings -> Privacy & Security -> Full Disk Access"
	say "(sudo alone does not lift it: the permission is per application, not per user)"
	FDA=0
else
	say "count: $(grep -c . "$TMPD/backups")"
	say "oldest: $(head -1 "$TMPD/backups")"
	say "newest: $(tail -1 "$TMPD/backups")"
	FDA=1
fi

rule "What changes between the latest backup and today's disk"
if [ "$TIMED_OUT" = 1 ]; then
	say "ABORTED after ${COMPARE_TIMEOUT}s."
	say "'tmutil compare' scans the whole volume against the last backup and"
	say "blocks on I/O (CPU near zero), so there is no way to know how much is"
	say "left. Run with COMPARE_TIMEOUT=3600 to actually wait it out."
elif [ "$SKIP_COMPARE" = 1 ]; then
	say "skipped on request (SKIP_COMPARE=1)."
elif [ "$FDA" = 1 ] && [ -s "$TMPD/compare" ] && ! blocked "$TMPD/compare"; then
	say "--- summary ---"
	tail -12 "$TMPD/compare" >>"$DRAFT"
	say ""
	say "--- 40 largest changed items ---"
	awk '$2 ~ /^[0-9]+$/ {printf "%s\t%s\n", $2, substr($0, index($0,$3))}' "$TMPD/compare" |
		sort -rn | head -40 |
		awk -F'\t' '{printf "%8.1f MB  %s\n", $1/1048576, $2}' >>"$DRAFT"
else
	say "skipped: depends on Full Disk Access."
fi

rule "Active exclusions today"
say "Two independent mechanisms; reading only one gives a confidently wrong answer."
say ""
say "--- SkipPaths (Time Machine plist): $NSKIP ---"
cat "$TMPD/skip" >>"$DRAFT"
say ""
say "--- xattr, read directly off disk up to 5 levels: $NEXCL ---"
say "(not from Spotlight: the index has no dotfiles at all and here it"
say " reported nothing under ~/Library, which is exactly where they are.)"
cat "$TMPD/excl" >>"$DRAFT"

rule "What goes back into the backup (source side), by bytes changed"
say "Ordered by CHANGED/${DAYS}d, not by size: what a backup costs is what"
say "changes, not what exists. A static 100GB folder is copied once and then"
say "costs nothing; a 1GB folder rebuilt every day costs every night."
say "Nothing on this list is excluded. Minimum size ${MIN_MB}MB."
say ""
say "FILES = how many files changed. Many files with few bytes each is the"
say "profile of a rebuilt cache (exclude the folder). Few files with many"
say "bytes is one large file being rewritten — and in that case remember TM"
say "copies only the changed blocks, so the real cost is lower than the number."
say ""
say "CAUTION: SIZE is the whole subtree, including children that are ALREADY"
say "excluded — CHANGED is not, it already discounts excluded children. So a"
say "folder can look enormous and change little because the expensive part"
say "of it already left."
say ""
say "CHANGED = ? means that folder's walk was abandoned at the time limit."
say "It is unknown, not zero, which is why it sorts to the top. Run again with"
say "a larger SIZE_TIMEOUT to resolve it."
say ""
say "    SIZE  CHANGED/${DAYS}d  FILES  PATH"

# One awk pass over four inputs: SkipPaths to filter, churn to rank, the
# abandoned roots to mark as unknown, sizes as the candidate set.
#
# A walk that was killed leaves no churn file, and without the abandoned list its
# whole subtree would read as "0 bytes changed" — a large directory reported as
# perfectly quiet, sorted to the bottom where nobody looks. Missing data is
# printed as `?` and sorted to the TOP instead: not knowing is worth more
# attention than knowing it is zero, not less.
#
# -F'\t' is not cosmetic. Every one of these files is tab-separated and holds
# paths, and awk's default splitting breaks on any whitespace: with it,
# `~/Library/Application Support` keys as `/Users/alice/Library/Application`,
# its churn lookup misses, and a large directory reports 0 bytes changed across
# 0 files — while the files that did change still show up in the parent's
# total. Silently, and only for paths with a space in them.
awk -F'\t' '
	FILENAME == abnd_f { ab[++na] = $0; next }
	FILENAME == excl_f { excl[++ne] = $0; next }
	FILENAME == churn_f { ch[$1] = $2; nf[$1] = $3; next }
	{
		kb = $1
		p = substr($0, index($0, "\t") + 1)
		if (p == "") next
		for (i = 1; i <= ne; i++)
			if (p == excl[i] || index(p "/", excl[i] "/") == 1) next
		if (!(p in ch))
			for (i = 1; i <= na; i++)
				if (p == ab[i] || index(p "/", ab[i] "/") == 1) {
					printf "%d\t%7dM %9s %6s  %s\n", 1000000000000000, kb / 1024, "?", "?", p
					next
				}
		c = (p in ch) ? ch[p] : 0
		printf "%d\t%7dM %9dM %6d  %s\n", c, kb / 1024, c / 1048576, nf[p] + 0, p
	}
' abnd_f="$TMPD/abandoned" excl_f="$TMPD/skip" churn_f="$TMPD/churn" \
	"$TMPD/abandoned" "$TMPD/skip" "$TMPD/churn" "$TMPD/sizes" |
	sort -rn | cut -f2- >"$TMPD/ranked"

# Second pass for the xattr mechanism: one walk per candidate, stopping as soon
# as 40 rows survive. Costs ~1.4ms a call, against 45s for `tmutil isexcluded`.
kept=0
: >"$TMPD/final"
while IFS= read -r line; do
	[ "$kept" -ge 40 ] && break
	p=$(printf '%s' "$line" | sed 's/^[^/]*//')
	excluded "$p" && continue
	printf '%s\n' "$line" >>"$TMPD/final"
	kept=$((kept + 1))
	tick "$kept" "40" "$(basename "$p")"
done <"$TMPD/ranked"
tickdone "$kept candidates after filtering both exclusion mechanisms"

cat "$TMPD/final" >>"$DRAFT"

# Only now does the file appear at $OUT. Interrupt the run at any point before
# this and there is no report rather than a convincing fragment of one.
mv "$DRAFT" "$OUT" || {
	printf 'could not write to %s\n' "$OUT" >&2
	exit 1
}
chown "$REAL_USER" "$OUT" 2>/dev/null || true

printf '\nreport saved to: %s\n' "$OUT" >&2
printf 'lines: %s\n' "$(grep -c . "$OUT")" >&2
