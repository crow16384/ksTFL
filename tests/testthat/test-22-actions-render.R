# ============================================================================
# Test: `actions` mechanism at the RENDER level (DOCX truth, not spec JSON)
#
# test-13 pins what actions serialize INTO; this file pins what they change in
# the generated document — the observable contract (task §6 + §9 tiers B/C).
# Helpers from helper-docx.R; render expectations verified live 2026-09-29.
# ============================================================================

find_row <- function(rows, first_cell) {
  for (r in rows) if (length(r) && r[1] == first_cell) return(r)
  NULL
}

# ---- individual actions -------------------------------------------------------

test_that("c_style() renders matching-row cells bold and leaves others plain", {
  p <- render_spec(
    create_table(act_df()) |>
      add_style("bold_it", s_font(bold = TRUE)) |>
      compute_cols(g == "B", c_style(lab, "bold_it")),
    "act_style")
  ms <- docx_cells(p)
  bold_cells <- unlist(lapply(ms, function(m) m$text[m$bold]))
  expect_true(all(c("r3", "r4") %in% bold_cells),
              label = "matched lab cells are bold")
  expect_false("r1" %in% bold_cells || "r2" %in% bold_cells,
               label = "non-matched lab cells never bold")
})

test_that("c_clear() blanks the matched cell without touching neighbours", {
  p <- render_spec(
    create_table(act_df()) |>
      compute_cols(lab == "r2", c_clear(g)),
    "act_clear")
  rows <- cell_texts(p)
  expect_true(any(vapply(rows, function(r)
    length(r) >= 2 && r[1] == "" && r[2] == "r2", logical(1))),
    label = "row r2 shows cleared group cell")
  expect_true(any(vapply(rows, function(r)
    length(r) >= 2 && r[1] == "A" && r[2] == "r1", logical(1))),
    label = "row r1 group cell untouched")
})

test_that("c_merge() spans exactly the merged columns for the matched row only", {
  p <- render_spec(
    create_table(act_df()) |>
      compute_cols(lab == "r3", c_merge(c(g, lab))),
    "act_merge")
  ms <- docx_cells(p)
  merged <- Filter(function(m)
    any(!is.na(m$gridSpan) & m$gridSpan >= 2 & m$text == "B"), ms)
  expect_gte(length(merged), 1L,
             label = "gridSpan>=2 cell carries leader text 'B'")
  expect_true(any(vapply(ms, function(m)
    any(m$text == "r1" & is.na(m$gridSpan)), logical(1))),
    label = "non-matching r1 row keeps an unspanned cell")
})

test_that("c_glue() writes glued display text (glue_col and text= variants)", {
  df <- data.frame(PARAM = c("ALT", "AST"), UNIT = c("U/L", "U/L"),
                   stringsAsFactors = FALSE)
  p1 <- render_spec(
    create_table(df) |>
      compute_cols(TRUE, c_glue(PARAM, "after", glue_col = UNIT, separator = " ")),
    "act_glue_col")
  p2 <- render_spec(
    create_table(df) |>
      compute_cols(PARAM == "ALT", c_glue(PARAM, "before", text = "*", separator = "")),
    "act_glue_text")
  t1 <- unlist(cell_texts(p1))
  t2 <- unlist(cell_texts(p2))
  expect_true(all(c("ALT U/L", "AST U/L") %in% t1))
  expect_true("*ALT" %in% t2, label = "text= glued before matched row")
  expect_false("*AST" %in% t2, label = "unmatched row untouched")
})

test_that("c_addrow() inserts a full-width synthetic row directly above the source", {
  p <- render_spec(
    create_table(act_df()) |>
      define_cols(g, isVisible = FALSE) |>
      compute_cols(lab == "r2", c_addrow("above", value_from = lab)),
    "act_addrow")
  ms <- docx_cells(p)
  # 2 visible columns after hiding `g` -> single cell with gridSpan == 2
  span_full <- vapply(ms, function(m)
    nrow(m) == 1 && identical(m$gridSpan[1], 2L) && m$text[1] == "r2", logical(1))
  expect_true(any(span_full), label = "r2 synthetic row inserted (full-width)")
  idx_synth <- which(span_full)[1]
  idx_real <- which(vapply(ms, function(m)
    any(m$text == "r2" & (is.na(m$gridSpan) | m$gridSpan < 2)), logical(1)))
  expect_equal(idx_synth + 1L, min(idx_real),
               label = "synthetic row sits immediately above source row")
})

test_that("c_pageBreak() splits the table, emits one page break, repeats header", {
  p <- render_spec(
    create_table(act_df()) |>
      compute_cols(lab == "r3", c_pageBreak()),
    "act_pb")
  x <- docx_part_text(p)
  expect_equal(length(rx_all(x, '<w:br w:type="page"/>')), 1L)
  expect_equal(length(rx_all(x, "(?s)<w:tbl(?: [^>]*)?>")), 2L,
               label = "isContinues=FALSE default: one <w:tbl> per segment")
  rows <- cell_texts(p)
  header_rows <- Filter(function(r)
    length(r) >= 2 && r[1] == "g" && r[2] == "lab", rows)
  expect_equal(length(header_rows), 2L,
               label = "column header re-emitted in each segment")
})

