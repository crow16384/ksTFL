# Tests for TFL Spec Initialization Functions
# Tests tfl_init(), .fill_spec_defaults(), .get_col_label(), .get_data_format()

test_that("tfl_init creates default Table spec with no arguments", {
  spec <- tfl_init()
  
  expect_s3_class(spec, "TFL_spec")
  expect_true(is.list(spec))
  expect_true(!is.null(spec$document))
  expect_true(!is.null(spec$attribs))
})

test_that("tfl_init accepts valid docType values", {
  spec_table <- tfl_init(docType = "Table")
  spec_listing <- tfl_init(docType = "Listing")
  spec_figure <- tfl_init(docType = "Figure")
  
  expect_s3_class(spec_table, "TFL_spec")
  expect_s3_class(spec_listing, "TFL_spec")
  expect_s3_class(spec_figure, "TFL_spec")
})

test_that("tfl_init rejects invalid docType", {
  expect_error(
    tfl_init(docType = "InvalidType"),
    class = "error"
  )
})

test_that("tfl_init with Figure docType rejects data parameter", {
  expect_error(
    tfl_init(data = mtcars, docType = "Figure"),
    class = "cli_error"
  )
})

test_that("tfl_init with Table docType accepts data frame", {
  spec <- tfl_init(data = mtcars, docType = "Table")
  
  expect_s3_class(spec, "TFL_spec")
  expect_true(!is.null(spec$dataRef))
})

test_that("tfl_init with Table docType rejects NULL data", {
  expect_error(
    tfl_init(data = NULL, docType = "Table"),
    class = "cli_error"
  )
})

test_that("tfl_init accepts docPrefix argument", {
  spec <- tfl_init(docPrefix = "Table 1.1", docType = "Table", data = mtcars)
  
  expect_s3_class(spec, "TFL_spec")
  # docPrefix should be stored in spec (implementation detail)
})

test_that("tfl_init with cols parameter filters columns", {
  # Using tidyselect expression
  spec <- tfl_init(
    data = mtcars,
    docType = "Table",
    cols = c(mpg, cyl, hp)
  )
  
  expect_s3_class(spec, "TFL_spec")
  # Column definitions should be created
  expect_true(is.list(spec$columns))
})

test_that("tfl_init rejects non-data-frame data input", {
  expect_error(
    tfl_init(data = list(a = 1, b = 2), docType = "Table"),
    class = "cli_error"
  )
})

test_that("tfl_init with empty data frame creates appropriate spec", {
  empty_df <- data.frame()
  spec <- tfl_init(data = empty_df, docType = "Table")
  
  expect_s3_class(spec, "TFL_spec")
})

test_that("tfl_init initializes all required top-level structures", {
  spec <- tfl_init()
  
  expect_true(!is.null(spec$document))
  expect_true(!is.null(spec$attribs))
  expect_true(is.list(spec$headers))
  expect_true(is.list(spec$footers))
  expect_true(is.list(spec$columns))
})
