# ksTFL Copilot important Instructions

!!! you are the professional R package developer working on the ksTFL package. You perfectly understand the codebase and its architecture. You perfectly understand R Rlang, S3 methods, R environments, tidyselect, checkmate, cli, jsonlite and roxygen documentation. You know how to work with R environments and how to structure R packages.
Don't be a lazy bitch, read the function implementation/parameters/roxygens before write any calls. Don't imagine how it may looks like - read what we actually have. 

Always use #oraios/serena before and after any actions with code!

Use #Context7 MCP

For installing R packages always use Russian CRAN mirrors! 

## Project Overview

**ksTFL** is an R package that generates metadata for clinical Tables, Figures, and Listings (TFLs). It creates a specification object (`TFL_spec`) that describes document structure, data, styles, and content—this metadata is then rendered into submission-quality styled DOCX documents via a built-in C++20 rendering engine (`render_docx()`) with deterministic HarfBuzz-based text measurement.

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
- **JSON Serialization**: [spec_serializer.R](R/spec_serializer.R) handles spec validation and JSON export
  - Main entry: `serialize_spec(spec, file_path = NULL)` returns JSON string or writes to file
  - Core pipeline: `.serialize_json_internal()` → `.fix_types()` → `.resolve_refs()` → `.resolve_allOf()` → `.protect_arrays()` → `jsonlite::toJSON()`
  - Schema constants defined in [constants.R](R/constants.R): `.const_schema_keywords`, `.const_schema_types`, `.const_json_pointer_*`
  - Uses base::modifyList for recursive merging (via `.merge_recursive()` from utility_functions.R)

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

### Constants & Magic Strings
**CRITICAL**: Replace ALL magic strings with constants defined in [constants.R](R/constants.R):
- Use `.const_schema_keywords` for JSON Schema keywords (`$ref`, `type`, `properties`, `items`, `enum`, `pattern`, `allOf`, `oneOf`, `anyOf`, etc.)
- Use `.const_schema_types` for valid JSON types
- Use `.const_json_pointer_*` for JSON Pointer manipulation (`#/`, escape characters)
- Rationale: Centralizes schema knowledge, reduces bugs, enables rapid schema evolution

### Function Parameter Hygiene
When refactoring functions, **remove unused parameters immediately**:
- If a parameter is never used in the function body, remove it from all calls
- Document the removal in commit messages
- This prevents signature mismatches causing "unused argument" errors
- Example: Removed `path` parameter from `.coerce_value()`, `.check_pattern()`, `.check_enum()`, `.resolve_combinator_type()` during refactoring

### Merge Function Consolidation
- Use `.merge_recursive(x, y)` from [utility_functions.R](R/utility_functions.R) for all list merging
- Implementation uses `base::modifyList(x, y, keep.null = TRUE)` - robust and preserves NULL values
- Do NOT create duplicate merge functions; consolidate into single implementation
- `keep.null = TRUE` ensures NULL values override base values (important for schema processing)

### Naming Conventions:
- **Column iterator**: Use `col_idx`, not `var` or `i`
- **Quotes**: Double quotes throughout (not single)
- **Numeric suffixes**: Use `1L` not `1` for type safety
- **Internal functions**: Always use `.` prefix (e.g., `.merge_recursive`, `.fix_types`)

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

### C++ Unit Tests (src/cpp_tests.cpp + test-18-cpp-units.R)
C++ modules are tested via a lightweight Rcpp-exported harness in `src/cpp_tests.cpp`.
Three exported functions return `list(passed = character[], failed = "<name>: <reason>")` and
bridge into the standard testthat runner via `tests/testthat/test-18-cpp-units.R`.

| Rcpp export | Module tested | Main assertions |
|---|---|---|
| `cpp_test_units()` | `units.cpp` | `parse_length` (all units + errors), `Color::parse`, conversions (`emu_to_twips` etc.), `page_size_dimensions`, `Length` arithmetic, `border_line_style_to_ooxml`, `alignment_to_ooxml` |
| `cpp_test_inline_parser()` | `inline_parser.cpp` | `has_inline_markup`, plain text, `<b>/<i>/<u>/<sup>/<sub>`, nesting, `<br/>/<p>`, case-insensitivity, unknown tags |
| `cpp_test_xml_writer()` | `xml_writer.cpp` | XML declaration, self-close, attributes, escaping (`&<>"`), `raw()`, `comment()`, `clear()/take()/depth()`, `namespace_decl()`, error conditions |

