#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Keep a development machine's disk from filling with regenerable bytes.
# macOS only — it drives Time Machine (tmutil) directly. On Linux there is
# nothing to exclude here; use the platform's own backup-exclusion mechanism.
#
#   dev-storage.sh report    where the disk went; the preview for exclude/reclaim (default)
#   dev-storage.sh exclude   keep caches/builds out of Time Machine — changes system state, no sudo needed
#   dev-storage.sh reclaim   delete regenerable caches, then thin snapshots — changes system state, no sudo needed
#   dev-storage.sh reclaim --deep   also drop builds untouched for 60 days
#   dev-storage.sh all       exclude + reclaim + report
#
# The one thing this script exists to encode: on APFS, deleting a cache frees
# nothing while a Time Machine local snapshot still references its blocks. macOS
# takes one hourly and keeps ~24, so a morning's cleanup is invisible until the
# evening. `reclaim` therefore always ends by thinning snapshots, and `exclude`
# stops the blocks being captured in the first place. Running the deletions
# without either step is the failure mode this replaces — it looks like it worked.

set -eu

if ! command -v tmutil >/dev/null 2>&1; then
	echo "tmutil not found on PATH — this script is macOS-only" >&2
	exit 2
fi

DEV=${DEV_ROOT:-$HOME/Development}
STALE_DAYS=60

# Regenerable by definition: a package cache, a compiler's output directory, a
# downloaded SDK. Everything here is rebuilt on demand by the tool that owns it.
#
# The VM bundle is the odd one out and belongs here anyway: it is a multi-gigabyte
# sparse disk image that mutates on every agent run, so backing it up copies the
# whole thing again and again, and what it holds is a disposable sandbox rather
# than anyone's source. Its app recreates it.
# Note what is NOT here: `Application Support/Code/User` holds settings,
# keybindings and snippets and is not regenerable by anything, so the VS Code
# entries below name cache directories one by one rather than the app's folder.
# The same care applies to any app root — check what sits beside the cache before
# adding the parent. That is why Xcode is named down to `Xcode/DerivedData` and
# `Xcode/iOS DeviceSupport` rather than all of `~/Library/Developer` (which also
# holds `Xcode/Archives`, never regenerable), and why a browser's whole
# `Application Support/<vendor>` folder is never named here — its profile, history
# and passwords live there beside its cache, and `~/Library/Caches` already
# covers the regenerable half.
GLOBAL_CACHES="
$HOME/Library/Developer/Xcode/DerivedData
$HOME/Library/Developer/Xcode/iOS DeviceSupport
$HOME/Library/Caches
$HOME/Library/pnpm/store
$HOME/Library/Application Support/Claude/vm_bundles
$HOME/Library/Application Support/com.apple.wallpaper
$HOME/Library/Application Support/Figma/DesktopProfile
$HOME/Library/Application Support/Code/Cache
$HOME/Library/Application Support/Code/CachedData
$HOME/Library/Application Support/Code/CachedExtensionVSIXs
$HOME/Library/Application Support/Code/WebStorage
$HOME/Library/Application Support/Code/DawnWebGPUCache
$HOME/Library/Application Support/Code/GPUCache
$HOME/Library/Application Support/Code/logs
$HOME/.vscode/extensions
$HOME/.npm
$HOME/.bun
$HOME/.cache
$HOME/.rustup
$HOME/.cargo/registry
$HOME/.cargo/git
$HOME/go/pkg
$HOME/.local/pipx
$HOME/.local/share/claude
"

# A build directory qualifies only when it is inside a git repository and that
# repository's own ignore rules cover it (see qualifies_as_build() below) — a
# name match alone is not enough, because "release", "out", "dist" and
# "coverage" are all plausible source directory names too.
BUILD_DIRS="node_modules target .next .turbo .vite release out coverage dist __pycache__"

# A plain config file, never the installed script, is where a user tunes these
# lists: KEY=value lines, read from $DEV_STORAGE_CONFIG or
# ~/.config/dev-storage/config. DEV_STORAGE_EXTRA and DEV_STORAGE_SKIP are read
# the same way from the environment; either source may repeat the key, and a
# value containing "/" is treated as a cache path, otherwise as a build-dir name.
CONFIG_FILE=${DEV_STORAGE_CONFIG:-$HOME/.config/dev-storage/config}
EXTRA=${DEV_STORAGE_EXTRA:-}
SKIP=${DEV_STORAGE_SKIP:-}
if [ -f "$CONFIG_FILE" ]; then
	while IFS='=' read -r key val || [ -n "$key" ]; do
		case "$key" in
		DEV_STORAGE_EXTRA) EXTRA="$EXTRA
