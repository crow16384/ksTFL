# ksTFL Copilot Instructions

## Project Overview
**ksTFL** is an R package that generates metadata for clinical Tables, Figures, and Listings (TFLs). It creates a specification object (`TFL_spec`) that describes document structure, data, styles, and content—this metadata is then passed to Python code for rendering into styled DOCX documents.

## Architecture & Data Flow

### Core Spec Structure
The heart of ksTFL is the spec object (`TFL_spec`), initialized by `tfl_init()` using user-faced wrappers create_table, create_text, create_figure and defined in [constants.R](R/constants.R). It contains:
- `document`: metadata (docType, hasData, titles, footers, etc.)
- `columns`: column definitions with formats and labels. columns are auto-detected for Tables from data frame input.
- `styleRows`, `styles`: styling specifications. `styleRows` is still TO DO.
- `titles`, `subtitles`, `footnotes`, `bodyText`: content layers
- `.metadata`: internal state (report_cols, data_env)

### Three Document Types
- **Table**: Requires data frame, auto-detects column formats, supports tidyselect for column filtering
- **Text**: Narrative-only (data=NULL), contains only bodyText
- **Figure**: Requires file path to image, minimal metadata

### DocType Validation Pattern
Each docType has explicit validation in `tfl_init()`:
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
**Pattern**: 
Use `switch(.., ...)` not multiple if statements for type dispatch.
Use `useMethod` for S3 dispatch if needed.
Use checkmate for validation (e.g., `assert_data_frame()`, `assert_names()`).
Use cli for warnings/errors and formatted messages. Provide detailed messages to end-users using cli
When anything needs to be defined as constants, define in [constants.R](R/constants.R).
When any functions changes from exported to internal, rename with `.` prefix and add `@keywords internal` in roxygen. Also remove from NAMESPACE.
When any functions became exported, add `@export` in roxygen and add to NAMESPACE. (consider S3method export derictive if S3 method).
Write detailed Roxygen documentation for all exported functions, including parameters, return values, examples, and details.

### 2. Type Coercion for Unknown Classes
When a column class isn't recognized:
- Use `.coerce_unknown_type()` (lines 370-410)
- **MUST validate** that values are scalar/atomic (not lists)
- Call `is.atomic()` and check `length() <= 1L`
- Throw `cli_abort()` if composite structures detected (e.g., list columns)

### 3. Schema-Based Configuration
Settings stored in [pkg_settings.R](R/pkg_settings.R) in `.options_env$defaults`:
- `spec_schema`: Currently "spec_schema_v1.json" (in `inst/schemas/`)
-  `row_style_schema`: Define allowed properties for rowStyles (still TO DO)
- `styles_schema`: Define allowed properties for style templates referenced by name in docTemplate of the spec (still TO DO)
- Default values cascade to spec during `tfl_init()` via `.fill_spec_defaults()`
- export and validation of the spec schema is handled in `spec_serializer.R` (still TO DO)

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

### 6. spec metadata
Internal metedata stored in `spec$.metadata` (this should not be serialized to json on export):
- `report_cols`: Tracks which data columns are included in the report (after tidyselect filtering). Important thing: tfl_init() copies the whole data frame to spec$.metadata$data_env so all the columns can be referenced by styleRows conditional formating, but only columns that were defined in cols= argument should appear in spec$columns/ report_cols and only for these columns user should be able to define formatting/stylings
- `data_env`: An environment that holds a copy of the input data frame and embedded functions for internal reference (e.g., styleRows conditional formatting). This prevents unnecessary data duplication in the spec object. the data_env has three layers:
  - functions layer: holds embedded functions (e.g., `.get_column_data()`) - functions have access to data layer and another functions in the same layer
  - data layer (spec$.metadata$data_env$`__data__`): holds the input data frame copied from tfl_init() argument
  - mask layer (spec$.metadata$data_env$`__mask__`): tidyselect mask environment for column filtering (created during tfl_init() processing)
Any conditions that will be implemented later in styleRows will be evaluated in the context of data_env so they can access the data columns directly. `.env_eval()` helper function is provided to evaluate expressions in the data_env context.
-  the data_env holds a shadow copy of the data. We must not mutate it. Any evaluations with data should be done outside or on-the-fly.

## Code Quality Standards

### Naming Conventions:
- **Column iterator**: Use `col_idx`, not `var` or `i`
- **Quotes**: Double quotes throughout (not single)
- **Numeric suffixes**: Use `1L` not `1` for type safety

### Validation Approach
- Use `checkmate::` for argument validation (e.g., `assert_data_frame()`, `assert_names()`)
- Always specify `.var.name` parameter for clear error messages
- Validate **early** before processing/mutating data

### Roxygen Documentation
- Use markdown in roxygen: `@param data A data frame...` with backticks for code
- Include `@details` for complex logic
- Provide `@examples` with `\dontrun{}` for external dependencies
- Mark internal functions: `@keywords internal`
- Include `\itemize` roxygen lists for multiple points where function uses dots argument

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
- correctness of the modified spec object after each operation
- test all function parameters and their combinations where applicable
- try to identify edge cases (e.g., empty data frames, all-NA columns, incorrect user inputs)

