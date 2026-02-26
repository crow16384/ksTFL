# File Structure and Responsibilities

## R/ Source Files (14 files)

### constants.R (~474 lines)
Central constants repository. Contains:
- .const_empty_spec: template for new TFL_spec objects
- Enum values: font names, alignment, line styles, vertical alignment, text orientation, page sizes, column types, doc types
- .const_color_hex_map: 40+ color name -> hex mappings
- Validation regex patterns: font_size, hex color, spacing, indents, margins, border width, row/col/content width
- .const_schema_properties: allowed properties per schema type (font, paragraph, column, document etc)
- .const_modifier_paths: style modifier class -> schema path mapping
- Default values: page size, orientation, template, format strings, missing value
- .const_options_styles: 30+ predefined clinical styles (font_bold, text_center, cell_highlight_*, indent_*, etc.)
- Package-level caches: .schema_cache, .style_resolution_cache, .format_spec_cache

### spec_init.R (~605 lines)
Spec initialization. Contains:
- .tfl_init(): internal initializer for all 3 docTypes with validation
- .fill_spec_defaults(): populates spec from package settings
- .init_column_specs(): auto-detects column formats from data
- .get_col_label(): extracts label attribute from column
- .coerce_unknown_type(): handles unknown column classes
- create_table(), create_text(), create_figure(): exported user wrappers

### spec_context.R (~2975 lines) - LARGEST FILE
Style system, content functions, column definitions. Contains:
- Context system: .set_context(), .clear_context(), .assert_context() with stack-based nesting
- Validation: .validate_params(), .validate_enum(), .validate_pattern(), .validate_color(), .normalize_color()
- Internal spec builders: .font_spec(), .spacing_spec(), .indents_spec(), .paragraph_spec(), .border_spec(), .borders_spec(), .table_style_spec(), .margins_spec(), .page_spec(), .col_format_spec()
- Exported style functions: s_font(), s_spacing(), s_indents(), s_paragraph(), s_border(), s_borders(), s_table_style(), p_margins(), p_page()
- add_style(): S3 generic with TFL_spec, TFL_options, default methods
- f_combine(): style combination helper
- define_cols(): column property definition with tidyselect, vectorized params
- Content: add_title(), add_subtitle(), add_footnote(), add_body_text() (S3), add_header() (S3), add_footer() (S3)
- add_span_header(): spanning column headers
- set_document(), set_page_style(): document configuration (S3 for spec/options)

### env_eval_helpers.R (~524 lines)
Data environment and evaluation. Contains:
- .create_data_env(): creates 3-layer environment (functions, data __data__, mask __mask__)
- .get_data_columns(), .get_data_column_names(): tidyselect wrappers
- .env_eval(): evaluate expression in data env
- Helper functions for compute_cols: .eval_change_of(), .eval_firstOf(), .eval_lastOf(), .eval_firstRow(), .eval_lastRow(), .group_by_nth(), .eval_get_names(), .eval_row_numbers(), .eval_every_nth(), .eval_in_env()

### rowstyle_actions.R (~980 lines)
Conditional row styling. Contains:
- compute_cols(): exported - captures condition + actions as quosures
- c_style(), c_merge(), c_addrow(), c_pageBreak(): action builders
- .finalize_compute_cols(): evaluates all captured conditions/actions during create_report()
- Action parsers: .parse_action_style(), .parse_action_merge(), .parse_action_addrow()
  - .parse_action_addrow() uses match.call() for robust named+positional argument resolution
- Action appenders: .append_style_action(), .append_merge_action(), .append_addrow_action(), .append_pagebreak_action()
- Sanitization: .sanitize_row_actions(), .check_merge_overlap(), .combine_column_styles()
- .build_stylerows_list(): converts row actions to serializable format

### create_report.R (~570 lines)
Report assembly. Contains:
- ._consolidate_styles_in_spec(): 2-pass style consolidation (collect refs + replace combos)
- create_report(): 6-phase pipeline (flatten, validate keys, finalize compute_cols, consolidate styles, renumber docOrder, build result)

### report_writer.R (~360 lines)
Serialization to disk. Contains:
- .remove_nulls_recursive(): cleans up NULLs before JSON export
- save_report(): validates, serializes, writes JSON + data files
- .save_table_data(): extracts and saves table data as JSON
- .save_figure_file(): copies figure files

### render_docx.R (137 lines)
R wrapper for C++ renderer. Contains:
- render_docx(): exported function — validates inputs, resolves template/font paths, calls C++ render_docx_impl()
- Default template: inst/templates/KeyStat_default.json
- Default fallback font: inst/fonts/LiberationSans-Regular.ttf

