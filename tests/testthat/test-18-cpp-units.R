# test-18-cpp-units.R — R testthat wrapper for C++ unit tests
#
# Calls Rcpp-exported test suites for:
#   - cpp_test_units()         : units.cpp  (parse_length, conversions, colors)
#   - cpp_test_inline_parser() : inline_parser.cpp  (HTML-like markup)
#   - cpp_test_xml_writer()    : xml_writer.cpp  (streaming OOXML emitter)
#
# Each suite returns list(passed = character[], failed = character[]),
# where 'failed' entries carry the "<test name>: <reason>" message.
#
# The helper .report_cpp_results() turns those lists into testthat
# expectations so every individual C++ assertion gets its own pass/fail
# line in the testthat output.

# ---------------------------------------------------------------------------
# Helper: turn a cpp test result list into testthat expectations
# ---------------------------------------------------------------------------

.report_cpp_results <- function(result, suite_label) {
  if (length(result$failed) > 0L) {
    fail_msg <- paste(result$failed, collapse = "\n  ")
    fail(paste0("[", suite_label, "] ", length(result$failed),
                " failure(s):\n  ", fail_msg))
  }
  expect_true(
    length(result$passed) > 0L,
    label = paste0(suite_label, ": at least 1 passing test")
  )
  succeed(paste0("[", suite_label, "] All ", length(result$passed),
                 " assertions passed"))
}

# ---------------------------------------------------------------------------
# Separate expect_ for each individual C++ assertion (detailed report)
# ---------------------------------------------------------------------------

.expect_each_cpp_result <- function(result) {
  for (name in result$passed) {
    expect_true(TRUE, label = name)
  }
  for (msg in result$failed) {
    # Extract the test name (before first ": ")
    parts <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    label <- if (length(parts) >= 1L) parts[[1L]] else msg
    reason <- if (length(parts) >= 2L) paste(parts[-1L], collapse = ": ") else "failed"
    expect_true(FALSE, label = paste0(label, " — ", reason))
  }
}

# ===========================================================================
# Suite 1: units.cpp
# ===========================================================================

test_that("C++ units — parse_length: basic unit conversions", {
  result <- cpp_test_units()

  # Grab only the tests whose names match "parse_length"
  pl_passed <- result$passed[startsWith(result$passed, "parse_length")]
  pl_failed <- result$failed[startsWith(result$failed, "parse_length")]

  for (name in pl_passed) expect_true(TRUE, label = name)
  for (msg  in pl_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    label  <- parts[[1L]]
    reason <- paste(parts[-1L], collapse = ": ")
    expect_true(FALSE, label = paste0(label, " — ", reason))
  }
})

test_that("C++ units — Length::parse static method", {
  result <- cpp_test_units()

  lp_passed <- result$passed[startsWith(result$passed, "Length::parse")]
  lp_failed <- result$failed[startsWith(result$failed, "Length::parse")]

  for (name in lp_passed) expect_true(TRUE, label = name)
  for (msg  in lp_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }
})

test_that("C++ units — emu_to_twips, emu_to_half_points, pt_to_half_points, pt_to_eighth_points", {
  result <- cpp_test_units()

  conv_names <- c("emu_to_twips", "emu_to_half_points",
                  "pt_to_half_points", "pt_to_eighth_points")
  pattern <- paste(conv_names, collapse = "|")

  conv_passed <- result$passed[grepl(pattern, result$passed)]
  conv_failed <- result$failed[grepl(pattern, result$failed)]

  for (name in conv_passed) expect_true(TRUE, label = name)
  for (msg  in conv_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }

  # Sanity: ensure at least one conversion test ran
  expect_gt(length(conv_passed) + length(conv_failed), 0L)
})

test_that("C++ units — page_size_dimensions (all five sizes)", {
  result   <- cpp_test_units()
  ps_passed <- result$passed[grepl("width EMU|height EMU", result$passed)]
  ps_failed <- result$failed[grepl("width EMU|height EMU", result$failed)]

  for (name in ps_passed) expect_true(TRUE, label = name)
  for (msg  in ps_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }

  # Should have 5 sizes × 2 dimensions = 10 tests
  expect_gte(length(ps_passed) + length(ps_failed), 10L)
})

