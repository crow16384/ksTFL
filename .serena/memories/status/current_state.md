# Current Status (Mar 4, 2026)

## isColBreak + isGrouping + c_addrow Fixes (Mar 4, 2026)

- **Bug 23: Duplicate TOC entries when isColBreak**
  - With `isColBreak = TRUE`, the table is split into horizontal segments; each segment’s first page was treated as “first page” for TOC, so the same title/subtitle appeared multiple times in the TOC.
  - Fix: In `docx_emitter.cpp` `emit_page()`, emit TC fields only when `segment.segment_index == 0` in addition to `page.is_first_page` (for both titles and subtitles).

- **Bug 24: Group subtitles lost and wrong pagination with c_addrow + isGrouping**
  - With grouping columns and `c_addrow('above')`, #ByGroup placeholders were not resolved (subtitle showed literal `#ByGroup1`, etc.), and new subjects (e.g. 01002) did not start on a new page — they appeared at the bottom of the previous subject’s page.
  - Root cause: Synthetic “above” rows did not inherit `force_page_break` or `group_values` from the data row below; paginator used the first row of each page for #ByGroup, so synthetic rows with empty `group_values` broke subtitle resolution; page break stayed on the data row so the break happened in the wrong place.
  - Fix: In `logical_table.cpp` `apply_style_rows()`, when inserting an “above” synthetic row, transfer `force_page_break`, `is_group_boundary`, and `group_values` from the data row to the synthetic row. In `paginator.cpp`, when the first row of a page has empty `group_values`, scan forward to the next row that has them for `dynamic_subtitle_values`.

- **Bug 25: Table grid artefacts when isColBreak + merged body rows**
  - With `isColBreak` and `c_addrow('above')`, horizontal lines extended beyond the right edge of the first segment (extra cells/columns).
  - Root cause: Body merge leaders used full `merge_span` (all visible columns); each segment only has a subset of columns in `w:tblGrid`; emitting that span produced gridSpan larger than the segment grid.
  - Fix: In `docx_emitter.cpp` `emit_table_row()`, clamp merge span and cell width to columns in the current segment (count segment columns in the span, sum only their widths), mirroring the header logic.

- **Docs**: `define_cols.md` — corrected `isColBreak` description (horizontal segment boundary, not page break). `add_subtitle.md` — noted that TOC entries are limited to the first segment when isColBreak is used. `.serena/memories/development/bugs_lessons.md` — added Bug 23, 24, 25 and lessons.

## pkgdown Build Fixes (Mar 4, 2026)

- **Issue: `pkgdown::build_site()` failed with X11 warning and CRAN timeout**
  - Warning 1: `png(..., res = dpi, units = "in"): unable to open connection to X11 display ''` — knitr’s default figure device needed a display.
  - Error: `readRDS(con)` timeout on `https://cran.rstudio.com/web/packages/packages.rds` in callr subprocess (downlit calls `tools::CRAN_package_db()` for autolinking).
  - Fixes:
    - **.Rprofile**: Set `knitr::opts_chunk$set(dev = "cairo_png")` so figures use Cairo (headless-safe). Patch downlit’s memoised `CRAN_urls()` via `utils::getFromNamespace("CRAN_urls", "downlit")` and replace its inner `_f` with a function returning `data.frame(Package = character(0), URL = character(0))` so the CRAN fetch is skipped when building articles.
    - **Vignettes**: Added `dev = "cairo_png"` to each setup chunk; in Reporting_Examples also `png(..., type = "cairo")` for the example plot.
    - **README**: Documented building the pkgdown site (timeout, downlit, optional pkgdown.offline for offline).
  - Result: `pkgdown::build_site(pkg = ".", install = FALSE, preview = FALSE)` completes without X11 and without network to CRAN.

## Rotated Header Text Wrapping (Mar 3, 2026)

- **Bug: Vertically rotated column headers (e.g. `labelStyleRef = "to_90"`) wrapped text inside cells**
  - Symptom: Labels like "RPH-104 (N=16)" broke into multiple lines within the rotated header cell.
  - Causes: (1) docx_emitter did not emit `w:noWrap` in `w:tcPr` for rotated cells (Word could wrap). (2) text_measurer for rotated cells did not include paragraph indents or paragraph spacing in the required row height, so the reserved height was too small when the template had non-zero indents/spacing.
  - Fixes: **docx_emitter.cpp**: For `text_orientation` vertical (btLr/tbRl), emit `<w:noWrap/>` in `w:tcPr`. **text_measurer.cpp**: For rotated path, add `indent_left + indent_right` and total paragraph spacing (`(before + after) * n_paras`) to `required_height`.
  - Result: Header row height accounts for indents/spacing; rotated labels render as intended (single line per segment where applicable).

## doc_footer Pagination Fix (Mar 3, 2026)

- **Bug: `footnotePlace = "doc_footer"` caused table broken across too many pages**
  - Symptom: With `set_document(footnotePlace = "doc_footer")`, tables broke prematurely; some pages showed only 1–2 rows while footnotes repeated on every page.
  - Root cause: In `paginator.cpp`, `compute_available_height()` ignored `footer_section_height`. When footnotes are placed in the Word footer part (`w:ftr`), `footer_section_height` = footer rows + footnotes. If that exceeds the space between bottom margin and `w:footer` distance, Word pushes the body up — but the paginator didn’t reserve that space, so it placed too many rows per page and Word broke them inconsistently.
  - Fix: In `compute_available_height()`, when `footer_section_height > (bottom_margin - footer_distance)`, subtract the overflow from available body height. Same logic for header overflow. File: `src/kstfl/paginator.cpp`.
  - Result: All three modes (`repeated`, `doc_footer`, `last_page`) now paginate consistently (e.g. 5 pages for the AE table example); all 1027 tests pass.

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
- fix: isColBreak + isGrouping + c_addrow — TOC duplicates, lost group subtitles, wrong pagination, table artefacts (Mar 4 2026)
- fix: pkgdown build without X11 and without CRAN fetch (Mar 4 2026) — .Rprofile (cairo_png + downlit CRAN_urls patch), vignettes dev = "cairo_png", README
- fix: rotated header text wrapping in table cells (Mar 3 2026) — docx_emitter w:noWrap for vertical text; text_measurer indents + paragraph spacing for rotated height
- fix: doc_footer pagination — account for footer overflow in compute_available_height (Mar 3 2026)
- feat: doc template handling and defaults — `tfl_set_options()`, `set_page_style()`, `set_document()` (Mar 2 2026)
  - Added `docTemplate` parameter to `tfl_set_options()` to set the session default document template (bundled name or external JSON file path).
  - Removed deprecated `glueNumType` document property from `set_document()`, schema, and printing paths.
  - Updated `set_page_style()` to accept either bundled template names or external JSON file paths, with validation and clearer docs.
  - Updated `.resolve_template_path()` in `render_docx.R` to resolve both bundled names and external paths, with robust fallbacks.
- fix: C++ code review — 9 bug/safety/perf fixes (Mar 1 2026, second session)
- feat: meta folder management — list, replay, clean (f9874c4, Mar 1 2026)
- Previous commits: C++ renderer fixes, pagination, text measurement, column width resolution
