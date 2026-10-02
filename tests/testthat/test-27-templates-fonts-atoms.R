# ============================================================================
# Test: templates listing/resolution, font registry, style-atoms catalog
#
# Previously ZERO references in tests (finding G1). UI shells
# (run_styles_editor / run_replay_app / view_tfl_spec / preview addins) stay
# out of scope here — they need a live Shiny/RStudio session and belong to
# manual or external verification.
# ============================================================================

test_that("tfl_list_templates() returns the bundled template names", {
  tmpls <- tfl_list_templates()
  expect_type(tmpls, "character")
  expect_gte(length(tmpls), 3L)
  expect_true("Default" %in% tmpls)
  expect_false(any(grepl("\\.json$", tmpls)), label = "names without extension")
  expect_identical(tmpls, sort(tmpls), label = "sorted listing")
})

test_that("write_doc() with a bundled overrideTemplate changes layout vs Default", {
  # Carbon_Dark is a bundled template with distinct header treatment; render
  # the same table twice and require document.xml to actually differ.
  dirs <- local_docx_dirs()
  base <- create_table(act_df()) |> add_title("Template probe")
  p_def <- write_doc(create_report(base), "tpl_default", outDir = dirs$out,
                     metaPath = dirs$meta, verbose = FALSE)
  p_alt <- write_doc(create_report(base), "tpl_alt", outDir = dirs$out,
                     metaPath = dirs$meta, verbose = FALSE,
                     overrideTemplate = "Carbon_Dark")
  expect_docx_valid(p_def)
  expect_docx_valid(p_alt)
  expect_false(identical(docx_part_text(p_def), docx_part_text(p_alt)),
               label = "override template visibly changes the document")
})

test_that("template numeric font_size is applied as points; string form unchanged (F04a)", {
  skip_if_not_installed("jsonlite")
  dirs <- local_docx_dirs()
  base <- jsonlite::fromJSON(system.file("templates", "Default.json", package = "ksTFL"),
                             simplifyVector = FALSE)
  sz_of <- function(x) unique(unlist(regmatches(x, gregexpr('w:sz w:val="[0-9]+"', x))))
  # baseline titles size (string) - sanity: distinct value present
  tpl_num <- base;  tpl_num$textStyles$titles$font$font_size <- 20     # JSON number
  tpl_str <- base;  tpl_str$textStyles$titles$font$font_size <- "20pt" # string twin
  f_num <- file.path(dirs$out, "t_num.json"); f_str <- file.path(dirs$out, "t_str.json")
  writeLines(jsonlite::toJSON(tpl_num, auto_unbox = TRUE, null = "null"), f_num)
  writeLines(jsonlite::toJSON(tpl_str, auto_unbox = TRUE, null = "null"), f_str)
  df1 <- data.frame(a = c("x", "y"), stringsAsFactors = FALSE)
  p_num <- write_doc(create_report(create_table(df1) |> add_title("T") |>
                       set_document(hasData = TRUE, docTemplate = f_num)),
                     "tpl_num_fs", outDir = dirs$out, metaPath = dirs$meta, verbose = FALSE)
  p_str <- write_doc(create_report(create_table(df1) |> add_title("T") |>
                       set_document(hasData = TRUE, docTemplate = f_str)),
                     "tpl_str_fs", outDir = dirs$out, metaPath = dirs$meta, verbose = FALSE)
  x_num <- docx_part_text(p_num); x_str <- docx_part_text(p_str)
  # 20pt -> half-point units -> 40
  expect_true(any(grepl('w:sz w:val="40"', sz_of(x_num))), info = paste(sz_of(x_num), collapse = " "))
  expect_identical(sort(sz_of(x_num)), sort(sz_of(x_str)),
                   label = "numeric and 'pt'-string font_size render identically")
})