$val" ;;
		DEV_STORAGE_SKIP) SKIP="$SKIP
$val" ;;
		'' | '#'*) ;;
		esac
	done <"$CONFIG_FILE"
fi

while IFS= read -r e; do
	[ -n "$e" ] || continue
	case "$e" in
	*/*) GLOBAL_CACHES="$GLOBAL_CACHES
$e" ;;
	*) BUILD_DIRS="$BUILD_DIRS $e" ;;
	esac
done <<EOF
$EXTRA
EOF

while IFS= read -r s; do
	[ -n "$s" ] || continue
	case "$s" in
	*/*) GLOBAL_CACHES="$(printf '%s\n' "$GLOBAL_CACHES" | grep -vxF "$s" || true)" ;;
	*) BUILD_DIRS="$(printf '%s\n' "$BUILD_DIRS" | tr ' ' '\n' | grep -vxF "$s" | tr '\n' ' ' || true)" ;;
	esac
done <<EOF
$SKIP
EOF

free_gb() {
	df -g /System/Volumes/Data | awk 'NR==2 {print $4}'
}

snapshots() {
	tmutil listlocalsnapshots / 2>/dev/null | grep -c local || true
}

# qualifies_as_build <dir> — a name match is not enough: "release", "out",
# "dist" and "coverage" are all plausible names for tracked source too (a
# plugin folder literally named "release/" in a git repository is exactly the
# case this guards). A directory qualifies only when it sits inside a git
# repository AND that repository's own ignore rules cover it — outside a git
# repository it never qualifies, however it is named.
qualifies_as_build() {
	d=$1
	parent=$(dirname "$d")
	name=$(basename "$d")
	git -C "$parent" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
	git -C "$parent" check-ignore -q "$name" 2>/dev/null
}

