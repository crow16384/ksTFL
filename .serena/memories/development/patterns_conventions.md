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

## Testing (R)
- testthat framework, 20 test files (setup-data.R + test-01 through test-18)
- Numbered test-NN-description pattern
- Tests cover: creation, columns, styles, content, stubs, headers/footers, options, reports, edge cases, integration, serialization, width recalc, report writer, compute_cols, stylerows, layout guessing, optimization fixes, ggplot figure, cpp units
- 806+ passing R tests total
- R code runs via Docker: `docker exec kstfl-r bash -c "cd /home/rstudio/ksTFL && ..."`

## C++ Unit Testing (added Feb 27, 2026)
Lightweight test harness inside src/cpp_tests.cpp — no external framework needed.

### TestResult struct pattern:
```cpp
// In src/cpp_tests.cpp — add a new [[Rcpp::export]] function:
// [[Rcpp::export]]
Rcpp::List cpp_test_<module>() {
    TestResult t;
    t.check_eq(actual, expected, "test name");          // int64_t, int, size_t, string overloads
    t.check(bool_expr, "name", "fail reason");          // boolean assertion
    t.check_throw([](){ /* must throw */ }, "name");    // expects std::exception
    t.check_no_throw([](){ /* must not throw */ }, "name");
    return t.to_list();  // list(passed=character[], failed="name: reason")
}
```

### 4-step registration for new C++ test suite:
1. Add `[[Rcpp::export]]` function in `src/cpp_tests.cpp`
2. Add `RcppExport SEXP _ksTFL_<name>()` wrapper in `src/RcppExports.cpp`
3. Add `{"_ksTFL_<name>", (DL_FUNC)&_ksTFL_<name>, 0}` entry in `src/init.cpp` CallEntries[]
4. Add `@keywords internal` R stub in `R/RcppExports.R` calling `.Call(\`_ksTFL_<name>\`)`
5. Add `test_that()` blocks in `tests/testthat/test-18-cpp-units.R`

### R-side runner pattern:
```r
result <- cpp_test_<module>()
for (name in result$passed) expect_true(TRUE, label = name)
for (msg  in result$failed) {
  parts <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
  expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
}
```

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
- OOXML highlight: use `<w:shd w:val="clear" w:color="auto" w:fill="HEX"/>` on runs — NOT `<w:highlight>` (requires named colors)
- Row heights: Paginator::paginate() is the ONLY place that sets row.measured_height — do not add measurement in renderer.cpp
- Format strings: always validate via is_safe_numeric_format() before snprintf; detect integer specifier by scanning for last conversion char
- TextGroup::style_refs is a vector — all refs merged in order by style_resolver and docx_emitter
- TextMeasurer is non-copyable (owns hb_buf_ resource); never copy, always pass by reference

## Package Build
- devtools::install(quick=TRUE) for quick rebuild
- devtools::test() for running full test suite
- Full build produces src/ksTFL.so (compiled from 15+ .cpp files)
