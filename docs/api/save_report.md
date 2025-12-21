# save_report(...)

Purpose: Serialize a `TFL_report` object to JSON format with associated data and figure files.

Parameters:
- `report` `TFL_report` object (output from `create_report()`)
- `docFileName` Character string. Name of the rendered document file (e.g., "report.docx")
- `outDir` Character string (optional). Output directory for Python renderer. Defaults to `tfl_get_option("output_directory")`
- `metaPath` Character string (optional). Directory to save JSON spec and data files. Defaults to `tempdir()`
- `prettify` Logical (optional). If TRUE, format JSON with indentation. Defaults to FALSE

Key package callees and transitive chains:
- Validates input is `TFL_report` class
- -> `serialize_spec(report)` to validate against schema and get `fixed` object
- For each spec by docType:
  - **Table**: `.save_table_data()` extracts data, filters to report columns, removes rownames, saves as JSON
  - **Figure**: `.save_figure_file()` copies image file with extension preservation
  - **Text**: No additional file processing
- -> `.remove_nulls_recursive(final_export)` to remove NULL values before JSON serialization
- -> `jsonlite::toJSON()` to serialize with `auto_unbox = TRUE` and `pretty = prettify`

Direct package callees:
- `serialize_spec`, `.save_table_data`, `.save_figure_file`, `.remove_nulls_recursive`, `.generate_hash`, `jsonlite::toJSON`, `cli_abort`, `cli_alert_success`, `cli_alert_info`, `tfl_get_option`, `normalizePath`, `checkmate::assert_*`

Usage notes:
- Automatically normalizes `outDir` to full system path
- Removes all NULL values before JSON export (prevents empty object/array serialization)
- Table data serialized with: `pretty = FALSE, digits = 8, null = NULL, na = NULL, dataframe = "columns", factor = "string"`
- Figure files copied with original extension preserved
- Returns invisibly with: spec_file (hash-based JSON filename), datetime (ISO 8601), metaPath (save directory)

