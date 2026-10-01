# ============================================================================
# Test: Validation and error surfaces (error MESSAGES, not just "it threw")
#
# These tests pin WHICH validator fires — message/class matchers are required
# per test-suite review 2026-09-29 (F8: ~92% of expect_error() calls were
# bare). They also prove valid inputs do NOT trip validation (F8 second half).
# ============================================================================

# ---- compute_cols / action-context guards -----------------------------------

test_that("c_* helpers refuse to run outside compute_cols()", {
  expect_error(c_style(1, "s"), "can only be used inside")
  expect_error(c_merge(c(a, b), "s"), "can only be used inside")
  expect_error(c_addrow("above"), "can only be used inside")
  expect_error(c_glue(a, "after", text = "x"), "can only be used inside")
  expect_error(c_clear(a), "can only be used inside")
  expect_error(c_pageBreak(), "can only be used inside")
})

test_that("compute_cols() rejects non-Table specs with a precise message", {
  txt <- create_text()
  expect_error(compute_cols(txt, TRUE, c_style(1, "s")),
               "only allowed for docType")
})

test_that("compute_cols() requires at least one action", {
  spec <- create_table(test_df)
  expect_error(compute_cols(spec, id > 1),
               "requires at least one action")
})

test_that("compute_cols() rejects NA-returning and wrong-length conditions", {
  # NA conditions are a hard error by design (actions contract, probe e2/e3)
  df <- data.frame(a = c("x", NA, "y"), b = 1:3)
  spec <- create_table(df)
  expect_error(
    create_report(compute_cols(spec, a == "x", c_style(2, "s"))),
    "cannot return NA"
  )

  spec2 <- create_table(test_df)
  expect_error(
    create_report(compute_cols(spec2, c(TRUE, FALSE), c_style(1, "s"))),
    "length"
  )
})

test_that("c_glue() glue_col/text interaction: parser precedence + hard rejections", {
  df <- data.frame(a = "x", b = "y")
  spec <- create_table(df)

  # DOCUMENTED CURRENT BEHAVIOR (finding F14): inside compute_cols the action is
  # parsed from the captured call, NOT by evaluating c_glue(); when BOTH
  # glue_col and text are given the builder-level "not both" guard never runs
  # and the parser silently prefers glue_col, discarding text.
  s_both <- compute_cols(spec, a == "x",
                         c_glue(a, "after", glue_col = b, text = "z"))
  sr <- create_report(s_both)[[1]]$styleRows
  act <- jsonlite::fromJSON(sr[1], simplifyVector = FALSE)$glue[[1]]
  expect_equal(act$glue_col, "b")
  expect_false("text" %in% names(act))

  expect_error(
    create_report(compute_cols(spec, a == "x", c_glue(a, "after"))),
    "requires either"
  )
  # vector text is a hard error (probe e1)
  expect_error(
    create_report(compute_cols(spec, a == "x",
                               c_glue(a, "after", text = c("p", "q")))),
    "must be.*string|len"
  )
  # glue_col overlapping target cols is rejected
  expect_error(
    create_report(compute_cols(spec, a == "x",
                               c_glue(a, "after", glue_col = a))),
    "must not overlap"
  )
})

test_that("c_glue() accepts each valid source form without error", {
  df <- data.frame(a = c("x", "y"), b = c("1", "2"))
  p1 <- write_doc(create_report(
    compute_cols(create_table(df), a == "x",
                 c_glue(a, "after", glue_col = b))),
    "glue_valid1", outDir = tempdir(), metaPath = tempdir(), verbose = FALSE)
  p2 <- write_doc(create_report(
    compute_cols(create_table(df), a == "x",
                 c_glue(a, "before", text = "T:", separator = ""))),
    "glue_valid2", outDir = tempdir(), metaPath = tempdir(), verbose = FALSE)
  expect_docx_valid(p1)
  expect_docx_valid(p2)
})

test_that("c_addrow() validates value_from resolution", {
  df <- data.frame(a = c("x", "y"), b = 1:2)
  # multi-column value_from rejected
  expect_error(
    create_report(compute_cols(create_table(df), a == "x",
                               c_addrow("above", value_from = c(a, b)))),
    "single column"
  )
  # omitting value_from is legal (empty separator row idiom)
  p <- write_doc(create_report(
    compute_cols(create_table(df), a == "x", c_addrow("above"))),
    "addrow_empty", outDir = tempdir(), metaPath = tempdir(), verbose = FALSE)
  expect_docx_valid(p)
})

# ---- define_cols parameter validation ----------------------------------------

# NOTE: define_cols() length-mismatch rejection is covered in test-02 with the
# exact message; not duplicated here (task section 7: orthogonal coverage).

test_that("define_cols() rejects unknown columns", {
  spec <- create_table(test_df)
  expect_error(define_cols(spec, no_such_col, label = "x"),
               "Invalid column selection|doesn't exist|not found")
})

test_that("define_cols() accepts the minimal valid call unchanged", {
  spec <- create_table(test_df)
  spec2 <- define_cols(spec, id, label = "L")
  expect_equal(spec2$columns$id$label, "L")
  # untouched columns keep their auto-detected format
  expect_equal(spec2$columns$value$format$type, "numeric")
})

# ---- add_header / add_footer arity -------------------------------------------

test_that("add_header()/add_footer() reject more than 3 parts with precise messages", {
  spec <- create_text()
  expect_error(add_header(spec, c("a", "b", "c", "d")),
               "3|three|parts", ignore.case = TRUE)
  expect_error(add_footer(spec, c("a", "b", "c", "d")),
               "3|three|parts", ignore.case = TRUE)
})

# ---- create_figure / create_table input guards --------------------------------

test_that("create_figure() rejects non-existent and non-file paths", {
  expect_error(create_figure("/nonexistent/path/to/image.png"),
               "readable file path")
  expect_error(create_figure(tempdir()), "readable file path")
})

test_that("create_table() rejects empty selection but accepts all valid shapes", {
  expect_error(create_table(data.frame()), "No columns selected")
  expect_no_error(create_table(data.frame(x = 1)))
  expect_no_error(create_table(data.frame(x = 1, y = 2), cols = c(y, x)))
})

# ---- report writer argument validation ----------------------------------------

test_that("save_report() type-checks its string arguments", {
  rpt <- create_report(create_table(test_df))
  dirs <- local_docx_dirs()
  expect_error(save_report(rpt, docFileName = 42), "character|string")
  expect_error(save_report(rpt, "ok", outDir = 42), "character|string")
  expect_error(save_report(rpt, "ok", outDir = dirs$out, metaPath = FALSE),
               "character|string")
})

test_that("create_report() rejects non-spec objects", {
  expect_error(create_report(1:3), "TFL_spec|TFL_report|class")
  expect_error(create_report(), "at least one|argument|empty", ignore.case = TRUE)
})