test_that("C++ units — Color::parse (valid and invalid inputs)", {
  result <- cpp_test_units()

  c_passed <- result$passed[startsWith(result$passed, "Color::parse")]
  c_failed <- result$failed[startsWith(result$failed, "Color::parse")]

  for (name in c_passed) expect_true(TRUE, label = name)
  for (msg  in c_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }
})

test_that("C++ units — Length arithmetic operators", {
  result <- cpp_test_units()

  ops_passed <- result$passed[startsWith(result$passed, "Length operator")]
  ops_failed <- result$failed[startsWith(result$failed, "Length operator")]

  for (name in ops_passed) expect_true(TRUE, label = name)
  for (msg  in ops_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }
})

test_that("C++ units — OOXML helpers (border_line_style_to_ooxml, alignment_to_ooxml)", {
  result    <- cpp_test_units()
  ox_passed <- result$passed[grepl("^OOXML", result$passed)]
  ox_failed <- result$failed[grepl("^OOXML", result$failed)]

  for (name in ox_passed) expect_true(TRUE, label = name)
  for (msg  in ox_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }
})

test_that("C++ units — no failures in full suite", {
  result <- cpp_test_units()
  .report_cpp_results(result, "units")
})

# ===========================================================================
# Suite 2: inline_parser.cpp
# ===========================================================================

test_that("C++ inline_parser — has_inline_markup detection", {
  result <- cpp_test_inline_parser()

  hm_passed <- result$passed[startsWith(result$passed, "no markup") |
                               startsWith(result$passed, "has markup")]
  hm_failed <- result$failed[startsWith(result$failed, "no markup") |
                               startsWith(result$failed, "has markup")]

  for (name in hm_passed) expect_true(TRUE, label = name)
  for (msg  in hm_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }
})

test_that("C++ inline_parser — plain text (no markup)", {
  result <- cpp_test_inline_parser()

  pl_passed <- result$passed[startsWith(result$passed, "plain:") |
                               startsWith(result$passed, "no tags:")]
  pl_failed <- result$failed[startsWith(result$failed, "plain:") |
                               startsWith(result$failed, "no tags:")]

  for (name in pl_passed) expect_true(TRUE, label = name)
  for (msg  in pl_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }
})

test_that("C++ inline_parser — bold, italic, underline, sup, sub", {
  result <- cpp_test_inline_parser()

  tags <- c("bold:", "italic:", "underline:", "superscript:", "subscript:")
  pattern <- paste(tags, collapse = "|")

  t_passed <- result$passed[grepl(pattern, result$passed)]
  t_failed <- result$failed[grepl(pattern, result$failed)]

  for (name in t_passed) expect_true(TRUE, label = name)
  for (msg  in t_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }
})

test_that("C++ inline_parser — mixed and nested tags", {
  result <- cpp_test_inline_parser()

  mix_passed <- result$passed[grepl("^(mixed|nested)", result$passed)]
  mix_failed <- result$failed[grepl("^(mixed|nested)", result$failed)]

  for (name in mix_passed) expect_true(TRUE, label = name)
  for (msg  in mix_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }
})

test_that("C++ inline_parser — line breaks (<br/>, <br>, <p>)", {
  result <- cpp_test_inline_parser()

  br_passed <- result$passed[grepl("^br|^<p>|^multi br", result$passed)]
  br_failed <- result$failed[grepl("^br|^<p>|^multi br", result$failed)]

  for (name in br_passed) expect_true(TRUE, label = name)
  for (msg  in br_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }
})

test_that("C++ inline_parser — case-insensitive tag names", {
  result <- cpp_test_inline_parser()

  ci_passed <- result$passed[startsWith(result$passed, "case-insensitive")]
  ci_failed <- result$failed[startsWith(result$failed, "case-insensitive")]

  for (name in ci_passed) expect_true(TRUE, label = name)
  for (msg  in ci_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }
})

test_that("C++ inline_parser — unknown tags are silently ignored", {
  result <- cpp_test_inline_parser()

  unk_passed <- result$passed[startsWith(result$passed, "unknown tag")]
  unk_failed <- result$failed[startsWith(result$failed, "unknown tag")]

  for (name in unk_passed) expect_true(TRUE, label = name)
  for (msg  in unk_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }
})

test_that("C++ inline_parser — get_plain_text strips markup", {
  result <- cpp_test_inline_parser()

  pt_passed <- result$passed[startsWith(result$passed, "plain_text:")]
  pt_failed <- result$failed[startsWith(result$failed, "plain_text:")]

  for (name in pt_passed) expect_true(TRUE, label = name)
  for (msg  in pt_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }
})

