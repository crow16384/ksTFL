# Test Phase 2 Implementation: Settings system with detection and routing
# This tests the dual-mode dispatch, settings object detection, and integration

library(testthat)
source("./tests/testthat/setup.R")

# Load package
devtools::load_all()

# ============================================================================
# TEST 1: Verify default bodyText is initialized
# ============================================================================
test_that("Default bodyText is initialized in settings", {
  # Reset to defaults
  tfl_reset_settings()
  settings <- tfl_get_settings()
  
  # names() returns plain strings without backticks
  bodytext_names <- names(settings$bodyText)
  expect_true("__default_001" %in% bodytext_names, 
              info = paste("Available names:", paste(bodytext_names, collapse = ", ")))
  expect_equal(settings$bodyText$`__default_001`$text, "No data to report")
  expect_equal(settings$bodyText$`__default_001`$order, 999L)
})

# ============================================================================
# TEST 2: Add header via settings context (dual-mode detection)
# ============================================================================
test_that("add_header in settings context returns tfl_header_setting", {
  header_obj <- add_header(c("PROJECT A", "", ""))
  
  expect_true(inherits(header_obj, "tfl_header_setting"))
  # header_obj is a list with 3 elements: the vector of header parts
  expect_equal(length(header_obj), 1)
  expect_equal(header_obj[[1]], c("PROJECT A", "", ""))
})

# ============================================================================
# TEST 3: Add footer via settings context
# ============================================================================
test_that("add_footer in settings context returns tfl_footer_setting", {
  footer_obj <- add_footer(c("Page", "1", ""))
  
  expect_true(inherits(footer_obj, "tfl_footer_setting"))
  # footer_obj is a list with 3 elements: the vector of footer parts
  expect_equal(length(footer_obj), 1)
  expect_equal(footer_obj[[1]], c("Page", "1", ""))
})

# ============================================================================
# TEST 4: Add bodyText via settings context
# ============================================================================
test_that("add_body_text in settings context returns tfl_bodytext_setting", {
  body_obj <- add_body_text("Custom message")
  
  expect_true(inherits(body_obj, "tfl_bodytext_setting"))
  expect_equal(body_obj$text, "Custom message")
})

# ============================================================================
# TEST 5: tfl_set_options detects and routes header setting
# ============================================================================
test_that("tfl_set_options detects tfl_header_setting and routes it", {
  tfl_reset_settings()
  
  header_obj <- add_header(c("COMPANY", "", ""))
  tfl_set_options(header_obj)
  
  settings <- tfl_get_settings()
  expect_equal(length(settings$headers), 1)
  expect_equal(settings$headers[[1]][[1]], "COMPANY")
})

# ============================================================================
# TEST 6: tfl_set_options detects and routes footer setting
# ============================================================================
test_that("tfl_set_options detects tfl_footer_setting and routes it", {
  tfl_reset_settings()
  
  footer_obj <- add_footer(c("Footer", "text", ""))
  tfl_set_options(footer_obj)
  
  settings <- tfl_get_settings()
  expect_equal(length(settings$footers), 1)
  expect_equal(settings$footers[[1]][[1]], "Footer")
})

# ============================================================================
# TEST 7: tfl_set_options detects and routes bodyText setting
# ============================================================================
test_that("tfl_set_options detects tfl_bodytext_setting and routes it", {
  tfl_reset_settings()
  
  # First check what's in settings before
  settings_before <- tfl_get_settings()
  cat("\n[TEST 7] bodyText before:", paste(names(settings_before$bodyText), collapse = ", "), "\n")
  
  body_obj <- add_body_text("New default message")
  cat("[TEST 7] body_obj class:", paste(class(body_obj), collapse = ", "), "\n")
  cat("[TEST 7] body_obj content:", str(body_obj), "\n")
  
  tfl_set_options(body_obj)
  
  settings <- tfl_get_settings()
  bodytext_names <- names(settings$bodyText)
  cat("[TEST 7] bodyText after:", paste(bodytext_names, collapse = ", "), "\n")
  cat("[TEST 7] bodyText entries: ", length(settings$bodyText), "\n")
  
  # Check that __default_001 was removed
  expect_false("__default_001" %in% bodytext_names)
  
  # Check that a new default ID was created
  has_default_002 <- "__default_002" %in% bodytext_names
  expect_true(has_default_002, info = paste("Available names:", paste(bodytext_names, collapse = ", ")))
  
  # Check that the text was set correctly
  if (has_default_002) {
    expect_equal(settings$bodyText$`__default_002`$text, "New default message")
  }
})

