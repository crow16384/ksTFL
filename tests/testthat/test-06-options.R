# ============================================================================
# Test: Package Options Management
# ============================================================================

test_that("tfl_set_options() sets missings option", {
  current <- tfl_get_option("missings")
  tfl_set_options(missings = "N/A")
  
  expect_equal(tfl_get_option("missings"), "N/A")
  
  # Cleanup
  tfl_set_options(missings = current)
})

test_that("tfl_set_options() sets page_size option", {
  tfl_reset_options()
  tfl_set_options(set_page_style(docTemplate = 'my_custom', page = p_page(size = 'Letter', orientation = 'portrait', margins = p_margins(top='3cm'))))
  
  opts <- tfl_get_options()
  expect_equal(opts$doc_style_template, "my_custom")
  expect_equal(opts$page$size, "Letter")
  expect_equal(opts$page$orientation, "portrait")
  expect_equal(opts$page$margins$top, "3cm")
})



test_that("tfl_get_options() returns list of all options", {
  opts <- tfl_get_options()
  
  expect_is(opts, "TFL_options")
  expect_true(length(names(opts)) > 0)
})

test_that("tfl_get_option() retrieves single option", {
  missings <- tfl_get_option("missings")
  
  expect_is(missings, "character")
  expect_equal(missings, "")  # Default is empty string
})

test_that("tfl_get_option() with invalid option name", {
  expect_error(
    tfl_get_option("nonexistent_option"),
    "Unknown option"
  )
})

test_that("tfl_reset_options() restores defaults", {
  # Change an option
  tfl_set_options(missings = "CUSTOM")
  expect_equal(tfl_get_option("missings"), "CUSTOM")
  
  # Reset
  tfl_reset_options()
  default_missings <- tfl_get_option("missings")
  expect_equal(default_missings, .const_default_missing_value)
})

test_that("tfl_set_options() with add_header helper", {
  tfl_reset_options()
  tfl_set_options(add_header(c("Left", "Center", "Right")))
  
  opts <- tfl_get_options()
  expect_length(opts$headers,1)
  
  tfl_set_options(add_header(c("Left", "Center", "Right")))
  
  opts <- tfl_get_options()
  expect_length(opts$headers,2)
})

test_that("tfl_set_options() with add_footer helper", {
  tfl_reset_options()
  tfl_set_options(add_footer(c("Page Header", "Page Footer")))
  
  opts <- tfl_get_options()
  expect_length(opts$footers,1)
  
  tfl_set_options(add_footer(c("Page Header", "Page Footer")))
  opts <- tfl_get_options()
  expect_length(opts$footers,2)
})


test_that("tfl_set_options() add_header with level replaces existing header", {
  tfl_reset_options()
  tfl_set_options(add_header("Original"))
  opts <- tfl_get_options()
  expect_length(opts$headers, 1)
  expect_equal(opts$headers[[1]], "Original")

  tfl_set_options(add_header("Replaced", level = 1))
  opts <- tfl_get_options()
  expect_length(opts$headers, 1)
  expect_equal(opts$headers[[1]], "Replaced")
})

test_that("tfl_set_options() add_footer with level replaces existing footer", {
  tfl_reset_options()
  tfl_set_options(add_footer("Original"))
  opts <- tfl_get_options()
  expect_length(opts$footers, 1)
  expect_equal(opts$footers[[1]], "Original")

  tfl_set_options(add_footer("Replaced", level = 1))
  opts <- tfl_get_options()
  expect_length(opts$footers, 1)
  expect_equal(opts$footers[[1]], "Replaced")
})

test_that("tfl_set_options() combined header+footer replacement in single call", {
  tfl_reset_options()
  tfl_set_options(add_header("H1"), add_footer("F1"))
  opts <- tfl_get_options()
  expect_length(opts$headers, 1)
  expect_length(opts$footers, 1)

  tfl_set_options(add_header("H2", level = 1), add_footer("F2", level = 1))
  opts <- tfl_get_options()
  expect_length(opts$headers, 1)
  expect_equal(opts$headers[[1]], "H2")
  expect_length(opts$footers, 1)
  expect_equal(opts$footers[[1]], "F2")
})

test_that("tfl_set_options() with page configuration object", {
  tfl_set_options(
    set_page_style(page= p_page(
    size = "Letter",
    orientation = "portrait",
    margins = p_margins(top = "1in", bottom = "1in", left = "0.75in", right = "0.75in")
  )))
  
  tfl_get_option("page")
  
  expect_equal(tfl_get_option("page")$size, "Letter")
  expect_equal(tfl_get_option("page")$orientation, "portrait")
})

test_that("default page setting is NULL (no override)", {
  tfl_reset_options()
  expect_null(tfl_get_option("page"))
})

test_that("bare spec has no page override — template provides defaults", {
  tfl_reset_options()
  spec <- create_text()
  expect_null(spec$attribs$documentStyle$page)
})

test_that("p_page() with partial args only includes specified fields", {
  tfl_reset_options()
  spec <- create_text()
  spec2 <- set_page_style(spec, page = p_page(size = "Letter"))
  expect_equal(spec2$attribs$documentStyle$page$size, "Letter")
  expect_null(spec2$attribs$documentStyle$page$orientation)
})

test_that("session-level partial page override flows to spec", {
  tfl_reset_options()
  tfl_set_options(set_page_style(page = p_page(orientation = "portrait")))
  spec <- create_text()
  expect_null(spec$attribs$documentStyle$page$size)
  expect_equal(spec$attribs$documentStyle$page$orientation, "portrait")
  tfl_reset_options()
})

