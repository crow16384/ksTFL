# Development Patterns and Conventions

## R Naming Conventions
- Internal functions: dot prefix (.function_name)
- Constants: .const_ prefix
- Column iterator: col_idx (not var or i)
- Double quotes throughout, not single
- Numeric suffixes: 1L not 1 for type safety

## C++ Naming Conventions
- Namespace: kstfl
- snake_case for functions and variables
- PascalCase for class/struct names (Renderer, XmlWriter, PageSlice)
- trailing underscore for member variables (start_tag_open_, config_)
- Header guards: KSTFL_MODULENAME_H

## Error Handling (R)
- Always use cli_abort() with structured messages: main, x= (problem), i= (info/remediation)
- Use cli_warn() for warnings, never base warning()
- Use checkmate for argument validation with .var.name parameter

## Error Handling (C++)
- throw RenderError("...") for all renderer errors (inherits std::runtime_error)
- Rcpp::stop() in rcpp_bindings.cpp to propagate errors to R
- Verbose logging via config_.verbose guarded std::cerr output in renderer.cpp

## Validation (R)
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
- All magic strings → constants in constants.R
- .const_schema_keywords for JSON Schema keywords
- .const_schema_types for JSON types
- .const_json_pointer_* for JSON pointer operations

## Argument Resolution Pattern (R)
- For call objects: use match.call(definition=fn, call=call_obj) to properly resolve positional + named args
- Don't rely on rlang::call_args() with positional indices when optional args may be skipped
- See .parse_action_addrow() for reference implementation

## Testing
- testthat framework, 19 test files (setup + 18 numbered)
- Numbered test-NN-* pattern
- Tests cover: creation, columns, styles, content, stubs, headers/footers, options, reports, edge cases, integration, serialization, width recalc, report writer, compute_cols, stylerows, layout guessing
- 806 passing tests total
- R code runs via Docker: `docker exec kstfl-r bash -c "cd /home/rstudio/ksTFL && ..."`

## Key Gotchas (R)
- Pipe placeholder _ reserved in R 4.1+
- switch(): no .default, use unnamed block for defaults
- Use [[ not [ for extracting atomic vectors
- Always check is.atomic() before as.character() on unknown types
- After editing functions, R may cache old definitions (devtools::reload_all)
- R is NOT installed on dev machine — don't try to run R code directly
- Don't commit to git without user request
- Use Russian CRAN mirrors for package installation
- text_width("") returns empty vector — must check length before max()

## Key Gotchas (C++) 
- XmlWriter: NEVER call attribute() after self_closing_element() — it doesn't set start_tag_open_
- Always use start_element() + attribute() + end_element() pattern for elements with attributes
- self_closing_element() is only for elements with NO attributes
- Data file paths: save_report writes "0001_xxx.json" but JSON spec stores "0001_xxx" — renderer must try .json extension fallback
- Column width "%": Length::parse("5%") needs reference_emu — defer to style_resolver where table_width is known
- nlohmann/json: use get_opt_str/get_opt_int helpers, not direct access for optional fields

## Package Build
- devtools::install(quick=TRUE) for quick rebuild
- devtools::test() for running full test suite
- Full build produces src/ksTFL.so (compiled from 15 .cpp files)
