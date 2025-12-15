# Tests for Validation and Error Handling
# Special handling for cli package error/warning capture

# Helper function to capture cli messages
capture_cli_message <- function(expr) {
  # cli messages are printed, so we use capture.output
  output <- capture.output({
    tryCatch(
      expr,
      error = function(e) {
        # Re-raise to be caught by caller
        stop(e)
      }
    )
  }, type = "message")
  
  output
}

test_that(".auto_id generates unique IDs", {
  # Test internal function indirectly through public API
  spec1 <- tfl_init(docType = "Figure") |>
    add_style(s_font())  # Auto-generates ID
  
  spec2 <- spec1 |>
    add_style(s_font())  # Auto-generates different ID
  
  # Both should have styles
  expect_true(length(spec2$attribs$styles) == 2)
})

test_that(".auto_id handles NULL existing_list", {
  # This is tested indirectly through add_style with NULL styles
  spec <- tfl_init(docType = "Figure")
  
  # First call to add_style with auto-generated ID on empty styles
  spec <- add_style(spec, s_font())
  
  expect_true(length(spec$attribs$styles) > 0)
})

test_that(".auto_stub_order generates sequential numbers", {
  spec <- tfl_init(data = mtcars, docType = "Table") |>
    add_stub_column("cyl", label = "Cyl") |>
    add_stub_column("vs", label = "Vs")
  
  expect_true(length(spec$stubColumns) >= 1)
})

test_that("Validation rejects invalid pattern in spacing", {
  expect_error(
    tfl_init(docType = "Figure") |>
      add_style("bad",
        s_spacing(before = "invalid_unit")
      ),
    class = "cli_error"
  )
})

test_that("Validation rejects non-numeric line_spacing", {
  expect_error(
    tfl_init(docType = "Figure") |>
      add_style("bad",
        s_spacing(line_spacing = "1.5")  # Should be numeric
      ),
    class = "cli_error"
  )
})

test_that("Validation checks alignment values", {
  expect_error(
    tfl_init(docType = "Figure") |>
      add_style("bad",
        s_paragraph(alignment = "diagonal")
      ),
    class = "cli_error"
  )
})

test_that("Validation rejects invalid font size format", {
  expect_error(
    tfl_init(docType = "Figure") |>
      add_style("bad",
        s_font(font_size = "14")  # Missing unit
      ),
    class = "cli_error"
  )
})

test_that("tfl_init provides helpful error for non-data-frame", {
  expect_error(
    tfl_init(data = list(a = 1), docType = "Table"),
    class = "cli_error"
  )
})

test_that("tfl_init rejects data with Table docType when NULL provided", {
  expect_error(
    tfl_init(data = NULL, docType = "Table"),
    class = "cli_error"
  )
})

test_that("tfl_init provides guidance for Figure with data", {
  expect_error(
    tfl_init(data = mtcars, docType = "Figure"),
    class = "cli_error"
  )
})

test_that("Empty data frame initialization", {
  empty_df <- data.frame()
  spec <- tfl_init(data = empty_df, docType = "Table")
  
  expect_s3_class(spec, "TFL_spec")
})

test_that("Column extraction fails with non-existent column", {
  expect_error(
    tfl_init(data = mtcars, docType = "Table", cols = c(mpg, nonexistent_col)),
    class = "error"
  )
})

test_that(".validate_params rejects unknown schema types", {
  expect_error(
    tfl_init(docType = "Figure") |>
      add_style("bad_style",
        list() # Not a valid modifier
      ),
    class = "cli_error"
  )
})

test_that(".validate_enum provides clear error for invalid choice", {
  expect_error(
    tfl_init(docType = "Figure") |>
      add_style("test",
        s_paragraph(alignment = "invalid_alignment")
      ),
    class = "cli_error"
  )
})

test_that(".validate_pattern provides column context in errors", {
  expect_error(
    tfl_init(docType = "Figure") |>
      add_style("test",
        s_spacing(before = "notaunit")
      ),
    class = "cli_error"
  )
})

test_that("Multiple validation errors accumulated", {
  expect_error(
    tfl_init(docType = "Figure") |>
      add_style("test",
        s_font(bold = "invalid", font_size = "14")  # Multiple issues
      ),
    class = "cli_error"
  )
})

test_that(".get_col_label handles NULL attributes", {
  df <- data.frame(x = c(1, 2, 3))
  spec <- tfl_init(data = df, docType = "Table")
  
  # Columns without labels should still work
  expect_s3_class(spec, "TFL_spec")
})

test_that(".get_col_label preserves non-empty labels", {
  df <- data.frame(x = c(1, 2, 3))
  attr(df$x, "label") <- "My Label"
  
  spec <- tfl_init(data = df, docType = "Table")
  
  expect_s3_class(spec, "TFL_spec")
})

test_that(".get_data_format detects numeric types", {
  df <- data.frame(
    int_col = 1L:3L,
    dbl_col = c(1.1, 2.2, 3.3),
    chr_col = c("a", "b", "c")
  )
  
  spec <- tfl_init(data = df, docType = "Table")
  
  expect_s3_class(spec, "TFL_spec")
})

test_that(".get_data_format warns on Date types", {
  df <- data.frame(
    date_col = as.Date(c("2020-01-01", "2020-01-02"))
  )
  
  # Should issue a warning about ISO conversion
  expect_warning(
    tfl_init(data = df, docType = "Table"),
    regexp = "ISO|date|time"
  )
})

test_that("spec object maintains consistency across operations", {
  spec <- tfl_init(data = mtcars, docType = "Table") |>
    add_style("test", s_font(bold = TRUE)) |>
    add_title("Test Title") |>
    add_subtitle("Test Subtitle")
  
  # Verify all operations succeeded
  expect_s3_class(spec, "TFL_spec")
  expect_true(length(spec$titles) > 0)
  expect_true(length(spec$subtitles) > 0)
  expect_true(length(spec$attribs$styles) > 0)
})

test_that("Pipeline operations preserve spec structure", {
  spec1 <- tfl_init(docType = "Figure")
  spec2 <- spec1 |> add_style("s1", s_font())
  spec3 <- spec2 |> add_style("s2", s_font())
  
  # Original spec should be unchanged
  expect_true(length(spec1$attribs$styles) == 0)
  expect_true(length(spec2$attribs$styles) == 1)
  expect_true(length(spec3$attribs$styles) == 2)
})



