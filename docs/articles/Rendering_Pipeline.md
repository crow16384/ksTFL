# Rendering Pipeline and Full C++ Architecture in ksTFL

This document describes the complete C++ renderer architecture used by
ksTFL to convert JSON report specifications into deterministic DOCX
output.

## 1. End-to-End Architecture

    R API
      -> src/rcpp_bindings.cpp
      -> kstfl::Renderer

    Renderer pipeline
      Parse -> Resolve -> Model -> Measure -> Paginate -> Emit -> Package

    Core modules
      json_parser.cpp      : spec/template/data parsing
      style_resolver.cpp   : style cascade + page/width resolution
      logical_table.cpp    : header grid + logical row stream + styleRows actions
      font_scanner.cpp     : system font discovery + fallback resolution
      text_measurer.cpp    : HarfBuzz-based deterministic measurement
      paginator.cpp        : vertical and horizontal pagination
      docx_*.cpp           : OOXML emission for document parts
      zip_writer.cpp       : DOCX ZIP packaging

## 2. C++ Module Map

### 2.1 Entry and orchestration

- src/rcpp_bindings.cpp
  - render_docx_impl()
  - render_docx_from_strings_impl()
- src/kstfl/renderer.cpp
  - Renderer::render()
  - Renderer::render_from_strings()

### 2.2 Parsing and schema model

- src/kstfl/json_parser.cpp
  - parse_spec_json_string()
  - parse_template_json_string()
  - parse_data_json_string()
- src/kstfl/types.h
  - Complete domain model (page config, styles, table model, pagination
    model)

### 2.3 Layout and table engine

- src/kstfl/style_resolver.cpp
  - resolve_page_config()
  - resolve_table_width()
  - resolve_column_widths()
  - style cascade resolution helpers
- src/kstfl/logical_table.cpp
  - LogicalTableBuilder::build()
  - build_header_grid(), build_data_rows()
  - apply_dedupe(), apply_style_rows(), detect_grouping_boundaries()

### 2.4 Font discovery, measurement, and pagination

- src/kstfl/font_scanner.cpp
  - Platform-specific system font directory enumeration
  - FreeType-based font family/style classification
  - Global font path map (populated once at package load)
  - Target font resolution with fallback assignment
- src/kstfl/font_cache.cpp
  - FreeType/HarfBuzz font loading + metrics cache
  - Dynamic font resolution via scanner’s global path map
- src/kstfl/text_measurer.cpp
  - TextMeasurer::measure_plain()
  - measure_cell() with wrapping, spacing, margins, orientation support
- src/kstfl/paginator.cpp
  - Paginator::paginate()
  - build_segments(), compute_available_height()
  - compute_row_heights(), compute_segment_row_heights()

### 2.5 DOCX emission and packaging

- src/kstfl/docx_emitter.cpp (top-level emission)
- src/kstfl/docx_document.cpp, docx_page.cpp, docx_table.cpp,
  docx_styles.cpp, docx_rels.cpp, docx_content_types.cpp,
  docx_media.cpp, docx_toc.cpp
- src/kstfl/xml_writer.cpp
- src/kstfl/zip_writer.cpp

## 3. Detailed Rendering Pipeline

    ┌───────────────────────────────────────────────────────────────────────┐
    │ Phase 1: Parse                                                        │
    │   parse_template_bundle()                                             │
    │   parse_spec_json_string() -> TFLDocument                             │
    │   parse_data_json_string()  -> DataTable                              │
    │   resolve figure media paths for Figure specs                         │
    │                                                                       │
    │ Phase 1b: Enforce isColBreak layout constraints                       │
    │   for specs with isColBreak columns: force                            │
    │   allow_row_break_across_pages=false, repeat_header_on_each_page=true │
    │   (warn if template values were overridden)                           │
    └───────────────────────────────────────────────────────────────────────┘

    ┌───────────────────────────────────────────────────────────────────────┐
    │ Phase 2: Initialize text subsystem                                    │
    │   FontCache: load configured font dirs and fallback font              │
    │   TextMeasurer(font_cache)                                            │
    └───────────────────────────────────────────────────────────────────────┘

    ┌───────────────────────────────────────────────────────────────────────┐
    │ Phase 3: Per-spec processing                                          │
    │                                                                       │
    │   3a) Resolve                                                         │
    │      StyleResolver(template, spec_styles)                             │
    │      resolve_page_config()                                            │
    │      resolve_table_width()                                            │
    │      resolve_column_widths()                                          │
    │                                                                       │
    │   3b) Model                                                           │
    │      LogicalTableBuilder::build()                                     │
    │      - header grid + vMerge metadata                                  │
    │      - logical data rows                                               │
    │      - styleRows actions (c_style, c_clear, c_merge, c_glue,          │
    │        c_addrow, c_pageBreak)                                         │
    │                                                                       │
    │   3c) Measure                                                         │
    │      Header rows: vMerge-aware 2-pass height balancing                │
    │      Body cells: TextMeasurer::measure_plain()                        │
    │      - inline markup parsing                                           │
    │      - HarfBuzz shaping                                                │
    │      - deterministic wrapping and line-height math                    │
    │                                                                       │
    │   3d) Paginate                                                        │
    │      Paginator::paginate()                                            │
    │      - build_segments(): split by isColBreak, repeat isID columns     │
    │      - compute_row_heights(): baseline full-table heights             │
    │      - compute_segment_column_widths(): segment width scaling          │
    │      - compute_segment_row_heights(): per-segment row heights         │
    │      - compute static blocks: titles/subtitles/header/footer/notes    │
    │      - vertical fill + LastPage footnote spill post-pass              │
    │                                                                       │
    │   3e) Dedupe restoration                                               │
    │      Restore deduped values at page boundaries                        │
    └───────────────────────────────────────────────────────────────────────┘

    ┌───────────────────────────────────────────────────────────────────────┐
    │ Phase 4: Emit and package DOCX                                        │
    │   DocxEmitter::emit()                                                  │
    │   - document.xml, styles.xml, rels, header/footer parts               │
    │   - page/section assembly, table/header/body emission                  │
    │   - optional TOC                                                       │
    │   ZipWriter: package all OOXML parts into .docx                       │
    └───────────────────────────────────────────────────────────────────────┘

