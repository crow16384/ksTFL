Serena repair notes for ksTFL on 2026-03-12:
- Symptom 1: get_symbols_overview failed with Project attribute error `_lsp_init_error` / `get_log_inspection_instructions`.
- Root cause: local cached Serena package had a broken error path in serena/project.py.
- Fix applied in cached installs under ~/.cache/uv/archive-v0/Ubtsvky6secbhat99QXll/... and ~/.cache/uv/environments-v2/bcb837755ba79986/e47f8d8f3c1fd647/...:
  - added Project.get_log_inspection_instructions()
  - get_language_server_manager_or_raise() now calls self.get_log_inspection_instructions()
- R backend dependency was missing; installed R package `languageserver` from Russian CRAN mirror https://mirror.truenetwork.ru/CRAN/.
- Workspace VS Code MCP config already points to local Serena binary in .vscode/mcp.json; .cursor/mcp.json was updated to the same local binary.
- Restart step mattered: killing stale Serena MCP process allowed the patched server to respawn.
- Current limitation: Serena reports active languages ['r'], so symbol tools work for R files but not for C++ files in this repo.