# find_builds — every build directory under $DEV, pruned so we never descend
# into one (a node_modules holds thousands of nested ones and none of them
# need their own exclusion), filtered to the ones git-ignore actually agrees
# are build output.
find_builds() {
	expr=""
	for d in $BUILD_DIRS; do
		expr="$expr -o -name $d"
	done
	# Unquoted on purpose: the expansion has to split into find's argument list.
	# shellcheck disable=SC2086
	find "$DEV" -maxdepth 6 \( ${expr# -o } \) -type d -prune 2>/dev/null |
		while IFS= read -r d; do
			qualifies_as_build "$d" && printf '%s\n' "$d"
			true
		done
}

# is_stale <dir> — stale means no file anywhere inside it was modified within
# STALE_DAYS. The directory's own mtime is never used for this: a directory's
# mtime changes only when an entry is added or removed at its top level, not
# when a file deep inside it is edited, so judging staleness by it reads an
# actively-edited tree as untouched.
is_stale() {
	[ -z "$(find "$1" -type f -mtime -"$STALE_DAYS" -print -quit 2>/dev/null)" ]
}

cmd_exclude() {
	echo "== excluding caches and build output from Time Machine"
	n=0
	# Heredoc, not a pipe: at least one of these paths contains a space, so the
	# list has to be read a line at a time, and the counter has to survive the
	# loop (a pipe would run it in a subshell and discard n).
	while IFS= read -r p; do
		[ -n "$p" ] && [ -e "$p" ] || continue
		tmutil addexclusion "$p" 2>/dev/null && n=$((n + 1)) || echo "  ! $p"
	done <<EOF
$GLOBAL_CACHES
EOF
	echo "  global caches: $n"

	n=0
	while IFS= read -r d; do
		[ -n "$d" ] || continue
		tmutil addexclusion "$d" 2>/dev/null && n=$((n + 1)) || echo "  ! $d"
	done <<EOF
$(find_builds)
EOF
	echo "  build dirs under $DEV: $n excluded"
	echo "  (re-run after cloning a repo or adding a package — exclusions are per-path,"
	echo "   so a directory created later is not covered until this runs again)"
}

cmd_reclaim() {
	deep=0
	[ "${1:-}" = "--deep" ] && deep=1
	before=$(free_gb)

	# This deletes only what GLOBAL_CACHES already excludes from Time Machine —
	# the delta this skill owns. General package-manager cleanup (`npm cache
	# clean`, `brew cleanup`) is left to a general-purpose macOS cleanup skill;
	# it does not touch what Time Machine backs up, so it is out of scope here.
	echo "== deleting regenerable caches"
	rm -rf "$HOME/Library/Developer/Xcode/DerivedData"/* 2>/dev/null || true
	rm -rf "$HOME/Library/Developer/Xcode/iOS DeviceSupport"/* 2>/dev/null || true
	rm -rf "$HOME/Library/Caches/org.swift.swiftpm" 2>/dev/null || true
	command -v pnpm >/dev/null && pnpm store prune >/dev/null 2>&1 || true

	# Bun's cache has no prune command, so it only grows. Drop it when nothing
	# in $DEV actually resolves through bun; otherwise leave it alone.
	if [ -d "$HOME/.bun/install/cache" ] &&
		! find "$DEV" -maxdepth 4 -name 'bun.lock*' -print -quit 2>/dev/null | grep -q .; then
		echo "  bun cache dropped (no bun.lock under $DEV)"
		rm -rf "$HOME/.bun/install/cache" 2>/dev/null || true
	fi

	if [ "$deep" = 1 ]; then
		echo "== dropping build output untouched for ${STALE_DAYS}d"
		find_builds | while IFS= read -r d; do
			if is_stale "$d"; then
				echo "  - $d"
				rm -rf "$d"
			fi
			true
		done
	else
		stale=$(find_builds | while IFS= read -r d; do
			is_stale "$d" && echo "$d"
			true
		done | wc -l | tr -d ' ')
		[ "$stale" -gt 0 ] && echo "== $stale build dirs untouched for ${STALE_DAYS}d — 'reclaim --deep' removes them"
	fi

	# Without this the deletions above are invisible: the blocks stay pinned by
	# whatever hourly snapshot was taken before them.
	echo "== thinning local snapshots ($(snapshots) present)"
	i=0
	while [ "$i" -lt 3 ]; do
		tmutil thinlocalsnapshots / 80000000000 4 >/dev/null 2>&1 || true
		i=$((i + 1))
	done
	echo "  remaining: $(snapshots)"
	echo "== free: ${before}G -> $(free_gb)G"
}

cmd_report() {
	echo "== free space"
	df -h /System/Volumes/Data | awk 'NR==2 {print "  " $4 " free of " $2 " (" $5 " used)"}'
	echo "  local snapshots: $(snapshots)"

	echo "== largest caches"
	printf '%s\n' "$GLOBAL_CACHES" | while IFS= read -r p; do
		[ -n "$p" ] && [ -e "$p" ] && du -sh "$p" 2>/dev/null || true
	done | sort -rh | head -8 | sed 's/^/  /'

	echo "== largest build output under $DEV"
	find_builds | while IFS= read -r d; do
		printf '%s\t%s\n' "$(du -sm "$d" 2>/dev/null | cut -f1)" "$d"
	done | sort -rn | head -10 | awk -F'\t' '{printf "  %sM\t%s\n", $1, $2}'

	# The preview for 'exclude' and 'reclaim': read this before running either.
	builds=$(find_builds)
	echo "== build dirs under $DEV that 'exclude' would add (git-ignored)"
	if [ -n "$builds" ]; then
		printf '%s\n' "$builds" | sed 's/^/  /'
	else
		echo "  (none found)"
	fi

	echo "== build dirs untouched for ${STALE_DAYS}d — 'reclaim --deep' would remove these"
	stale=""
	if [ -n "$builds" ]; then
		stale=$(printf '%s\n' "$builds" | while IFS= read -r d; do
			is_stale "$d" && echo "$d"
			true
		done)
	fi
	if [ -n "$stale" ]; then
		printf '%s\n' "$stale" | sed 's/^/  /'
	else
		echo "  (none stale)"
	fi
	echo "  (read this list aloud to the user before running 'reclaim --deep')"
}

case "${1:-report}" in
report) cmd_report ;;
exclude) cmd_exclude ;;
reclaim) cmd_reclaim "${2:-}" ;;
all)
	cmd_exclude
	cmd_reclaim "${2:-}"
	cmd_report
	;;
*)
	sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
	exit 1
	;;
esac
