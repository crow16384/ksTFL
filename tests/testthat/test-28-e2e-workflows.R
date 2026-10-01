# ============================================================================
# Test: end-to-end pipelines (task §10)
#
# Representative multi-feature workflows: data -> spec DSL -> actions ->
# DOCX -> full A+B+C validation -> replay. Integration regressions that
# unit tests structurally cannot see (R layer <-> C++ engine contract).
# ============================================================================

tfl_uk <- function() {
  data.frame(
    SECTION   = c("Demographics", "Demographics", "AEs", "AEs"),
    PARAM     = c("Age (years)", "Sex (M/F)", "Any AE", "SAE"),
    COL1      = c("n", "value", "value", "value"),
    TRTA      = c("45.2 (3.1)", "21 / 9", "18 (60.0%)", "3 (10.0%)"),
    TRTB      = c("46.0 (2.8)", "19 / 11", "12 (40.0%)", "1 (3.3%)"),
    stringsAsFactors = FALSE
  )
}

test_that("E2E safety-table workflow: spans, dedupe, widths, footnote, header/footer", {
  p <- render_spec(
    create_table(tfl_uk()) |>
      define_cols(SECTION, label = "", dedupe = TRUE, isVisible = FALSE) |>
      define_cols(PARAM, label = "Parameter", colWidth = "5cm") |>
      define_cols(COL1, label = "", isVisible = FALSE) |>
      define_cols(TRTA, label = "Trt A (N=30)", colWidth = "3cm") |>
      define_cols(TRTB, label = "Trt B (N=30)", colWidth = "3cm") |>
      add_title("Table 1. Demographics and AEs") |>
      add_footnote("Data on file.") |>
      add_header(c("", "Protocol XYZ", "")) |>
      add_footer(c("Confidential", "Page {PAGE}")) |>
      compute_cols(SECTION == "AEs",
                   c_addrow("above", value_from = SECTION)) |>
      set_page_style(page = p_page(size = "A4", orientation = "landscape")),
    "e2e_uk")

  # A: valid document
  expect_docx_valid(p)
  # B: exactly one table, header/footer parts present, footer references
  x <- docx_part_text(p)
  expect_equal(length(rx_all(x, "(?s)<w:tbl(?: [^>]*)?>")), 1L)
  expect_true(any(grepl("^word/footer", docx_parts(p))))
  expect_match(x, "footerReference", fixed = TRUE)
  # C: every content string the user provided is in the document
  # every content string the user provided: body/document.xml...
  texts <- unlist(c(docx_paragraph_texts(p), unlist(cell_texts(p), recursive = FALSE)))
  # ...plus running header/footer parts (page furniture lives there, not document.xml)
  hf_parts <- grep("^word/(header|footer)", docx_parts(p), value = TRUE)
  hf_text <- paste(vapply(hf_parts, function(q)
    paste(docx_paragraph_texts(p, q), collapse = " "), character(1)), collapse = " ")
  for (needle in c("Table 1. Demographics and AEs", "Parameter",
                   "Trt A (N=30)", "45.2 (3.1)", "18 (60.0%)", "SAE",
                   "Data on file")) {
    expect_true(any(grepl(needle, texts, fixed = TRUE)),
                label = paste0("E2E content present: ", needle))
  }
  for (needle in c("Protocol XYZ", "Confidential")) {
    expect_true(grepl(needle, hf_text, fixed = TRUE),
                label = paste0("E2E page furniture present: ", needle))
  }
  # {PAGE} macro must become a real Word field, not literal text
  hf_raw <- paste(vapply(hf_parts, function(q) docx_part_text(p, q), character(1)),
                  collapse = "")
  expect_true(grepl("<w:instrText[^>]*>\\s*PAGE\\s*</w:instrText>", hf_raw),
              label = "Page field emitted as instrText")
  # synthetic section header rows exist (twice: AEs group)
  sect_rows <- Filter(function(r) length(r) == 1 && r == "AEs", cell_texts(p))
  expect_gte(length(sect_rows), 1L)
})

