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

## Bug 16: <sub> Tag Sets Wrong State (Mar 2026)
**Symptom**: Subscript text rendered as superscript
**Root Cause**: inline_parser.cpp switch case for `TagType::Sub` set `state.superscript = true` instead of `state.subscript = true`. A fragile trailing `if` block patched it, but was easy to accidentally remove.
**Fix**: Changed switch case to `state.subscript = true; state.superscript = false; break;` and removed the trailing `if` block.
**File**: src/kstfl/inline_parser.cpp
**Lesson**: Switch cases must be correct on their own; never rely on a post-switch patch for correctness.

## Bug 17: w:highlight Emits Hex Instead of OOXML Color Name (Mar 2026)
**Symptom**: Highlight color silently ignored by Word
**Root Cause**: `<w:highlight w:val="..."/>` requires one of 15 OOXML named colors (e.g. "yellow"), not a hex code. docx_emitter.cpp was emitting the raw hex string.
**Fix**: Replaced `<w:highlight>` with `<w:shd w:val="clear" w:color="auto" w:fill="HEX"/>` on the run, which accepts arbitrary hex colors.
**File**: src/kstfl/docx_emitter.cpp

## Bug 18: Row Heights Measured Twice with Different Code Paths (Mar 2026)
**Symptom**: Potential pagination discrepancy — renderer and paginator could disagree on row heights
**Root Cause**: renderer.cpp Phase 3c measured all body row heights and stored them in `row.measured_height`. Then `Paginator::compute_row_heights()` re-measured independently. Two separate code paths for the same data.
**Fix**: Removed the duplicate measurement loop from renderer.cpp. Changed `Paginator::paginate()` to take `std::vector<LogicalRow>&` (non-const) and store computed heights back into `row.measured_height` after `compute_row_heights()`. Paginator is now the single source of truth.
**Files**: src/kstfl/renderer.cpp, src/kstfl/paginator.cpp, src/kstfl/paginator.h

## Bug 19: snprintf Format String Validation Fragile (Mar 2026)
**Symptom**: Format like "displayed: %.2f" would match 'd' heuristic and cast to int (UB); malicious format strings could cause UB
**Root Cause**: Integer-format detection in `apply_column_format()` searched for 'd'/'i'/'u'/'x'/'o' anywhere in the format string — a substring match, not a specifier match.
**Fix**: Added `is_safe_numeric_format()` that validates format strings against a regex whitelist `%[flags][width][.precision][diuoxXfFeEgG]`. Unsafe formats return the value unchanged. Integer specifier detection now finds the actual conversion character (last match in the specifier set).
**File**: src/kstfl/logical_table.cpp
**Lesson**: Format string validation must match the actual conversion specifier, not any occurrence of a character.

## Bug 20: Ragged Column Data Silently Accepted (Mar 2026)
**Symptom**: Mismatched column lengths in data JSON produce incorrect table rendering with no error
**Fix**: Added post-parse validation in `parse_data_internal()` that emits `std::cerr` warning when any column length differs from `dt.n_rows`.
**File**: src/kstfl/json_parser.cpp

## Bug 21: doc_footer Pagination — Table Broken Across Too Many Pages (Mar 2026)
**Symptom**: With `set_document(footnotePlace = "doc_footer")`, tables broke prematurely; some pages had only 1–2 rows; footnotes repeated on every page.
**Root Cause**: `compute_available_height()` ignored `footer_section_height`. When footnotes go into Word footer part (`w:ftr`), footer content = footer rows + footnotes. If that exceeds (bottom_margin - footer_distance), Word pushes the body up; the paginator did not reserve that space.
**Fix**: In `compute_available_height()`, when `footer_section_height > (bottom_margin - footer_distance)`, subtract the overflow from available body height. Same for header overflow.
**File**: src/kstfl/paginator.cpp
**Lesson**: Header/footer content that overflows the margin area steals body space. Paginator must subtract overflow from available height.

