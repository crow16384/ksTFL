# ============================================================================
# Test: create_report() accepts list-of-specs arguments
# ============================================================================

test_that("create_report accepts a named list of TFL_spec", {
  spec1 <- create_table(mtcars[1:2, 1:2])
  spec2 <- create_table(mtcars[3:4, 1:2])
  out <- list(t1 = spec1, t2 = spec2)

  report <- create_report(out)

  expect_s3_class(report, "TFL_report")
  expect_equal(length(report), 2L)
  expect_equal(
    names(report),
    c(paste0("t1_", spec1$.metadata$hash),
      paste0("t2_", spec2$.metadata$hash))
  )
  expect_equal(report[[1]]$document$docOrder, 1L)
  expect_equal(report[[2]]$document$docOrder, 2L)
})

test_that("create_report falls back to <outer>_<i> for unnamed list elements", {
  spec1 <- create_table(mtcars[1:2, 1:2])
  spec2 <- create_table(mtcars[3:4, 1:2])
  out <- list(spec1, spec2)

  report <- create_report(out)

  expect_equal(
    names(report),
    c(paste0("out_1_", spec1$.metadata$hash),
      paste0("out_2_", spec2$.metadata$hash))
  )
})

test_that("create_report uses 'spec_<i>' fallback for literal list(...) call", {
  spec1 <- create_table(mtcars[1:2, 1:2])

  report <- create_report(list(spec1))

  expect_equal(names(report), paste0("spec_1_", spec1$.metadata$hash))
})

test_that("create_report mixes list args with variadic specs and reports", {
  spec0 <- create_table(mtcars[1:2, 1:2])
  spec1 <- create_table(mtcars[3:4, 1:2])
  spec2 <- create_table(mtcars[5:6, 1:2])
  spec3 <- create_table(mtcars[7:8, 1:2])
  inner_report <- create_report(spec3)

  report <- create_report(spec0, list(a = spec1, b = spec2), inner_report)

  expect_equal(length(report), 4L)
  expect_equal(report[[1]]$document$docOrder, 1L)
  expect_equal(report[[4]]$document$docOrder, 4L)
  expect_equal(
    names(report)[1:3],
    c(paste0("spec0_", spec0$.metadata$hash),
      paste0("a_", spec1$.metadata$hash),
      paste0("b_", spec2$.metadata$hash))
  )
})

test_that("create_report rejects nested lists", {
  spec <- create_table(mtcars[1:2, 1:2])
  expect_error(
    create_report(list(list(spec))),
    "[Nn]ested lists"
  )
})

test_that("create_report rejects non-spec elements inside a list", {
  expect_error(
    create_report(list(a = "not a spec")),
    "must be TFL_spec or TFL_report"
  )
})

test_that("create_report auto-disambiguates duplicate keys within a list", {
  spec <- create_table(mtcars[1:2, 1:2])
  out <- list(a = spec, a = spec)

  report <- suppressMessages(create_report(out))

  hash <- spec$.metadata$hash
  expect_equal(names(report), c(paste0("a_", hash), paste0("a_2_", hash)))
})

test_that("create_report flattens TFL_report elements inside a list", {
  spec1 <- create_table(mtcars[1:2, 1:2])
  spec2 <- create_table(mtcars[3:4, 1:2])
  inner <- create_report(spec1)

  report <- create_report(list(inner, extra = spec2))

  expect_equal(length(report), 2L)
  # inner's key is preserved verbatim (the outer slot name is ignored for
  # TFL_report elements)
  expect_true(names(report)[1] %in% names(inner))
  expect_equal(names(report)[2], paste0("extra_", spec2$.metadata$hash))
})
