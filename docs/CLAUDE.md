# CLAUDE.md

## Project Identity

ksTFL is an R package for generating clinical Tables, Figures, and
Listings (TFL) metadata and rendering submission-quality DOCX output via
a C++20 engine.

Primary language: R Secondary language: C++20 (Rcpp)

## Core Architecture

- Main object: `TFL_spec`
- User-facing initializers:
  [`create_table()`](https://example.com/reference/create_table.md),
  [`create_text()`](https://example.com/reference/create_text.md),
  [`create_figure()`](https://example.com/reference/create_figure.md)
- Rendering entrypoint: `render_docx()`
- Serialization pipeline is schema-driven and relies on constants in
  `R/constants.R`
- Internal metadata lives in `spec$.metadata` and must not be serialized

## Required Coding Conventions

- Prefer `checkmate::` assertions for argument validation.
- Use `cli_abort()` and `cli_warn()` for user-facing errors and
  warnings.
- Use double quotes in R code.
- Use integer suffixes like `1L` where appropriate.
- Prefix internal functions with `.` and keep them unexported.
- Exported functions must have complete roxygen docs and matching
  NAMESPACE entries.
- Replace magic strings with constants from `R/constants.R`.
- Reuse existing helpers instead of creating duplicates (for merges use
  `.merge_recursive()`).

## Data and Context Rules

- Treat `spec$.metadata$data_env` as read-only shadow data.
- Do not mutate stored input data in metadata environments.
- Keep table column behavior consistent: selected columns drive report
  columns, while full data may remain available for evaluation context.

## Style Composition Rules

Follow context-based style nesting constraints:

- `add_style(...)` can contain
  [`s_font()`](https://example.com/reference/s_font.md),
  [`s_paragraph()`](https://example.com/reference/s_paragraph.md),
  [`s_table_style()`](https://example.com/reference/s_table_style.md).
- [`s_borders()`](https://example.com/reference/s_borders.md) must be
  nested inside `s_table_style(...)`.
- [`s_border()`](https://example.com/reference/s_border.md) is used only
  as side values inside `s_borders(...)`.

## Supported Inline Markup

Supported inline tags in text cell values:

- `<b>`, `<i>`, `<u>`, `<s>`, `<sup>`, `<sub>`, `<br>`, `<p>`
- `<s>` maps to OOXML strike (`<w:strike/>`)

## Validation and Testing Expectations

When changing behavior:

- Add or update `testthat` coverage under `tests/testthat/`.
- Cover edge cases (empty inputs, all-NA columns, invalid user input).
- Keep C++ unit harness wiring consistent across:
  - `src/cpp_tests.cpp`
  - `src/RcppExports.cpp`
  - `src/init.cpp`
  - `R/RcppExports.R`
  - `tests/testthat/test-18-cpp-units.R`

## MCP Tools

### Serena (R code)

This project uses the **Serena** semantic coding MCP server
(`oraios/serena`). It is the preferred tool for R code exploration and
editing over raw file reads.

### Starting Serena

Serena starts automatically via `.vscode/mcp.json` using
`tools/start_serena.sh`. The script: 1. Prefers a locally installed
`serena` binary. 2. Falls back to the cached wheel via `uvx --offline`.
3. Final fallback: `uvx --from git+https://github.com/oraios/serena`
(requires network).

**Single instance only** — Serena is defined only in `.vscode/mcp.json`.
Do not add it to global `~/.config/Code/User/mcp.json` or
`ksTFL.code-workspace`.

### Using Serena Tools

- On every session, call `mcp_oraios_serena_check_onboarding_performed`
  first. If not onboarded, call `mcp_oraios_serena_onboarding`.
- Read relevant project memories with `mcp_oraios_serena_read_memory` /
  `mcp_oraios_serena_list_memories`.
- Use `mcp_oraios_serena_get_symbols_overview` and
  `mcp_oraios_serena_find_symbol` instead of reading whole files.
- Use `mcp_oraios_serena_replace_symbol_body` for symbol-level edits;
  use `mcp_oraios_serena_replace_content` for targeted line-level
  changes.
- Write durable findings to memory with
  `mcp_oraios_serena_write_memory`.

### cclsp / clangd (C++ code)

This project uses the **cclsp** MCP server (`cclsp/clangd`) for C++ code
navigation. Use it for all C++ work.

- **Find definition:** `mcp_cclsp_clangd_find_definition` — jump to
  where a symbol is defined.
- **Find references:** `mcp_cclsp_clangd_find_references` — locate all
  usages of a symbol.
- **Find implementation:** `mcp_cclsp_clangd_find_implementation` — find
  virtual method implementations.
- **Hover info:** `mcp_cclsp_clangd_get_hover` — get type info and docs
  for a symbol.
- **Diagnostics:** `mcp_cclsp_clangd_get_diagnostics` — check compile
  errors/warnings in a file.
- **Workspace symbols:** `mcp_cclsp_clangd_find_workspace_symbols` —
  search symbols by name across all C++ files.
- **Call hierarchy:** `mcp_cclsp_clangd_prepare_call_hierarchy`,
  `get_incoming_calls`, `get_outgoing_calls`.
- **Rename:** `mcp_cclsp_clangd_rename_symbol` — safe rename across all
  usages.

cclsp starts automatically via `.vscode/mcp.json` using
`tools/start_cclsp.sh`. Requires `clangd` (`/usr/bin/clangd`) and
`compile_commands.json` (regenerate with
`./tools/gen_compile_commands.sh`).

## Practical Workflow for Agents

Before editing code:

- Check onboarding and read Serena memories
  (`mcp_oraios_serena_check_onboarding_performed`,
  `mcp_oraios_serena_list_memories`).
- For R code: read function implementations and roxygen docs via Serena
  symbol tools.
- For C++ code: use cclsp (`mcp_cclsp_clangd_find_definition`,
  `mcp_cclsp_clangd_get_hover`, `mcp_cclsp_clangd_find_references`) to
  navigate before editing.
- Do not infer APIs from memory; verify signatures in source.
- Search for existing patterns and follow local style.

During edits:

- Keep changes minimal and scoped.
- Preserve backward compatibility unless task explicitly requests
  breaking changes.
- Update all affected references when renaming or moving symbols.

After edits:

- Run relevant tests for touched areas.
- Regenerate documentation/NAMESPACE artifacts when required.

## Helpful Commands

When installing R packages, always use the Russian CRAN mirror:

``` bash
R -q -e "options(repos=c(CRAN='https://mirror.truenetwork.ru/CRAN/')); install.packages('...')"
```

R package checks and tests (examples):

``` bash
R -q -e "devtools::test()"
R -q -e "devtools::check()"
R -q -e "testthat::test_dir('tests/testthat')"
```

C++ compile database task (workspace task/script):

``` bash
./tools/gen_compile_commands.sh
```

## What to Avoid

- Do not introduce new style/context APIs when equivalent ones already
  exist.
- Do not bypass schema constants with hardcoded JSON schema keywords.
- Do not use base
  [`stop()`](https://rdrr.io/r/base/stop.html)/[`warning()`](https://rdrr.io/r/base/warning.html)
  for user-facing validation messages where `cli` is already used.
- Do not serialize internal `.metadata` state into output JSON.
