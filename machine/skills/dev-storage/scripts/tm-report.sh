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
# the useful half of the message ("...bloqueado e") on a wide window while wasting
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
say "cores $NCPU   limite ${MIN_MB}MB   janela ${DAYS}d"

# --- 1. context ----------------------------------------------------------------
phase "Contexto do disco e do Time Machine"
rule "Disco"
df -h / /System/Volumes/Data 2>/dev/null >>"$DRAFT"
rule "Destino do backup"
tmutil destinationinfo >>"$DRAFT" 2>&1
say ""
tmutil status 2>/dev/null | sed -n '1,8p' >>"$DRAFT"
say "AutoBackup: $(defaults read /Library/Preferences/com.apple.TimeMachine.plist AutoBackup 2>/dev/null || echo '?')"
SNAPS=$(tmutil listlocalsnapshots / 2>/dev/null | grep -c local)
rule "Snapshots locais"
say "quantidade: $SNAPS"
say "(cada um segura os blocos de tudo que foi apagado depois dele;"
say " 'dev-storage.sh reclaim' termina afinando-os)"
note "destino: $(tmutil destinationinfo 2>/dev/null | awk -F': ' '/Mount Point/{print $2; exit}')"
note "snapshots locais: $SNAPS"

# --- 2. backup side, launched in the background --------------------------------
# The slowest step and independent of everything else, so it runs while phases
# 3-5 do their work. Collected in phase 6.
phase "Lado do backup (em segundo plano)"
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
note "listbackups + compare disparados (pid $BG)"
if [ "$SKIP_COMPARE" = 1 ]; then
	note "compare desativado (SKIP_COMPARE=1)"
else
	note "'tmutil compare' varre o volume inteiro contra o ultimo backup:"
	note "leva minutos e fica bloqueado em I/O, com quase zero CPU."
	note "limite ${COMPARE_TIMEOUT}s (COMPARE_TIMEOUT=), ou SKIP_COMPARE=1 para pular."
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
phase "Exclusoes ativas (xattr + SkipPaths)"
defaults read /Library/Preferences/com.apple.TimeMachine.plist SkipPaths 2>/dev/null |
	sed -n 's/^ *"\{0,1\}\(\/[^",]*\)"\{0,1\},\{0,1\} *$/\1/p' | sort >"$TMPD/skip"
NSKIP=$(grep -c . "$TMPD/skip" 2>/dev/null || echo 0)

# Read the xattr off the disk instead of asking Spotlight for it. The index is
# the wrong instrument twice over: it holds no dotfiles at all, and on this
# machine it reports nothing under ~/Library either — which is precisely where
# the exclusions live. Batched with `-exec … {} +`, testing every directory costs
# seconds and finds 316 exclusions where `mdfind` finds none.
#
# Five levels, not three. The exclusions this policy sets are that deep —
# `Library/Application Support/Claude/vm_bundles` is four — and a depth-3 scan
# missed it, so 6.9 GB of excluded VM image was charged to its parents' churn.
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
# whichever one it omits: ~/.omlx here is 104 GB excluded solely via SkipPaths.
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
phase "Tamanhos por pasta ($NCPU cores em paralelo)"

# Skip what is already excluded before walking it. These can never reach the
# candidate list, and one of them here is 104 GB — the walk was pure cost.
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
note "$NTOP a medir, $SKIPPED ja excluidas (nao serao percorridas)"

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
	# child alone held 8730 of the changed files in a seven-day window. Counting
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
	beat "despachando $i/$NTOP  $(basename "$d")"
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
		note "abandonadas apos ${SIZE_TIMEOUT}s: $(tr '\n' ' ' <"$TMPD/abandoned")"
		break
	fi
	beat "medindo — faltam $(alive) de $NTOP: $(lagging) (${w}s)"
	sleep 1
done
cat "$TMPD"/sz.* 2>/dev/null | awk -v m="$MIN_MB" '$1/1024 >= m' | sort -rn >"$TMPD/sizes"
NCAND=$(grep -c . "$TMPD/sizes" 2>/dev/null || echo 0)
tickdone "$NTOP pastas medidas ($SKIPPED puladas), $NCAND acima de ${MIN_MB}MB"

# --- 5. churn -------------------------------------------------------------------
# What a backup costs is not the bytes a directory holds, it is the bytes that
# moved: a static 104 GB directory is copied once and then costs nothing, while a
# small directory rebuilt daily costs every night. So rank by churn and keep size
# as context, rather than the other way round.
#
# This used to ask Spotlight, which cannot answer it: the index contains no
# dotfiles at all. ~/.claude had 5388 files changed in a week and ~/.vscode 4625,
# and both were reported static — the two noisiest directories on the machine,
# silently inverted. The walk above costs a second pass over the same trees and
# is complete.
phase "Bytes alterados por pasta (${DAYS}d)"
cat "$TMPD"/ch.* 2>/dev/null >"$TMPD/changed"
NREC=$(grep -c . "$TMPD/changed" 2>/dev/null || echo 0)
note "$NREC arquivos alterados em ${DAYS}d"

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
tickdone "$NREC arquivos, ${CHTOT}MB alterados em ${DAYS}d"

# --- 6. join and write ----------------------------------------------------------
phase "Consolidando o relatorio"

rule "Backups no destino (precisa de Full Disk Access)"
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
	beat "aguardando compare (${w}s de ${COMPARE_TIMEOUT}s, bloqueado em I/O)"
	sleep 1
