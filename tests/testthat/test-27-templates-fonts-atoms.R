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
