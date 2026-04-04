#!/usr/bin/env bash
set -euo pipefail

project_root="${1:-$PWD}"

if command -v serena >/dev/null 2>&1; then
  exec serena start-mcp-server --context ide --project "$project_root"
fi

# Offline-first fallback: use cached Serena wheel from uv cache when available.
if command -v uvx >/dev/null 2>&1; then
  cached_wheel="$(find "${HOME}/.cache/uv/sdists-v9" -type f -name 'serena_agent-*.whl' 2>/dev/null | sort -V | tail -n 1 || true)"
  if [[ -n "${cached_wheel}" ]]; then
    exec uvx --offline --from "${cached_wheel}" serena start-mcp-server --context ide --project "$project_root"
  fi
fi

if command -v uvx >/dev/null 2>&1; then
  exec uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context ide --project "$project_root"
fi

echo "Serena launcher not found. Install 'serena' or 'uvx' to run the MCP server." >&2
exit 127