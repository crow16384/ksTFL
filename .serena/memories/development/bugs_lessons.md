# Bugs & Lessons Learned

## Bug 1: Percent Column Width Parsing (Feb 2026)
**Symptom**: Length::parse("5.0%") called without reference width → crash or 0 result
**Root Cause**: json_parser.cpp parsed col_width_raw directly as Length, but % widths need table_width (available only after page geometry computation)
**Fix**: Changed ColumnFormat from `optional<Length> col_width` to `optional<string> col_width_raw`. Deferred parsing to style_resolver.cpp::resolve_column_widths() where table_width is known.
**Files**: types.h, json_parser.cpp, style_resolver.cpp
**Lesson**: Defer unit parsing that depends on context (page size, parent dimensions) until resolution phase.

## Bug 2: Data File .json Extension Mismatch (Feb 2026)
**Symptom**: Renderer says "Data file not found" despite save_report() writing it
**Root Cause**: save_report writes `0001_abc123.json` but spec stores dataRef as `0001_abc123` (no extension). Renderer tried exact path match only.
**Fix**: Added .json extension fallback in renderer.cpp: try exact path, then path + ".json"
**Files**: renderer.cpp
**Lesson**: When two components (writer and reader) communicate via file paths, ensure extension conventions match or add fallback.

## Bug 3: XmlWriter attribute() Outside Start Tag (Feb 2026)
**Symptom**: `"XmlWriter::attribute() called outside of start tag"` crash during OOXML emission
**Root Cause**: `self_closing_element("X")` writes `<X/>` immediately and does NOT set `start_tag_open_ = true`. But 14 places in docx_emitter.cpp called `self_closing_element()` followed by `attribute()`, which requires `start_tag_open_`.
**Fix**: Changed all 14 occurrences to `start_element()` + `attribute()` + `end_element()` pattern.
**Lesson**: CRITICAL XML WRITER RULE — `self_closing_element()` is ONLY for elements with zero attributes.

## Bug 4: Empty String text_width Crash (Feb 2026)
**Symptom**: `vapply(..., integer(1))` error — expected integer, got double (-Inf)
**Root Cause**: `text_width("")` returns zero-length vector. `max()` of empty vector returns `-Inf`.
**Fix**: Added guard: `if (length(w) == 0L) 0L else max(w)` in max_line_width() helper
**Lesson**: Always handle empty/zero-length results from text measurement.

## Bug 5: c_addrow Positional Argument Misidentification (Feb 2026)
**Symptom**: c_addrow(pos = "above", styleRef = "cat_header") incorrectly interpreted styleRef as value_from
**Fix**: Replaced positional access with `match.call(definition = c_addrow, call = action_call)`.
**Lesson**: NEVER use positional index access on call_args() when function has optional arguments.

## Bug 6: gluePrefix Type Mismatch (Feb 2026)
**Symptom**: tfl_set_options() rejected gluePrefix = ": " (character)
**Fix**: Changed `gluePrefix = ": "` to `gluePrefix = TRUE` in test examples
**Lesson**: Always check the actual function signature/docs before passing values.

## Bug 7: Pagination — isGrouping Forced Page Breaks (Feb 2026)
**Symptom**: Example 4 produced 14 pages instead of 1; each isGrouping value change triggered a page break
**Root Cause**: paginator.cpp treated `is_group_boundary` as a page break trigger, same as `force_page_break`
**Fix**: Removed `is_group_boundary` break condition from paginator. Only `force_page_break` (set by isPaging column changes) triggers page breaks. Moved `detect_grouping_boundaries()` before `apply_dedupe()` since dedupe blanks the cell text needed for boundary detection.
**Files**: paginator.cpp, logical_table.cpp
**Lesson**: isGrouping and isPaging are distinct concepts — grouping controls deduplication and dynamic subtitles, paging controls page breaks. Never conflate boundary detection with break triggering.

## Bug 8: Header Vertical Merge Missing (Feb 2026)
**Symptom**: Example 2 stub column headers showed empty cells where label should span vertically
**Root Cause**: build_header_grid() created stub rows and label rows independently. Columns not covered by stubs in the upper rows were empty cells; their labels appeared only in the bottom label row. No vMerge markup was generated.
**Fix**: Added VMergeState enum (None/Restart/Continue). Uncovered columns in stub rows get vMerge::Restart with the column label text. The label row marks those columns as vMerge::Continue (empty). emit_cell_props() emits `<w:vMerge w:val="restart">` or `<w:vMerge/>` accordingly.
**Files**: types.h, logical_table.cpp, docx_emitter.cpp, docx_emitter.h
**Lesson**: Multi-row headers with spanning stubs require explicit vertical merge tracking per cell.

