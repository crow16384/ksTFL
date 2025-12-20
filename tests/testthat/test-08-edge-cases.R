# ============================================================================
# Test: Edge Cases and Boundary Conditions
# ============================================================================

test_that("create_table() handles all-NA numeric column", {
  df_with_na <- data.frame(x = c(NA_integer_, NA, NA))
  spec <- create_table(df_with_na)
  
  expect_equal(spec$columns$x$format$type, "numeric")
})

test_that("create_table() handles all-NA character column", {
  df_with_na <- data.frame(x = c(NA_character_, NA_character_, NA_character_))
  spec <- create_table(df_with_na)
  
  expect_equal(spec$columns$x$format$type, "string")
})

test_that("create_table() handles empty data frame", {
  df_empty <- data.frame()
  expect_error(create_table(df_empty), "No columns selected for the table")
  
})

test_that("create_table() handles single row data frame", {
  df_single <- data.frame(id = 1, name = "A")
  spec <- create_table(df_single)
  
  expect_equal(length(spec$columns), 2)
  expect_equal(spec$columns$id$format$type, "numeric")
})

test_that("create_table() handles single column data frame", {
  df_single_col <- data.frame(x = 1:10)
  spec <- create_table(df_single_col)
  
  expect_equal(length(spec$columns), 1)
})

test_that("add_title() with very long text", {
  spec <- create_text()
  long_text <- paste(rep("This is a very long title ", 100), collapse = "")
  spec <- add_title(spec, long_text)
  
  expect_equal(nchar(spec$titles[[1]]$text), nchar(long_text))
})

test_that("add_body_text() with special characters and UTF-8", {
  spec <- create_text()
  spec <- add_body_text(spec, "Special: © ™ € 中文 日本語")
  
  expect_true(grepl("©", spec$bodyText[[1]]$text))
  expect_true(grepl("中文", spec$bodyText[[1]]$text))
})

test_that("define_cols() with single column recycling", {
  spec <- create_table(test_df)
  spec <- define_cols(spec, c(id, value, ratio), label = "Same Label")
  
  expect_equal(spec$columns$id$label, "Same Label")
  expect_equal(spec$columns$value$label, "Same Label")
  expect_equal(spec$columns$ratio$label, "Same Label")
})

test_that("define_cols() with per-column recycling", {
  spec <- create_table(test_df)
  spec <- define_cols(spec, c(id, value), label = c("L1", "L2"))
  
  expect_equal(spec$columns$id$label, "L1")
  expect_equal(spec$columns$value$label, "L2")
})

test_that("add_style() creates unique IDs for auto-generated styles", {
  spec <- create_text()
  spec <- add_style(spec, 'style', s_font(bold = TRUE))
  spec <- add_style(spec, 'style', s_font(italic = TRUE))
  
  style_ids <- names(spec$attribs$styles)
  expect_equal(length(unique(style_ids)), length(style_ids))
})

test_that("create_report() handles large data frame tables", {
  large_df <- data.frame(x = 1:10000, y = rnorm(10000))
  spec <- create_table(large_df)
  
  report <- create_report(spec)
  
  expect_equal(length(report), 1)
  expect_equal(length(report[[1]]$columns), 2)
})

test_that("add_header() with empty strings", {
  spec <- create_text()
  spec <- add_header(spec, c("", "", ""))
  
  expect_equal(length(spec$headers[[1]]), 3)
})