test_that("template body/header row_height are applied when set (F04b); auto keeps measured", {
  skip_if_not_installed("jsonlite")
  dirs <- local_docx_dirs()
  base <- jsonlite::fromJSON(system.file("templates", "Default.json", package = "ksTFL"),
                             simplifyVector = FALSE)
  trh <- function(x) sort(unique(unlist(regmatches(x, gregexpr('w:trHeight w:val="[0-9]+"', x)))))
  df1 <- data.frame(a = c("x", "y"), stringsAsFactors = FALSE)

  tpl40 <- base
  tpl40$tableStyle$body$row$row_height   <- "40pt"
  tpl40$tableStyle$header$row$row_height <- "20pt"
  f <- file.path(dirs$out, "t_rh.json")
  writeLines(jsonlite::toJSON(tpl40, auto_unbox = TRUE, null = "null"), f)

  p <- write_doc(create_report(create_table(df1) |> add_title("T") |>
                   set_document(hasData = TRUE, docTemplate = f)),
                 "tpl_rh", outDir = dirs$out, metaPath = dirs$meta, verbose = FALSE)
  x <- docx_part_text(p)
  # 40pt = 800 twips, 20pt = 400 twips
  expect_true(grepl('w:trHeight w:val="800"', x, fixed = TRUE), info = paste(trh(x), collapse = " "))
  expect_true(grepl('w:trHeight w:val="400"', x, fixed = TRUE), info = paste(trh(x), collapse = " "))

  # explicit spec row_h atom must still WIN over the template value
  p2 <- write_doc(create_report(create_table(df1) |> add_title("T") |>
                   add_style("rh2", s_table_style(row_height = "2pt")) |>
                   compute_cols(TRUE, c_style(a, "rh2")) |>
                   set_document(hasData = TRUE, docTemplate = f)),
                 "tpl_rh_atom", outDir = dirs$out, metaPath = dirs$meta, verbose = FALSE)
  x2 <- docx_part_text(p2)
  expect_true(grepl('w:trHeight w:val="40"', x2, fixed = TRUE),
              label = "spec row_height atom beats template row_height")

  # bundled default: row_height "auto" -> nothing changes vs plain Default render
  p3 <- write_doc(create_report(create_table(df1) |> add_title("T") |>
                   set_document(hasData = TRUE)),
                 "tpl_rh_default", outDir = dirs$out, metaPath = dirs$meta, verbose = FALSE)
  x3 <- docx_part_text(p3)
  expect_false(grepl('w:trHeight w:val="800"', x3, fixed = TRUE),
               label = "auto template height stays measured (no regression)")
})

test_that("cellDefaults.vertical_alignment applies when nothing higher sets valign (F04d)", {
  skip_if_not_installed("jsonlite")
  dirs <- local_docx_dirs()
  base <- jsonlite::fromJSON(system.file("templates", "Default.json", package = "ksTFL"),
                             simplifyVector = FALSE)
  va_of <- function(x) sort(unique(unlist(regmatches(x, gregexpr('w:vAlign w:val="[a-z]+"', x)))))

  # strip valign from all higher cascade levels (row defaults + structural),
  # leave cellDefaults.vertical_alignment = top
  tpl <- base
  tpl$tableStyle$header$row$vertical_alignment <- NULL
  tpl$tableStyle$body$row$vertical_alignment   <- NULL
  tpl$tableStyle$structural$allHeaders$vertical_alignment <- NULL
  tpl$tableStyle$structural$tableBody$vertical_alignment  <- NULL
  tpl$tableStyle$cellDefaults$vertical_alignment <- "top"
  f <- file.path(dirs$out, "t_cdva.json")
  writeLines(jsonlite::toJSON(tpl, auto_unbox = TRUE, null = "null"), f)

  df1 <- data.frame(a = c("x", "y"), stringsAsFactors = FALSE)
  p <- write_doc(create_report(create_table(df1) |> add_title("T") |>
                   set_document(hasData = TRUE, docTemplate = f)),
                 "tpl_cdva", outDir = dirs$out, metaPath = dirs$meta, verbose = FALSE)
  expect_identical(va_of(docx_part_text(p)), 'w:vAlign w:val="top"',
                   label = "cellDefaults valign reaches the DOCX when nothing overrides it")

  # bundled Default unchanged: every cell still center (structural wins)
  p2 <- write_doc(create_report(create_table(df1) |> add_title("T") |>
                   set_document(hasData = TRUE)),
                 "tpl_cdva_default", outDir = dirs$out, metaPath = dirs$meta, verbose = FALSE)
  expect_identical(va_of(docx_part_text(p2)), 'w:vAlign w:val="center"',
                   label = "Default template valign cascade unchanged (zero golden diff)")

  # cell-level va atom must still beat cellDefaults
  tpl2 <- tpl
  tpl2$tableStyle$cellDefaults$vertical_alignment <- "bottom"
  f2 <- file.path(dirs$out, "t_cdva2.json")
  writeLines(jsonlite::toJSON(tpl2, auto_unbox = TRUE, null = "null"), f2)
  p3 <- write_doc(create_report(create_table(df1) |> add_title("T") |>
                   add_style("vat", s_table_style(vertical_alignment = "top")) |>
                   compute_cols(TRUE, c_style(a, "vat")) |>
                   set_document(hasData = TRUE, docTemplate = f2)),
                 "tpl_cdva_atom", outDir = dirs$out, metaPath = dirs$meta, verbose = FALSE)
  x3 <- docx_part_text(p3)
  expect_true(grepl('w:vAlign w:val="top"', x3, fixed = TRUE),
              label = "spec va atom wins over cellDefaults")
  expect_true(grepl('w:vAlign w:val="bottom"', x3, fixed = TRUE),
              label = "untouched cells fall back to cellDefaults bottom")
})

