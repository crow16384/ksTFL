# create_report(...)

Purpose: Combine `TFL_spec` and `TFL_report` objects into a single `TFL_report`.

Parameters:
- `...` One or more `TFL_spec` or `TFL_report` objects.

Key package callees and transitive chains:
- Validates input types and keys.
- For new `TFL_spec` inputs: -> `._consolidate_styles_in_spec(spec)`
  - `._consolidate_styles_in_spec` traverses `spec$columns`, `spec$stubColumns`, `titles`, `subtitles`, `footnotes`, `bodyText`, `headers`, `footers` to collect style refs
  - Identifies combinations and creates merged style hashes using `.generate_hash` and `.merge_recursive`
  - Replaces combination refs and prunes unreferenced styles
- Renumbers `docOrder`, creates `dataRef`, and warns on duplicate dataRef values

Direct package callees:
- `._consolidate_styles_in_spec`, `.generate_hash`, `.merge_recursive`, `cli_abort`, `cli_warn`

Usage notes:
- Preserves keys for specs extracted from input `TFL_report` objects; new specs are keyed by `<varname>_<hash>`.
