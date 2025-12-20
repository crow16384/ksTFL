# ============================================================================
# Test: Report Creation and Style Consolidation
# ============================================================================

test_that("create_report() combines single spec", {
  spec <- create_table(test_df)
  
  report <- create_report(spec)
  
  expect_s3_class(report, "TFL_report")
  expect_is(report, "list")
  expect_equal(length(report), 1)
})

test_that("create_report() combines multiple specs", {
  table1 <- create_table(test_df)
  table2 <- create_text()
  
  report <- create_report(table1, table2)
  
  expect_equal(length(report), 2)
})

test_that("create_report() keys specs by variable name and hash", {
  spec1 <- create_table(test_df)
  spec2 <- create_text()
  
  report <- create_report(spec1, spec2)
  
  keys <- names(report)
  expect_true(length(keys) == 2)
  # Keys should contain the variable names
  expect_true(any(grepl("spec1", keys)))
  expect_true(any(grepl("spec2", keys)))
})

test_that("create_report() sets docOrder", {
  spec1 <- create_table(test_df)
  spec2 <- create_text()
  spec3 <- create_figure(filepath = test_image_path)
  
  report <- create_report(spec1, spec2, spec3)
  
  expect_equal(report[[1]]$document$docOrder, 1)
  expect_equal(report[[2]]$document$docOrder, 2)
  expect_equal(report[[3]]$document$docOrder, 3)
})

test_that("create_report() sets dataRef", {
  spec1 <- create_table(test_df)
  spec2 <- create_text()
  
  report <- create_report(spec1, spec2)
  
  # dataRef should be padded order with hash
  expect_true(grepl("^0001_", report[[1]]$dataRef))
  expect_true(grepl("^0002_", report[[2]]$dataRef))
})

test_that("create_report() validates all inputs are TFL_spec", {
  spec <- create_table(test_df)
  
  expect_error(
    create_report(spec, "not_a_spec"),
    "must be of class TFL_spec"
  )
})

test_that("create_report() requires at least one spec", {
  expect_error(
    create_report(),
    "at least one|requires"
  )
})

test_that("create_report() consolidates style combinations", {
  spec <- create_table(test_df)
  spec <- add_style(spec, id = "style1", s_font(bold = TRUE))
  spec <- add_style(spec, id = "style2", s_font(italic = TRUE))
  # Apply combination of styles to column
  spec <- define_cols(spec, id, labelStyleRef = c("style1", "style2"))
  
  report <- create_report(spec)
  spec_result <- report[[1]]
  
  # After consolidation, combined reference should be replaced with hash or preserved
  expect_true(!is.null(spec_result$columns$id$labelStyleRef))
})

test_that("create_report() with many specs", {
  specs <- lapply(1:3, function(i) {
    create_text()
  })
  
  report <- create_report(specs[[1]], specs[[2]], specs[[3]])
  
  expect_equal(length(report), 3)
  expect_true(all(vapply(report, function(x) inherits(x, "TFL_spec"), logical(1))))
})

test_that("create_report() returns TFL_report class", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  
  expect_is(report, "TFL_report")
})

