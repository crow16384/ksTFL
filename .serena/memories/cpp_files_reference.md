# ksTFL — C++ Source Files Reference

All C++ sources live under `src/`. The rendering engine is in `src/kstfl/`. Everything is in the `kstfl` namespace. C++20.

---

## src/kstfl/types.h
**THE central type header.** All shared data structures. Include this everywhere.

### Primitive types
- `Length` — measurement with `.emu` storage; constructed via `from_emu/twips/pt/cm/in()`; operators: `+`, `-`, `*`, `/`, `<=>`
- `Color` — hex string wrapper; `Color::parse()`, `.empty()`, `==`, `!=`
- `PAGE_SAFETY_MARGIN` — constant `Length`
- Interface `Mergeable<T>` — constraint for `merged_with()` / `merge_from()` / `operator==`

### Enums
- `BorderLineStyle` — None, Single, Double, Dashed, Dotted, Thick, DashSmallGap, DotDash, DotDotDash, Triple, ThinThickSmallGap, ThickThinSmallGap, Wave
- `Alignment` — Left, Center, Right, Justify
- `VerticalAlignment` — Top, Center, Bottom
- `TextOrientation` — Horizontal, BottomToTop, TopToBottom
- `PageSize` — A4, A3, Letter, Legal, Executive
- `Orientation` — Portrait, Landscape
- `DocType` — Table, Figure, Text
- `FootnotePlace` — DocFooter, Repeated, LastPage
- `LogicalRowType` — DataRow, SyntheticRow, GroupBreak
- `VMergeState` — None, Restart, Continue
- Free functions: `border_line_style_to_ooxml()`, `alignment_to_ooxml()`

### Style property structs (all Mergeable)
- `Border` — color, width, line_style
- `Borders` — top, bottom, left, right, insideH, insideV
- `FontProps` — font_name, font_size, bold, italic, underline, strikethrough, color, highlight
- `SpacingProps` — before, after, line_spacing_multiplier, exact_line_height
- `IndentProps` — left, right, first_line, hanging
- `ParagraphProps` — alignment, spacing, indents, widow_control, keep_next, keep_lines, outline_level, borders
- `TableCellProps` — background_color, borders, cell_margin_*, vertical_alignment, text_orientation, row_height

### Style definition
- `StyleDef` — id, font, paragraph, table_style (all Mergeable)
- `StyleMap` — alias for style lookup map

### Page / document
- `PageMargins` — top, bottom, left, right, header_distance, footer_distance
- `PageMarginsOverride` — optional override (same fields)
- `PageConfigOverride` — size + orientation override
- `PageConfig` — size, orientation, margins; `.page_width()`, `.page_height()`, `.usable_width()`, `.usable_height()`
- `TableStyleConfig` — header_row, body_row, table_alignment, empty lines, borders, row-break/repeat-header flags, default cell margins, `Structural` nested struct
- `TextStyles` — named StyleDef refs for all text contexts (default_style, doc_header/footer, titles, subtitles, footnotes, table_header/body, toc_title/entry, figure_caption)
- `FigureStyleConfig` — alignment, space_before/after, caption_position, caption_text_style_ref
- `StylesTemplate` — page, text_styles, table_style, figure_style, widow_control

### Column / data
- `ColumnFormat` — type, format string, missings, col_width_raw, value_style_ref
- `ColumnSpec` — id, label, col_order, is_visible, is_id, is_grouping, is_col_break, dedupe, is_paging, format, label_style_ref, resolved_width
- `StubColumn` — label, stub_order, cols, label_style_ref, resolved_width
- `DataTable` — col_names, columns (vector of vector<string>), n_rows; `.col(name)`

### Row actions
- `StyleAction` — cols, style_ref
- `MergeAction` — cols, style_ref
- `AddRowAction` — pos (Before/After), value_from, style_ref
- `PageBreakAction` — sentinel
- `ClearAction` — cols
- `GlueAction` — cols, position, glue_col, text, separator
- `RowActionSet` — aggregates all action types; `.empty()`

