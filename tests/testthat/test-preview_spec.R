test_that("preview_spec uses cli output and contains key sections", {
  df <- data.frame(id = 1:3, age = c(45, 50, 60))
  spec <- tfl_init(df)

  spec <- add_title(spec, "Study Title")
  spec <- add_header(spec, c("ACME", "Clinical", "2025"))

  # Capture both messages (cli tends to use messages) and stdout using testthat helpers
  out_msg <- testthat::capture_messages(preview_spec(spec))
  out_out <- testthat::capture_output_lines(preview_spec(spec))
  out_raw <- c(out_msg, out_out)

  # Strip ANSI/terminal control sequences for robust matching
  out <- cli::ansi_strip(out_raw)

  expect_true(any(grepl("TFL Specification Preview", out)))
  expect_true(any(grepl("Document Type:", out)))
  expect_true(any(grepl("Has Data:", out)))
  expect_true(any(grepl("Titles:", out)))
  expect_true(any(grepl("Headers:", out)))
})