test_that("E2E write -> replay reproduces byte-stable document.xml for a complex spec", {
  dirs <- local_docx_dirs()
  spec <- create_table(tfl_uk()) |>
    add_title("Replay me") |>
    define_cols(SECTION, dedupe = TRUE) |>
    add_style("bold_it", s_font(bold = TRUE)) |>
    compute_cols(PARAM == "SAE", c_style(TRTA, "bold_it"))
  orig <- write_doc(create_report(spec), "rp", outDir = dirs$out,
                    metaPath = dirs$meta, verbose = FALSE)
  sf <- spec_json_paths(dirs$meta)
  again <- file.path(dirs$out, "rp_again.docx")
  replay_report(sf[1], meta_dir = dirs$meta, output_path = again)
  expect_equal(docx_part_text(orig), docx_part_text(again),
               label = "renderer deterministic: replay == original document.xml")
})

test_that("E2E figure workflow: ggplot PNG (if available) embeds into figure DOCX", {
  skip_if_not_installed("ggplot2")
  png_path <- tempfile(fileext = ".png")
  grDevices::png(png_path, width = 400, height = 300)
  print(ggplot2::ggplot(data.frame(x = 1:3, y = 1:3),
                        ggplot2::aes(x, y)) + ggplot2::geom_point())
  grDevices::dev.off()
  on.exit(unlink(png_path), add = TRUE)

  old_w <- tfl_get_option("figureWidth"); old_h <- tfl_get_option("figureHeight")
  on.exit({ tfl_set_options(figureWidth = old_w); tfl_set_options(figureHeight = old_h) },
          add = TRUE)
  tfl_set_options(figureWidth = "8in", figureHeight = "5in")
  p <- render_spec(
    create_figure(png_path) |>
      add_title("Figure 1. Scatter"),
    "e2e_fig")
  expect_docx_valid(p)
  media <- docx_parts(p)[grepl("^word/media/", docx_parts(p))]
  expect_length(media, 1L)
  x <- docx_part_text(p)
  expect_match(x, "<w:drawing", fixed = TRUE)
  expect_true(grepl("Figure 1. Scatter", paste(docx_paragraph_texts(p), collapse = "|"),
                    fixed = TRUE))
})

test_that("E2E multi-spec mixed report: order, TOC, per-spec types in one document", {
  dirs <- local_docx_dirs()
  t1 <- create_table(act_df()) |> add_title("E2E Table One")
  tx  <- create_text() |> add_body_text("E2E narrative paragraph")
  r2  <- create_table(act_df()) |> add_title("E2E Table Two")
  p <- write_doc(create_report(t1, tx, r2), "e2e_mixed",
                 outDir = dirs$out, metaPath = dirs$meta, verbose = FALSE,
                 toc = TRUE, tocTitle = "Index")
  expect_docx_valid(p)
  x <- docx_part_text(p)
  expect_equal(length(rx_all(x, "(?s)<w:tbl(?: [^>]*)?>")), 2L)
  texts <- paste(c(docx_paragraph_texts(p),
                   unlist(cell_texts(p), recursive = FALSE)), collapse = "\n")
  for (needle in c("Index", "E2E Table One", "E2E narrative paragraph",
                   "E2E Table Two")) {
    expect_true(grepl(needle, texts, fixed = TRUE),
                label = paste0("mixed doc: ", needle))
  }
  expect_lt(unname(gregexpr("E2E Table One", texts)[[1]][1]),
            unname(gregexpr("E2E Table Two", texts)[[1]][1]),
            label = "doc order follows create_report() argument order")
})

test_that("E2E pagination: enough rows to split -> multiple tbl segments with repeated headers", {
  .seed0 <- suppressWarnings(RNGkind()); set.seed(7)
  big <- data.frame(lab = paste0("row_", 1:40), val = round(rnorm(40), 2))
  suppressWarnings(RNGkind(.seed0[1], .seed0[2], .seed0[3]))
  p <- render_spec(
    create_table(big) |>
      add_title("Long listing") |>
      define_cols(lab, label = "Label") |>
      define_cols(val, label = "Value", format = "%.2f"),
    "e2e_paginate")
  x <- docx_part_text(p)
  tbls <- length(rx_all(x, "(?s)<w:tbl(?: [^>]*)?>"))
  expect_gte(tbls, 1L)
  # all rows present exactly once across segments (no row loss in pagination)
  texts <- unlist(cell_texts(p))
  expect_equal(sum(texts == "row_1"), 1L)
  expect_equal(sum(texts == "row_40"), 1L)
  expect_equal(sum(startsWith(texts, "row_")), 40L,
               label = "pagination never drops or duplicates data rows")
})