### Document structure
- `TextGroup` — text, order, style_refs, body_placement, toc_level
- `HeaderFooterRow` — left, center, right, order, style_ref
- `DocumentInfo` — doc_type, has_data, glue_num_type, doc_order, is_continues, content_width_raw, footnote_place, top/bottom_empty_line
- `FigureInfo` — width, height, scale_mode, device
- `TFLSpec` — key, document, page_override, margin_overrides, spec_styles, headers, footers, stub_columns, columns, style_rows, titles, subtitles, footnotes, body_text, data_ref, figure_path, figure
- `ReportMetadata` — out_dir, doc_file_name, datetime, insert_toc, toc_title
- `TFLDocument` — metadata + specs vector
- `RendererConfig` — data_values_preformatted, font_dirs, fallback_font_path, use_field_codes, verbose

### Layout types
- `LogicalCell` — text, col_id, is_merged, is_merge_leader, merge_span, merged_width, style_refs, is_deduped
- `LogicalRow` — type, source_index, cells, row_style_ref, force_page_break, is_group_boundary, is_oversized, capped_height, group_values, measured_height
- `HeaderGridCell` — label, col_span, row_span, width, style_ref, v_merge, text_orientation, source_col_index
- `HeaderGrid` — rows, total_height, row_heights
- `PageSlice` — page_number, first/last_row, is_first/last_page, has_titles/subtitles/footnotes, dynamic_subtitle_values, height breakdowns
- `HorizontalSegment` — segment_index, column_indices, pages, row_heights
- `PaginationResult` — segments, total_pages

### Inline markup types
- `InlineRunStyle` — bold/italic/underline/strikethrough overrides, superscript, subscript
- `TextRun` — text, style
- `ParsedParagraph` — runs
- `ParsedCell` — paragraphs

---

## src/kstfl/renderer.h / renderer.cpp
Main orchestrator class.

**`Renderer`:**
- `add_default_font_paths()` — scans system font dirs
- `add_font_path(path)` — add extra directory
- `set_fallback_font(path)` — path to Liberation Sans
- `set_config(RendererConfig)` — configure renderer
- `render(spec_json_path, template_json_path, output_path)` → total pages
- `render_from_strings(spec_json, template_json, output_path, data_dir)` → total pages

---

## src/kstfl/logical_table.h / logical_table.cpp
Builds the logical table model from parsed spec data.

**`LogicalTableBuilder`:**
- `build(spec, data, template, resolver, measurer)` → `Result`
- `Result` — header_grid, data_rows, col_idx_map
- `build_header_grid()` — builds span/merge grid from stub/column specs
- `build_data_rows()` — materializes data into LogicalRow/LogicalCell
- `apply_dedupe()` — suppresses repeated values per column
- `apply_style_rows()` — applies RowActionSet conditions
- `detect_grouping_boundaries()` — marks group break rows
- `is_safe_numeric_format()` — validates printf-style format strings

---

## src/kstfl/paginator.h / paginator.cpp
Splits table into `PageSlice` / `HorizontalSegment` sets.

**`Paginator`:**
- `paginate(spec, logical_rows, header_grid, page_config, template, resolver, measurer)` → `PaginationResult`
- `build_segments()` — horizontal column grouping (col-break columns)
- `compute_available_height()` — usable body height per page
- `compute_row_heights()` — measures all rows via TextMeasurer
- `compute_segment_column_widths()` — per-segment visible widths
- `compute_segment_row_heights()` — row heights per horizontal segment

---

## src/kstfl/style_resolver.h / style_resolver.cpp
Resolves final `StyleDef` for any context by merging template + spec styles.