### schema_serialize.R (~1141 lines)
Schema-driven validation and JSON preparation. Contains:
- .load_schema(), .clear_schema_cache(), .get_schema_file_path(): schema loading
- .build_json_pointer(), .resolve_refs(): JSON pointer resolution
- .resolve_allOf(): allOf combinator merging
- .serialize_json_internal(), .fix_types(): schema-aware type coercion
- .protect_arrays(): ensures arrays serialize correctly
- serialize_spec(): main entry point for schema validation + JSON export

### pkg_settings.R (~291 lines)
Package options management. Contains:
- .options_env: environment storing defaults and current settings
- tfl_get_options(), tfl_get_option(): read options
- tfl_set_options(): update options (handles S3 objects like add_header, add_style)
- tfl_reset_options(): restore defaults

### utility_functions.R (~770 lines)
General utilities. Contains:
- .is_scalar_atomic(), .is_readable_file(), .is_readable_dir()
- .merge_recursive(): list merging with modifyList(keep.null=TRUE)
- .auto_id(): unique ID generation
- .generate_hash(): deterministic hash via digest
- .guess_table_layout(): auto column format detection
- .parse_colwidth(), .validate_colwidth_minimum(), .validate_relative_colwidth()
- .recalculate_col_widths(): auto width redistribution
- .unclass_recursive(): strip classes recursively
- max_line_width(): handles empty strings (returns 0L for empty input)

### ksTFL.R
Package-level docs, .onLoad(), .onAttach(), .onUnload()

### spec_print.R
print.TFL_spec(): console + HTML viewer rendering

### RcppExports.R
Auto-generated Rcpp bindings. Contains:
- render_docx_impl(): R-side stub for C++ renderer
- cpp_test_units(), cpp_test_inline_parser(), cpp_test_xml_writer(): @keywords internal stubs calling .Call(`_ksTFL_*`)

## src/ — C++ Renderer Engine

### Build System
- src/Makevars: CXX_STD=CXX20, links HarfBuzz/FreeType/minizip via pkg-config
- src/Makevars.win: Windows build variant
- src/vendor/nlohmann/: vendored nlohmann/json v3.11.3 (header-only)

### Rcpp Binding Files
- src/init.cpp: R_init_ksTFL with CallEntries registration (includes 3 cpp_test_* entries)
- src/rcpp_bindings.cpp: render_docx_impl() Rcpp function — bridges R args to kstfl::Renderer::render()
- src/RcppExports.cpp: auto-generated Rcpp exports (includes cpp_test_* wrappers)
- src/cpp_tests.cpp: C++ unit test suites — TestResult harness + 3 Rcpp-exported runners (~440 lines, ~135 assertions total):
  - cpp_test_units(): 60+ assertions — parse_length all units+errors, Color::parse, emu/pt/twips conversions, page_size_dimensions×5, Length arithmetic, border_line_style_to_ooxml, alignment_to_ooxml
  - cpp_test_inline_parser(): 35+ assertions — all inline tags (b/i/u/sup/sub), nesting, br/p, case-insensitivity, unknown tag passthrough
  - cpp_test_xml_writer(): 40+ assertions — declaration, elements, attrs, text escaping, raw/comment/namespace_decl, clear/take/depth, error conditions

### Core Renderer (src/kstfl/) — 12 modules

**types.h** (~650 lines) — All data structures:
- Length (EMU-based with pt/in/cm/mm/% parsing), Color, Border, Borders
- FontProps, SpacingProps, IndentProps, ParagraphProps, TableCellProps
- StyleDef, StyleMap (unordered_map<string, StyleDef>)
- PageConfig, PageMargins, TableStyleConfig, StylesTemplate
- ColumnSpec, ColumnFormat (col_width_raw for deferred % resolution), StubColumn
- TextGroup, HeaderFooterRow, DataTable
- StyleAction, MergeAction, AddRowAction, PageBreakAction, RowActionSet
- DocumentInfo, TFLSpec, ReportMetadata, TFLDocument, RendererConfig
- LogicalCell, LogicalRow, LogicalRowType, HeaderGrid, HeaderGridCell
- PageSlice, HorizontalSegment

**renderer.cpp/.h** — Main orchestrator:
- Renderer::render(): 6-phase pipeline (parse → resolve → model → measure → paginate → emit)
- Font path management, config, verbose logging

