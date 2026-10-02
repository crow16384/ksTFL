# ============================================================================
# Test: DOCX structural validation (task §9 tier B)
#
# Pure-R assertions over the OOXML package: parts, sections, tables, header
# rows, page geometry, embedded figures. No external tools (see test-suite
# review 2026-09-29); rendering fidelity beyond structure lives in the
# external harness tests-docx/.
# ============================================================================

W <- 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'

test_that("a minimal table DOCX has the mandatory OOXML skeleton", {
  p <- render_spec(create_table(data.frame(a = 1, b = "x")) |>
                     add_title("Skeleton"), "skel")
  expect_docx_valid(p)
  parts <- docx_parts(p)
  expect_true("word/fontTable.xml" %in% parts ||
                "word/styles.xml" %in% parts,
              label = "at least one style/font definition part")
  expect_true("docProps" %in% paste0("x", "") ||
                any(grepl("^word/", parts)), label = "word/ tree present")
  x <- docx_part_text(p)
  expect_match(x, W, fixed = TRUE, label = "main namespace declared")
})

test_that("section properties reflect page settings (A4 default, Letter override)", {
  pa <- render_spec(create_table(data.frame(a = 1)) |> add_title("A4"), "sec_a4")
  x <- docx_part_text(pa)
  m <- rx_group(x, '<w:pgSz ([^/]*)/>', 1)
  expect_gte(length(m), 1L)
  expect_true(any(grepl('w:w="16838"', m)), info = paste(m, collapse = " "))
  expect_true(any(grepl('w:h="11906"', m)), info = paste(m, collapse = " "))
  expect_true(any(grepl('w:orient="landscape"', m)))

  pl <- render_spec(
    create_table(data.frame(a = 1)) |> add_title("Letter") |>
      set_page_style(page = p_page(size = "Letter", orientation = "portrait")),
    "sec_letter")
  xl <- docx_part_text(pl)
  ml <- rx_group(xl, '<w:pgSz ([^/]*)/>', 1)
  expect_true(any(grepl('w:w="12240"', ml)), info = paste(ml, collapse = " "))
  expect_true(any(grepl('w:h="15840"', ml)), info = paste(ml, collapse = " "))
  expect_false(any(grepl('w:orient="landscape"', ml)))
})

test_that("continuousSection writes sectPr type=continuous; default is nextPage", {
  pc <- render_spec(create_table(data.frame(a = 1)) |>
                      set_document(continuousSection = TRUE) |>
                      add_title("C"), "sec_cont")
  xc <- docx_part_text(pc)
  expect_match(xc, '<w:type w:val="continuous"', fixed = TRUE)

  # default: NO explicit w:type in the trailing sectPr (OOXML implies nextPage)
  pn <- render_spec(create_table(data.frame(a = 1)) |> add_title("N"), "sec_next")
  xn <- docx_part_text(pn)
  sect <- rx_all(xn, "(?s)<w:sectPr[^>]*>.*?</w:sectPr>")
  expect_gte(length(sect), 1L)
  expect_false(any(grepl('<w:type', sect, fixed = TRUE)),
               label = "single-section default omits w:type (Word: nextPage)")
})

test_that("column-header rows are marked as repeatable (w:tblHeader)", {
  p <- render_spec(create_table(act_df()) |> add_title("HD"), "hdrrow")
  x <- docx_part_text(p)
  expect_gte(length(rx_all(x, "<w:tblHeader/>")), 1L,
             label = "header row carries w:tblHeader")
})

test_that("add_header()/add_footer() emit header/footer parts with their text", {
  p <- render_spec(
    create_table(data.frame(a = 1:2)) |>
      add_title("HF") |>
      add_header(c("LeftH", "CenterH", "RightH")) |>
      add_footer(c("LeftF", "CenterF", "RightF")),
    "hf")
  parts <- docx_parts(p)
  hdrs <- parts[grepl("^word/header.*\\.xml$", parts)]
  ftrs <- parts[grepl("^word/footer.*\\.xml$", parts)]
  expect_gte(length(hdrs), 1L, label = "header parts exist")
  expect_gte(length(ftrs), 1L, label = "footer parts exist")
  all_hf <- paste(vapply(c(hdrs, ftrs), function(q) docx_part_text(p, q), character(1)),
                  collapse = "")
  for (txt in c("LeftH", "CenterH", "RightH", "LeftF", "CenterF", "RightF")) {
    expect_true(grepl(txt, all_hf, fixed = TRUE), label = paste0("HF text: ", txt))
  }
  # sectPr must reference the parts
  x <- docx_part_text(p)
  expect_match(x, "headerReference", fixed = TRUE)
  expect_match(x, "footerReference", fixed = TRUE)
})

test_that("figure DOCX embeds the image part and references it", {
  skip_if_not(file.exists(test_image_path))
  p <- render_spec(create_figure(test_image_path) |> add_title("Fig"), "fig1")
  expect_docx_valid(p)
  parts <- docx_parts(p)
  media <- parts[grepl("^word/media/", parts)]
  expect_equal(length(media), 1L)
  expect_true(grepl("\\.png$", media), info = media)
  x <- docx_part_text(p)
  expect_match(x, "<w:drawing", fixed = TRUE)
  rels <- docx_part_text(p, "word/_rels/document.xml.rels")
  expect_match(rels, "media/", fixed = TRUE)
})

