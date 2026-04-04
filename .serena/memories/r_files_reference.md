# ksTFL — R Source Files Reference

All files live under `R/`. Internal (non-exported) functions are prefixed with `.`.

---

## R/constants.R
Central constants store. All named `.const_*`. Never hardcode schema keywords or values that exist here.

**Key constants:**
- `.const_empty_spec` — skeleton TFL_spec structure
- `.const_schema_properties`, `.const_modifier_paths`, `.const_schema_keywords` — schema navigation
- `.const_json_pointer_escapes` — JSON pointer escape rules
- `.const_color_hex_map` — named color → hex map
- Regex patterns: `.const_pattern_font_size`, `.const_pattern_hex_color`, `.const_pattern_color`, `.const_pattern_spacing`, `.const_pattern_indents`, `.const_pattern_margins`, `.const_pattern_border_width`, `.const_pattern_row_height`, `.const_pattern_col_width`, `.const_pattern_content_width`, `.const_pattern_figure_size`, `.const_pattern_table_empty_line`
- Enumerations: `.const_alignment_values`, `.const_word_styles`, `.const_line_styles`, `.const_vertical_alignment`, `.const_text_orientation`, `.const_page_sizes`, `.const_page_orientations`, `.const_column_types`, `.const_doc_types`, `.const_figure_scale_modes`, `.const_figure_devices`, `.const_border_sides`, `.const_schema_types`, `.const_font_names`, `.const_asset_extensions`
- Defaults: `.const_default_page_size`, `.const_default_page_orientation`, `.const_default_doc_template`, `.const_default_numeric_format`, `.const_default_missing_value`, `.const_default_bodytext`, `.const_bodytext_default_id_prefix`
- File refs: `.const_index_file`, `.const_spec_schema_file`, `.const_style_schema_file`, `.const_row_style_schema_file`, `.const_schemas_dir`
- Numeric: `.const_min_line_spacing`, `.const_max_header_footer_parts`, `.const_default_bodytext_order`
- Package-level caches: `.schema_cache`, `.style_resolution_cache`, `.format_spec_cache`
- Options defaults: `.const_options_page`, `.const_options_header_footer`, `.const_options_bodytext`, `.const_options_styles`

---

## R/spec_init.R
Spec object construction — entry point for all user-facing initializers.

**Exported:** `create_table()`, `create_text()`, `create_figure()`
**Internal:**
- `.tfl_init()` — core initializer called by all three exported functions
- `.init_column_specs()` — builds column spec list from data + tidyselect
- `.fill_spec_defaults()` — applies default values to the spec
- `.generate_default_bodytext_id()` — auto-ids for body text blocks
- `.get_col_label()` — resolves column label from data or spec
- `.coerce_unknown_type()` — coerces unsupported column types
- `.figure_size_to_inches()` — unit conversion for figure dimensions
- `.save_ggplot_to_temp()` — saves ggplot to temp file for figure specs

---

## R/spec_context.R
Largest R file. Defines the style/context API — all `s_*`, `p_*`, `add_*`, `set_*` functions live here.

**Style atoms (exported):** `s_font()`, `s_spacing()`, `s_indents()`, `s_paragraph()`, `s_border()`, `s_borders()`, `s_table_style()`, `p_margins()`, `p_page()`
**Style composition (exported):** `add_style()` (S3: `TFL_spec`, `TFL_options`, `default`), `f_combine()`, `c.tfl_style_combine()`
**Column/text spec (exported):** `define_cols()`, `add_title()`, `add_subtitle()`, `add_footnote()`, `add_body_text()` (S3), `add_header()` (S3), `add_footer()` (S3), `add_span_header()`, `set_document()`, `set_page_style()` (S3)
**Internal validation:** `.assert_context()`, `.set_context()`, `.clear_context()`, `.get_allowed_properties()`, `.validate_params()`, `.validate()`, `.validate_required()`, `.validate_enum()`, `.validate_pattern()`, `.validate_figure_dimension_settings()`, `.validate_color()`, `.normalize_color()`
**Internal spec builders:** `.font_spec()`, `.spacing_spec()`, `.indents_spec()`, `.paragraph_spec()`, `.border_spec()`, `.borders_spec()`, `.table_style_spec()`, `.margins_spec()`, `.page_spec()`, `.col_format_spec()`
**Style resolution:** `.process_style_modifier()`, `.validate_style_payload()`, `._resolve_style_refs()`, `.check_spec_consistency()`
**Context marker env:** `.context_marker_env`, `.schema_cache_env`
**Helper:** `.add_text_group_impl()`, `.add_header_footer_impl()`, `.auto_stub_order()`

---

## R/schema_serialize.R
JSON schema-driven serialization pipeline.

**Exported:** `serialize_spec()`
**Internal:** `.load_schema()`, `.clear_schema_cache()`, `.get_schema_file_path()`, `.normalize_json_pointer_path()`, `.validate_schema_input()`, `.has_combinator()`, `.get_combinator_variants()`, `.serialize_json_internal()`, `.protect_arrays()`, `.json_pointer_escape()`, `.resolve_refs()`, `.resolve_allOf()`, `.allows_null()`, `.match_type()`, `.coerce_value()`, `.check_enum()`, `.check_pattern()`, `.apply_pattern_properties()`, `.resolve_combinator_type()`, `.fix_types()`
**Cache:** `.schema_cache` (field)

