#!/usr/bin/env bash
set -euo pipefail

plugin_root="$(cd "$(dirname "$0")/.." && pwd)"
core_root="$plugin_root/core"

cd "$core_root"
moon check --deny-warn --target native
moon test --target native
moon build cmd/server --target native --release

binary="$(find "$core_root/_build" -type f -name server -print -quit)"
if [[ -z "$binary" ]]; then
  echo "找不到 cmd/server 的 native 构建产物" >&2
  exit 1
fi

mkdir -p "$plugin_root/dist/linux-x64"
cp "$binary" "$plugin_root/dist/linux-x64/moonbit-guardian-server"
chmod +x "$plugin_root/dist/linux-x64/moonbit-guardian-server"
