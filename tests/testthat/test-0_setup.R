# Dummy test to document setup - not actual test
# This file exists so testthat can properly recognize the test directory

test_that("Test environment is properly configured", {
  expect_true(require("testthat", quietly = TRUE))
  expect_true(require("ksTFL", quietly = TRUE))
  expect_true(require("cli", quietly = TRUE))
})