**`StyleResolver`:**
- Constructed with `StylesTemplate` + spec `StyleMap`
- `resolve_page_config(spec)` → `PageConfig`
- `resolve_table_width(spec, page_config)` → `Length`
- `resolve_column_widths(spec, page_config)` → widths vector
- `resolve_header_cell_style(col_spec, resolver)` → `StyleDef`
- `resolve_body_cell_style(col_spec, row_style_ref, spec)` → `StyleDef`
- `resolve_title_style / subtitle / footnote / doc_header / doc_footer / body_text / toc_title / toc_entry / figure_caption()` — named text style resolvers
- `find_style(id, spec_styles, tmpl)` — lookup in spec then template
- `apply_style_ref(base, ref, spec_styles, tmpl)` → merged `StyleDef`
- `resolve_content_style(...)` → general resolver

---

## src/kstfl/docx_emitter.h / docx_emitter.cpp
Emits OOXML content for a complete multi-spec document.

**`DocxEmitter`:**
- `emit(document, all_templates, config, measurer)` - main entry
- `build_hdr_ftr_parts()` — builds header/footer XML parts per spec
- `emit_document_xml()` — writes `word/document.xml`
- `emit_page(slice, spec, ...)` — emits one page slice to XML
- `emit_table() / emit_table_header() / emit_table_row()` — table XML
- `emit_paragraph() / emit_parsed_paragraph() / emit_run_props() / emit_para_props() / emit_cell_props()` — paragraph/run level
- `emit_text_groups() / emit_text_groups_combined()` — titles/subtitles/footnotes
- `emit_header_footer_section()` — doc header/footer
- `emit_figure_drawing()` — inline EMF/image
- `emit_section_props()` — `<w:sectPr>` per page
- `emit_page_field() / emit_numpages_field()` — field codes
- `emit_toc_page()` — TOC page
- `emit_styles() / emit_settings() / emit_font_table()` — document styles parts
- `stamp_exact_line_height()` — post-processing pass for exact heights
- Helpers: `HdrFtrPartInfo`, `TocHeadingEntry`, `SpecHdrFtrRefs`, `find_toc_heading_style_id()`

---

## src/kstfl/inline_parser.h / inline_parser.cpp
Parses inline HTML-like markup tags into `ParsedCell`.

**Functions (all `kstfl::`):**
- `parse_inline_markup(text)` → `ParsedCell`
- `has_inline_markup(text)` → bool
- `get_plain_text(parsed_cell)` → plain string
- Supported tags: `<b>`, `<i>`, `<u>`, `<s>` (strike), `<sup>`, `<sub>`, `<br>`, `<p>`

---

## src/kstfl/text_measurer.h / text_measurer.cpp
HarfBuzz + FreeType-based deterministic text measurement.

**`MeasuredText`:** width, height, line_count
**`TextMeasurer`:**
- `measure_cell(parsed_cell, font, width, ...)` → `MeasuredText`
- `measure_plain(text, font, width)` → `MeasuredText`
- `measure_run_width(runs, font)` → `Length`
- `line_height(font)` → `Length`
- `effective_font_size(font)` → pt value
- Internal: `cache_` (measurement cache), `hb_buf_` (HarfBuzz buffer)

---

## src/kstfl/font_cache.h / font_cache.cpp
FreeType + HarfBuzz font face cache.

**Types:** `FaceKey` (name, bold, italic), `FaceKeyHash`, `CachedFace` (ft_face, hb_font, file_path), `FontMetrics` (ascent, descent, line_height, units_per_em), `MetricsKey`, `MetricsKeyHash`
**`FontCache`:**
- `add_font_dir(path)` — index fonts in directory
- `get_face(name, bold, italic)` → `CachedFace*`
- `get_metrics(name, bold, italic, size_pt)` → `FontMetrics`
- `get_hb_font(name, bold, italic)` → `hb_font_t*`
- `find_font_file(name, bold, italic)` → path string
- `load_face(key)` — internal face loader

---

## src/kstfl/font_scanner.h / font_scanner.cpp
System font directory scanning and font registry management.

**Types:** `FontPathMap` (name → path map), `FontResolution` (target, resolved_family, resolved_path, is_fallback), `FontScanReport` (resolutions, dirs_scanned)
**Functions:**
- `get_system_font_dirs()` — returns platform font dirs (macOS: /System/Library/Fonts etc.)
- `initialize_font_registry(dirs, fallback_path)` — scans and caches fonts
- `get_font_path_map()` — returns current registry map
- `get_all_font_dirs()` — all scanned directories
- `get_fallback_family()` — name of fallback font (Liberation Sans)