## Bug 22: Rotated Header Text Wrapping in Cells (Mar 2026)
**Symptom**: Vertically rotated column headers (e.g. `labelStyleRef = "to_90"`) wrapped text inside the cell (e.g. "RPH-104 (N=16)" split across lines).
**Root Causes**: (1) docx_emitter did not emit `w:noWrap` in `w:tcPr` for rotated cells, so Word could wrap. (2) text_measurer for rotated cells did not include paragraph indents or paragraph spacing in required row height — row was too short when template had non-zero indents/spacing.
**Fix**: docx_emitter.cpp: for vertical text_orientation emit `<w:noWrap/>` in `w:tcPr`. text_measurer.cpp: for rotated path add `indent_left + indent_right` and `(spacing_before + spacing_after) * n_paras` to `required_height`.
**Files**: src/kstfl/docx_emitter.cpp, src/kstfl/text_measurer.cpp
**Lesson**: Rotated cell “height” is the text-flow width; Word subtracts paragraph indents and adds paragraph spacing. Measurement must include both so row height is sufficient.

## Build: pkgdown Without X11 and Without CRAN (Mar 2026)
**Symptom**: `pkgdown::build_site()` failed with (1) `png(...): unable to open connection to X11 display ''`, (2) `readRDS(con)` timeout on `cran.rstudio.com/.../packages.rds` in callr subprocess.
**Root Causes**: (1) knitr’s default figure device required X11. (2) downlit (used when building articles) calls `tools::CRAN_package_db()` → fetches packages.rds; in callr subprocess this times out when offline/firewalled.
**Fix**: .Rprofile: (1) `knitr::opts_chunk$set(dev = "cairo_png")` for headless figures. (2) Patch downlit’s memoised `CRAN_urls()`: get it via `utils::getFromNamespace("CRAN_urls", "downlit")`, replace environment’s `_f` with a function returning `data.frame(Package = character(0), URL = character(0))`, reset cache. Vignettes: add `dev = "cairo_png"` in setup; Reporting_Examples use `png(..., type = "cairo")`. README: document build and optional pkgdown.offline.
**Lesson**: For headless/CI pkgdown: use cairo device globally; to avoid CRAN fetch in subprocess, patch downlit in .Rprofile so the subprocess inherits the patch.

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

### OOXML Highlight / Shading
- `<w:highlight w:val="..."/>` requires one of 15 named OOXML colors — does NOT accept hex
- Use `<w:shd w:val="clear" w:color="auto" w:fill="RRGGBB"/>` on runs for arbitrary hex background colors

### XmlWriter comment() Safety
- `XmlWriter::comment()` sanitizes `--` → `- -` to prevent malformed XML comments
- Caller no longer needs to ensure absence of `--` in comment text

### Format String Safety
- `apply_column_format()` validates format strings via `is_safe_numeric_format()` regex before passing to snprintf
- Safe pattern: `%[flags][width][.precision][diuoxXfFeEgG]` with optional literal prefix/suffix
- Integer specifier detection uses last-character scan, not substring search

### Row Height Single Source of Truth
- `Paginator::paginate()` is the single source of truth for `row.measured_height`
- Do NOT add row height measurement in renderer.cpp — it will create a duplicate code path

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

### Rotated (Vertical) Text in Table Cells
- Row height for rotated cell = natural text width + indent_left + indent_right + (spacing_before + spacing_after) * n_paras + cell_margin_top + cell_margin_bottom
- Emit `w:noWrap` in `w:tcPr` when text_orientation is vertical so Word does not wrap
- Measurement uses max paragraph width across `<br>`-separated paragraphs; spacing/indents must be included

### pkgdown Build (Headless / Offline)
- Set `knitr::opts_chunk$set(dev = "cairo_png")` in .Rprofile so callr subprocess gets headless-safe figures
- Patch downlit `CRAN_urls()` in .Rprofile (replace inner `_f`, reset cache) to skip CRAN packages.rds fetch
- Vignette setup chunks: add `dev = "cairo_png"`; explicit `png()` use `type = "cairo"`
