# File Structure and Responsibilities

## R/ Source Files

### constants.R (474 lines)
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

### spec_init.R (605 lines)
Spec initialization. Contains:
- .tfl_init(): internal initializer for all 3 docTypes with validation
- .fill_spec_defaults(): populates spec from package settings
- .init_column_specs(): auto-detects column formats from data
- .get_col_label(): extracts label attribute from column
- .coerce_unknown_type(): handles unknown column classes
- create_table(), create_text(), create_figure(): exported user wrappers

### spec_context.R (2975 lines) - LARGEST FILE
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

### env_eval_helpers.R (524 lines)
Data environment and evaluation. Contains:
- .create_data_env(): creates 3-layer environment (functions, data __data__, mask __mask__)
- .get_data_columns(), .get_data_column_names(): tidyselect wrappers
- .env_eval(): evaluate expression in data env
- Helper functions for compute_cols: .eval_change_of(), .eval_firstOf(), .eval_lastOf(), .eval_firstRow(), .eval_lastRow(), .group_by_nth(), .eval_get_names(), .eval_row_numbers(), .eval_every_nth(), .eval_in_env()

### rowstyle_actions.R (970 lines)
Conditional row styling. Contains:
- compute_cols(): exported - captures condition + actions as quosures
- c_style(), c_merge(), c_addrow(), c_pageBreak(): action builders
- .finalize_compute_cols(): evaluates all captured conditions/actions during create_report()
- Action parsers: .parse_action_style(), .parse_action_merge(), .parse_action_addrow()
- Action appenders: .append_style_action(), .append_merge_action(), .append_addrow_action(), .append_pagebreak_action()
- Sanitization: .sanitize_row_actions(), .check_merge_overlap(), .combine_column_styles()
- .build_stylerows_list(): converts row actions to serializable format

### create_report.R (570 lines)
Report assembly. Contains:
- ._consolidate_styles_in_spec(): 2-pass style consolidation (collect refs + replace combos)
- create_report(): 6-phase pipeline (flatten, validate keys, finalize compute_cols, consolidate styles, renumber docOrder, build result)

### report_writer.R (360 lines)
Serialization to disk. Contains:
- .remove_nulls_recursive(): cleans up NULLs before JSON export
- save_report(): validates, serializes, writes JSON + data files
- .save_table_data(): extracts and saves table data as JSON
- .save_figure_file(): copies figure files

### schema_serialize.R (1141 lines)
Schema-driven validation and JSON preparation. Contains:
- .load_schema(), .clear_schema_cache(), .get_schema_file_path(): schema loading
- .build_json_pointer(), .resolve_refs(): JSON pointer resolution
- .resolve_allOf(): allOf combinator merging
- .serialize_json_internal(), .fix_types(): schema-aware type coercion
- .protect_arrays(): ensures arrays serialize correctly
- serialize_spec(): main entry point for schema validation + JSON export

### pkg_settings.R (291 lines)
Package options management. Contains:
- .options_env: environment storing defaults and current settings
- tfl_get_options(), tfl_get_option(): read options
- tfl_set_options(): update options (handles S3 objects like add_header, add_style)
- tfl_reset_options(): restore defaults

### utility_functions.R (770 lines)
General utilities. Contains:
- .is_scalar_atomic(), .is_readable_file(), .is_readable_dir()
- .merge_recursive(): list merging with modifyList(keep.null=TRUE)
- .auto_id(): unique ID generation
- .generate_hash(): deterministic hash via digest
- .guess_table_layout(): auto column format detection
- .parse_colwidth(), .validate_colwidth_minimum(), .validate_relative_colwidth()
- .recalculate_col_widths(): auto width redistribution
- .unclass_recursive(): strip classes recursively

### ksTFL.R
Package-level docs, .onLoad(), .onAttach(), .onUnload()

### spec_print.R
print.TFL_spec(): console + HTML viewer rendering

## Tests (18 files)
test-01-basic-creation.R, test-02-define-cols.R, test-03-add-style.R, test-04-content.R, test-04b-stub-column.R, test-05-headers-footers.R, test-05b-text-groups.R, test-06-options.R, test-07-create-report.R, test-08-edge-cases.R, test-09-integration.R, test-10-serialization.R, test-11-width-recalc.R, test-12-report-writer.R, test-13-compute-cols.R, test-14-stylerows-consolidation.R, test-15-guess-layout.R, test-16-optimization-fixes.R

## Schemas (inst/schemas/)
- spec_schema_v1.json (941 lines): main spec validation schema
- row_style_actions_schema_v0.json: styleRows validation
- styles_schema_v0.json, styles_schema_v1.json: style definitions
- spec_schema_v0.json: legacy schema