---

## src/kstfl/xml_writer.h / xml_writer.cpp
Streaming XML builder with proper escaping and tag-stack validation.

**`XmlWriter`:**
- `write_declaration()`, `start_element(tag)`, `end_element()`, `self_closing_element(tag)`
- `attribute(name, value)` — string or numeric
- `text(content)` — escaped text content
- `raw(content)` — raw unescaped content
- `comment(text)`, `namespace_decl(prefix, uri)`
- Convenience: `element_with_text(tag, text)`, `element_with_attr(tag, attr, val)`
- `str()` / `take()` / `clear()` / `depth()`
- Internal: `close_start_tag()`, `escape_text_into()`, `escape_attr_into()`

---

## src/kstfl/zip_writer.h / zip_writer.cpp
Wraps libzip to produce `.docx`-compatible ZIP archives.

**`ZipWriter`:**
- `add_entry(path, content_string)` — add text entry
- `add_binary_entry(path, bytes)` — add binary entry
- `add_file(path, source_path)` — add from disk
- `close()` — finalize and close the zip

---

## src/kstfl/docx_packager.cpp
Assembles the final DOCX ZIP from all emitted XML parts. No header — internal only.

---

## src/kstfl/docx_layout.cpp
Column width and table geometry calculations. No header — internal only.

---

## src/kstfl/docx_table.cpp
Table-level XML emission helpers. No header — internal.

---

## src/kstfl/docx_sections.cpp
Section/page properties XML. No header — internal.

---

## src/kstfl/docx_metadata.cpp
Core properties (app.xml, core.xml) XML. No header — internal.

---

## src/kstfl/docx_document.cpp
`word/document.xml` top-level structure. No header — internal.

---

## src/kstfl/docx_content.cpp
Body content XML (paragraphs, runs, figures). No header — internal.

---

## src/kstfl/docx_drawing.cpp
Drawing/image embedding XML (`<w:drawing>`). No header — internal.

---

## src/kstfl/docx_styles.cpp
`word/styles.xml` emission. No header — internal.

---

## src/kstfl/docx_page.cpp
Page break and section XML helpers. No header — internal.

---

## src/kstfl/docx_toc.cpp
Table of contents XML (`<w:sdt>` TOC field). No header — internal.

---

## src/kstfl/style_types.cpp
Implementations for style type helpers (merge logic, etc.). No header — internal.

---

## src/kstfl/units.h / units.cpp
Unit conversion utilities (`Length` method implementations).

---

## src/kstfl/json_parser.h / json_parser.cpp
JSON parsing for spec and template files.

---

## src/rcpp_bindings.cpp
Rcpp entry points — do not edit without updating `RcppExports.cpp` + `init.cpp`.

**Functions (callable from R via `RcppExports.R`):**
- `render_docx_impl(spec_json_path, template_json_path, output_path, font_dirs, fallback_font_path, data_values_preformatted, use_field_codes, verbose)` → int (pages)
- `render_docx_from_strings_impl(spec_json, template_json, output_path, data_dir, font_dirs, ...)` → int
- `init_font_registry_impl(font_dirs, fallback_font_path)` — initialize registry
- `get_font_dirs_impl()` → CharacterVector of scanned dirs

---

## src/cpp_tests.cpp
C++ unit test runner invokable from R.

**R-callable:** `cpp_test_units()`, `cpp_test_inline_parser()`, `cpp_test_xml_writer()`, `cpp_test_format_validator()`
- Uses `kstfl` namespace directly
- `TestResult` class used internally

**Wiring requirement:** Any new test function must be added to:
1. `src/cpp_tests.cpp`
2. `src/RcppExports.cpp`
3. `src/init.cpp`
4. `R/RcppExports.R`
5. `tests/testthat/test-18-cpp-units.R`