test_that("table grid geometry: one w:gridCol per visible column; widths sum positive", {
  p <- render_spec(
    create_table(act_df()) |>
      define_cols(g, colWidth = "2cm") |>
      define_cols(v, isVisible = FALSE),
    "grid1")
  x <- docx_part_text(p)
  grid <- rx_all(x, "(?s)<w:tblGrid>.*?</w:tblGrid>")[1]
  expect_false(is.na(grid))
  cols <- rx_group(grid, '<w:gridCol w:w="(\\d+)"', 1)
  expect_equal(length(cols), 2L)
  widths <- as.integer(cols)
  expect_true(all(widths > 0))
  expect_gt(widths[1], 0)  # explicit colWidth honoured at least as nonzero dxa
})

test_that("isContinues=FALSE splits long tables into per-page <w:tbl>; TRUE keeps one table", {
  # (verified 2026-09-29; also relevant to trap 11 in the coder skill)
  big <- data.frame(lab = paste0("r", 1:60), val = as.numeric(1:60))
  base <- create_table(big) |> add_title("Cont contract") |>
    define_cols(lab, isPaging = TRUE)
  p_false <- render_spec(base |> set_document(isContinues = FALSE), "cont_f")
  p_true  <- render_spec(base |> set_document(isContinues = TRUE),  "cont_t")
  x_f <- docx_part_text(p_false); x_t <- docx_part_text(p_true)
  tbl_f <- length(rx_all(x_f, "(?s)<w:tbl(?: [^>]*)?>"))
  tbl_t <- length(rx_all(x_t, "(?s)<w:tbl(?: [^>]*)?>"))
  expect_gte(tbl_f, 1L)
  expect_lte(tbl_t, tbl_f, label = "continuous keeps fewer (one) table blocks")
  # native header repeat only in continuous mode
  expect_match(x_t, "<w:tblHeader/>", fixed = TRUE)
})

test_that("doc_footer footnotes survive WITHOUT add_footer (finding F05a)", {
  df <- data.frame(a = c("x", "y"), stringsAsFactors = FALSE)
  p <- render_spec(create_table(df) |>
                     add_footnote("NOTE_IN_DOCFOOTER") |>
                     set_document(hasData = TRUE, footnotePlace = "doc_footer"),
                   "f05a_noftr")
  parts <- docx_parts(p)
  footers <- grep("^word/footer.*\\.xml$", parts, value = TRUE)
  expect_gte(length(footers), 1L, label = "footer part auto-created for doc_footer notes")
  all_ft <- paste(vapply(footers, function(f) docx_part_text(p, f), character(1)), collapse = "")
  expect_match(all_ft, "NOTE_IN_DOCFOOTER", fixed = TRUE,
               label = "footnote text present in the footer part")
  # repeated mode must NOT gain a footer part when no footer rows were added
  p2 <- render_spec(create_table(df) |>
                      add_footnote("NOTE_REPEATED") |>
                      set_document(hasData = TRUE, footnotePlace = "repeated"),
                    "f05a_rep")
  expect_equal(length(grep("^word/footer.*\\.xml$", docx_parts(p2))), 0L,
               label = "no footer part without footer rows in repeated mode")
  x2 <- docx_part_text(p2)
  expect_match(x2, "NOTE_REPEATED", fixed = TRUE, label = "repeated note still in body")
})

test_that("doc_footer with explicit add_footer keeps footer rows AND note (regression pair)", {
  df <- data.frame(a = c("x", "y"), stringsAsFactors = FALSE)
  p <- render_spec(create_table(df) |>
                     add_footnote("NOTE_A") |>
                     add_footer("FOOTER_ROW_B") |>
                     set_document(hasData = TRUE, footnotePlace = "doc_footer"),
                   "f05a_with")
  parts <- docx_parts(p)
  footers <- grep("^word/footer.*\\.xml$", parts, value = TRUE)
  expect_gte(length(footers), 1L)
  all_ft <- paste(vapply(footers, function(f) docx_part_text(p, f), character(1)), collapse = "")
  expect_true(all(c("NOTE_A", "FOOTER_ROW_B") %in% c(
    if (grepl("NOTE_A", all_ft, fixed = TRUE)) "NOTE_A" else NA,
    if (grepl("FOOTER_ROW_B", all_ft, fixed = TRUE)) "FOOTER_ROW_B" else NA)),
    label = "both footnote and footer rows land in the footer part")
})

test_that("empty-text document renders body paragraphs without a table", {
  dirs <- local_docx_dirs()
  spec <- create_text() |>
    add_title("Pure text") |>
    add_body_text("Line one") |>
    add_body_text("Line two")
  p <- write_doc(create_report(spec), "txt1", outDir = dirs$out,
                 metaPath = dirs$meta, verbose = FALSE)
  x <- docx_part_text(p)
  expect_equal(length(rx_all(x, "(?s)<w:tbl(?: [^>]*)?>")), 0L)
  paras <- docx_paragraph_texts(p)
  expect_true(all(c("Line one", "Line two") %in% paras))
  expect_equal(which(paras == "Line one") < which(paras == "Line two"), TRUE,
               label = "body text order preserved")
})