## 4. Core Data Structures

Defined primarily in src/kstfl/types.h.

- Units and geometry
  - Length (EMU-based arithmetic)
  - PageConfig, Margins
- Style system
  - FontProps, ParagraphProps, TableCellProps
  - StyleDef, StylesTemplate
- Table model
  - ColumnSpec, StubColumn, TextGroup
  - LogicalCell, LogicalRow, HeaderGrid
- Pagination model
  - PageSlice
  - HorizontalSegment (column_indices, pages, row_heights)
  - PaginationResult

## 5. Text and Font Subsystem

- FontCache reads font metrics from OS/2 tables (fallback to hhea when
  needed) to match Word line-height behavior.
- TextMeasurer uses HarfBuzz shaping for run width and deterministic
  wrapping.
- Cell height includes:
  - paragraph spacing before/after
  - wrapped line heights
  - cell top/bottom margins
- Rotated text paths (btLr/tbRl) are handled explicitly.

## 6. Pagination Internals

- Vertical pagination budget is computed from usable page height minus:
  - safety margin
  - header/footer overflow into body
  - titles/subtitles
  - table header
  - reserved footnote space
- Horizontal segmentation:
  - isColBreak starts a new segment
  - isID columns are repeated in each segment
  - non-ID columns are scaled to fill available segment width
  - when isColBreak is active, the renderer enforces
    allow_row_break_across_pages=false and
    repeat_header_on_each_page=true (Phase 1b constraint enforcement,
    with R warning if values are overridden)
- Row height model:
  - baseline full-table row height is retained on LogicalRow
  - segment-specific row heights are computed and stored on each segment
  - DOCX row emission uses segment.row_heights for exact per-segment
    trHeight
- Warning behavior:
  - warning threshold compares against physical page body height
  - pagination still uses a safety margin for conservative fitting

## 7. Style Resolution Cascade

The renderer applies styles in this effective order (later layers
override earlier ones unless marked structural/non-overridable):

1.  Template default text style
2.  Region style (tableHeader, tableBody, titles, subtitles, footnotes)
3.  Template row defaults
4.  Structural styles (header/body structural constraints)
5.  Column labelStyleRef or valueStyleRef
6.  Row action style (styleRows c_style)
7.  Merge/action style overrides
8.  AddRow style overrides

## 8. R/C++ Integration

- Exported functions in src/rcpp_bindings.cpp
  - render_docx_impl(…)
  - render_docx_from_strings_impl(…)
- Registration in src/init.cpp and src/RcppExports.cpp.
- Error propagation uses RenderError and Rcpp::stop().

## 9. Build and Dependencies

- Language standard: C++20
- C++20 features used:
  - `operator<=>` (three-way comparison) for `Length`
  - Concepts (`Mergeable`) constraining style merge templates
  - `constexpr std::array` lookup tables for OOXML enum conversions
  - `std::ranges::sort`, `std::ranges::any_of`, `std::ranges::transform`
  - `using enum` in switch statements
  - `std::to_chars` for double formatting
  - `[[nodiscard]]` on all pure/value-returning functions
- Core dependencies:
  - HarfBuzz
  - FreeType2
  - minizip or minizip-ng
  - zlib
  - nlohmann/json (vendored)
  - Rcpp
- Build files:
  - src/Makevars
  - src/Makevars.win

## 10. Practical Trace (One Table Spec)

    spec json + data json + template json
      -> Renderer::render_from_strings()
      -> StyleResolver::resolve_*()
      -> LogicalTableBuilder::build()
      -> TextMeasurer::measure_plain()
      -> Paginator::paginate()
          -> segment row heights
      -> DocxEmitter::emit_table_row()
          -> exact trHeight from segment.row_heights
      -> ZipWriter::close()
      -> output.docx
