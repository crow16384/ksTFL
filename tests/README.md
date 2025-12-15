# ksTFL Test Suite Documentation

## Overview

The ksTFL package includes a comprehensive testthat unit test suite covering all publicly exported functions and their parameters. The tests validate functionality, error handling, and integration across the package.

## Test Organization

Tests are organized into logical groups within `tests/testthat/`:

### 1. **test-0_setup.R** - Test Environment Configuration
- Verifies that testthat, ksTFL, and cli packages are properly loaded
- Ensures test environment is ready before running other tests

### 2. **test-spec_initialization.R** - Spec Initialization Functions
**Tests:** `tfl_init()`

**Coverage:**
- Default specification creation with no arguments
- Valid docType values: "Table", "Listing", "Figure"
- Invalid docType rejection
- Data parameter validation
  - Figure docType rejects data
  - Table docType requires data
  - Non-data-frame inputs rejected
- Column selection with tidyselect expressions
- docPrefix parameter handling
- Empty data frame handling
- All required top-level structures initialized

**Key Test Cases:**
- 11 tests covering initialization scenarios
- Validates both success and failure paths
- Tests tidyselect column filtering

### 3. **test-style_modifiers.R** - Style Specification Functions
**Tests:** `s_font()`, `s_spacing()`, `s_indents()`, `s_paragraph()`, `s_border()`, `s_borders()`, `s_table_style()`, `s_margins()`, `s_page()`, via `add_style()`

**Coverage:**
- Font properties: name, size, bold, italic, underline, color
- Spacing: before, after, line_spacing with units validation
- Indentation: left, right, first_line
- Paragraph: alignment, keep_together
- Borders: position, color, width, style
- Table cell: background_color, vertical_align
- Margins: top, bottom, left, right
- Page: size, orientation
- Parameter validation (type checking, enum values)
- Auto-ID generation
- Last-win merge strategy for multiple calls
- Invalid modifier rejection

**Key Test Cases:**
- 25+ tests covering all style modifiers
- Validates parameter types and valid values
- Tests modifier merging behavior
- Tests auto-generated IDs

### 4. **test-context_manipulation.R** - Context Functions
**Tests:** `add_title()`, `add_subtitle()`, `add_footnote()`, `add_body_text()`, `add_header()`, `add_footer()`, `add_stub_column()`, `set_document()`, `set_document_style()`, `define_cols()`, `c_format()`

**Coverage:**
- Title/subtitle/footnote/body text addition
- Header/footer management
- Stub column definition with auto-order
- Document property setting
- Document style reference setting
- Column definition and format specification
- Context requirement enforcement
- Parameter options (displayLevel, placement, etc.)
- Auto-ID generation
- Accumulation of multiple items

**Key Test Cases:**
- 21+ tests for context-dependent operations
- Validates context requirements
- Tests parameter options and defaults
- Tests accumulation behavior with multiple calls

### 5. **test-package_settings.R** - Settings Management
**Tests:** `tfl_get_settings()`, `tfl_get_setting()`, `tfl_set_settings()`, `tfl_reset_settings()`

**Coverage:**
- Settings retrieval (all and individual)
- Required settings fields
- Settings update with single/multiple values
- Settings merging with existing values
- Default restoration
- Setting persistence across calls
- Integration with spec initialization

**Key Test Cases:**
- 15+ tests for settings management
- Tests atomic and bulk operations
- Validates persistence and defaults
- Tests integration with initialization

### 6. **test-validation_and_errors.R** - Validation and Error Handling
**Tests:** All validation functions, error conditions, and error message capture

**Coverage:**
- Auto-ID generation with NULL handling
- Auto-stub order calculation
- Pattern validation (spacing units, alignment values)
- Type validation (logical, numeric, character)
- Enum validation (alignment, page size, etc.)
- Column and data format detection
- Date/time type handling
- Data frame requirements
- Non-existent column handling
- Multiple validation errors
- cli error/warning message capture
- Spec consistency across pipeline operations