# ---- ordering / interaction pairs (render-level) ------------------------------

test_that("glue BEFORE addrow: synthetic row carries the glued snapshot", {
  df <- data.frame(PARAM = c("ALT", "X"), VISIT = c("W1", "W1"),
                   stringsAsFactors = FALSE)
  p <- render_spec(
    create_table(df) |>
      define_cols(VISIT, isVisible = FALSE) |>
      compute_cols(PARAM == "ALT",
                   c_glue(PARAM, "after", glue_col = VISIT, separator = ":"),
                   c_addrow("above", value_from = PARAM)),
    "act_glue_add")
  texts <- unlist(cell_texts(p))
  expect_gte(sum(texts == "ALT:W1"), 2L,
             label = "glued value visible on both synthetic and source row")
  expect_true("X" %in% texts, label = "non-matched row unaffected")
})

test_that("clear-then-glue vs glue-then-clear produce different visible text", {
  df <- data.frame(a = c("keep", "hit"), b = c("B1", "B2"),
                   stringsAsFactors = FALSE)
  base <- create_table(df) |> define_cols(b, isVisible = FALSE)
  p1 <- render_spec(
    compute_cols(base, a == "hit", c_clear(a), c_glue(a, "after", glue_col = b)),
    "act_clr_gl")
  p2 <- render_spec(
    compute_cols(base, a == "hit", c_glue(a, "after", glue_col = b), c_clear(a)),
    "act_gl_clr")
  t1 <- unlist(cell_texts(p1))
  t2 <- unlist(cell_texts(p2))
  expect_true("B2" %in% t1, label = "clear->glue leaves glued value only")
  expect_false("hitB2" %in% t1)
  expect_false("B2" %in% t2, label = "glue->clear wipes the cell afterwards")
})

test_that("conditions see RAW data even after display-level glue", {
  df <- data.frame(a = c("x", "y"), b = c("1", "2"), stringsAsFactors = FALSE)
  p <- render_spec(
    create_table(df) |>
      add_style("bold_it", s_font(bold = TRUE)) |>
      compute_cols(a == "x",
                   c_glue(a, "after", text = "-GLUED"),
                   c_style(a, "bold_it")),
    "act_rawcond")
  ms <- docx_cells(p)
  glued_bold <- any(vapply(ms, function(m)
    any(m$text == "x-GLUED" & m$bold), logical(1)))
  expect_true(glued_bold,
              label = "style applies to raw-matched row despite glued display text")
})

test_that("two c_addrow calls above the same source stack contiguously", {
  df <- data.frame(a = c("first", "src", "last"), stringsAsFactors = FALSE)
  p <- render_spec(
    create_table(df) |>
      compute_cols(a == "src", c_addrow("above", value_from = a)) |>
      compute_cols(a == "src", c_addrow("above", value_from = a)),
    "act_two_calls")
  rows <- cell_texts(p)
  idx <- which(vapply(rows, function(r) length(r) >= 1 && r[1] == "src",
                      logical(1)))
  expect_equal(length(idx), 3L,
               label = "two synthetic rows + the real row all read 'src'")
  expect_equal(diff(idx), c(1L, 1L),
               label = "the three rows stack contiguously in document order")
})

test_that("overlapping merges in one block warn and keep one merge", {
  df <- data.frame(a = "x", b = "y", cc = "z", stringsAsFactors = FALSE)
  spec <- create_table(df) |>
    compute_cols(TRUE, c_merge(c(a, b)), c_merge(c(b, cc)))
  expect_warning(rpt <- create_report(spec), "merge|Merge|overlap")
  # survivor: first-defined merge remains (cols a,b)
  row1 <- jsonlite::fromJSON(rpt[[1]]$styleRows[1], simplifyVector = FALSE)
  expect_length(row1$merge, 1L)
  expect_equal(unlist(row1$merge[[1]]$cols), c("a", "b"))
})

test_that("c_style() across two blocks combines non-conflicting properties", {
  df <- data.frame(a = c("m", "n"), stringsAsFactors = FALSE)
  p <- render_spec(
    create_table(df) |>
      add_style("bold_it", s_font(bold = TRUE)) |>
      add_style("ital_it", s_font(italic = TRUE)) |>
      compute_cols(a == "m", c_style(a, "bold_it")) |>
      compute_cols(a == "m", c_style(a, "ital_it")),
    "act_style_combine")
  x <- docx_part_text(p)
  runs <- rx_all(x, "(?s)<w:r>(?:(?!</w:r>).)*<w:t(?: [^>]*)?>m</w:t>(?:(?!</w:r>).)*</w:r>")
  expect_gte(length(runs), 1L)
  expect_true(any(grepl("<w:b/>|<w:b ", runs)), label = "bold from block 1 kept")
  expect_true(any(grepl("<w:i/>|<w:i ", runs)), label = "italic from block 2 combined")
})
