# ksTFL Copilot Instructions

## Project Overview
**ksTFL** is an R package that generates metadata for clinical Tables, Figures, and Listings (TFLs). It creates a specification object (`TFL_spec`) that describes document structure, data, styles, and content—this metadata is then passed to Python code for rendering into styled DOCX documents.

## Architecture & Data Flow

### Core Spec Structure
The heart of ksTFL is the spec object (`TFL_spec`), initialized by `tfl_init()` and defined in [constants.R](R/constants.R). It contains:
- `document`: metadata (docType, hasData, titles, footers, etc.)
- `columns`: column definitions with formats and labels
- `styleRows`, `styles`: styling specifications
- `titles`, `subtitles`, `footnotes`, `bodyText`: content layers
- `.metadata`: internal state (report_cols, data_env)

### Three Document Types
- **Table**: Requires data frame, auto-detects column formats, supports tidyselect for column filtering
- **Text**: Narrative-only (data=NULL), contains only bodyText
- **Figure**: Requires file path to image, minimal metadata

### DocType Validation Pattern
Each docType has explicit validation in `tfl_init()` (lines 48-95 in [spec_init.R](R/spec_init.R)):
- **Figure**: Must validate file readability with `.is_readable_file()`
- **Text**: Must reject non-NULL data argument
- **Table**: Must validate data.frame and column selection

## Key Development Patterns

### 1. Column Auto-Detection (spec_init.R:159-180)
When building a Table, `tfl_init()` extracts and formats each column:
```r
.init_column_specs(data, data_cols)  # Helper extracts column specs
.get_data_format(col, col_name)      # Auto-detects type and format
.get_col_label(col)                  # Retrieves label attribute
```
**Pattern**: Use `switch(col_class, ...)` not multiple if statements for type dispatch.

### 2. Type Coercion for Unknown Classes
When a column class isn't recognized:
- Use `.coerce_unknown_type()` (lines 370-410)
- **MUST validate** that values are scalar/atomic (not lists)
- Call `is.atomic()` and check `length() <= 1L`
- Throw `cli_abort()` if composite structures detected (e.g., list columns)

### 3. Schema-Based Configuration
Settings stored in [pkg_settings.R](R/pkg_settings.R) in `.options_env$defaults`:
- `spec_schema_file`: Currently "spec_schema_v1.json" (in `inst/schemas/`)
- `style_schema_file`, `row_style_schema_file`: Define allowed properties
- Default values cascade to spec during `tfl_init()` via `.fill_spec_defaults()`

### 4. Error Messages with cli Package
Use `cli_abort()` and `cli_warn()` (not base R stop/warning):
```r
cli_abort(c(
  "Main error message:",
  x = "Problem description",
  i = "Remediation or info"
))
```
This ensures consistent, formatted error output to users.

### 5. Helper Functions (Internal)
All internal functions start with `.` (e.g., `.init_column_specs`, `.fill_spec_defaults`). They:
- Have `@keywords internal` in roxygen
- Are NOT exported in NAMESPACE
- Handle specific sub-tasks (kept separate from main logic)

## Code Quality Standards

### Naming Conventions
- **Variables**: `snake_case` (e.g., `has_data`, not `hasData`)
- **Column iterator**: Use `col_idx`, not `var` or `i`
- **Quotes**: Double quotes throughout (not single)
- **Numeric suffixes**: Use `1L` not `1` for type safety

### Validation Approach
- Use `checkmate::` for argument validation (e.g., `assert_data_frame()`, `assert_names()`)
- Always specify `.var.name` parameter for clear error messages
- Validate **early** before processing (see `tfl_init()` lines 48-100)

### Roxygen Documentation
- Use markdown in roxygen: `@param data A data frame...` with backticks for code
- Include `@details` for complex logic
- Provide `@examples` with `\dontrun{}` for external dependencies
- Mark internal functions: `@keywords internal`

## Testing & Loading

### Package Initialization
- [99_loader.R](R/99_loader.R) loaded first (prefix "99_" ensures ordering)
- `.onLoad()`: Package startup message, initialize .options_env
- Custom S3 methods can be registered here if needed

### Test Structure
Tests in `tests/testthat/` use standard testthat patterns. Key test scenarios:
- Spec initialization with different docTypes
- Column selection via tidyselect expressions
- Type detection and format assignment
- Error conditions (invalid data, missing files, etc.)

## Common Tasks

### Adding a New Column Format
1. Update `.get_data_format()` switch statement (spec_init.R:333-365)
2. Add new case with appropriate type ("numeric" or "string") and format
3. Test with both valid and edge cases (NA values, empty columns)

### Updating Schema Constraints
1. Modify `inst/schemas/spec_schema_v1.json`
2. Update `pkg_settings.R` if new defaults needed
3. Add validation in relevant helper (e.g., `.fill_spec_defaults()`)

### Adding New Setter Functions
Follow the pattern of exported functions like `tfl_init()`:
- Use roxygen with `@export`
- Validate inputs with checkmate
- Modify spec object by reference or return updated spec
- Use `cli_abort()` for errors

## Integration Points
- **Python backend**: Receives serialized spec (via `spec_serializer.R`) as JSON
- **External data**: tidyselect for column filtering, data frame input
- **Dependencies**: cli (messages), checkmate (validation), rlang (quoting), tidyselect (column selection)

## Common Gotchas
- **Pipe placeholder `_`**: Reserved in R 4.1+, don't use as variable name
- **Switch statement**: No `.default` option—use unnamed block `{ }` for defaults
- **Column extraction**: Use `[[` not `[` to get atomic vector, not single-element list
- **Coercion validation**: Always check `is.atomic()` before `as.character()` on unknown types
