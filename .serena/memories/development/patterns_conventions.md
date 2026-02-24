# Development Patterns and Conventions

## Naming Conventions
- Internal functions: dot prefix (.function_name)
- Constants: .const_ prefix
- Column iterator: col_idx (not var or i)
- Double quotes throughout, not single
- Numeric suffixes: 1L not 1 for type safety

## Error Handling
- Always use cli_abort() with structured messages: main, x= (problem), i= (info/remediation)
- Use cli_warn() for warnings, never base warning()
- Use checkmate for argument validation with .var.name parameter

## Validation
- checkmate for type assertions: assert_data_frame, assert_string, assert_character, assert_class, assert_names
- .validate_params() for schema property validation
- .validate_enum(), .validate_pattern(), .validate_color() for value constraints
- Validate early before processing/mutating data

## Style Context System
- .set_context() pushes to stack, .clear_context() pops
- .assert_context() traverses parent frames + fallback to package stack
- Enforces: s_borders() only in s_table_style(), s_spacing()/s_indents() only in s_paragraph()

## S3 Dispatch
- add_style, add_body_text, add_header, add_footer, set_page_style have methods for TFL_spec, TFL_options, default
- Registered in NAMESPACE with S3method() directives
- f_combine uses c.tfl_style_combine S3 method

## Constants Centralization  
- All magic strings -> constants in constants.R
- .const_schema_keywords for JSON Schema keywords
- .const_schema_types for JSON types
- .const_json_pointer_* for JSON pointer operations

## Testing
- testthat framework, 18 test files
- Numbered test-NN-* pattern
- Tests cover: creation, columns, styles, content, stubs, headers/footers, options, reports, edge cases, integration, serialization, width recalc, report writer, compute_cols, stylerows, layout guessing

## Key Gotchas (from copilot-instructions.md)
- Pipe placeholder _ reserved in R 4.1+
- switch(): no .default, use unnamed block for defaults
- Use [[ not [ for extracting atomic vectors
- Always check is.atomic() before as.character() on unknown types
- After editing functions, R may cache old definitions (devtools::reload_all)
- R is NOT installed on dev machine - don't try to run R code
- Don't commit to git without user request
- Use Russian CRAN mirrors for package installation