**Pattern for new C++ tests:**
```cpp
// In src/cpp_tests.cpp — add a new [[Rcpp::export]] function:
// [[Rcpp::export]]
Rcpp::List cpp_test_<module>() {
    TestResult t;
    t.check_eq(actual, expected, "test name");
    t.check_throw([](){ /* must throw */ }, "throws on bad input");
    return t.to_list();
}
```
Then:
1. Register in `src/RcppExports.cpp` (add wrapper)
2. Register in `src/init.cpp` (add to `CallEntries[]`)
3. Add R stub in `R/RcppExports.R` with `@keywords internal`
4. Add `test_that()` blocks in `tests/testthat/test-18-cpp-units.R`

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
- **C++ rendering engine**: Receives serialized spec and data (via `save_report()`) as JSON; renders via `render_docx()` using HarfBuzz/FreeType/minizip
- **External data**: tidyselect for column filtering, data frame input
- **Dependencies**: cli (messages), checkmate (validation), rlang (quoting), tidyselect (column selection), Rcpp (C++ interface)

## Common Gotchas
- **Pipe placeholder `_`**: Reserved in R 4.1+, don't use as variable name
- **Switch statement**: No `.default` option—use unnamed block `{ }` for defaults
- **Column extraction**: Use `[[` not `[` to get atomic vector, not single-element list
- **Coercion validation**: Always check `is.atomic()` before `as.character()` on unknown types. better to use checkmate where possible.
- **Stale R environment**: After editing functions, R may cache old definitions. Restart R or use `devtools::reload_all()` to reload package
- **Path parameters**: Avoid threading `path` through recursive functions for error reporting—use context management or error wrapping instead. Removes ~30% of parameter passing overhead
- **Schema resolution performance**: `.resolve_refs()` is recursive and called for every schema object. Use constants and avoid string comparisons in hot paths

## Refactoring Lessons Learned (Dec 18, 2025)

### Completed Optimizations
1. **Constants Extraction** (~100+ magic strings → centralized constants)
2. **Helper Function Creation** (5 new helper functions for schema processing)
3. **Error Message Standardization** (all errors use `cli_abort()` with structured formatting)
4. **Merge Function Consolidation** (single `.merge_recursive()` implementation)
5. **Parameter Cleanup** (~30% reduction in parameter passing for recursive functions)

### Key Patterns
- JSON Schema processing pipeline: `.serialize_json_internal()` → `.fix_types()` → `.resolve_refs()` → `.resolve_allOf()` → `.protect_arrays()` → `jsonlite::toJSON()`
- Constants usage: All schema keywords, types, and JSON pointer manipulations stored in `.const_*` definitions
- Merge strategy: Use `.merge_recursive(x, y)` with `keep.null = TRUE` for all list merging



### Context-Based Function Nesting (CRITICAL)
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

## Settings/Options Management (CRITICAL)
- **Naming**: Use "options" terminology: `tfl_set_options()`, `tfl_get_options()`, `tfl_get_option()`, `tfl_reset_options()`
- **Replace behavior**: When `tfl_set_options()` is called with `add_header()` or `add_footer()`, it **REPLACES** previous headers/footers, not accumulate
  - ✓ First call: `tfl_set_options(add_header(c("A", "B", "C")))`
  - ✓ Second call: `tfl_set_options(add_header(c("X", "Y", "Z")))` - Replaces with X/Y/Z, previous A/B/C are gone
- **Page margins**: Must use `s_margins()` with proper units OR valid list keys, NOT raw unitless numbers
  - ✗ `margins = list(top = 1.0, bottom = 1.0)` - ERROR: need units
  - ✓ `margins = list(top = "1.0in", bottom = "1.0in", left = "0.75in", right = "0.75in")`

## Column Definition with define_cols() (CRITICAL - Dec 19, 2025)
`define_cols()` has been refactored to accept format parameters directly (no longer wraps in `c_format()` function):
- **Signature**: `define_cols(spec, cols, label = NULL, isID = FALSE, type = NULL, format = NULL, missings = NULL, colWidth = NULL, valueStyleRef = NULL, isColBreak = FALSE, labelStyleRef = NULL)`
- **Format parameters**: `type`, `format`, `missings`, `colWidth`, `valueStyleRef` now accept direct values (recycled 1-or-n)
  - Length 1: applied to all columns
  - Length matching cols: applied individually
  - Invalid: other lengths raise error