**Key Test Cases:**
- 30+ tests for validation and error handling
- Special handling for cli package message capture
- Tests error messages and guidance
- Tests pipeline consistency

## Running Tests

### Run All Tests
```r
# From R console
devtools::test()

# Or using testthat directly
testthat::test_package("ksTFL")
```

### Run Specific Test File
```r
testthat::test_file("tests/testthat/test-spec_initialization.R")
```

### Run Tests with Specific Pattern
```r
testthat::test_dir("tests/testthat", filter = "settings")
```

### Run Single Test
```r
testthat::test_that("tfl_init creates default Table spec with no arguments", {
  spec <- tfl_init()
  expect_s3_class(spec, "TFL_spec")
})
```

## Special Considerations

### CLI Package Message Capture

The ksTFL package uses the `cli` package for formatted error and warning messages. Unlike base R's `stop()` and `warning()`, cli messages must be captured differently:

**Capturing CLI Errors:**
```r
# cli errors can be caught with expect_error()
expect_error(
  tfl_init(docType = "Invalid"),
  class = "cli_error"
)
```

**Capturing CLI Warnings:**
```r
# cli warnings can be caught with expect_warning()
expect_warning(
  tfl_init(data = date_df, docType = "Table"),
  regexp = "ISO|conversion"
)
```

**Pattern for Message Content:**
```r
# When you need to check message content:
expect_error(
  add_style(spec, "invalid"),
  class = "cli_error"
)
# The error message will be formatted by cli but can be checked in custom matchers
```

### Test Fixtures and Setup

The `setup.R` file provides:
- `setup_package()`: Runs before all tests
- `teardown_package()`: Runs after all tests
- Automatic settings reset to defaults between tests

This ensures tests don't interfere with each other.

## Test Coverage Summary

| Function | Tests | Coverage |
|----------|-------|----------|
| tfl_init | 11 | Initialization, validation, error handling |
| Style modifiers | 25+ | All 9 modifiers, parameters, merging |
| Context functions | 21+ | All 11 context functions, validation |
| Settings functions | 15+ | CRUD operations, persistence |
| Validation/Errors | 30+ | Auto-ID, patterns, types, integration |
| **Total** | **180+** | **All exported functions** |

## Adding New Tests

When adding new functions or parameters:

1. **Determine test category**: Is it initialization, styling, context, or settings?
2. **Add test file**: Use `test-` prefix in filename
3. **Write positive tests**: Test expected behavior
4. **Write negative tests**: Test error conditions
5. **Document special cases**: Add comments for non-obvious tests
6. **Run full suite**: Ensure no regressions

### Test Template
```r
test_that("function does expected action", {
  # Setup
  data <- create_test_data()
  
  # Execute
  result <- function_under_test(data)
  
  # Verify
  expect_true(condition)
  expect_equal(result$field, expected_value)
})
```

## Continuous Integration

To run tests automatically on commit:

```r
# Use devtools hooks
usethis::use_github_actions()
```

This creates workflow files that run `devtools::test()` on push.

## Troubleshooting Tests

### Test Failure Patterns

**Pattern validation failures:**
- Check unit abbreviations (pt, cm, in, mm)
- Verify alignment values match enum

**Type validation failures:**
- Ensure logical values are TRUE/FALSE, not "TRUE"/"FALSE"
- Check numeric vs character parameters

**Context failures:**
- Ensure test uses piped spec from tfl_init()
- Verify functions requiring context are within proper context

**Settings persistence issues:**
- Call tfl_reset_settings() after tests that modify settings
- Use setup/teardown for automatic cleanup

## Related Documentation

- See [CONTRIBUTING.md](../CONTRIBUTING.md) for development guidelines
- See [README.md](../README.md) for package overview
- See source code Roxygen comments for function-level documentation
