# ============================================================================
# Test: DOCX semantic content validation (task §9 tier C)
#
# The document must not merely exist and parse — it must contain the data the
# user put in, formatted as configured, in order. Pure-R over document.xml.
# ============================================================================

test_that("cell values render through define_cols format and missings token", {
  df <- data.frame(x = c(1.234, NA, 2), stringsAsFactors = FALSE)
  p <- render_spec(
    create_table(df) |> define_cols(x, format = "%.2f", missings = "NA*"),
    "sem_fmt")
  texts <- unlist(cell_texts(p))
  expect_true("1.23" %in% texts && "2.00" %in% texts,
              info = paste(texts, collapse = " | "))
  expect_true("NA*" %in% texts, label = "missings token substituted")
  expect_false("NA" %in% texts, label = "bare NA never leaks into document")
})

test_that("labels are what is rendered as column headers, not raw names", {
  p <- render_spec(
    create_table(act_df()) |>
      define_cols(g, label = "Treatment group"),
    "sem_label")
  paras <- docx_paragraph_texts(p)
  expect_true("Treatment group" %in% paras)
  expect_false("g" %in% paras, label = "raw column name replaced by label")
})

test_that("titles, subtitles and footnotes appear as document text in order", {
  p <- render_spec(
    create_table(act_df()) |>
      add_title("The Main Title") |>
      add_subtitle("The Subtitle") |>
      add_footnote("A footnote here"),
    "sem_text")
  paras <- docx_paragraph_texts(p)
  i_t <- which(paras == "The Main Title")
  i_s <- which(paras == "The Subtitle")
  expect_equal(i_t + 1L, i_s, label = "subtitle directly below title")
  expect_true(any(grepl("A footnote here", paras, fixed = TRUE)))
  # title paragraph precedes first table content in document order
  all_texts <- unlist(paras)
  expect_lt(which(all_texts == "The Main Title")[1],
            which(all_texts %in% c("r1", "g"))[1])
})

test_that("inline markup renders as OOXML structure, not literal tags", {
  dirs <- local_docx_dirs()
  p <- write_doc(create_report(
    create_text() |>
      add_body_text("H<sub>2</sub>O and E=mc<sup>2</sup> line<br>next")),
    "sem_markup", outDir = dirs$out, metaPath = dirs$meta, verbose = FALSE)
  x <- docx_part_text(p)
  expect_match(x, '<w:vertAlign w:val="subscript"', fixed = TRUE)
  expect_match(x, '<w:vertAlign w:val="superscript"', fixed = TRUE)
  expect_true(grepl("<w:br/>", x, fixed = TRUE))
  expect_false(grepl("<sub>", x, fixed = TRUE),
               label = "markup consumed, never leaked as literal text")
})

test_that("row order in document mirrors input data order (rendering contract)", {
  df <- data.frame(lab = c("zeta", "alpha", "mid"), val = 3:1,
                   stringsAsFactors = FALSE)
  p <- render_spec(create_table(df), "sem_order")
  col1 <- unlist(lapply(cell_texts(p), function(r) if (length(r)) r[1] else NA))
  idx <- match(c("zeta", "alpha", "mid"), col1)
  expect_true(!any(is.na(idx)), label = "all three rows present")
  expect_equal(diff(idx), c(1L, 1L),
               label = "package never reorders input rows")
})

test_that("UTF-8 content survives round-trip into the document", {
  dirs <- local_docx_dirs()
  txt <- "Клиника 中文 © ™"
  p <- write_doc(create_report(create_text() |> add_body_text(txt)),
                 "sem_utf", outDir = dirs$out, metaPath = dirs$meta,
                 verbose = FALSE)
  paras <- docx_paragraph_texts(p)
  expect_true(any(grepl(txt, paras, fixed = TRUE)),
              label = "non-ASCII body text present verbatim")
})

test_that("dedupe=TRUE suppresses repeated values but keeps row count", {
  df <- data.frame(g = c("A", "A", "A", "B"), x = 1:4, stringsAsFactors = FALSE)
  p <- render_spec(create_table(df) |> define_cols(g, dedupe = TRUE), "sem_dedupe")
  rows <- cell_texts(p)
  data_rows <- Filter(function(r) length(r) == 2 && r[2] %in% as.character(1:4), rows)
  expect_equal(length(data_rows), 4L, label = "all rows still rendered")
  first_col <- vapply(data_rows, function(r) r[1], character(1))
  expect_equal(first_col, c("A", "", "", "B"),
               label = "run-based suppression: only first of each run shows")
})