## Bug 9: Integer Format UB — Garbage in Columns (Feb 2026)
**Symptom**: 'vs' and 'am' columns (integer 0/1) showed garbage values like "32660176" or "4294967295"
**Root Cause**: apply_column_format() passed `double` to `snprintf` with `%d` format specifier — undefined behavior. `snprintf` expected an `int` argument for `%d`.
**Fix**: Detect integer format specifiers (%d/%i/%u/%x/%o) and apply `static_cast<int>(dval)` before snprintf.
**Files**: logical_table.cpp
**Lesson**: ALWAYS match snprintf format specifier types. %d expects int, not double. This is UB that silently produces garbage on most platforms.

## Bug 10: Table Bottom Border Lost (Feb 2026)
**Symptom**: Table's last data row had no bottom border despite template defining structural.table_bottom_border
**Root Cause**: json_parser.cpp had an empty stub for structural border parsing (lines 734-736 did nothing). The 3 structural borders were defined in the template JSON but never stored in TableStyleConfig::Structural. Body row borders were all "none", overriding any table-level border.
**Fix**: (1) Added 3 border fields to Structural struct. (2) Parsed all structural borders via parse_border(). (3) Added `is_last_row` parameter to emit_table_row(). (4) On last data row per page, override cell bottom border with structural.table_bottom_border.
**Files**: types.h, json_parser.cpp, docx_emitter.cpp, docx_emitter.h
**Lesson**: Always verify that parsed config is actually stored and consumed. Empty stubs with comments like "for emit phase" are red flags — trace the full data flow from parse → store → apply.

## Bug 11: Titles as Separate Paragraphs (Feb 2026)
**Symptom**: Multiple add_title() calls produced separate paragraphs instead of one paragraph with soft breaks
**Root Cause**: Each add_title() creates a separate TextGroup. emit_text_groups() emits each TextGroup as its own `<w:p>` paragraph. No mechanism existed to combine groups into a single paragraph.
**Fix**: Added emit_text_groups_combined() method that emits all TextGroups as runs within a single `<w:p>`, with `<w:br/>` between groups. Each group retains its own font style as separate runs. Paragraph properties come from base style. glue_prefix is emitted as the first run.
**Files**: docx_emitter.cpp, docx_emitter.h
**Lesson**: OOXML paragraph = `<w:p>`, runs = `<w:r>` within it. Multiple styles within one paragraph require separate runs. Soft break = `<w:br/>` inside a run. Design the emit function to match the desired OOXML structure.

## General Lessons

### XmlWriter API Contract
- start_element() → start_tag_open_ = true → attribute() works → end_element() closes
- self_closing_element() → writes <X/> immediately → start_tag_open_ stays false → attribute() THROWS
- end_element() when start_tag_open_: emits `/>` (auto self-close)
- end_element() when !start_tag_open_: emits `</X>` (normal close)

### Pagination Architecture
- isGrouping: marks group boundaries for dedupe + dynamic subtitles; does NOT force page breaks
- isPaging: marks paging column changes that FORCE page breaks
- detect_grouping_boundaries() must run BEFORE apply_dedupe() (dedupe blanks cell text)
- Paginator only checks force_page_break flag, never is_group_boundary

### OOXML Border Architecture
- Cell borders override table borders in Word (cell-level takes precedence)
- Structural borders (header_top, header_bottom, table_bottom) are "table-level" concepts
  but must be applied as cell borders in OOXML (no table-level bottom border concept)
- Template body.row.borders = "none" means: no borders on body rows by default
- Last row bottom border must be explicitly set on each cell of the last row

### R Call Object Patterns
- rlang::call_args(): returns args in order they appear in the CALL (not the definition)
- match.call(definition, call): properly maps positional args to named params per function signature

### Text Specs and Data
- Text specs (docType="Text") don't have data files, but create_report still assigns dataRef
- Renderer logs "WARNING: Data file not found" for text specs — this is benign