## Common Tasks

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
- **Python backend**: Receives serialized spec and data (via `spec_serializer.R`) as JSON - still TO DO
- **External data**: tidyselect for column filtering, data frame input
- **Dependencies**: cli (messages), checkmate (validation), rlang (quoting), tidyselect (column selection)

## Common Gotchas
- **Pipe placeholder `_`**: Reserved in R 4.1+, don't use as variable name
- **Switch statement**: No `.default` option—use unnamed block `{ }` for defaults
- **Column extraction**: Use `[[` not `[` to get atomic vector, not single-element list
- **Coercion validation**: Always check `is.atomic()` before `as.character()` on unknown types. better to use checkmate where possible.

## Context-Based Function Nesting (CRITICAL)
The package uses `.assert_context()` and `.set_context()` for enforcing proper function call hierarchy. **This is essential to understand:**

### Function Nesting Rules (from spec_context.R):
1. **`add_style(spec, id, ...)`** - Top-level style definition
   - ✓ Can contain: `s_font()`, `s_paragraph()`, `s_table_style()`
   - ✗ Cannot contain: `s_borders()` directly (must be inside `s_table_style()`)

2. **`s_font()`** - Direct child of `add_style()`
   - Parameters: `font_name`, `font_size`, `bold`, `italic`, `underline`, `color`, `highlight`
   - ✓ `add_style(spec, s_font(...))`

3. **`s_table_style()`** - Direct child of `add_style()`
   - Parameters: `background_color`, `row_height`, `vertical_alignment`, `text_orientation`, `borders`
   - ✓ `add_style(spec, s_table_style(borders = s_borders(...)))`
   - ✗ `add_style(spec, s_table_style(...), s_borders(...))` - s_borders() must be inside s_table_style()

4. **`s_borders()`** - MUST be child of `s_table_style()`
   - Each side takes: `top = s_border(...)`, `bottom = s_border(...)`, `left = s_border(...)`, `right = s_border(...)`
   - ✗ `add_style(spec, s_borders(...))` - ERROR: can only be used inside s_table_style()

5. **`s_border()` (singular)** - Individual border for one side
   - Parameters: `color` (hex), `width` (e.g., "1pt"), `line_style` (e.g., "single", "double", "dashed", "dotted", "thick", "none")
   - ✓ `s_borders(top = s_border(width = "1pt", line_style = "single"))`

6. **`s_paragraph()`** - Direct child of `add_style()`
   - Can contain: `spacing = s_spacing(...)`, `indents = s_indents(...)`
   - ✓ `add_style(spec, s_paragraph(spacing = s_spacing(...), indents = s_indents(...)))`

7. **`s_spacing()`, `s_indents()`** - MUST be inside `s_paragraph()`
   - ✗ `add_style(spec, s_spacing(...))` - ERROR
   - ✓ `add_style(spec, s_paragraph(spacing = s_spacing(...)))`

8. **`c_format()`** - Can ONLY be used inside `define_cols()`
   - Parameters: `type` ("string" or "numeric"), `format` (sprintf format), `missings`, `colWidth`, `valueStyleRef`
   - ✓ `define_cols(spec, col, c_format(type = "numeric", format = "0.00"))`
   - ✗ `add_style(spec, c_format(...))` - ERROR

## Settings/Options Management (CRITICAL)
- **Naming**: Use "options" terminology: `tfl_set_options()`, `tfl_get_options()`, `tfl_get_option()`, `tfl_reset_options()`
- **Replace behavior**: When `tfl_set_options()` is called with `add_header()` or `add_footer()`, it **REPLACES** previous headers/footers, not accumulate
  - ✓ First call: `tfl_set_options(add_header(c("A", "B", "C")))`
  - ✓ Second call: `tfl_set_options(add_header(c("X", "Y", "Z")))` - Replaces with X/Y/Z, previous A/B/C are gone
- **Page margins**: Must use `s_margins()` with proper units OR valid list keys, NOT raw unitless numbers
  - ✗ `margins = list(top = 1.0, bottom = 1.0)` - ERROR: need units
  - ✓ `margins = list(top = "1.0in", bottom = "1.0in", left = "0.75in", right = "0.75in")`

## Column Selection with tidyselect (CRITICAL)
`define_cols()` uses `enquos()` for tidyselect support. **Always use `c()` for multiple columns:**
- ✗ `define_cols(spec, col1, col2, label = "...")` - ERROR: object 'col2' not found
- ✓ `define_cols(spec, c(col1, col2), label = "...")` - CORRECT
- ✓ `define_cols(spec, col1, label = "...")` - CORRECT (single column)

## tfl_init() Parameter Patterns (CRITICAL)
Three document types with different parameter requirements:
```r
# TABLE: Requires data frame
tfl_init(data = data_frame, cols = everything(), docType = "Table", id = "t01s01")

# FIGURE: Requires file path string
tfl_init(data = "path/to/figure.png", docType = "Figure", id = "f01s01")

# TEXT: Requires NULL for data
tfl_init(data = NULL, docType = "Text", id = "txt01")
```

## Code updates
- do not try to run R code - R is not installed on the given machine. Ask user to run code suggested by you and give you console output if needed
- do not commit to git - user will ask you to do so if needed
- when commiting check the diff of all modified files and write short but meaningful commit messages