**json_parser.cpp/.h** — JSON → C++ types:
- Parses spec JSON, template JSON, data JSON files
- Handles all type mappings (enums, optionals, color parsing)
- Stores raw column width strings for deferred resolution

**style_resolver.cpp/.h** — Style merging and resolution:
- Merges template defaults with spec styles
- resolve_column_widths(): parses col_width_raw with table_width reference for %
- Resolves styleRef chains into concrete StyleDef objects

**logical_table.cpp/.h** — Table model builder:
- Builds header grid from column labels + stub columns (spanning headers)
- Expands styleRows actions (c_style, c_merge, c_addrow, c_pageBreak)
- Produces LogicalRow stream (header rows, data rows, addrow inserts, page breaks)

**text_measurer.cpp/.h** — HarfBuzz text measurement:
- measure_text_width(): shapes text with HarfBuzz, returns width in EMU
- measure_cell_height(): calculates wrapped cell height (word wrap, line spacing)
- Handles inline markup and font fallback

**font_cache.cpp/.h** — Font management:
- Scans directories for .ttf/.otf fonts
- Maps font family + bold/italic to file path
- Fallback chain: requested → Arial → Liberation Sans → DejaVu Sans → Noto Sans → FreeSans

**inline_parser.cpp/.h** — Inline markup parser:
- Parses inline markup in text: **bold**, *italic*, __underline__, ~~strikethrough~~
- Produces TextRun segments with font property overrides

**paginator.cpp/.h** — Deterministic pagination:
- Vertical pagination: fills pages respecting row heights, page breaks, keep-together
- Horizontal pagination: splits wide tables at isColBreak column boundaries
- Produces PageSlice objects with column subsets

**docx_emitter.cpp/.h** (~1700 lines) — OOXML generation:
- Emits complete .docx package parts: [Content_Types].xml, _rels/.rels, word/document.xml, styles.xml, settings.xml, fontTable.xml, word/_rels/document.xml.rels
- Table emission: emit_table(), emit_table_header(), emit_table_row(), emit_cell_props()
- Text emission: emit_paragraph(), emit_parsed_paragraph(), emit_text_groups(), emit_run_props(), emit_para_props()
- Page layout: emit_section_props(), emit_page(), emit_page_break()
- Headers/footers: emit_header_footer_section(), emit_page_field(), emit_numpages_field()
- Writes via XmlWriter → ZipWriter

**xml_writer.cpp/.h** — Streaming XML writer:
- start_element(): writes `<X` and sets start_tag_open_ = true
- attribute(): requires start_tag_open_ == true, writes ` attr="val"`
- end_element(): auto-emits `/>` when start_tag_open_ (no content), else `</X>`
- self_closing_element(): writes `<X/>` immediately, does NOT set start_tag_open_
- CRITICAL: Never call attribute() after self_closing_element() — always use start_element()

**zip_writer.cpp/.h** — minizip wrapper:
- Creates .docx (ZIP) package
- add_file(): adds entry with content bytes
- Handles DEFLATE compression

**units.cpp/.h** — Unit conversion:
- EMU (English Metric Units) as internal representation
- Conversions: pt↔EMU, in↔EMU, cm↔EMU, mm↔EMU, half-pt↔EMU, twips↔EMU
- Length::parse() handles "12pt", "1.5in", "5%", etc.

## Bundled Resources (inst/)

### inst/templates/
- KeyStat_default.json: default styles template for rendering

### inst/fonts/
- LiberationSans-Regular.ttf, -Bold.ttf, -Italic.ttf, -BoldItalic.ttf: fallback fonts

### inst/schemas/
- spec_schema_v1.json (941 lines): main spec validation schema
- row_style_actions_schema_v0.json: styleRows validation
- styles_schema_v0.json, styles_schema_v1.json: style definitions
- spec_schema_v0.json: legacy schema

### inst/examples/
- full_cycle_render.R: 10 comprehensive full-cycle examples (minimal→complex)
- ksTFL_example.R, ksTFL_example_extended.R: earlier spec-only examples
- README.md: example descriptions

## Tests (20 files in tests/testthat/)
setup-data.R, test-01 through test-18:
basic-creation, define-cols, add-style, content, stub-column, headers-footers, text-groups, options, create-report, edge-cases, integration, serialization, width-recalc, report-writer, compute-cols, stylerows-consolidation, guess-layout, optimization-fixes, ggplot-figure, cpp-units

Total: 806+ passing R tests + 135 C++ assertions via test-18-cpp-units.R
