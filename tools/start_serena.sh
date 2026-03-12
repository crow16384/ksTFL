#!/usr/bin/env bash
set -euo pipefail

project_root="${1:-$PWD}"

if command -v serena >/dev/null 2>&1; then
  exec serena start-mcp-server --context ide --project "$project_root"
fi

if command -v uvx >/dev/null 2>&1; then
  exec uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context ide --project "$project_root"
fi

echo "Serena launcher not found. Install 'serena' or 'uvx' to run the MCP server." >&2
exit 127