test_that("TOC option inserts a real field with the custom title", {
  dirs <- local_docx_dirs()
  r1 <- create_report(
    create_table(data.frame(a = 1)) |> add_title("First TFL"),
    create_table(data.frame(a = 2)) |> add_title("Second TFL"))
  p <- write_doc(r1, "sem_toc", outDir = dirs$out, metaPath = dirs$meta,
                 verbose = FALSE, toc = TRUE, tocTitle = "Contents TFL")
  x <- docx_part_text(p)
  expect_match(x, "<w:instrText", fixed = TRUE)
  expect_true(grepl("TOC", x, fixed = TRUE))
  expect_true(grepl("Contents TFL", x, fixed = TRUE))
})

test_that("isColBreak splits a wide table into repeated-ID segments", {
  df <- data.frame(A = 1:3, B = 4:6, C = 7:9, D = 10:12, stringsAsFactors = FALSE)
  p <- render_spec(
    create_table(df) |>
      define_cols(A, isID = TRUE) |>
      define_cols(B, isColBreak = TRUE),
    "sem_colbreak")
  x <- docx_part_text(p)
  expect_equal(length(rx_all(x, "(?s)<w:tbl(?: [^>]*)?>")), 2L,
               label = "two segments on separate pages")
  rows <- cell_texts(p)
  headers <- Filter(function(r) "A" %in% r, rows)
  expect_gte(length(headers), 2L, label = "ID column header repeats per segment")
})

test_that("footnotePlace=doc_footer puts the note in the footer part WHEN paired with add_footer", {
  # Author-accepted contract (0.11.9): doc_footer REQUIRES add_footer(), else the
  # note is silently dropped. Pinned so any change to this semantics is loud.
  dirs <- local_docx_dirs()
  spec <- create_table(data.frame(a = 1:2)) |>
    set_document(footnotePlace = "doc_footer") |>
    add_footnote("DF-NOTE-ABC") |>
    add_footer(c("Conf", ""))
  p <- write_doc(create_report(spec), "sem_docfooter", outDir = dirs$out,
                 metaPath = dirs$meta, verbose = FALSE)
  fparts <- grep("^word/footer", docx_parts(p), value = TRUE)
  expect_true(any(vapply(fparts, function(q)
    grepl("DF-NOTE-ABC", docx_part_text(p, q), fixed = TRUE), logical(1))),
    label = "note lands in a footer part")

  # unpaired: FIXED behavior (F05a) — the footer part is auto-created and
  # the note survives without add_footer() (was silently dropped pre-fix)
  dirs2 <- local_docx_dirs()
  spec2 <- create_table(data.frame(a = 1:2)) |>
    set_document(footnotePlace = "doc_footer") |>
    add_footnote("DF-NOTE-DROPPED")
  p2 <- write_doc(create_report(spec2), "sem_docfooter2", outDir = dirs2$out,
                  metaPath = dirs2$meta, verbose = FALSE)
  fparts2 <- grep("^word/footer", docx_parts(p2), value = TRUE)
  expect_gte(length(fparts2), 1L, label = "footer part auto-created without add_footer")
  expect_true(any(vapply(fparts2, function(q)
    grepl("DF-NOTE-DROPPED", docx_part_text(p2, q), fixed = TRUE), logical(1))),
    label = "doc_footer note survives without add_footer")
})

test_that("footnotePlace last_page vs repeated differ only across multi-page splits", {
  # a page-split table via c_pageBreak shows placement difference
  df <- data.frame(lab = c("one", "two"), stringsAsFactors = FALSE)
  dirs <- local_docx_dirs()  # lives for the whole test_that body
  mk <- function(place) {
    write_doc(create_report(
      create_table(df) |>
        set_document(footnotePlace = place) |>
        add_footnote("PLACE-MARKER") |>
        compute_cols(lab == "two", c_pageBreak())),
      paste0("sem_fn_", place), outDir = dirs$out, metaPath = dirs$meta,
      verbose = FALSE)
  }
  x_rep_paras <- paste(docx_paragraph_texts(mk("repeated")), collapse = "|")
  x_lst_paras <- paste(docx_paragraph_texts(mk("last_page")), collapse = "|")
  # NOTE: raw document.xml grep is unreliable here — text may split across
  # runs; joined paragraph text is the observable truth.
  expect_equal(lengths(regmatches(x_rep_paras, gregexpr("PLACE-MARKER", x_rep_paras))), 2L,
               label = "repeated: footnote on every segment")
  expect_equal(lengths(regmatches(x_lst_paras, gregexpr("PLACE-MARKER", x_lst_paras))), 1L,
               label = "last_page: footnote once")
})
