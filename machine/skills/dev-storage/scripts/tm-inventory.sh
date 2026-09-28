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

say "Time Machine — inventario do destino"
say "host $(hostname -s)   user $REAL_USER   $(date)"
say "SOMENTE LEITURA: nada e apagado por este script."

# --- 1. locate ------------------------------------------------------------------
phase "Localizando o destino e os backups"
DEST=$(tmutil destinationinfo 2>/dev/null | awk -F': +' '/Mount Point/{print $2; exit}')
say ""
say "destino: ${DEST:-desconhecido}"

tmutil listbackups >"$TMPD/backups" 2>&1
if grep -qi 'full disk access\|operation not permitted' "$TMPD/backups"; then
	note "BLOQUEADO: sem Full Disk Access."
	rule "Bloqueado"
	say "Este relatorio precisa de Full Disk Access no terminal."
	say "Ajustes -> Privacidade e Seguranca -> Acesso Total ao Disco."
	say "sudo NAO substitui: a permissao e por aplicativo, nao por usuario."
	mv "$DRAFT" "$OUT" && chown "$REAL_USER" "$OUT" 2>/dev/null
	printf '\nrelatorio (bloqueado) em: %s\n' "$OUT" >&2
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
	beat "nao montado, tentando o anterior: $(basename "$(dirname "$b")")"
done <<EOF
$(sort -r "$TMPD/backups")
EOF

if [ -z "$LATEST" ]; then
	note "nenhum dos $NBK backups esta montado e acessivel"
	rule "Nenhum backup acessivel"
	say "listbackups conhece $NBK backups, mas nenhum esta montado agora."
	say "Os snapshots aparecem sob /Volumes/.timemachine sob demanda; abrir o"
	say "backup no app do Time Machine costuma monta-los."
	mv "$DRAFT" "$OUT" && chown "$REAL_USER" "$OUT" 2>/dev/null
	exit 1
fi
[ "$SKIPPED_UNMOUNTED" -gt 0 ] &&
	note "$SKIPPED_UNMOUNTED backup(s) mais recente(s) nao montado(s) — usando o mais novo acessivel"
note "$NBK backups; usando: $(basename "$(dirname "$LATEST")")"

# The mounted snapshots are visible in `mount` even without Full Disk Access,
# which is the cheapest way to confirm the layout rather than assume it.
say "backups: $NBK"
say "mais antigo: $(head -1 "$TMPD/backups")"
say "mais recente: $(tail -1 "$TMPD/backups")"
say "analisado:   $LATEST"
[ "$SKIPPED_UNMOUNTED" -gt 0 ] &&
	say "($SKIPPED_UNMOUNTED backup(s) mais recente(s) nao estavam montados)"
say ""
say "--- datas ---"
sed -n 's|.*/\([0-9-]*\)\.backup/.*|\1|p' "$TMPD/backups" >>"$DRAFT"
say ""
say "Se todas as datas forem do mesmo dia, o destino nao carrega historico"
say "antigo: o lixo acumulado que este relatorio procura seria pequeno, e a"
say "exclusao na origem ja resolve o futuro."
say ""
say "--- snapshots montados agora ---"
mount | grep -i timemachine >>"$DRAFT" 2>/dev/null || say "(nenhum montado)"

# --- 2. find the user's home inside the latest backup ---------------------------
phase "Localizando a home dentro do backup"
# Discover rather than assume: the volume directory inside a backup is named after
# the source volume ("Macintosh HD - Data" and friends), which is not ours to guess.
BHOME=$(find "$LATEST" -maxdepth 4 -type d -path "*/Users/$REAL_USER" 2>/dev/null | head -1)
if [ -z "$BHOME" ]; then
	note "nao encontrei Users/$REAL_USER dentro de $LATEST"
	rule "Estrutura inesperada"
	say "Nao localizei a home do usuario dentro do backup mais recente."
	say "Conteudo do nivel superior:"
	find "$LATEST" -maxdepth 1 -mindepth 1 2>&1 | head -20 >>"$DRAFT"
	mv "$DRAFT" "$OUT" && chown "$REAL_USER" "$OUT" 2>/dev/null
	exit 1
fi
note "home no backup: $BHOME"
say ""
say "home dentro do backup: $BHOME"

# --- 3. targeted probe of the categories we already know are regenerable --------
# Cheap and precise: ask about the paths whose answer we can act on, instead of
# walking the whole tree to rediscover them.
phase "Categorias reconstruiveis presentes no backup"
CANDIDATES="
Library/Developer
Library/Caches
Library/Application Support/Claude/vm_bundles
Library/Application Support/com.apple.wallpaper
Library/Application Support/Code
Library/Application Support/Google
Library/Application Support/Figma
.npm
.bun
.cache
.rustup
.cargo/registry
.omlx
.vscode/extensions
go/pkg
.local/pipx
.local/share/claude
.litert-lm
.gemini/antigravity-ide/browser_recordings
"
: >"$TMPD/found"
n=0
while IFS= read -r rel; do
	[ -n "$rel" ] || continue
	n=$((n + 1))
	beat "consultando $rel"
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
beatdone "$(grep -c . "$TMPD/found" 2>/dev/null || echo 0) de $n categorias presentes no backup"

