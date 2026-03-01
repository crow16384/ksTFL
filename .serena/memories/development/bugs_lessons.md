# Bugs & Lessons Learned

## Bug 1: Percent Column Width Parsing (Feb 2026)
**Symptom**: Length::parse("5.0%") crash without reference width
**Fix**: Deferred to style_resolver::resolve_column_widths() where table_width is known. col_width_raw stored as string.
**Lesson**: Defer unit parsing that depends on context until resolution phase.

## Bug 2: Data File .json Extension Mismatch (Feb 2026)
**Fix**: Added .json extension fallback in renderer.cpp.
**Lesson**: Ensure extension conventions match between writer and reader, or add fallback.

## Bug 3: XmlWriter attribute() Outside Start Tag (Feb 2026)
**Symptom**: Crash during OOXML emission
**Fix**: Changed 14 occurrences of self_closing_element() + attribute() to start_element() + attribute() + end_element().
**CRITICAL RULE**: self_closing_element() is ONLY for elements with zero attributes.

## Bug 4: Empty String text_width Crash (Feb 2026)
**Fix**: Guard: if (length(w) == 0L) 0L else max(w) in max_line_width()

## Bug 5: c_addrow Positional Argument Misidentification (Feb 2026)
**Fix**: match.call(definition = c_addrow, call = action_call)
**Lesson**: NEVER use positional index access on call_args() when function has optional arguments.

## Bug 6: gluePrefix Type Mismatch (Feb 2026)
**Fix**: gluePrefix is bool, not string.

## Bug 7: Pagination isGrouping Forced Page Breaks (Feb 2026)
**Fix**: Removed is_group_boundary break condition from paginator. Only force_page_break triggers breaks.
**Lesson**: isGrouping (dedup/subtitles) vs isPaging (page breaks) are distinct.

## Bug 8: Header Vertical Merge Missing (Feb 2026)
**Fix**: VMergeState enum (None/Restart/Continue). Uncovered stub-row columns get Restart + label text; label row marks them Continue.

## Bug 9: Integer Format UB (Feb 2026)
**Symptom**: %d with double arg -> garbage values
**Fix**: static_cast<int>(dval) for %d/%i/%u/%x/%o format specifiers.
**Lesson**: ALWAYS match snprintf format specifier types.

## Bug 10: Table Bottom Border Lost (Feb 2026)
**Fix**: Parse structural borders in json_parser; apply to last data row per page in docx_emitter via is_last_row parameter.

## Bug 11: Titles as Separate Paragraphs (Feb 2026)
**Fix**: emit_text_groups_combined() combines all TextGroups in single <w:p> with <w:br/> between groups.

## Bug 12: Header Text Truncation (Mar 2026)
**Symptom**: "Description" header rendered as "Descrip" (clipped)
**Root Cause**: text_measurer.cpp treated a single word wider than cell width as 1 line. w:hRule="exact" clipped the overflow.
**Fix**: Character-level wrapping: when word_width > inner_width, compute full_lines = word_width.emu / inner_width.emu, add that many lines, carry remainder as current_line_width.
**File**: src/kstfl/text_measurer.cpp
**Lesson**: Single words can exceed cell width. Must estimate char-level line count, not assume 1 line.

## Bug 13: Lost Data in Cells with indent_1 Style (Mar 2026)
**Symptom**: Text clipped in rows using indent_1 (0.5cm left indent)
**Root Cause**: text_measurer::measure_cell() computed inner_width = cell_width - cell_margins, but did not subtract paragraph indents. Overestimated available width -> underestimated line count -> row too short.
**Fix**: After computing inner_width, subtract IndentProps::left + right (if indents present).
**File**: src/kstfl/text_measurer.cpp
**Lesson**: Paragraph indents reduce effective text width just like cell margins. Both must be subtracted.

## Bug 14: Lost Data in Last Row of Fixed-Unit Column Tables (Mar 2026)
**Symptom**: TEST_03_05, 06, 09, 10, 11 — last row data clipped/missing
**Root Cause**: resolve_column_widths() resolved percentage columns against full table_width, ignoring already-allocated fixed-unit (cm/in/mm/pt) columns. Total column widths exceeded table_width.
**Fix**: Two-pass algorithm:
  - Pass 1: resolve fixed-unit columns, accumulate fixed_total
  - Pass 2: resolve % columns against (table_width - fixed_total) as pct_reference
**File**: src/kstfl/style_resolver.cpp
**Lesson**: Mixed fixed+percent column layouts require two-pass resolution. Fixed columns must be subtracted from the reference before resolving percentages.

## Bug 15: R cli Glue Expression Error in render_docx() (Mar 2026)
**Symptom**: Error in cli::cli_alert_success with inline `if` expression
**Root Cause**: cli glue context does not support inline R control flow (if/else)
**Fix**: Pre-compute page_label <- if (n_pages != 1L) "pages" else "page" before the cli call.
**File**: R/render_docx.R
**Lesson**: cli glue strings only support simple variable interpolation. Pre-compute any conditional values.

## General Lessons

### XmlWriter API Contract
- start_element() -> attribute() works -> end_element() closes
- self_closing_element() -> writes <X/> immediately -> attribute() THROWS
- NEVER call attribute() after self_closing_element()

### Pagination Architecture
- isGrouping: dedup + dynamic subtitles; does NOT force page breaks
- isPaging: forces page breaks on column value changes
- detect_grouping_boundaries() must run BEFORE apply_dedupe()

### Text Measurement Rules
- inner_width = cell_width - cell_margin_left - cell_margin_right - para_indent_left - para_indent_right
- Single words wider than inner_width: full_lines = word_width / inner_width, remainder = word_width % inner_width
- Always guard max() against empty vectors

### Column Width Resolution
- Fixed units (cm/in/mm/pt): resolve first, sum as fixed_total
- Percentages: resolve against (table_width - fixed_total)
- Unspecified: distribute remaining width equally

### OOXML Border Architecture
- Cell borders override table borders
- Structural borders must be applied as cell borders (no table-level bottom border in OOXML)
- Last row bottom border must be set on each cell explicitly

### R Call Object Patterns
- match.call(definition, call): properly maps positional args to named params
- Never use positional index on call_args() with optional args

### cli Package
- No inline if/else in glue strings
- Pre-compute conditional values before passing to cli_* functions
- Use {.path}, {.val}, {.file}, {.fn}, {.field} for styled output
