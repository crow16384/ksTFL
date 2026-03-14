#!/usr/bin/env bash
set -euo pipefail

# Keep local npm prefix binaries available when launched by MCP clients.
export PATH="$HOME/.local/node_modules/.bin:$HOME/.local/bin:$PATH"

if command -v cclsp >/dev/null 2>&1; then
  exec cclsp
fi

exec npx -y cclsp@0.7.0