- **Column selection**: Uses `enquos()` for tidyselect support. **Always use `c()` for multiple columns:**
  - ✗ `define_cols(spec, col1, col2, label = "...")` - ERROR: object 'col2' not found
  - ✓ `define_cols(spec, c(col1, col2), label = "...")` - CORRECT
  - ✓ `define_cols(spec, col1, label = "...")` - CORRECT (single column)
- **Example**: 
  ```r
  define_cols(spec, c(age, weight), type = "numeric", format = "0.00", valueStyleRef = "numeric_right")
  ```

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

## Session-Specific Notes (Dec 18, 2025 Refactoring)

### Files Modified
- **constants.R**: Added 14 new constants for JSON Schema keywords and types
- **schema_serialize.R**: 
  - Replaced all 100+ magic strings with constant references
  - Created 5 new helper functions
  - Standardized error messages with cli format
  - Removed unused parameters from 4 functions and all call sites
  - Consolidated merge functionality (removed `.deep_merge`, use `.merge_recursive`)
  - Simplified `.fix_types()` by ~70 lines through parameter removal

### State of Codebase
✅ **Constants**: Comprehensive schema keyword and type coverage
✅ **Error Handling**: Uniform cli-based error messages throughout
✅ **Code Cleanliness**: No unused parameters in function signatures
✅ **Merge Functions**: Single robust implementation using base::modifyList
✅ **Helper Functions**: Extracted common patterns for reusability

⏳ **Still TO DO** (per original instructions):
- `row_style_schema` validation rules (design pending)
- `styles_schema` validation rules (design pending)

✅ **Completed Since Initial Instructions**:
- Style consolidation in `create_report()` with hash-based merging
- Predefined clinical styles (30+ in `.const_options_styles`)
- Column definition refactoring (direct format parameters, 1-or-n recycling)
- `missings` parameter in package options
- Enhanced `valueStyleRef` support matching `labelStyleRef` behavior
- Comprehensive roxygen documentation pass

### Future Enhancements
1. Implement `row_style_schema` validation rules (conditional row styling)
2. Implement `styles_schema` validation for predefined style templates
3. Performance optimization: memoization for schema lookups if needed
4. Regression test suite for rendered DOCX output (visual/structural validation)


## Doc Pass — Dec 19, 2025

Summary of documentation improvements:
- Updated roxygen in `R/spec_context.R`, `R/env_eval_helpers.R`, `R/create_report.R`, `R/pkg_settings.R`
- Added missing file-level tags; fixed Rd generation for `.onAttach()` and `.onUnload()`
- Clarified context-based function nesting in `add_style()` and related functions
- Removed duplicate documentation blocks

## Current State of Codebase (Feb 27, 2026)

✅ **Fully Implemented**:
- Spec initialization for all 3 docTypes (Table, Text, Figure)
- Column auto-detection and format assignment
- Style consolidation with hash-based merging
- Context-based function nesting validation
- Extended `create_report()` with mixed report/spec support
- 30+ predefined clinical styles
- Comprehensive error messages with `cli_abort()`
- Full test coverage for core functionality (19 R test files, 806+ passing tests)
- **ggplot2 integration**: `create_figure()` accepts ggplot objects (auto-rendered via `ggsave()`)
- **C++20 DOCX Renderer**: complete end-to-end pipeline (HarfBuzz → OOXML → .docx)
- **C++ Unit Tests** (`src/cpp_tests.cpp` + `test-18-cpp-units.R`): 135+ assertions covering `units.cpp`, `inline_parser.cpp`, `xml_writer.cpp`

⏳ **Still TO DO**:
- `row_style_schema` validation rules
- `styles_schema` validation rules
- Regression test suite for rendered DOCX output
- Windows build testing (Makevars.win exists but untested)
- Structural header_top/bottom border application in emitter (parsed but not yet emitted)

## Quick Reference

**Create specs**:
```r
spec_table <- create_table(mtcars)
spec_text <- create_text()
spec_figure <- create_figure("path/to/image.png")
```

**Combine into reports**:
```r
# Single create
report <- create_report(spec_table, spec_text)

# Mix reports with specs
report_extended <- create_report(report, spec_figure, spec_text2)
```

**Style a column**:
```r
spec <- add_style(spec, id = "my_style", s_font(bold = TRUE))
spec <- define_cols(spec, c(col1, col2), labelStyleRef = "my_style")
```

