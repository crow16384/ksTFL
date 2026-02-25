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

### style_resolver.cpp/.h
- merge_styles(): template defaults + spec styles → final StyleMap
- resolve_style(): lookup/merge style by ref (handles f_combine chains)
- resolve_column_widths(): parse col_width_raw with table_width EMU reference for percentage widths
- compute_table_width(): page width - margins = available table width

### logical_table.cpp/.h
- build(): DataTable + columns + styleRows → LogicalRow stream
- Build header grid from column labels + stub columns (spanning headers)
- Expand styleRows actions into per-row modifications:
  - c_style → per-cell style overrides
  - c_merge → horizontal cell merges
  - c_addrow → insert synthetic rows above/below data rows
  - c_pageBreak → insert page break markers

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
- Vertical: accumulate row heights, break at page capacity; respect keep-together, isPaging headers
- Horizontal: split at isColBreak boundaries when table exceeds page width
- Each PageSlice has: column subset, row indices, continuation flags

### docx_emitter.cpp/.h (~1700 lines)
Largest C++ file. Emits complete OOXML .docx package:
- Package parts: [Content_Types].xml, _rels/.rels, word/document.xml, word/styles.xml, word/settings.xml, word/fontTable.xml, word/_rels/document.xml.rels
- Table: emit_table → emit_table_header + emit_table_row per row → emit_cell_props per cell
- Paragraphs: emit_paragraph → emit_run_props + text content
- Sections: emit_section_props → page size, margins, header/footer references
- Multi-page documents: each PageSlice becomes a section with appropriate section properties

### xml_writer.cpp/.h
Streaming XML writer with state tracking:
- start_element("X"): writes `<X`, sets start_tag_open_ = true
- attribute("a", "v"): writes ` a="v"`, REQUIRES start_tag_open_ == true
- end_element(): if start_tag_open_ emits `/>` (self-close), else `</X>`
- self_closing_element("X"): writes `<X/>` immediately, does NOT set start_tag_open_
- CRITICAL RULE: Never call attribute() after self_closing_element() — use start_element() + attribute() + end_element() instead

### zip_writer.cpp/.h
minizip (classic) wrapper:
- create(): opens new ZIP file
- add_file(name, data): adds entry with DEFLATE compression
- close(): finalizes ZIP archive

### units.cpp/.h
EMU-based unit system:
- 1 inch = 914400 EMU
- 1 pt = 12700 EMU
- 1 cm = 360000 EMU
- Length::parse(): "12pt" → EMU, "1.5in" → EMU, "5%" → fraction of reference_emu

### types.h (~650 lines)
All data structures in kstfl namespace. Key types:
- Length: EMU value + parse from string
- Color: hex string
- StyleDef: font + paragraph + table_style props
- ColumnSpec: name, label, format, style refs, visibility, ordering
- TFLSpec: complete document specification (document, columns, styles, content, styleRows)
- RendererConfig: verbose, font_dirs, fallback_font, template_path
- LogicalRow/LogicalCell: row stream for pagination
- PageSlice/HorizontalSegment: pagination output

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
