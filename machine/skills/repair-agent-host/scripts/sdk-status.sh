#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Report, per agent, the SDK version this VS Code requires against the versions cached on disk,
# and the last model count the agent host wrote to its log. Writes nothing.
#
# Usage: sdk-status.sh [agent ...]     (default: claude codex)

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_paths.sh"

command -v node >/dev/null 2>&1 || {
  echo "sdk-status.sh needs 'node' on PATH — install it and re-run" >&2
  exit 2
}

resolve_paths
TARGET="$(sdk_target)"

echo "app        $APP_ROOT"
echo "user data  $USER_DATA"
echo "sdk target $TARGET"
echo

agents=("$@")
[ ${#agents[@]} -eq 0 ] && agents=(claude codex)

status=0
for agent in "${agents[@]}"; do
  required="$(sdk_field "$agent" version || true)"
  if [ -z "$required" ]; then
    printf '%-8s no agentSdks.%s entry in product.json — this VS Code ships no SDK for it\n' "$agent" "$agent"
    continue
  fi

  cache="$(sdk_cache_root "$agent")"
  cached="$(ls "$cache" 2>/dev/null | tr '\n' ' ' | sed 's/ $//' || true)"
  marker="$cache/$required/$TARGET/.complete"

  printf '%-8s requires %-12s cached: %s\n' "$agent" "$required" "${cached:-none}"
  if [ -f "$marker" ]; then
    printf '%-8s OK       %s\n' "" "$cache/$required/$TARGET"
  else
    printf '%-8s MISSING  no .complete at %s\n' "" "$cache/$required/$TARGET"
    printf '%-8s          run: install-sdk.sh %s\n' "" "$agent"
    status=1
  fi
  echo
done

log="$(newest_agenthost_log || true)"
if [ -n "$log" ]; then
  echo "log        $log"
  refreshes="$(grep -h "Models refreshed" "$log" | tail -3 || true)"
  if [ -n "$refreshes" ]; then
    echo "$refreshes"
  else
    echo "           no model refresh recorded yet"
  fi
  # One log carries every agent; the [Agent] prefix is what attributes a line.
  deferred="$(grep -h "SDK not downloaded yet" "$log" 2>/dev/null \
    | grep -o '\[[A-Za-z]*\]' \
    | grep -viE '\[(info|warn|error|trace|debug)\]' \
    | sort -u | tr '\n' ' ' || true)"
  if [ -n "$deferred" ]; then
    echo "           reported as not downloaded for: $deferred"
  fi
  # The agent host writes these lines at launch. The log directory is named for that launch, so a
  # marker written after it means the cache changed under a host that never re-read it. The log file's
  # own mtime answers nothing here: a running VS Code keeps touching it.
  started="$(basename "$(dirname "$log")")"
  newest_marker="$(ls -t "$USER_DATA"/agent-host/sdk-cache/*/*/*/.complete 2>/dev/null | head -1 || true)"
  if [ -n "$newest_marker" ]; then
    installed="$(date -r "$newest_marker" +%Y%m%dT%H%M%S)"
    if [ "$installed" \> "$started" ]; then
      echo "           this log is from $started, older than the SDK installed at $installed"
      echo "           restart VS Code and read the count again"
    fi
  fi
else
  echo "log        no agenthost.log under $USER_DATA/logs — the agent host has not run"
fi

exit $status