**Add content**:
```r
spec <- add_title(spec, "Title")
spec <- add_subtitle(spec, "Subtitle")
spec <- add_footnote(spec, "Note")
```

**Full pipeline (save + render)**:
```r
spec <- create_table(mtcars) |> add_title("Title")
report <- create_report(spec)
saved <- save_report(report, "demo.docx")
render_docx(
  spec_json = file.path(saved$metaPath, saved$spec_file),
  output_path = "output/demo.docx"
)
```



## Session Notes (Dec 20, 2025 - Extended create_report())

### Extended create_report() to Support Mixed Input Types
The `create_report()` function now accepts both `TFL_spec` and `TFL_report` objects for flexible composition:

**New Capability**: Combine previously generated reports with new specs
```r
# Create initial report
report1 <- create_report(spec1, spec2)

# Extend with new specs
final_report <- create_report(report1, spec3, spec4)
# Result: 4 specs combined in order-preserving manner
```

**6-Phase Processing Pipeline** in `create_report()`:
1. **Phase 1: Flatten inputs** - Extract specs from TFL_report objects while preserving keys
2. **Phase 2: Validate keys** - Reject duplicate spec keys (content duplicates)
3. **Phase 3: Consolidate styles** - Only for new TFL_spec objects (marked `is_new=TRUE`)
4. **Phase 4: Renumber docOrder & create dataRef** - Global sequential numbering (1, 2, 3, ...) and new dataRef for new specs
5. **Phase 5: Warn on dataRef duplicates** - Collect all warnings and issue once
6. **Phase 6: Build result** - Assemble final TFL_report with preserved key structure

**Key Design Decisions**:
- **Order preservation**: Input order determines final docOrder (1-based)
- **Selective consolidation**: Only new specs undergo style consolidation; pre-consolidated specs from reports are preserved as-is
- **Key preservation**: Report specs keep their original keys; new specs get keys as `<varname>_<hash>`
- **dataRef handling**: New specs get `<padded_docOrder>_<hash>` (e.g., `0001_abc123def456`); report dataRef values preserved unchanged
- **Duplicate detection**: Error on duplicate keys; warn on duplicate dataRef (may indicate shared data files)

**Implementation File**: [create_report.R](R/create_report.R) - `create_report()` function (~180 lines)

**Test Coverage** (20 comprehensive tests in test-07-create-report.R):
- Basic single/multiple specs, mixed reports + specs
- docOrder sequential validation (1, 2, 3, ...)
- dataRef creation format (`^\d{4}_[a-f0-9]{16}$`)
- Style consolidation for new specs only
- Style preservation from input reports
- Duplicate key detection (error)
- Duplicate dataRef detection (warning)
- Nested report combinations
- Multiple independent style consolidations

## Session Notes (Feb 27, 2026 — C++ Unit Tests)

### New C++ Test Infrastructure

Added a lightweight, framework-agnostic C++ test harness directly inside the package.

**Files created/modified:**

| File | Change |
|---|---|
| `src/cpp_tests.cpp` | New — 3 Rcpp-exported test functions (~440 lines) |
| `tests/testthat/test-18-cpp-units.R` | New — 24 `test_that` blocks (~290 lines) |
| `src/RcppExports.cpp` | Added 3 `RcppExport SEXP` wrappers |
| `src/init.cpp` | Added 3 entries to `CallEntries[]` |
| `R/RcppExports.R` | Added 3 `@keywords internal` R stubs |
| `src/Makevars` | Added `cpp_tests.cpp` to `SOURCES` |
| `src/Makevars.win` | Same as above for Windows |

**Harness design (`TestResult` struct in `cpp_tests.cpp`):**
- `check_eq(actual, expected, name)` — overloads for int64_t, int, size_t, string
- `check(bool, name, msg)` — boolean assertion
- `check_throw(fn, name)` — expects `std::exception` to be thrown
- `check_no_throw(fn, name)` — expects clean execution
- `to_list()` — returns `Rcpp::List(passed = char[], failed = "name: reason")`

**R-side runner pattern (`test-18-cpp-units.R`):**
```r
result <- cpp_test_units()
# Report every individual C++ assertion as its own expect_true / expect_false:
for (name in result$passed) expect_true(TRUE, label = name)
for (msg  in result$failed) {
  parts <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
  expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
}
```

**Run tests:**
```r
devtools::load_all()       # recompiles with cpp_tests.cpp
devtools::test(filter = "18")
```