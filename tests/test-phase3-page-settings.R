# Test Phase 3: Page settings integration
# This tests page settings via tfl_page() function with settings

library(testthat)
source("./tests/testthat/setup.R")

# Load package
devtools::load_all()

# ============================================================================
# TEST 1: Page settings can be set via tfl_set_options with tfl_page()
# ============================================================================
test_that("Page settings can be set via tfl_set_options with tfl_page()", {
  tfl_reset_settings()
  
  # Create page settings with tfl_page
  page_settings <- tfl_page(
    size = "Letter",
    orientation = "portrait"
  )
  
  # Store in options
  tfl_set_options(page = page_settings)
  
  settings <- tfl_get_settings()
  expect_true(!is.null(settings$page))
  expect_equal(settings$page$size, "Letter")
  expect_equal(settings$page$orientation, "portrait")
})

# ============================================================================
# TEST 2: Page settings can be set as plain list
# ============================================================================
test_that("Page settings can be set as plain list", {
  tfl_reset_settings()
  
  page_list <- list(
    size = "A4",
    orientation = "landscape"
  )
  
  tfl_set_options(page = page_list)
  
  settings <- tfl_get_settings()
  expect_equal(settings$page$size, "A4")
  expect_equal(settings$page$orientation, "landscape")
})

# ============================================================================
# TEST 3: Page settings are applied to new specs
# ============================================================================
test_that("Page settings are applied to new specs via .fill_spec_defaults", {
  tfl_reset_settings()
  
  # Set page settings
  page_settings <- tfl_page(
    size = "Legal",
    orientation = "landscape"
  )
  
  tfl_set_options(page = page_settings)
  
  # Create a new spec
  spec <- list()
  spec <- .fill_spec_defaults(spec)
  
  # Check that page settings were applied
  expect_true(!is.null(spec$attribs$documentStyle$page))
  expect_equal(spec$attribs$documentStyle$page$size, "Legal")
  expect_equal(spec$attribs$documentStyle$page$orientation, "landscape")
})

# ============================================================================
# TEST 4: Multiple settings combined (headers + page)
# ============================================================================
test_that("Multiple settings work together (headers + page)", {
  tfl_reset_settings()
  
  header_obj <- add_header(c("Report", "", ""))
  page_obj <- tfl_page(size = "Legal", orientation = "portrait")
  
  tfl_set_options(
    header_obj,
    page = page_obj
  )
  
  settings <- tfl_get_settings()
  
  # Check headers
  expect_equal(length(settings$headers), 1)
  
  # Check page
  expect_equal(settings$page$size, "Legal")
  expect_equal(settings$page$orientation, "portrait")
  
  # Create spec and verify both are applied
  spec <- list()
  spec <- .fill_spec_defaults(spec)
  
  expect_equal(length(spec$headers), 1)
  expect_equal(spec$attribs$documentStyle$page$size, "Legal")
})

# ============================================================================
# TEST 5: Page settings with margins using tfl_page()
# ============================================================================
test_that("Page settings with margins work correctly using tfl_page()", {
  tfl_reset_settings()
  
  # Create page with margins
  page_obj <- tfl_page(
    size = "A4",
    orientation = "landscape",
    margins = list(
      top = 1.0,
      bottom = 1.0,
      left = 0.75,
      right = 0.75
    )
  )
  
  tfl_set_options(page = page_obj)
  
  settings <- tfl_get_settings()
  
  # Check page settings
  expect_equal(settings$page$size, "A4")
  expect_true(!is.null(settings$page$margins))
  expect_equal(settings$page$margins$top, 1.0)
  expect_equal(settings$page$margins$left, 0.75)
})

# ============================================================================
# TEST 6: Page settings with footers and bodyText all together
# ============================================================================
test_that("All settings work together (page + headers + footers + bodyText)", {
  tfl_reset_settings()
  
  header_obj <- add_header(c("Title", "", ""))
  footer_obj <- add_footer(c("Page", "1", ""))
  body_obj <- add_body_text("Custom content")
  page_obj <- tfl_page(size = "A4", orientation = "portrait")
  
  tfl_set_options(
    header_obj,
    footer_obj,
    body_obj,
    page = page_obj
  )
  
  settings <- tfl_get_settings()
  
  # Create spec and verify all are applied
  spec <- list()
  spec <- .fill_spec_defaults(spec)
  
  expect_equal(length(spec$headers), 1)
  expect_equal(length(spec$footers), 1)
  expect_true(length(spec$bodyText) >= 1)
  expect_equal(spec$attribs$documentStyle$page$size, "A4")
})

cat("\n✅ Phase 3 Page Settings Tests Complete\n")
