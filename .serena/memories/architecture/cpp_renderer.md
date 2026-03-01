# C++ Renderer Architecture

## Overview
Complete DOCX generation engine. Reads JSON spec + data from save_report(), produces .docx with deterministic pagination. Returns total page count to R.

## 6-Phase Rendering Pipeline (renderer.cpp)
1. **Parse**: spec JSON + template JSON + data JSONs (json_parser)
2. **Resolve**: merge styles, compute page geometry, resolve column widths (style_resolver)
3. **Model**: build logical table — header grid, row stream, styleRows expansion (logical_table)
4. **Measure**: HarfBuzz text shaping + cell height measurement (text_measurer, font_cache)
5. **Paginate**: deterministic vertical + horizontal pagination (paginator)
6. **Emit**: stream OOXML into .docx ZIP (docx_emitter, xml_writer, zip_writer)

## Entry Point: R → C++
1. R: render_docx() validates inputs, resolves paths
2. R: calls render_docx_impl() (rcpp_bindings.cpp) — returns int page count
3. C++: kstfl::Renderer::render() executes pipeline, returns size_t total_pages
4. Rcpp binding casts size_t → int and returns to R
5. R: captures n_pages, displays in cli_alert_success

## Module Responsibilities

### renderer.cpp/.h
- render() and render_from_strings() both return size_t (total page count)
- Accumulates total_pages across all specs: total_pages += kv.second.total_pages
- std::cerr log: "[ksTFL] Pages produced: N"
- Font path management, verbose logging

### json_parser.cpp/.h
- parse_spec(), parse_template(), parse_data()
- col_width_raw stored as string for deferred resolution
- Data file lookup: tries exact path, then path + ".json" fallback
- Structural borders (header_top, header_bottom, table_bottom) parsed via parse_border()

### style_resolver.cpp/.h
- merge_styles(), resolve_style(), compute_table_width()
- resolve_column_widths(): TWO-PASS ALGORITHM (Mar 2026 fix)
  - Pass 1: resolve fixed-unit columns (cm/in/mm/pt), accumulate fixed_total
  - Pass 2: resolve % columns against (table_width - fixed_total) as pct_reference
  - Remaining width distributed equally among unspecified columns
- resolve_base_header_style(): template cascade only

### logical_table.cpp/.h
- build(): DataTable + columns + styleRows → LogicalRow stream
- Header grid with VMergeState (None/Restart/Continue) for stub columns
- apply_column_format(): integer formats use static_cast<int>(double) to avoid UB
- detect_grouping_boundaries() runs BEFORE apply_dedupe()
- Only force_page_break triggers page breaks; is_group_boundary does not

### text_measurer.cpp/.h
- measure_text_width(): HarfBuzz shaping → EMU width
- measure_cell_height(): word-wrap with line/paragraph spacing
- inner_width = cell_width - cell_margin_left - cell_margin_right - para_indent_left - para_indent_right
- Character-level wrapping for single words wider than inner_width:
  full_lines = word_width.emu / inner_width.emu; remainder carried as current_line_width
- Handles inline markup via font property switching

### font_cache.cpp/.h
- scan_directories(), resolve_font()
- Fallback chain: requested → Arial → Liberation Sans → DejaVu Sans → Noto Sans → FreeSans
- System paths: /usr/share/fonts, /usr/local/share/fonts, ~/.fonts
- Bundled: inst/fonts/LiberationSans-*.ttf

### inline_parser.cpp/.h
- parse(): text → vector<TextRun>
- Markup: **bold**, *italic*, __underline__, ~~strikethrough~~

### paginator.cpp/.h
- paginate(): LogicalRow stream → vector<PageSlice>
- Vertical: accumulate row heights, break at page capacity
- force_page_break only (not is_group_boundary) triggers page breaks
- Oversized row warning (Mar 2026): if used_height.emu == 0 && rh > available:
  std::cerr << "[ksTFL] WARNING: Row N height (Xpt) exceeds available page body height (Ypt). The row will be split across pages by Word."
- Horizontal: split at isColBreak boundaries
- Dynamic subtitle values captured from first row of each page

### docx_emitter.cpp/.h (~1700 lines)
- emit_table(), emit_table_header(), emit_table_row(is_last_row), emit_cell_props()
- Last data row per page: structural.table_bottom_border applied to cell bottom borders
- Header cells: <w:vMerge w:val="restart"> or <w:vMerge/> for vertical merge
- emit_text_groups_combined(): all titles in single <w:p> with <w:br/> between groups
- emit_section_props(), emit_page(), emit_page_break()
- Header/footer: separate word/headerN.xml, word/footerN.xml parts
- xml:space="preserve" auto-added on <w:t>

### xml_writer.cpp/.h
- start_element() → start_tag_open_ = true → attribute() works → end_element()
- self_closing_element(): writes <X/> immediately, does NOT set start_tag_open_
- CRITICAL: NEVER call attribute() after self_closing_element()

### zip_writer.cpp/.h
- minizip wrapper, DEFLATE compression

### units.cpp/.h
- 1 inch = 914400 EMU, 1 pt = 12700 EMU, 1 cm = 360000 EMU
- Length::parse(): "12pt"/"1.5in"/"5%" → EMU

### types.h (~700 lines)
- All data structures: Length, Color, Border, FontProps, ParagraphProps, TableCellProps
- PageConfig, StylesTemplate, ColumnSpec, LogicalRow, PageSlice, etc.
- VMergeState: None, Restart, Continue
- TableStyleConfig::Structural: header_top_border, header_bottom_border, table_bottom_border

## Build Configuration
- CXX_STD = CXX20
- PKG_CPPFLAGS: -I./vendor + pkg-config for harfbuzz, freetype2, minizip
- PKG_LIBS: pkg-config --libs for harfbuzz, freetype2, minizip
- 15 source files compiled

## Template (KeyStat_default.json)
- Title: Courier New 9pt bold, center
- Subtitle: Courier New 9pt, left
- Footnotes: Arial 8pt italic, left
- Structural borders: header_top=1.5pt, header_bottom=1pt, table_bottom=1.5pt (single black)
- Header row: borders top=1.5pt, bottom=1pt; body row: all borders=none
- Cell margins: header 2pt left/right; body 2pt left, 1pt right