rule "Reconstruivel que esta dentro do backup"
say "'unico' = espaco NAO compartilhado com outros backups, ou seja o que"
say "realmente seria liberado. du sobre snapshots conta o mesmo bloco uma vez"
say "por backup e superestima grosseiramente; por isso usamos uniquesize."
say ""
say "COMO LER UM VALOR BAIXO: significa que este caminho e identico nos outros"
say "backups, entao apagar de UM backup nao libera nada. NAO significa que ele"
say "seja barato: ele continua entrando em todo backup futuro ate ser excluido"
say "na origem. Um numero baixo aqui e argumento para excluir, nao para ignorar."
say ""
say "Uma categoria AUSENTE desta lista e uma boa noticia: quer dizer que ja esta"
say "excluida e nao chegou ao backup."
say ""
if [ -s "$TMPD/found" ]; then
	# Print the raw byte count beside the MB. Rounding alone turns "a few KB",
	# "exactly zero" and "parsed the wrong field" into the same 0.0, which is
	# three very different conclusions wearing one number.
	sort -rn "$TMPD/found" |
		awk -F'\t' '{printf "%9.1f MB  (%s bytes)  %s\n", $1/1048576, $1, $2}' >>"$DRAFT"
else
	say "(nenhuma das categorias conhecidas foi encontrada)"
fi

if [ -s "$TMPD/unparsed" ]; then
	say ""
	say "--- uniquesize devolveu formato que nao reconheci ---"
	say "Mande estas linhas para ajustar o parsing; nao as trate como zero."
	cat "$TMPD/unparsed" >>"$DRAFT"
fi

# --- 4. optional deep walk ------------------------------------------------------
phase "Varredura da arvore do backup${DEEP:+ (DEEP=$DEEP)}"
if [ "$DEEP" != 1 ]; then
	note "pulada — use DEEP=1 para descobrir categorias que nao estao na lista"
	rule "Varredura profunda"
	say "Nao executada. DEEP=1 percorre a arvore do backup para achar o que a"
	say "lista de categorias nao previu. Custa I/O no volume de backup."
else
	du -kx -d 3 "$BHOME" 2>/dev/null >"$TMPD/tree.part" &
	WP=$!
	W0=$(date +%s)
	while kill -0 "$WP" 2>/dev/null; do
		w=$(($(date +%s) - W0))
		[ "$w" -ge "$WALK_TIMEOUT" ] && {
			kill "$WP" 2>/dev/null
			note "abandonada apos ${WALK_TIMEOUT}s"
			break
		}
		beat "percorrendo a arvore do backup (${w}s de ${WALK_TIMEOUT}s)"
		sleep 2
	done
	beatdone "varredura concluida"
	rule "Maiores itens dentro do backup (tamanho logico)"
	say "ATENCAO: este e o tamanho LOGICO, nao o espaco ocupado. Blocos"
	say "compartilhados entre backups aparecem inteiros aqui. Use a secao"
	say "anterior (uniquesize) para saber o que seria liberado de fato."
	say ""
	awk -v m="$MIN_MB" '$1/1024 >= m' "$TMPD/tree.part" 2>/dev/null | sort -rn | head -40 |
		awk '{printf "%8dM  %s\n", $1/1024, substr($0, index($0, "\t") + 1)}' >>"$DRAFT"
fi

# --- 5. the commands, for a human to read and run -------------------------------
phase "Montando os comandos para revisao"
rule "Comandos sugeridos — NAO executados por este script"
say "Apagar de um backup e IRREVERSIVEL. Leia cada linha antes de rodar."
say "'delete -p' remove um caminho do historico sem apagar backups inteiros."
say ""
if [ -s "$TMPD/found" ]; then
	sort -rn "$TMPD/found" | while IFS="$(printf '\t')" read -r us rel; do
		[ "${us:-0}" -gt 104857600 ] || continue # so acima de 100MB unicos
		say "# libera ~$((us / 1048576)) MB"
		say "sudo tmutil delete -p \"$BHOME/$rel\""
		say ""
	done
else
	say "(nada acima do limiar)"
fi
say "Depois de apagar, confirme que a origem esta excluida para nao voltar:"
say "  dev-storage.sh exclude"

mv "$DRAFT" "$OUT" || {
	printf 'nao consegui escrever em %s\n' "$OUT" >&2
	exit 1
}
chown "$REAL_USER" "$OUT" 2>/dev/null || true
printf '\nrelatorio salvo em: %s\n' "$OUT" >&2
printf 'linhas: %s\n' "$(grep -c . "$OUT")" >&2
