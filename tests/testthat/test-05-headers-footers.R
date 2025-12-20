# ============================================================================
# Test: Headers and Footers
# ============================================================================

test_that("add_header() with single header", {
  spec <- create_text()
  spec <- add_header(spec, "Page Header")
  
  expect_true(length(spec$headers) > 0)
})

test_that("add_header() with three-part header", {
  spec <- create_text()
  spec <- add_header(spec, c("Left", "Center", "Right"))
  
  expect_equal(length(spec$headers[[1]]), 3)
  expect_equal(spec$headers[[1]][1], "Left")
  expect_equal(spec$headers[[1]][2], "Center")
  expect_equal(spec$headers[[1]][3], "Right")
})

test_that("add_header() rejects more than 3 parts", {
  spec <- create_text()
  
  expect_error(
    add_header(spec, c("A", "B", "C", "D")),
    "cannot have more than 3|maximum"
  )
})

test_that("add_footer() with single footer", {
  spec <- create_text()
  spec <- add_footer(spec, "Page Footer")
  
  expect_true(length(spec$footers) > 0)
})

test_that("add_footer() with three-part footer", {
  spec <- create_text()
  spec <- add_footer(spec, c("Left", "Center", "Right"))
  
  expect_equal(length(spec$footers[[1]]), 3)
})

test_that("add_footer() multiple footers", {
  spec <- create_text()
  spec <- add_footer(spec, c("Left", "Center", "Right"))
  spec <- add_footer(spec, c("Left", "Center", "Right"))
  
  expect_equal(length(spec$footers[[1]]), 3)
  expect_equal(length(spec$footers[[2]]), 3)
})

test_that("add_footer() rejects more than 3 parts", {
  spec <- create_text()
  
  expect_error(
    add_footer(spec, c("A", "B", "C", "D")),
    "cannot have more than 3|maximum"
  )
})




test_that("add_header() replaces previous header ", {
  spec <- create_text()
  spec <- add_header(spec, "First Header")
  spec <- add_header(spec, "Rewrite Header",level = 1)
  
  # Should replace, not accumulate
  expect_equal(length(spec$headers), 1)
  expect_equal(spec$headers[[1]][1], "Rewrite Header")
})

test_that("add_footer() replaces previous footer (not accumulate)", {
  spec <- create_text()
  spec <- add_footer(spec, "First Footer")
  spec <- add_footer(spec, "Rewrite Footer", level = 1)
  
  # Should replace, not accumulate
  expect_equal(length(spec$footers), 1)
  expect_equal(spec$footers[[1]][1], "Rewrite Footer")
})

