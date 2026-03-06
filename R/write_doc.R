## =============================================================================
## High-level convenience: save + render report in one step
## =============================================================================

#' Save and Render a TFL Report to DOCX
#'
#' Convenience wrapper around [save_report()] and [render_docx()] that saves a
#' `TFL_report` object to JSON (plus any required data/figure files) and
#' immediately renders it to a DOCX file in a single call.
#'
#' This mirrors the helper used in the example `inst/examples/init.R` script
#' (previously called `save_and_render()`), but is provided as a public,
#' documented API function named `write_doc()`.
#'
#' @param report A `TFL_report` object created by [create_report()].
#' @param name Character(1). Base file name (without extension) for the output
#'   DOCX document. The `.docx` extension is appended automatically.
#' @param outDir Character(1). Directory where the final DOCX file will be
#'   written. Defaults to `tfl_get_option("output_directory")`.
#' @param metaPath Character(1). Directory where the intermediate specification
#'   JSON and associated data/figure files will be stored. Defaults to
#'   `tfl_get_option("meta_directory")`.
#' @param prettify Logical. When `TRUE`, pretty‑prints the JSON written by
#'   [save_report()] for easier inspection. Default `FALSE` (compact JSON).
#' @param toc Logical. When `TRUE`, enables automatic insertion of a Table of
#'   Contents page via [save_report()]. Defaults to
#'   `tfl_get_option("insertTOC")`.
#' @param tocTitle Character(1). Heading placed above the TOC field on the TOC
#'   page. Defaults to `tfl_get_option("tocTitle")`.
#' @param overrideTemplate Optional character string. Global template override used
#'   by [render_docx()] for all specs. Accepts either:
#'   \\itemize{
#'     \\item A predefined bundled template name (e.g. `"Navy_Pro"`).
#'     \\item A file path (absolute or relative) to an external template JSON file.
#'   }
#'   If `NULL` (default), templates are resolved per-spec from each spec's
#'   `docTemplate` value via [render_docx()] (allowing mixed templates in
#'   multi-spec reports). If a provided name/path cannot be resolved,
#'   a warning is emitted and `CRO Example_default` is used.
#' @param font_dirs Optional character vector of additional directories to
#'   search for fonts when rendering via [render_docx()].
#' @param fallback_font Optional character string. Path to a fallback font file
#'   used by [render_docx()]. If `NULL`, the package default is used.
#' @param verbose Logical. If `TRUE`, [render_docx()] prints progress messages.
#'
#' @return Invisibly returns the full path to the generated `.docx` file.
#'
#' @seealso [create_report()], [save_report()], [render_docx()],
#'   [tfl_set_options()], [tfl_get_option()]
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Basic end-to-end workflow ----------------------------------------------
#' library(ksTFL)
#'
#' # Create a simple table spec
#' tbl <- create_table(mtcars) |>
#'   add_title("Table 1: Motor Trend Car Road Tests") |>
#'   set_document(hasData = TRUE)
#'
#' # Combine into a report
#' rpt <- create_report(tbl)
#'
#' # Write DOCX to the default output directory (getwd() by default)
#' doc_path <- write_doc(
#'   report = rpt,
#'   name   = "mtcars_demo"
#' )
#'
#' cat("DOCX written to:", doc_path, "\n")
#'
#' # Custom output and meta directories, with TOC ---------------------------
#' tfl_set_options(
#'   output_directory = "output",
#'   insertTOC = TRUE,
#'   tocTitle  = "List of Tables"
#' )
#'
#' rpt2 <- create_report(tbl)
#' write_doc(
#'   report   = rpt2,
#'   name     = "mtcars_with_toc",
#'   outDir   = "output",
#'   metaPath = file.path(tempdir(), "ksTFL_meta"),
#'   prettify = TRUE,
#'   toc      = TRUE
#' )
#' }
write_doc <- function(report,
                      name,
                      outDir = tfl_get_option("output_directory"),
                      metaPath = tfl_get_option("meta_directory"),
                      prettify = FALSE,
                      toc = tfl_get_option("insertTOC"),
                      tocTitle = tfl_get_option("tocTitle"),
                      overrideTemplate = NULL,
                      font_dirs = NULL,
                      fallback_font = NULL,
                      verbose = FALSE) {
  # ---- Validation ----
  if (!inherits(report, "TFL_report")) {
    cli::cli_abort("Input {.arg report} must be of class TFL_report")
  }

  checkmate::assert_string(name, null.ok = FALSE, .var.name = "name")
  checkmate::assert_string(outDir, null.ok = FALSE, .var.name = "outDir")
  checkmate::assert_string(metaPath, null.ok = FALSE, .var.name = "metaPath")
  checkmate::assert_flag(prettify, .var.name = "prettify")
  checkmate::assert_flag(toc, .var.name = "toc")
  checkmate::assert_string(tocTitle, null.ok = FALSE, .var.name = "tocTitle")
  checkmate::assert_flag(verbose, .var.name = "verbose")

  if (!is.null(overrideTemplate)) {
    checkmate::assert_string(overrideTemplate, null.ok = FALSE, .var.name = "overrideTemplate")
  }
  if (!is.null(font_dirs)) {
    checkmate::assert_character(font_dirs, min.len = 1L, .var.name = "font_dirs")
  }
  if (!is.null(fallback_font)) {
    checkmate::assert_string(fallback_font, null.ok = FALSE, .var.name = "fallback_font")
  }

  # Normalize output directory (to match save_report behaviour)
  outDir <- normalizePath(outDir, winslash = "/", mustWork = FALSE)

  # Ensure metaPath exists
  if (!dir.exists(metaPath)) {
    dir.create(metaPath, recursive = TRUE, showWarnings = FALSE)
  }

  # ---- Save report specification and data/files ----
  docx_name <- paste0(name, ".docx")

  save_result <- save_report(
    report     = report,
    docFileName = docx_name,
    outDir     = outDir,
    metaPath   = metaPath,
    prettify   = prettify,
    insertTOC  = toc,
    tocTitle   = tocTitle
  )

  spec_path   <- file.path(save_result$metaPath, save_result$spec_file)
  output_path <- file.path(outDir, docx_name)

  # Keep overrideTemplate semantics consistent with docTemplate: bundled name or path.
  if (!is.null(overrideTemplate)) {
    overrideTemplate <- .resolve_template_value(overrideTemplate, spec_key = "write_doc")
  }

  # ---- Render DOCX from saved spec ----
  render_docx(
    spec_json     = spec_path,
    template_json = overrideTemplate,
    output_path   = output_path,
    font_dirs     = font_dirs,
    fallback_font = fallback_font,
    verbose       = verbose
  )

  cat(sprintf("  [OK] %s -> %s\n", name, output_path))
  invisible(output_path)
}

