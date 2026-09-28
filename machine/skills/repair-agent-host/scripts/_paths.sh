#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Resolve the VS Code installation and user-data directory this machine uses.
# Sourced by sdk-status.sh and install-sdk.sh; never run on its own.
#
# Override either half when the install is somewhere unusual:
#   VSCODE_APP_ROOT   the directory holding product.json
#   VSCODE_USER_DATA  the directory holding globalStorage/ and agent-host/

set -euo pipefail

resolve_paths() {
  local channel="${VSCODE_CHANNEL:-stable}"

  if [ -n "${VSCODE_APP_ROOT:-}" ] && [ -n "${VSCODE_USER_DATA:-}" ]; then
    APP_ROOT="$VSCODE_APP_ROOT"
    USER_DATA="$VSCODE_USER_DATA"
    return
  fi

  case "$(uname -s)" in
    Darwin)
      if [ "$channel" = "insiders" ]; then
        APP_ROOT="/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app"
        USER_DATA="$HOME/Library/Application Support/Code - Insiders"
      else
        APP_ROOT="/Applications/Visual Studio Code.app/Contents/Resources/app"
        USER_DATA="$HOME/Library/Application Support/Code"
      fi
      ;;
    Linux)
      if [ "$channel" = "insiders" ]; then
        APP_ROOT="/usr/share/code-insiders/resources/app"
        USER_DATA="$HOME/.config/Code - Insiders"
      else
        APP_ROOT="/usr/share/code/resources/app"
        USER_DATA="$HOME/.config/Code"
      fi
      ;;
    *)
      echo "unsupported platform $(uname -s); set VSCODE_APP_ROOT and VSCODE_USER_DATA" >&2
      exit 2
      ;;
  esac

  APP_ROOT="${VSCODE_APP_ROOT:-$APP_ROOT}"
  USER_DATA="${VSCODE_USER_DATA:-$USER_DATA}"

  if [ ! -f "$APP_ROOT/product.json" ]; then
    echo "no product.json under $APP_ROOT — set VSCODE_APP_ROOT to the directory that holds it" >&2
    exit 2
  fi
}

# The value the agent host builds as `${platform}-${arch}`, with a musl suffix on
# a musl Linux for an SDK that ships a separate musl package.
sdk_target() {
  local os arch libc
  case "$(uname -s)" in
    Darwin) os="darwin" ;;
    Linux)  os="linux" ;;
    *) echo "unsupported platform" >&2; return 2 ;;
  esac
  case "$(uname -m)" in
    arm64|aarch64) arch="arm64" ;;
    x86_64|amd64)  arch="x64" ;;
    *) echo "unsupported architecture $(uname -m)" >&2; return 2 ;;
  esac
  if [ "$os" = "linux" ] && ! ldd --version 2>&1 | grep -qi glibc; then
    libc="-musl"
  else
    libc=""
  fi
  printf '%s-%s%s\n' "$os" "$arch" "$libc"
}

# Read one field of product.json's agentSdks entry for an agent id.
sdk_field() {
  local agent="$1" field="$2"
  node -e '
    const p = require(process.argv[1] + "/product.json");
    const e = (p.agentSdks || {})[process.argv[2]];
    if (!e) { process.exit(3); }
    process.stdout.write(String(e[process.argv[3]] ?? ""));
  ' "$APP_ROOT" "$agent" "$field"
}

sdk_cache_root() {
  printf '%s/agent-host/sdk-cache/%s\n' "$USER_DATA" "$1"
}

# The newest agenthost.log, which is the only place the model count is reported.
newest_agenthost_log() {
  ls -dt "$USER_DATA"/logs/*/agenthost.log 2>/dev/null | head -1
}
