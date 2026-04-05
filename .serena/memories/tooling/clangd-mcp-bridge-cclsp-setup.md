Date: 2026-03-14
Configured clangd MCP bridge via cclsp for ksTFL.
- Added workspace config file `cclsp.json` with extensions c/cc/cpp/cxx/h/hh/hpp/hxx and clangd command:
  `clangd --background-index --compile-commands-dir=. --query-driver=/usr/bin/g++ --fallback-style=LLVM`.
- Added launcher script `tools/start_cclsp.sh` that prepends `$HOME/.local/node_modules/.bin` and falls back to `npx -y cclsp@0.7.0`.
- Wired MCP server in `.vscode/mcp.json` as `cclsp/clangd` and in `.cursor/mcp.json` as `cclsp-clangd`, both with env `CCLSP_CONFIG_PATH=${workspaceFolder}/cclsp.json`.
- Added clangd fallback C++20 flags in `.vscode/settings.json` (`clangd.fallbackFlags`).
- Global npm install failed due EACCES (`/usr/local/lib/node_modules`); user-local install worked with `npm install --prefix $HOME/.local cclsp@0.7.0`.
- Regenerated `compile_commands.json`; output confirms g++ uses `-std=gnu++20`.