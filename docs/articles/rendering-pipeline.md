# Rendering Pipeline Diagram

![ksTFL logo](figures/ksTFL-logo.svg)

This document describes the internal C++ rendering pipeline that converts
TFL specifications into DOCX output.

## Pipeline Overview

```
┌──────────────────────────────────────────────────────────────┐
│  R Layer (rcpp_bindings.cpp)                                 │
│  render_docx_impl() / render_docx_from_strings_impl()       │
│  → Instantiates Renderer, sets config, calls render()       │
└────────────────────────┬─────────────────────────────────────┘
                         ▼
┌──────────────────────────────────────────────────────────────┐
│  RENDERER (renderer.cpp) — Pipeline Orchestrator             │
│                                                              │
│  Phase 1: Parse                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ parse_template_bundle() → TemplateBundle (default +     │ │
│  │                           per-spec StylesTemplates)     │ │
│  │ parse_spec_json_string() → TFLDocument (N specs)        │ │
│  │ For each spec.data_ref:                                 │ │
│  │   parse_data_json_string() → DataTable (col-oriented)   │ │
│  │ For Figure specs: resolve figure_path (png/jpg/svg)     │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  Phase 2: Initialize Fonts                                   │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ FontCache → add_font_dir() for each config_.font_dirs   │ │
│  │ TextMeasurer(font_cache)                                │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  Phase 3: Per-Spec Processing Loop                           │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ For each TFLSpec:                                       │ │
│  │                                                         │ │
│  │ 3a. Style Resolution                                    │ │
│  │  StyleResolver(template, spec_styles)                   │ │
│  │  → resolve_page_config() → PageConfig                   │ │
│  │  → resolve_table_width() → table_width                  │ │
│  │  → resolve_column_widths() → columns[].resolved_width   │ │
│  │                                                         │ │
│  │ 3b. Logical Table Construction                          │ │
│  │  LogicalTableBuilder::build(spec, data)                 │ │
│  │  ┌───────────────────────────────────────────────────┐  │ │
│  │  │ build_header_grid(spec)                           │  │ │
│  │  │  → stub rows (sorted by stubOrder desc)           │  │ │
│  │  │  → post-pass 1: promote lower stubs into gaps     │  │ │
│  │  │  → post-pass 2: fill remaining empty placeholders │  │ │
│  │  │  → post-pass 3: peel edge columns from spans      │  │ │
│  │  │  → label row (bottom, per-column labels)           │  │ │
│  │  │                                                   │  │ │
│  │  │ build_data_rows(spec, data)                       │  │ │
│  │  │  → for each data row: create LogicalRow with      │  │ │
│  │  │    cells (apply format, missings replacement)      │  │ │
│  │  │                                                   │  │ │
│  │  │ detect_grouping_boundaries(rows)                  │  │ │
│  │  │  → mark force_page_break at group value changes   │  │ │
│  │  │                                                   │  │ │
│  │  │ apply_dedupe(rows)                                │  │ │
│  │  │  → blank consecutive duplicate cell values        │  │ │
│  │  │                                                   │  │ │
│  │  │ apply_style_rows(rows, actions, cols, data)       │  │ │
│  │  │  → c_style: per-cell style_ref override           │  │ │
│  │  │  → c_clear: blank display text                    │  │ │
│  │  │  → c_merge: horizontal cell merge (gridSpan)      │  │ │
│  │  │  → c_glue: concatenate text to cells              │  │ │
│  │  │  → c_addrow: insert synthetic rows above/below    │  │ │
│  │  │  → c_pageBreak: force page break                  │  │ │
│  │  └───────────────────────────────────────────────────┘  │ │
│  │                                                         │ │
│  │ 3c. Measurement                                         │ │
│  │  ┌───────────────────────────────────────────────────┐  │ │
│  │  │ Measure header grid cells:                        │  │ │
│  │  │  → vMerge-aware 2-pass height distribution        │  │ │
│  │  │  → text_orientation stamp for label row            │  │ │
│  │  │                                                   │  │ │
│  │  │ TextMeasurer::measure_plain() for each cell:      │  │ │
│  │  │  → parse_inline_markup() → ParsedCell             │  │ │
│  │  │  → measure_cell() (HarfBuzz shaping per run)      │  │ │
│  │  │  → word-wrap simulation → height/width/lines      │  │ │
│  │  │  → rotated cell special path (btLr/tbRl)          │  │ │
│  │  └───────────────────────────────────────────────────┘  │ │
│  │                                                         │ │
│  │ 3d. Pagination                                          │ │
│  │  ┌───────────────────────────────────────────────────┐  │ │
│  │  │ Paginator::paginate(spec, rows, header_grid, ...) │  │ │
│  │  │  → build_segments() (isColBreak → horiz segments) │  │ │
│  │  │  → compute_row_heights() (all cols, once)         │  │ │
│  │  │  → compute static heights:                        │  │ │
│  │  │    header/footer sections, titles, subtitles,     │  │ │
│  │  │    table header, footnotes                        │  │ │
│  │  │  → vertical fill: rows → pages                    │  │ │
│  │  │    break on: overflow, force_page_break            │  │ │
│  │  │  → post-pass: LastPage footnote spill             │  │ │
│  │  │  → result: PaginationResult{ segments[], pages[]} │  │ │
│  │  └───────────────────────────────────────────────────┘  │ │
│  │                                                         │ │
│  │ 3e. Dedupe Value Restoration at Page Boundaries         │ │
│  │  → scan backward from each page boundary, restore      │ │
│  │    last non-blank value in dedupe columns               │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  Phase 4: Emit DOCX                                          │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ DocxEmitter::emit(doc, data, output, pages, rows, hdrs)│ │
│  │  → build_hdr_ftr_parts() → header/footer XML parts     │ │
│  │  → build_toc_heading_styles() → outline level styles    │ │
│  │  → emit_document_xml():                                 │ │
│  │    → TOC page (optional)                                │ │
│  │    → per-spec: section breaks, page interleaving        │ │
│  │      → emit_page(): titles, subtitles, table, footnotes │ │
│  │        → emit_table(): tblPr, tblGrid, header, rows     │ │
│  │          → emit_table_header(): vMerge, gridSpan         │ │
│  │          → emit_table_row(): cell style, content         │ │
│  │            → emit_paragraph() → parse_inline_markup()    │ │
│  │              → emit_parsed_paragraph_runs()              │ │
│  │                → emit_run_props() (w:rPr)                │ │
│  │  → emit_package(): ZIP assembly                          │ │
│  │    → [Content_Types].xml, _rels, document.xml            │ │
│  │    → styles.xml, settings.xml, fontTable.xml             │ │
│  │    → header/footer parts, media (figures)                │ │
│  └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

## Key Data Flow

```
JSON files → TFLDocument + DataTable + StylesTemplate
  → StyleResolver (8-level cascade)
  → LogicalTableBuilder (header grid + row stream)
  → TextMeasurer (HarfBuzz, deterministic)
  → Paginator (vertical + horizontal)
  → DocxEmitter (OOXML XML generation)
  → ZipWriter (DOCX archive)
```

## Style Resolution Cascade (8 levels)

```
1. Template default text style
2. Region style (tableHeader / tableBody / titles / etc.)
3. Template row defaults (header_row / body_row)
4. Structural styles (allHeaders / tableBody — non-overridable)
5. Column valueStyleRef / labelStyleRef
6. Row style action (from styleRows c_style)
7. Merge styleRef
8. AddRow styleRef
```
