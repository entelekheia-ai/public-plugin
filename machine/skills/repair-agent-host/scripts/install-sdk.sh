#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Populate the Agent Host SDK cache for one agent at the version this VS Code requires,
# using the same layout, URL and completion marker the built-in downloader uses.
#
# Usage: install-sdk.sh <agent>      e.g. install-sdk.sh claude

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_paths.sh"

for tool in curl tar node; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "install-sdk.sh needs '$tool' on PATH — install it and re-run" >&2
    exit 2
  }
done

agent="${1:-}"
if [ -z "$agent" ]; then
  echo "usage: install-sdk.sh <agent>   (claude, codex)" >&2
  exit 2
fi

resolve_paths
TARGET="$(sdk_target)"

version="$(sdk_field "$agent" version || true)"
template="$(sdk_field "$agent" urlTemplate || true)"
if [ -z "$version" ] || [ -z "$template" ]; then
  echo "no agentSdks.$agent in $APP_ROOT/product.json — nothing to install" >&2
  exit 2
fi

cache="$(sdk_cache_root "$agent")"
dest="$cache/$version/$TARGET"
if [ -f "$dest/.complete" ]; then
  echo "already complete: $dest"
  exit 0
fi

url="${template//\{sdkTarget\}/$TARGET}"
case "$url" in
  *'{'*) echo "urlTemplate holds an unknown placeholder: $template" >&2; exit 2 ;;
esac

work="$cache/$version.tmp.$$"
trap 'rm -rf "$work"' EXIT
rm -rf "$work"
mkdir -p "$work/$TARGET"

echo "downloading $agent $version ($TARGET)"
echo "  from $url"
curl -fL --retry 3 --progress-bar -o "$work/sdk.tgz" "$url"

# The tarball's root is node_modules/, so it extracts with no component stripped.
root="$(tar -tzf "$work/sdk.tgz" | head -1)"
case "$root" in
  node_modules/*|node_modules) ;;
  *) echo "unexpected tarball root '$root' — expected node_modules/; refusing to extract" >&2; exit 1 ;;
esac

tar -xzf "$work/sdk.tgz" -C "$work/$TARGET"
rm -f "$work/sdk.tgz"

# Prove the SDK resolves before it is handed back as a cache hit — a directory of
# the right shape that fails to load looks identical to a working one until a
# session starts. Run the check against the work folder, before the move and
# before the .complete marker is written, so a failed install cannot read as
# valid on re-run.
if [ "$agent" = "claude" ]; then
  node -e '
    const { createRequire } = require("module");
    const r = createRequire(process.argv[1] + "/");
    const sdk = r("@anthropic-ai/claude-agent-sdk");
    if (typeof sdk.query !== "function") { throw new Error("claude-agent-sdk exports no query()"); }
    console.log("verified: @anthropic-ai/claude-agent-sdk loads and exports query()");
  ' "$work/$TARGET"
fi

# The empty .complete file is the only thing the agent host reads as a cache hit.
# Written only now, after whatever check above passed.
: > "$work/$TARGET/.complete"

mkdir -p "$cache/$version"
rm -rf "$dest"
mv "$work/$TARGET" "$dest"

echo "installed $dest"

echo
echo "restart VS Code, then re-run sdk-status.sh and read the model count."