test_that("write_doc() warns and falls back to Default for an unknown template name", {
  dirs <- local_docx_dirs()
  expect_warning(
    p <- write_doc(create_report(create_table(act_df()) |> add_title("X")),
                   "tpl_unknown", outDir = dirs$out, metaPath = dirs$meta,
                   verbose = FALSE, overrideTemplate = "NoSuchTemplate"),
    "fallback|Default|cannot|not found|resolve", ignore.case = TRUE)
  expect_docx_valid(p)
})

test_that("unknown docTemplate on the spec also warns, never silently corrupts", {
  dirs <- local_docx_dirs()
  spec <- create_table(act_df()) |>
    add_title("Bad spec template") |>
    set_document(docTemplate = "TotallyMissing")
  expect_warning(
    p <- write_doc(create_report(spec), "tpl_spec_bad", outDir = dirs$out,
                   metaPath = dirs$meta, verbose = FALSE),
    "Default|fallback|resolve|not found", ignore.case = TRUE)
  expect_docx_valid(p)
})

test_that("tfl_font_status() reports registry without erroring", {
  st <- tfl_font_status()
  expect_true(is.null(st) || is.list(st) || is.data.frame(st))
})

test_that("tfl_rescan_fonts() rebuilds the registry and status stays consistent", {
  expect_no_error(tfl_rescan_fonts())
  st <- tfl_font_status()
  expect_false(is.null(st), label = "registry present after explicit rescan")
})

test_that("style atoms catalog is built and emitted without error", {
  # NOTE: the catalog uses cli console output, which is NOT capturable via
  # capture.output() in a scripted (non-interactive) session — verified on
  # zorin 2026-09-29. Assert the call itself succeeds; the atoms' real
  # contract is exercised by the rendering test below.
  expect_no_error(tfl_style_atoms_catalog())
  expect_no_error(tfl_print_style_atoms())
})

test_that("atoms actually resolve as style references in a rendered spec", {
  # the atoms catalog is only documentation if add_style/f_combine accept names
  p <- render_spec(
    create_table(act_df()) |>
      add_style("hd", s_font(bold = TRUE)) |>
      compute_cols(lab == "r3", c_style(lab, "hd")),
    "atoms_render")
  ms <- docx_cells(p)
  bold_r3 <- any(vapply(ms, function(m) any(m$text == "r3" & m$bold), logical(1)))
  expect_true(bold_r3)
})
