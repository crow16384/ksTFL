# Current Status (Mar 1, 2026)

## Fully Implemented
- Spec initialization for all 3 docTypes (Table, Text, Figure)
- **ggplot2 integration in create_figure()**: accepts ggplot2 objects directly
- Column auto-detection, format assignment, auto width calculation
- Style consolidation with hash-based merging in create_report()
- Context-based function nesting validation (spec_context.R)
- 30+ predefined clinical styles
- Comprehensive error messages with cli_abort()
- Full test coverage (20 test files: 19 R testthat + 1 C++ harness, 806+ passing tests)
- Conditional row styling (compute_cols with c_style, c_merge, c_addrow, c_pageBreak)
- Schema-driven serialization and validation
- save_report() for JSON + data file export — now also maintains _index.json
- Package options management
- Print method for TFL_spec (console + HTML viewer)
- Spanning column headers (add_span_header)
- **C++20 DOCX Renderer** — complete end-to-end rendering pipeline
- **C++ Unit Tests**: src/cpp_tests.cpp, 3 suites, ~135 assertions

## New in Mar 1, 2026 Session

### Bug Fixes (committed)
- **Bug 12: Header text truncation** (e.g. "Descrip" instead of "Description")
  - Root cause: text_measurer.cpp treated single words wider than cell as 1 line
  - Fix: character-level wrapping logic — estimates full_lines + remainder for oversized words
  - File: src/kstfl/text_measurer.cpp

- **Bug 13: Lost data in cells with indent_1 style**
  - Root cause: text_measurer.cpp did not subtract paragraph left/right indents from inner_width
  - Fix: subtract IndentProps::left + right from inner_width before word-wrap calculation
  - File: src/kstfl/text_measurer.cpp

- **Bug 14: Lost data in last row of fixed-unit column tables (TEST_03_05, 06, 09, 10, 11)**
  - Root cause: style_resolver::resolve_column_widths() summed fixed-unit + percentage columns incorrectly, total exceeded table_width
  - Fix: two-pass algorithm — pass 1 resolves fixed-unit (cm/in/mm/pt) columns and accumulates fixed_total; pass 2 resolves percentage columns against (table_width - fixed_total)
  - File: src/kstfl/style_resolver.cpp

- **Bug 15: R cli glue expression error in render_docx()**
  - Root cause: inline `if` expression inside cli::cli_alert_success glue context not supported
  - Fix: pre-compute page_label variable before passing to cli_alert_success
  - File: R/render_docx.R

### New Features (committed)
- **Page count in render log**: C++ renderer now returns total page count
  - renderer.cpp / renderer.h: render() and render_from_strings() return size_t page count
  - rcpp_bindings.cpp: return type changed from void to int
  - R/RcppExports.R: manually updated to remove invisible() wrapper
  - R/render_docx.R: captures n_pages, displays in cli_alert_success message

- **Pagination warning for oversized rows**:
  - paginator.cpp: std::cerr warning when row height exceeds available page body height
  - Condition: used_height.emu == 0 && rh > available

- **Meta folder management** (R/meta_management.R, new file):
  - list_reports(meta_dir, sort_by): scan meta folder, return data frame with is_latest column
  - replay_report(spec_json, meta_dir, output_path, ...): re-render DOCX from stored JSON
  - clean_reports(meta_dir, keep_versions=1, dry_run=TRUE): remove obsolete specs + orphaned data files
  - Internal: .read_spec_index(), .scan_meta_folder(), .collect_spec_meta(), .resolve_spec_path(), .update_spec_index()
  - save_report() updated to call .update_spec_index() after each save
  - _index.json maintained in meta folder for O(1) lookups
  - All three functions exported in NAMESPACE

### MCP Servers Configured (.cursor/mcp.json)
- **Serena** (oraios/serena via uvx): semantic code intelligence, symbol-level tools, --context ide, --project /home/meguty/Develop/R/ksTFL
- **Context7** (@upstash/context7-mcp via npx): up-to-date library docs in chat

## Still TODO
- row_style_schema validation rules
- styles_schema validation rules
- Performance optimization: memoization for schema lookups
- Regression test suite for rendered DOCX output
- Windows build testing
- Structural header_top_border / header_bottom_border application in emitter

## Full Cycle Test Examples (inst/examples/full_cycle_render.R)
13 examples covering minimal table through ggplot2 figures.
Manual unit tests: inst/examples/manul_unit_tests/TEST_03/ (test_03.R, 11 specs)

## Docker Environment
- Image: rocker/verse:latest, container: kstfl-r
- Project mount: /home/rstudio/ksTFL
- R is NOT installed on host — all R execution via docker exec

## Git History (recent)
- feat: meta folder management — list, replay, clean (f9874c4, Mar 1 2026)
- Previous commits: C++ renderer fixes, pagination, text measurement, column width resolution
