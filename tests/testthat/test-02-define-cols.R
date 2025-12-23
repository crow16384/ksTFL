# ============================================================================
# Test: Column Definition with define_cols()
# ============================================================================

test_that("define_cols() accepts single column", {
  spec <- create_table(test_df)
  spec <- define_cols(spec, id, type = "numeric", format = "%d1")
  
  # Access format object structure correctly
  expect_equal(spec$columns$id$format$type, "numeric")
  expect_equal(spec$columns$id$format$format, "%d1")
})

test_that("define_cols() accepts multiple columns with c()", {
  spec <- create_table(test_df)
  spec <- define_cols(spec, c(id, value, ratio), type = "numeric", format = "0.00")
  
  expect_equal(spec$columns$id$format$format, "0.00")
  expect_equal(spec$columns$value$format$format, "0.00")
  expect_equal(spec$columns$ratio$format$format, "0.00")
})

test_that("define_cols() recycles single parameter to all columns", {
  spec <- create_table(test_df)
  spec <- define_cols(spec, c(id, value, ratio), label = "Numeric Column")
  
  expect_equal(spec$columns$id$label, "Numeric Column")
  expect_equal(spec$columns$value$label, "Numeric Column")
  expect_equal(spec$columns$ratio$label, "Numeric Column")
})

test_that("define_cols() accepts per-column parameters (length matching)", {
  spec <- create_table(test_df)
  spec <- define_cols(
    spec, 
    c(id, value, ratio), 
    label = c("ID", "Value", "Ratio")
  )
  
  expect_equal(spec$columns$id$label, "ID")
  expect_equal(spec$columns$value$label, "Value")
  expect_equal(spec$columns$ratio$label, "Ratio")
})

test_that("define_cols() rejects mismatched parameter lengths", {
  spec <- create_table(test_df)
  
  expect_error(
    define_cols(spec, c(id, value, ratio), label = c("A", "B")),
    "must have length 1 or"
  )
})

test_that("define_cols() sets type parameter in format object", {
  spec <- create_table(test_df)
  spec <- define_cols(spec, c(id, value), type = "numeric")
  
  expect_equal(spec$columns$id$format$type, "numeric")
  expect_equal(spec$columns$value$format$type, "numeric")
  
  expect_error(define_cols(spec, c(id, value), type = "error"), 'Allowed: "string" and "numeric"')
})

test_that("define_cols() sets format parameter in format object", {
  spec <- create_table(test_df)
  spec <- define_cols(spec, value, format = "0.0000")
  
  expect_equal(spec$columns$value$format$format, "0.0000")
})

test_that("define_cols() sets missings in format object", {
  spec <- create_table(test_df)
  spec <- define_cols(spec, c(value, ratio), missings = "N/A")
  
  expect_equal(spec$columns$value$format$missings, "N/A")
  expect_equal(spec$columns$ratio$format$missings, "N/A")
})

test_that("define_cols() sets colWidth in format object", {
  spec <- create_table(test_df)
  spec <- define_cols(spec, id, colWidth = "15%")
  
  # When autoColWidth=TRUE (default), colWidth gets normalized and rounded
  # 15% + other auto_weights normalized to 100% results in ~15.1%
  expect_true(!is.null(spec$columns$id$format$colWidth))
  expect_match(spec$columns$id$format$colWidth, "^[0-9.]+%$")
  
  # Invalid colWidth should error
  expect_error(define_cols(spec, id, colWidth = "no unit"), "Invalid")
})

test_that("define_cols() sets isID parameter", {
  spec <- create_table(test_df)
  spec <- define_cols(spec, id, isID = TRUE)
  
  expect_true(spec$columns$id$isID)
})

test_that("define_cols() sets isColBreak parameter", {
  spec <- create_table(test_df)
  spec <- define_cols(spec, group, isColBreak = TRUE)
  
  expect_true(spec$columns$group$isColBreak)
})

test_that("define_cols() sets labelStyleRef parameter", {
  spec <- create_table(test_df)
  spec <- define_cols(spec, id, labelStyleRef = "header_bold")
  
  expect_equal(spec$columns$id$labelStyleRef, "header_bold")
  
  spec <- define_cols(spec, id, labelStyleRef = f_combine("header_bold", "font_bold"))
  
  expect_equal(length(spec$columns$id$labelStyleRef), 2)
  
})

test_that("define_cols() sets valueStyleRef in format object", {
  spec <- create_table(test_df)
  spec <- define_cols(spec, value, valueStyleRef = "numeric_right")
  
  # valueStyleRef can be in format object when set via define_cols
  expect_true(!is.null(spec$columns$value$format$valueStyleRef))
  
  spec <- define_cols(spec, id, valueStyleRef = f_combine("header_bold", "font_bold"))
  
  expect_equal(length(spec$columns$id$format$valueStyleRef), 2)
})

test_that("define_cols() chains multiple calls", {
  spec <- create_table(test_df)
  spec <- define_cols(spec, id, type = "numeric")
  spec <- define_cols(spec, group, type = "string")
  spec <- define_cols(spec, value, label = "Value Override")
  
  expect_equal(spec$columns$id$format$type, "numeric")
  expect_equal(spec$columns$group$format$type, "string")
  expect_equal(spec$columns$value$label, "Value Override")
})

test_that("define_cols() with colWidth preserves existing type", {
  # Issue: https://github.com/...
  # When calling define_cols() with colWidth but no type parameter,
  # the previously set type should be preserved (not dropped)
  spec <- create_table(test_df)
  
  # First: set type and label
  spec <- define_cols(spec, id, type = "numeric", label = "ID")
  expect_equal(spec$columns$id$format$type, "numeric")
  expect_equal(spec$columns$id$label, "ID")
  
  # Second: set colWidth only
  spec <- define_cols(spec, id, colWidth = "10%")
  
  # Type should be preserved
  expect_equal(spec$columns$id$format$type, "numeric", 
               info = "type field should not be dropped when specifying colWidth")
  expect_equal(spec$columns$id$label, "ID", 
               info = "label should also be preserved")
  
  # colWidth should be set
  expect_true(!is.null(spec$columns$id$format$colWidth))
})

