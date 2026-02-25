# C++ Renderer Architecture

## Overview
The C++ renderer is a complete DOCX generation engine that reads the JSON spec + data produced by save_report() and produces submission-quality .docx files with deterministic pagination.

## 6-Phase Rendering Pipeline (renderer.cpp)
1. **Parse**: Read spec JSON, template JSON, data JSON files (json_parser)
2. **Resolve**: Merge template + spec styles; compute page geometry; resolve column widths (style_resolver)
3. **Model**: Build logical table — header grid, row stream, styleRows expansion (logical_table)
4. **Measure**: HarfBuzz text shaping + cell height measurement (text_measurer, font_cache)
5. **Paginate**: Deterministic vertical + horizontal pagination (paginator)
6. **Emit**: Stream OOXML into .docx ZIP package (docx_emitter, xml_writer, zip_writer)

## Module Responsibilities

### json_parser.cpp/.h
- parse_spec(): spec JSON → TFLSpec
- parse_template(): template JSON → StylesTemplate
- parse_data(): data JSON → DataTable
- Column width stored as raw string (col_width_raw) for deferred % resolution
- Data file lookup: tries exact path first, then path + ".json" extension fallback
- Structural borders (header_top, header_bottom, table_bottom) parsed via parse_border()

### style_resolver.cpp/.h
- merge_styles(): template defaults + spec styles → final StyleMap
- resolve_style(): lookup/merge style by ref (handles f_combine chains)
- resolve_column_widths(): parse col_width_raw with table_width EMU reference for percentage widths
- compute_table_width(): page width - margins = available table width
- resolve_base_header_style(): template cascade only (default → tableHeader → header_row → structural.allHeaders)

### logical_table.cpp/.h
- build(): DataTable + columns + styleRows → LogicalRow stream
- Build header grid from column labels + stub columns (spanning headers)
  - VMergeState tracking for vertical merge in multi-row headers
  - Uncovered columns get vMerge::Restart; label row marks them as vMerge::Continue
- apply_column_format(): numeric/integer snprintf formatting with proper type casting
  - Integer formats (%d/%i/%u/%x/%o): static_cast<int>(double) to avoid UB
- Expand styleRows actions into per-row modifications
- detect_grouping_boundaries(): runs BEFORE dedupe; sets is_group_boundary + force_page_break (isPaging only)
- Build order: header grid → data rows → detect boundaries → dedupe → styleRows → collect grouping indices

### text_measurer.cpp/.h
- measure_text_width(): HarfBuzz shaping → width in EMU
- measure_cell_height(): word-wrap calculation with line/paragraph spacing
- Handles inline markup (bold, italic, underline) via font property switching

### font_cache.cpp/.h
- scan_directories(): find .ttf/.otf files in given paths
- resolve_font(): family name + bold/italic → font file path
- Fallback chain: requested → Arial → Liberation Sans → DejaVu Sans → Noto Sans → FreeSans
- System paths searched: /usr/share/fonts, /usr/local/share/fonts, ~/.fonts
- Bundled fallback: inst/fonts/LiberationSans-*.ttf (4 variants)

### inline_parser.cpp/.h
- parse(): text → vector<TextRun>
- Supported markup: **bold**, *italic*, __underline__, ~~strikethrough~~
- TextRun carries text content + font overrides relative to base style

### paginator.cpp/.h
- paginate(): LogicalRow stream → vector<PageSlice>
- Vertical: accumulate row heights, break at page capacity; respect keep-together
- Only force_page_break triggers page breaks (set by isPaging column changes)
- is_group_boundary does NOT trigger page breaks (only for dedup/subtitle tracking)
- Horizontal: split at isColBreak boundaries when table exceeds page width
- Dynamic subtitle values captured from first row of each page

### docx_emitter.cpp/.h (~1550 lines)
Largest C++ file. Emits complete OOXML .docx package:
- Package parts: [Content_Types].xml, _rels/.rels, word/document.xml, word/styles.xml, word/settings.xml, word/fontTable.xml, word/_rels/document.xml.rels
- Header/footer parts: word/headerN.xml, word/footerN.xml (separate XML parts referenced via sectPr)
- Table: emit_table → emit_table_header + emit_table_row per row → emit_cell_props per cell
  - emit_table_row: is_last_row parameter for bottom border override
  - Last data row per page gets structural.table_bottom_border applied to cell borders
  - Header cells emit <w:vMerge> for vertical merge (Restart/Continue)
- Paragraphs: emit_paragraph → parse_inline_markup → emit_parsed_paragraph → emit_run_props
- Title/subtitle emission:
  - emit_text_groups(): each TextGroup = separate paragraph (used for subtitles, footnotes)
  - emit_text_groups_combined(): all TextGroups concatenated in single <w:p> with <w:br/> between groups
    - Each group retains per-group font style as separate runs
    - glue_prefix emitted as first run before title groups
- Sections: emit_section_props → page size, margins, header/footer references

### xml_writer.cpp/.h
Streaming XML writer with state tracking:
- start_element("X"): writes `<X`, sets start_tag_open_ = true
- attribute("a", "v"): writes ` a="v"`, REQUIRES start_tag_open_ == true
- end_element(): if start_tag_open_ emits `/>` (self-close), else `</X>`
- self_closing_element("X"): writes `<X/>` immediately, does NOT set start_tag_open_
- element_with_text(): auto-adds xml:space="preserve" for <w:t> elements
- CRITICAL RULE: Never call attribute() after self_closing_element()

### zip_writer.cpp/.h
minizip (classic) wrapper:
- create(): opens new ZIP file
- add_file(name, data): adds entry with DEFLATE compression
- close(): finalizes ZIP archive

### units.cpp/.h
EMU-based unit system:
- 1 inch = 914400 EMU, 1 pt = 12700 EMU, 1 cm = 360000 EMU
- Length::parse(): "12pt" → EMU, "1.5in" → EMU, "5%" → fraction of reference_emu

### types.h (~700 lines)
Key types:
- TableStyleConfig::Structural: all_headers, table_body (StyleDef), header_top_border, header_bottom_border, table_bottom_border (Border)
- VMergeState: None, Restart, Continue
- HeaderGridCell: label, col_span, row_span, width, style_ref, v_merge
- DocumentInfo: glue_prefix is bool (true = prefix glued to first title line)
- ColumnFormat: type, format_str (snprintf pattern), missings, col_width_raw

## Entry Point: R → C++
1. R: render_docx() validates inputs, resolves paths
2. R: calls render_docx_impl() (Rcpp binding in rcpp_bindings.cpp)
3. C++: creates kstfl::Renderer, configures fonts/template, calls render()
4. C++: Renderer::render() executes 6-phase pipeline
5. Result: .docx file written to output_path

## Build Configuration
- CXX_STD = CXX20
- PKG_CPPFLAGS: -I./vendor + pkg-config for harfbuzz, freetype2, minizip
- PKG_LIBS: pkg-config --libs for harfbuzz, freetype2, minizip
- 15 source files compiled: init, rcpp_bindings, RcppExports, + 12 kstfl/*.cpp

## Template (KeyStat_default.json)
- Title: Courier New 9pt bold, center-aligned
- Subtitle: Courier New 9pt, left-aligned
- Footnotes: Arial 8pt italic, left-aligned
- Table: center-aligned
- Structural borders: header_top=1.5pt, header_bottom=1pt, table_bottom=1.5pt (all single black)
- Header row: borders top=1.5pt, bottom=1pt; body row: all borders=none
- Body cells: table_bottom_border overrides bottom border on last data row per page
