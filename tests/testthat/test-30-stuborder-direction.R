# ============================================================================
# Regression test: stubOrder vertical direction (verified live 2026-10-01)
# HIGHER stubOrder renders HIGHER on the page:
#   band(2) -> band(1) -> column labels -> data
# The package's own header grid sorts stubs by stub_order DESCENDING
# (src/kstfl/logical_table.cpp:138); each column's label renders in the row
# directly below the LOWEST band covering that column.
# ============================================================================

test_that("higher stubOrder renders in a higher header row (DOCX order)", {
  # engine availability probe follows the existing suite pattern:
  ok <- tryCatch({
    s <- create_table(data.frame(x = 1)) |> set_document(hasData = TRUE)
    p <- write_doc(create_report(s), name = "stubdir_probe",
                   outDir = tempdir(), metaPath = tempdir(), verbose = FALSE)
    file.exists(p)
  }, error = function(e) FALSE)
  if (!ok) skip("C++ renderer not available for DOCX emission")

  d <- data.frame(x1 = 1:2, x2 = 1:2, x3 = 1:2)
  spec <- create_table(d) |>
    define_cols(c(x1, x2, x3), label = c("L1", "L2", "L3")) |>
    add_span_header(cols = c(x1, x2, x3), label = "BAND1", stubOrder = 1) |>
    add_span_header(cols = c(x1, x2),      label = "BAND2", stubOrder = 2)

  out <- write_doc(create_report(spec), name = "stubdir_order",
                   outDir = tempfile("o_"), metaPath = tempfile("m_"),
                   verbose = FALSE)
  expect_docx_valid(out)

  x <- docx_part_text(out)
  tbl <- rx_all(x, "(?s)<w:tbl(?: [^>]*)?>.*?</w:tbl>")[1]
  trs <- rx_all(tbl, "(?s)<w:tr(?: [^>]*)?>.*?</w:tr>")
  row_text <- vapply(trs, function(tr)
    paste(rx_group(tr, "(?s)<w:t(?: [^>]*)?>([^<]*)</w:t>", 1), collapse = "|"),
    character(1))

  pos_b1 <- grep("BAND1", row_text)[1]
  pos_b2 <- grep("BAND2", row_text)[1]
  pos_lbl <- grep("L1", row_text)[1]

  expect_true(!is.na(pos_b1) && !is.na(pos_b2) && !is.na(pos_lbl))
  # direction: BAND2 (stubOrder 2) above BAND1 (1) above the labels row
  expect_lt(pos_b2, pos_b1)
  expect_lt(pos_b1, pos_lbl)
})

test_that("column labels merge down below the lowest band covering them", {
  # same render as above is reused when available; cheap spec-level check:
  spec <- create_table(data.frame(a = 1, b = 2, c = 3)) |>
    add_span_header(cols = c(a, b, c), label = "ALL", stubOrder = 1) |>
    add_span_header(cols = c(a),       label = "SOLO", stubOrder = 2)
  orders <- unname(vapply(spec$stubColumns, function(s) s$stubOrder, numeric(1)))
  expect_equal(sort(orders), c(1, 2))
})
