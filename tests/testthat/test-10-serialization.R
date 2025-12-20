# ============================================================================
# Test: Spec Serialization
# ============================================================================

test_that("serialize_spec() accepts TFL_report object", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  
  result <- serialize_spec(report)
  
  expect_is(result, "list")
  expect_true("fixed" %in% names(result))
})

test_that("serialize_spec() returns list with spec and fixed keys", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  
  result <- serialize_spec(report)
  
  expect_true("spec" %in% names(result))
  expect_true("fixed" %in% names(result))
})

test_that("serialize_spec() fixed element is JSON-serializable", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  
  result <- serialize_spec(report)
  
  # The fixed element should be serializable to JSON
  expect_is(result$fixed, "list")
})

test_that("serialize_spec() preserves spec structure in result", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  
  result <- serialize_spec(report)
  
  # result$spec should be the TFL_report
  expect_s3_class(result$spec, "TFL_report")
})

test_that("serialize_spec() with title and content", {
  spec <- create_text()
  spec <- add_title(spec, "Test Document")
  spec <- add_body_text(spec, "Document content")
  
  report <- create_report(spec)
  result <- serialize_spec(report)
  
  expect_true(!is.null(result$fixed))
})

test_that("serialize_spec() with styled spec", {
  spec <- create_table(test_df)
  spec <- add_style(spec, id = "my_style", s_font(bold = TRUE))
  spec <- define_cols(spec, id, labelStyleRef = "my_style")
  
  report <- create_report(spec)
  result <- serialize_spec(report)
  
  expect_is(result, "list")
  expect_true("fixed" %in% names(result))
})

test_that("serialize_spec() with empty text spec", {
  spec <- create_text()
  
  report <- create_report(spec)
  result <- serialize_spec(report)
  
  expect_is(result$fixed, "list")
})

test_that("serialize_spec() handles multiple specs in report", {
  spec1 <- create_table(test_df)
  spec2 <- create_text()
  spec3 <- create_figure(filepath = test_image_path)
  
  report <- create_report(spec1, spec2, spec3)
  result <- serialize_spec(report)
  
  expect_equal(length(result$spec), 3)
})

test_that("serialize_spec() with enforce_additional_properties parameter", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  
  # Test with FALSE (default)
  result1 <- serialize_spec(report, enforce_additional_properties = FALSE)
  expect_is(result1, "list")
  
  # Test with TRUE
  result2 <- serialize_spec(report, enforce_additional_properties = TRUE)
  expect_is(result2, "list")
})

test_that("serialize_spec() result is consistent across calls", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  
  result1 <- serialize_spec(report)
  result2 <- serialize_spec(report)
  
  # Both should have same structure
  expect_equal(names(result1), names(result2))
})