done
if [ "$TIMED_OUT" = 1 ]; then
	tickdone "compare abortado apos ${COMPARE_TIMEOUT}s — resto do relatorio intacto"
else
	tickdone "lado do backup concluido em $(($(date +%s) - WAIT0))s"
fi

if blocked "$TMPD/backups"; then
	say "BLOQUEADO — conceda Full Disk Access ao terminal e rode de novo."
	say "System Settings -> Privacy & Security -> Full Disk Access"
	say "(sudo sozinho nao levanta: a permissao e por aplicativo, nao por usuario)"
	FDA=0
else
	say "quantidade: $(grep -c . "$TMPD/backups")"
	say "mais antigo: $(head -1 "$TMPD/backups")"
	say "mais recente: $(tail -1 "$TMPD/backups")"
	FDA=1
fi

rule "O que muda entre o backup mais recente e o disco de hoje"
if [ "$TIMED_OUT" = 1 ]; then
	say "ABORTADO apos ${COMPARE_TIMEOUT}s."
	say "'tmutil compare' varre o volume inteiro contra o ultimo backup e fica"
	say "bloqueado em I/O (CPU perto de zero), entao nao ha como saber se falta"
	say "pouco. Rode com COMPARE_TIMEOUT=3600 se quiser esperar de verdade."
elif [ "$SKIP_COMPARE" = 1 ]; then
	say "pulado a pedido (SKIP_COMPARE=1)."
elif [ "$FDA" = 1 ] && [ -s "$TMPD/compare" ] && ! blocked "$TMPD/compare"; then
	say "--- resumo ---"
	tail -12 "$TMPD/compare" >>"$DRAFT"
	say ""
	say "--- 40 maiores itens alterados ---"
	awk '$2 ~ /^[0-9]+$/ {printf "%s\t%s\n", $2, substr($0, index($0,$3))}' "$TMPD/compare" |
		sort -rn | head -40 |
		awk -F'\t' '{printf "%8.1f MB  %s\n", $1/1048576, $2}' >>"$DRAFT"
else
	say "pulado: depende de Full Disk Access."
fi

rule "Exclusoes ativas hoje"
say "Dois mecanismos independentes; ler so um da resposta errada com confianca."
say ""
say "--- SkipPaths (plist do Time Machine): $NSKIP ---"
cat "$TMPD/skip" >>"$DRAFT"
say ""
say "--- xattr, lido direto do disco ate 5 niveis: $NEXCL ---"
say "(nao vem do Spotlight: o indice nao tem dotfile nenhum e aqui nao"
say " reportou nada sob ~/Library, que e justamente onde eles estao.)"
cat "$TMPD/excl" >>"$DRAFT"

rule "O que volta para o backup (lado da origem), por bytes alterados"
say "Ordenado por MUDOU/${DAYS}d, nao por tamanho: o custo de um backup e o que"
say "muda, nao o que existe. Uma pasta estatica de 100GB e copiada uma vez e"
say "depois custa zero; uma de 1GB reconstruida todo dia custa toda noite."
say "Nada nesta lista esta excluido. Minimo ${MIN_MB}MB de tamanho."
say ""
say "ARQ = quantos arquivos mudaram. Muitos arquivos com poucos bytes cada e o"
say "perfil de cache reconstruido (exclua a pasta). Poucos arquivos com muitos"
say "bytes e um arquivo grande sendo reescrito — e nesse caso lembre que o TM"
say "copia so os blocos alterados, entao o custo real e menor que o numero."
say ""
say "CUIDADO: o tamanho e o da subarvore inteira, inclusive de filhas que JA"
say "estao excluidas — MUDOU nao, esse ja desconta as filhas excluidas. Entao"
say "uma pasta pode aparecer enorme e mudar pouco porque o caro nela ja saiu."
say ""
say "MUDOU = ? significa que a varredura daquela pasta foi abandonada no limite"
say "de tempo. E desconhecido, nao zero, e por isso vem no topo. Rode de novo com"
say "SIZE_TIMEOUT maior para resolver."
say ""
say " TAMANHO  MUDOU/${DAYS}d    ARQ  CAMINHO"

# One awk pass over four inputs: SkipPaths to filter, churn to rank, the
# abandoned roots to mark as unknown, sizes as the candidate set.
#
# A walk that was killed leaves no churn file, and without the abandoned list its
# whole subtree would read as "0 bytes changed" — a 45 GB directory reported as
# perfectly quiet, sorted to the bottom where nobody looks. Missing data is
# printed as `?` and sorted to the TOP instead: not knowing is worth more
# attention than knowing it is zero, not less.
#
# -F'\t' is not cosmetic. Every one of these files is tab-separated and holds
# paths, and awk's default splitting breaks on any whitespace: with it,
# `~/Library/Application Support` keys as `/Users/alice/Library/Application`,
# its churn lookup misses, and 21 GB of directory reports 0 bytes changed across
# 0 files — while the 4905 files that did change still show up in the parent's
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
tickdone "$kept candidatos apos filtrar as duas exclusoes"

cat "$TMPD/final" >>"$DRAFT"

# Only now does the file appear at $OUT. Interrupt the run at any point before
# this and there is no report rather than a convincing fragment of one.
mv "$DRAFT" "$OUT" || {
	printf 'nao consegui escrever em %s\n' "$OUT" >&2
	exit 1
}
chown "$REAL_USER" "$OUT" 2>/dev/null || true

printf '\nrelatorio salvo em: %s\n' "$OUT" >&2
printf 'linhas: %s\n' "$(grep -c . "$OUT")" >&2
