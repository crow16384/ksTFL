# ============================================================================
# Test: Basic Document Creation (create_table, create_text, create_figure)
# ============================================================================

test_that("create_table() initializes with default parameters", {
  spec <- create_table(large_df)
  
  expect_s3_class(spec, "TFL_spec")
  expect_equal(spec$document$docType, "Table")
  expect_true(spec$document$hasData)
  expect_equal(length(spec$columns), length(names(large_df)))
  # Page defaults come from template, not spec — bare spec has no page override
  expect_null(spec$attribs$documentStyle$page)
  expect_equal(spec$columns$idx$format$type, 'numeric')
  expect_true(length(spec$bodyText) > 0)
  
})

test_that("create_table() accepts tidyselect column selection", {
  spec <- create_table(test_df, cols = c(id, group, value))
  
  expect_equal(length(spec$columns), 3)
  expect_true(all(c("id", "group", "value") %in% names(spec$columns)))
  
  spec <- create_table(test_df, 1:3)
  expect_equal(length(spec$columns), 3)
  
  spec <- create_table(test_df, -1)
  expect_equal(length(spec$columns), ncol(test_df)-1)


})


test_that("create_table() auto-detects column types in format object", {
  spec <- create_table(test_df)
  
  # format is a nested object with type, format, missings, etc.
  expect_equal(spec$columns$id$format$type, "numeric")
  expect_equal(spec$columns$value$format$type, "numeric")
  expect_equal(spec$columns$group$format$type, "string")
  expect_equal(spec$columns$name$format$type, "string")
})

test_that("create_table() auto-generates format objects for columns", {
  spec <- create_table(test_df)
  
  # All columns should have a format object with type property
  for (col in spec$columns) {
    expect_is(col$format, "list")
    expect_true(!is.null(col$format$type))
    expect_true(col$format$type %in% c("numeric", "string"))
  }
})


test_that("create_text() creates text-only spec", {
  spec <- create_text()
  
  expect_s3_class(spec, "TFL_spec")
  expect_equal(spec$document$docType, "Text")
  expect_false(spec$document$hasData)
  expect_length(spec$columns, 0)
})

test_that("create_figure() creates figure spec from valid image path", {
  spec <- create_figure(test_image_path)
  
  expect_s3_class(spec, "TFL_spec")
  expect_equal(spec$document$docType, "Figure")
  expect_false(spec$document$hasData)
  expect_true(.is_readable_file(spec$.metadata$filePath))
})

test_that("create_figure() rejects invalid image path", {
  expect_error(
    create_figure("/nonexistent/path/to/image.png"),
    "requires a readable file path"
  )
})