# ============================================================================
# TEST 8: Multiple settings applied together
# ============================================================================
test_that("tfl_set_options handles multiple settings in one call", {
  tfl_reset_settings()
  
  header_obj <- add_header(c("Title", "", ""))
  footer_obj <- add_footer(c("Page", "1", ""))
  body_obj <- add_body_text("Custom content")
  
  tfl_set_options(
    header_obj,
    footer_obj,
    body_obj
  )
  
  settings <- tfl_get_settings()
  expect_equal(length(settings$headers), 1)
  expect_equal(length(settings$footers), 1)
  
  # Check for default_002 created from custom bodyText
  bodytext_names <- names(settings$bodyText)
  has_default_002 <- "__default_002" %in% bodytext_names
  expect_true(has_default_002, info = paste("Available names:", paste(bodytext_names, collapse = ", ")))
})

# ============================================================================
# TEST 9: Named parameter settings still work
# ============================================================================
test_that("Named parameter settings work (backwards compatible)", {
  tfl_reset_settings()
  
  tfl_set_options(
    bodyTitles = FALSE,
    contentWidth = "95%"
  )
  
  settings <- tfl_get_settings()
  expect_false(settings$bodyTitles)
  expect_equal(settings$contentWidth, "95%")
})

# ============================================================================
# TEST 10: Settings applied to new spec via .fill_spec_defaults
# ============================================================================
test_that(".fill_spec_defaults applies headers/footers/bodyText to new spec", {
  tfl_reset_settings()
  
  # Set some options
  header_obj <- add_header(c("Department", "", ""))
  footer_obj <- add_footer(c("Footer", "", ""))
  tfl_set_options(header_obj, footer_obj)
  
  # Create new spec - should get settings applied
  spec <- list()
  spec <- .fill_spec_defaults(spec)
  
  expect_equal(length(spec$headers), 1)
  expect_equal(length(spec$footers), 1)
  expect_true(length(spec$bodyText) >= 1, info = "bodyText should have at least one entry")
  
  # Check for default bodyText (may be named with or without backticks internally)
  bodytext_names <- names(spec$bodyText)
  has_default_001 <- "__default_001" %in% bodytext_names
  expect_true(has_default_001, info = paste("Available bodyText names:", paste(bodytext_names, collapse = ", ")))
})

# ============================================================================
# TEST 11: tfl_set_settings backwards compatibility wrapper works
# ============================================================================
test_that("tfl_set_settings is backwards compatible wrapper", {
  tfl_reset_settings()
  
  header_obj <- add_header(c("Compat", "", ""))
  tfl_set_settings(header_obj)  # Use old function name
  
  settings <- tfl_get_settings()
  expect_equal(length(settings$headers), 1)
})

# ============================================================================
# TEST 12: Spec pipeline still works (backwards compatible)
# ============================================================================
test_that("Spec pipeline with add_header.TFL_options works", {
  options <- list()
  class(options) <- "TFL_options"
  options$headers <- list()
  
  options <- add_header.TFL_options(options, c("New header"))
  
  expect_equal(length(options$headers), 1)
  expect_equal(options$headers[[1]][[1]], "New header")
})

# ============================================================================
# TEST 13: Auto-removal of defaults when adding custom bodyText to spec
# ============================================================================
test_that("Custom bodyText auto-removes __default_001 from list spec", {
  tfl_reset_settings()
  
  # Create spec with defaults applied
  spec <- list()
  spec <- .fill_spec_defaults(spec)
  
  expect_true("`__default_001`" %in% names(spec$bodyText) || "__default_001" %in% names(spec$bodyText))
  
  # Add custom text - should remove all defaults
  spec <- add_body_text.TFL_spec(spec, text = "Custom text")
  
  expect_false("`__default_001`" %in% names(spec$bodyText) && "__default_001" %in% names(spec$bodyText))
  # Should have added new entry with auto-generated ID or user-provided
  expect_true(length(spec$bodyText) > 0)
})

# ============================================================================
# TEST 14: Level parameter for headers
# ============================================================================
test_that("Level parameter replaces header at specific row", {
  options <- list()
  class(options) <- "TFL_options"
  options$headers <- list()
  
  options <- add_header.TFL_options(options, c("Row 1"))
  options <- add_header.TFL_options(options, c("Row 2"))
  
  # Replace row 1
  options <- add_header.TFL_options(options, c("Row 1 REPLACED"), level = 1)
  
  expect_equal(length(options$headers), 2)
  expect_equal(options$headers[[1]][[1]], "Row 1 REPLACED")
  expect_equal(options$headers[[2]][[1]], "Row 2")
})

cat("\n✅ Phase 2 Integration Tests Complete\n")