---

## R/rowstyle_actions.R
Row-level styling and table transformation actions.

**Exported (DSL):** `compute_cols()`, `c_style()`, `c_merge()`, `c_addrow()`, `c_pageBreak()`, `c_glue()`, `c_clear()`
**Internal:**
- `.finalize_compute_cols()` — evaluates conditions and builds rowstyle list
- `.parse_action_*()` group — parse each DSL action type
- `.append_*_action()` group — append actions to spec
- `.sanitize_row_actions()`, `.check_merge_overlap()`, `.combine_column_styles()`, `.build_stylerows_list()`

---

## R/env_eval_helpers.R
Environment-based expression evaluation for compute_cols conditions.

**Internal:** `.create_data_env()`, `.get_data_columns()`, `.get_data_column_names()`, `.env_eval()`, `.eval_change_of()`, `.eval_firstOf()`, `.eval_lastOf()`, `.eval_firstRow()`, `.eval_lastRow()`, `.group_by_nth()`, `.eval_get_names()`, `.eval_row_numbers()`, `.eval_every_nth()`, `.eval_in_env()`
**Struct:** `.env_func_list` — lookup table of allowed eval functions

---

## R/create_report.R
Report assembly — combines multiple TFL_spec objects into a report payload.

**Exported:** `create_report()`
**Internal:** `._consolidate_styles_in_spec()` — deduplicates/inlines style references
**Pipeline phases (documented as string markers):**
1. Flatten inputs (order-preserving)
2. Validate duplicate keys
3. Finalize compute_cols actions
4. Style consolidation
5. Renumber docOrder globally, create dataRef
6. Validate dataRef
7. Build result

---

## R/report_writer.R
Persists report payloads to disk — JSON specs + data/figure files.

**Exported:** `save_report()`
**Internal:** `.remove_nulls_recursive()`, `.save_table_data()`, `.save_figure_file()`
**Pipeline:** serialize → strip .metadata → build `_metadata` section → generate hash filename → write JSON → update `_index.json`

---

## R/render_docx.R
DOCX rendering entrypoint — bridges R to C++ renderer.

**Exported:** `render_docx()`
**Internal:** `.resolve_template_value()`, `.resolve_template_paths_by_spec()`, `.build_multi_template_payload()`, `.list_bundled_templates()`

---

## R/write_doc.R
High-level convenience wrapper combining `save_report()` + `render_docx()`.

**Exported:** `write_doc()`

---

## R/meta_management.R
Manages the spec index and report lifecycle (list, replay, clean).

**Exported:** `list_reports()`, `replay_report()`, `clean_reports()`
**Internal:** `.read_spec_index()`, `.normalize_data_refs()`, `.scan_meta_folder()`, `.collect_spec_meta()`, `.write_spec_index()`, `.update_spec_index()`, `.identify_obsolete_specs()`, `.collect_live_refs()`, `.merge_spec_jsons()`, `.resolve_spec_path()`

---

## R/pkg_settings.R
Package-level option management. Uses a private `.options_env`.

**Exported:** `tfl_get_options()`, `tfl_get_option()`, `tfl_set_options()`, `tfl_reset_options()`, `tfl_list_templates()`

---

## R/font_management.R
Font scanning and status reporting.

**Exported:** `tfl_rescan_fonts()`, `tfl_font_status()`
**Internal:** `.print_font_report()`

---

## R/utility_functions.R
General-purpose helpers used across the package.

**Internal:** `.is_scalar_atomic()`, `.is_readable_dir()`, `.is_readable_file()`, `.merge_recursive()`, `.auto_id()`, `.generate_hash()`, `.guess_table_layout()`, `.unclass_recursive()`, `.parse_colwidth()`, `.validate_colwidth_minimum()`, `.validate_relative_colwidth()`, `.recalculate_col_widths()`

---

## R/spec_print.R
TFL_spec pretty-printing and Shiny viewer.

**Exported:** `print.TFL_spec()`, `view_tfl_spec()`
**Internal:** `.scalar_text()`, `.render_text_object()`, `.render_rows()`, `.render_columns()`, `.render_TFL_spec_viewer()`

---

## R/addin_tfl_spec_preview.R
RStudio addin and style explorer utilities.

**Exported:** `tfl_spec_preview_selection()`, `tfl_spec_preview_prompt()`, `tfl_print_style_atoms()`
**Internal:** `.style_atom_category()`, `.flatten_style_value()`, `.hex_swatch()`, `tfl_style_atoms_catalog()`

---

## R/RcppExports.R
Auto-generated Rcpp glue (do not edit manually).

**Rcpp wrappers:** `cpp_test_units()`, `cpp_test_inline_parser()`, `cpp_test_xml_writer()`, `cpp_test_format_validator()`, `render_docx_impl()`, `render_docx_from_strings_impl()`, `init_font_registry_impl()`, `get_font_dirs_impl()`

---

## R/ksTFL.R
Package bootstrap.

**Internal:** `.pkg_env` (package environment), `.onLoad()`, `.onAttach()`, `.onUnload()`

---

## R/run_replay_app.R
Shiny app for replaying saved reports.

**Exported:** `run_replay_app()`

---

## R/run_styles_editor.R
Shiny styles editor UI.

**Exported:** `run_styles_editor()`