test_that("C++ inline_parser — no failures in full suite", {
  result <- cpp_test_inline_parser()
  .report_cpp_results(result, "inline_parser")
})

# ===========================================================================
# Suite 3: xml_writer.cpp
# ===========================================================================

test_that("C++ xml_writer — XML declaration", {
  result <- cpp_test_xml_writer()

  d_passed <- result$passed[startsWith(result$passed, "declaration")]
  d_failed <- result$failed[startsWith(result$failed, "declaration")]

  for (name in d_passed) expect_true(TRUE, label = name)
  for (msg  in d_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }
})

test_that("C++ xml_writer — basic element creation (self-close, with text)", {
  result <- cpp_test_xml_writer()

  el_passed <- result$passed[grepl("^self-close|^element_with_text|^nested",
                                   result$passed)]
  el_failed <- result$failed[grepl("^self-close|^element_with_text|^nested",
                                   result$failed)]

  for (name in el_passed) expect_true(TRUE, label = name)
  for (msg  in el_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }
})

test_that("C++ xml_writer — attributes (string, int, multiple)", {
  result <- cpp_test_xml_writer()

  at_passed <- result$passed[grepl("^string attribute|^int64 attribute|^multiple attr",
                                   result$passed)]
  at_failed <- result$failed[grepl("^string attribute|^int64 attribute|^multiple attr",
                                   result$failed)]

  for (name in at_passed) expect_true(TRUE, label = name)
  for (msg  in at_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }
})

test_that("C++ xml_writer — text and attribute escaping (&, <, >, \")", {
  result <- cpp_test_xml_writer()

  esc_passed <- result$passed[grepl("^text escape|^attr escape", result$passed)]
  esc_failed <- result$failed[grepl("^text escape|^attr escape", result$failed)]

  for (name in esc_passed) expect_true(TRUE, label = name)
  for (msg  in esc_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }

  # Must test at least &, <, > for text  and " for attrs = 4 cases
  expect_gte(length(esc_passed) + length(esc_failed), 4L)
})

test_that("C++ xml_writer — convenience helpers (element_with_attr, raw, comment)", {
  result <- cpp_test_xml_writer()

  h_passed <- result$passed[grepl("^element_with_attr|^raw:|^comment:",
                                  result$passed)]
  h_failed <- result$failed[grepl("^element_with_attr|^raw:|^comment:",
                                  result$failed)]

  for (name in h_passed) expect_true(TRUE, label = name)
  for (msg  in h_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }
})

test_that("C++ xml_writer — clear(), take(), depth()", {
  result <- cpp_test_xml_writer()

  state_passed <- result$passed[grepl("^clear:|^take:|^depth:", result$passed)]
  state_failed <- result$failed[grepl("^clear:|^take:|^depth:", result$failed)]

  for (name in state_passed) expect_true(TRUE, label = name)
  for (msg  in state_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }
})

test_that("C++ xml_writer — namespace_decl", {
  result    <- cpp_test_xml_writer()
  ns_passed <- result$passed[startsWith(result$passed, "namespace_decl")]
  ns_failed <- result$failed[startsWith(result$failed, "namespace_decl")]

  for (name in ns_passed) expect_true(TRUE, label = name)
  for (msg  in ns_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }
})

test_that("C++ xml_writer — error conditions throw correctly", {
  result <- cpp_test_xml_writer()

  err_passed <- result$passed[startsWith(result$passed, "error:")]
  err_failed <- result$failed[startsWith(result$failed, "error:")]

  for (name in err_passed) expect_true(TRUE, label = name)
  for (msg  in err_failed) {
    parts  <- strsplit(msg, ": ", fixed = TRUE)[[1L]]
    expect_true(FALSE, label = paste0(parts[[1L]], " — ", paste(parts[-1L], collapse = ": ")))
  }

  # Both error scenarios must be present
  expect_gte(length(err_passed) + length(err_failed), 2L)
})

test_that("C++ xml_writer — no failures in full suite", {
  result <- cpp_test_xml_writer()
  .report_cpp_results(result, "xml_writer")
})

# ==========================================================================
# Format Validator (is_safe_numeric_format manual parser)
# ==========================================================================

test_that("C++ format_validator — no failures in full suite", {
  result <- cpp_test_format_validator()
  .report_cpp_results(result, "format_validator")
})
