# Current Status (Mar 1, 2026)

## C++ Code Review Fixes (Mar 1, 2026 — second session)

### Bug Fixes
- **Bug 16: `<sub>` tag sets wrong state** (inline_parser.cpp)
  - Switch case for `TagType::Sub` was setting `superscript = true` instead of `subscript = true`
  - Removed fragile trailing `if` block that was patching the bug post-switch
  - Fix: `state.subscript = true; state.superscript = false; break;` in the switch

- **Bug 17: w:highlight emits hex instead of OOXML color name** (docx_emitter.cpp)
  - `<w:highlight>` requires named colors; hex was silently ignored by Word
  - Fix: replaced with `<w:shd w:val="clear" w:color="auto" w:fill="HEX"/>` on runs

- **Bug 18: Row heights measured twice** (renderer.cpp + paginator.cpp)
  - renderer.cpp Phase 3c duplicated `Paginator::compute_row_heights()` logic
  - Fix: removed Phase 3c loop from renderer.cpp; `Paginator::paginate()` now takes `std::vector<LogicalRow>&` (non-const) and stores heights into `row.measured_height` — single source of truth

- **Bug 19: snprintf format string validation fragile** (logical_table.cpp)
  - Substring search for 'd' matched "displayed: %.2f" → UB cast to int
  - Fix: `is_safe_numeric_format()` validates against regex whitelist; integer specifier found by scanning for last conversion char

- **Bug 20: Ragged column data silently accepted** (json_parser.cpp)
  - Fix: post-parse validation in `parse_data_internal()` warns via `std::cerr` on length mismatch

### Safety Improvements
- **S2: XmlWriter::comment() sanitizes `--`** (xml_writer.cpp)
  - Replaces `--` with `- -` to prevent malformed XML comments from user-controlled text

- **S3: snprintf format string whitelist** (logical_table.cpp)
  - See Bug 19 above — same fix addresses the safety concern

### Performance Improvements
- **M2: HarfBuzz buffer reused in TextMeasurer** (text_measurer.cpp/.h)
  - `hb_buf_` created once in constructor (stored as `mutable hb_buffer_t*`), reset via `hb_buffer_reset()` per call
  - Eliminates ~20,000 buffer alloc/destroy cycles for large tables

### API / Design Improvements
- **M3: Multiple styleRef supported in TextGroup** (types.h, json_parser.cpp, style_resolver.cpp/.h, paginator.cpp, docx_emitter.cpp)
  - `TextGroup::style_ref` (optional<string>) → `TextGroup::style_refs` (vector<string>)
  - All style refs merged in order (R side may pass multiple refs)
  - `resolve_title_style()`, `resolve_subtitle_style()`, `resolve_footnote_style()` now accept `vector<string>`
  - All 7 consumer sites updated (3 in paginator.cpp, 4 in docx_emitter.cpp)

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

## New in Mar 1, 2026 Session (first commit)

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
- **Pagination warning for oversized rows**: paginator.cpp
- **Meta folder management** (R/meta_management.R): list_reports, replay_report, clean_reports

### MCP Servers Configured (.cursor/mcp.json)
- **Serena** (oraios/serena via uvx): semantic code intelligence
- **Context7** (@upstash/context7-mcp via npx): up-to-date library docs

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
- fix: C++ code review — 9 bug/safety/perf fixes (Mar 1 2026, second session)
- feat: meta folder management — list, replay, clean (f9874c4, Mar 1 2026)
- Previous commits: C++ renderer fixes, pagination, text measurement, column width resolution
