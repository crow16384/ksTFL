# File Structure and Responsibilities

## R/ Source Files (15 files)

### constants.R (~474 lines)
Central constants repository. Contains:
- .const_empty_spec, enum values, color map, validation regex patterns
- .const_schema_properties, .const_modifier_paths, default values
- .const_options_styles: 30+ predefined clinical styles (font_bold, text_center, cell_highlight_*, indent_*, etc.)
- Package-level caches: .schema_cache, .style_resolution_cache, .format_spec_cache
- .const_index_file = "_index.json" (meta folder index filename)

### spec_init.R (~605 lines)
- .tfl_init(), .fill_spec_defaults(), .init_column_specs(), .get_col_label(), .coerce_unknown_type()
- create_table(), create_text(), create_figure(): exported user wrappers

### spec_context.R (~2975 lines) - LARGEST FILE
- Context system, validation, style spec builders, exported style functions
- add_style(), f_combine(), define_cols(), content functions, set_document(), set_page_style()

### env_eval_helpers.R (~524 lines)
- .create_data_env(), .get_data_columns(), .env_eval()
- compute_cols helpers: .eval_change_of(), .eval_firstOf(), .eval_lastOf(), etc.

### rowstyle_actions.R (~980 lines)
- compute_cols(), c_style(), c_merge(), c_addrow(), c_pageBreak()
- .finalize_compute_cols(), action parsers, .build_stylerows_list()

### create_report.R (~570 lines)
- ._consolidate_styles_in_spec(), create_report(): 6-phase pipeline

### report_writer.R (~360 lines)
- save_report(): validates, serializes, writes JSON + data files
- Now calls .update_spec_index() after writing spec JSON to maintain _index.json
- .save_table_data(), .save_figure_file()

### render_docx.R (137 lines)
- render_docx(): validates inputs, resolves paths, calls C++ render_docx_impl()
- Captures integer page count returned by C++, displays via cli_alert_success
- page_label pre-computed outside cli glue context (avoids inline-if error)

### meta_management.R (~521 lines) [NEW Mar 1 2026]
Meta folder management. Public API:
- list_reports(meta_dir, sort_by): scan meta folder, return data frame with is_latest column
- replay_report(spec_json, meta_dir, output_path, template_json, verbose): re-render from JSON
- clean_reports(meta_dir, keep_versions=1L, dry_run=TRUE): remove obsolete + orphaned files
Internal helpers:
- .read_spec_index(): read _index.json or fall back to .scan_meta_folder()
- .scan_meta_folder(): build index data frame by reading every spec JSON
- .collect_spec_meta(): extract _metadata + dataRef list from one spec JSON (returns NULL for data JSONs)
- .resolve_spec_path(): resolve doc_file name or hash filename to absolute path
- .update_spec_index(): append/update one row in _index.json (called by save_report)
- .const_index_file = "_index.json"

### schema_serialize.R (~1141 lines)
- .load_schema(), .serialize_json_internal(), .fix_types(), serialize_spec()

### pkg_settings.R (~291 lines)
- .options_env, tfl_get_options/option/set/reset

### utility_functions.R (~770 lines)
- .parse_colwidth(), .recalculate_col_widths(), .generate_hash(), max_line_width()

### ksTFL.R
- Package-level docs, .onLoad(), .onAttach(), .onUnload()

### spec_print.R
- print.TFL_spec(): console + HTML viewer

### RcppExports.R
- Auto-generated Rcpp bindings (manually patched: render_docx_impl returns int, not invisible)
- render_docx_impl(), render_docx_from_strings_impl(): return integer page count
- cpp_test_units(), cpp_test_inline_parser(), cpp_test_xml_writer(): @keywords internal

## src/ - C++ Renderer Engine

### Build System
- src/Makevars: CXX_STD=CXX20, links HarfBuzz/FreeType/minizip via pkg-config
- src/vendor/nlohmann/: vendored nlohmann/json v3.11.3

### Rcpp Binding Files
- src/init.cpp: R_init_ksTFL with CallEntries
- src/rcpp_bindings.cpp: render_docx_impl() + render_docx_from_strings_impl() — return int (page count)
- src/RcppExports.cpp: auto-generated exports
- src/cpp_tests.cpp: C++ unit test suites (~440 lines, ~135 assertions)

### Core Renderer (src/kstfl/) - 12 modules
- types.h (~650 lines): all data structures
- renderer.cpp/.h: 6-phase pipeline, returns size_t page count
- json_parser.cpp/.h: JSON → C++ types
- style_resolver.cpp/.h: style merging, two-pass column width resolution
- logical_table.cpp/.h: table model builder
- text_measurer.cpp/.h: HarfBuzz measurement, char-level wrapping, paragraph indent correction
- font_cache.cpp/.h: font management + fallback chain
- inline_parser.cpp/.h: inline markup parser
- paginator.cpp/.h: deterministic pagination + oversized-row warning
- docx_emitter.cpp/.h (~1700 lines): OOXML generation
- xml_writer.cpp/.h: streaming XML writer
- zip_writer.cpp/.h: minizip wrapper
- units.cpp/.h: EMU unit conversions

## Bundled Resources (inst/)

### inst/templates/
- CRO Example_default.json: default styles template

### inst/fonts/
- LiberationSans-Regular/Bold/Italic/BoldItalic.ttf

### inst/schemas/
- spec_schema_v1.json (941 lines), row_style_actions_schema_v0.json
- styles_schema_v0.json, styles_schema_v1.json, spec_schema_v0.json (legacy)

### inst/examples/
- full_cycle_render.R: 13 comprehensive examples
- manul_unit_tests/TEST_03/test_03.R: 11 manual unit test specs

## Tests (20 files in tests/testthat/)
setup-data.R, test-01 through test-18
806+ passing R tests + 135 C++ assertions

## Configuration
- .cursor/mcp.json: Serena (uvx, --context ide, --project) + Context7 (npx) MCP servers
- NAMESPACE: exports all public functions including list_reports, replay_report, clean_reports
