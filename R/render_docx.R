#' Resolve a template path from the docTemplate value stored in a spec JSON
#'
#' Reads the first spec entry's `attribs$documentStyle$docTemplate` field and
#' resolves it to an absolute JSON file path. The value may be:
#' \itemize{
#'   \item A predefined bundled template name (e.g. `"Navy_Pro"`) — looked up in
#'     `inst/templates/<name>.json`.
#'   \item A file path to an external template JSON file (absolute or relative).
#' }
#' Falls back to `KeyStat_default.json` with a warning when the value is absent
#' or cannot be resolved.
#'
#' @param spec_json_path Path to the spec JSON file.
#' @return Absolute path to the resolved template JSON file.
#' @keywords internal
#' @noRd
.resolve_template_path <- function(spec_json_path) {
  doc_template <- tryCatch({
    spec_data  <- jsonlite::fromJSON(spec_json_path, simplifyVector = FALSE)
    spec_keys  <- setdiff(names(spec_data), "_metadata")
    if (length(spec_keys) > 0L) {
      spec_data[[spec_keys[[1L]]]][["attribs"]][["documentStyle"]][["docTemplate"]]
    } else {
      NULL
    }
  }, error = function(e) NULL)

  if (!is.null(doc_template) && nzchar(doc_template)) {
    # If the value looks like a file path (contains a path separator or ends
    # with .json), treat it as an external file path.
    is_file_path <- grepl("[/\\\\]", doc_template) || grepl("\\.json$", doc_template, ignore.case = TRUE)

    if (is_file_path) {
      if (file.exists(doc_template)) {
        return(normalizePath(doc_template))
      }
      cli::cli_warn(c(
        "External template file {.path {doc_template}} not found.",
        i = "Falling back to {.val KeyStat_default}."
      ))
    } else {
      resolved <- system.file(
        "templates", paste0(doc_template, ".json"),
        package = "ksTFL"
      )
      if (nzchar(resolved)) {
        return(resolved)
      }
      cli::cli_warn(c(
        "Template {.val {doc_template}} not found in package templates.",
        i = "Falling back to {.val KeyStat_default}.",
        i = "Available templates: {.val {.list_bundled_templates()}}"
      ))
    }
  }

  system.file("templates", "KeyStat_default.json",
              package = "ksTFL", mustWork = TRUE)
}

#' List all bundled template names (without .json extension)
#' @keywords internal
#' @noRd
.list_bundled_templates <- function() {
  tmpl_dir <- system.file("templates", package = "ksTFL")
  if (!nzchar(tmpl_dir)) return(character(0L))
  files <- list.files(tmpl_dir, pattern = "\\.json$", full.names = FALSE)
  tools::file_path_sans_ext(files)
}


#' Render a DOCX Document from TFL Report
#'
#' Renders a TFL report (previously saved via \code{\link{save_report}}) into
#' a styled DOCX document using the C++ rendering engine. The renderer
#' performs deterministic pagination with HarfBuzz-based text measurement,
#' producing submission-quality clinical tables, figures, and listings.
#'
#' @param spec_json Character string. Path to the spec JSON file produced by
#'   \code{\link{save_report}}.
#' @param template_json Character string. Path to the styles template JSON file.
#'   If \code{NULL} (default), the template is resolved automatically from the
#'   \code{docTemplate} name stored in the spec (set via
#'   \code{\link{set_page_style}(docTemplate = "Navy_Pro")}). The name is looked
#'   up in the package's bundled \code{inst/templates/} directory. If not found,
#'   the default \code{KeyStat_default} template is used and a warning is issued.
#' @param output_path Character string. Path for the output .docx file. If the
#'   directory does not exist, it will be created.
#' @param font_dirs Character vector (optional). Additional directories to search
#'   for fonts. The package's bundled fonts (inst/fonts/) are always included
#'   automatically. Only fonts from these directories are used — no system
#'   fonts are searched.
#' @param fallback_font Character string (optional). Path to a fallback font file
#'   (e.g., Liberation Sans). If not specified, the embedded fallback font is used.
#' @param verbose Logical. If \code{TRUE}, print progress messages to stderr.
#'   Default: \code{FALSE}.
#'
#' @return Invisibly returns the \code{output_path} (the path to the generated
#'   .docx file).
#'
#' @details
#' The rendering pipeline operates in the following phases:
#' \enumerate{
#'   \item \strong{Parse}: Read spec JSON, template JSON, and data JSON files
#'   \item \strong{Resolve}: Merge template and spec styles; compute page geometry
#'   \item \strong{Model}: Build logical table (header grid, row stream, styleRows expansion)
#'   \item \strong{Measure}: HarfBuzz-based text shaping and cell height measurement
#'   \item \strong{Paginate}: Deterministic vertical and horizontal pagination
#'   \item \strong{Emit}: Stream OOXML into a valid .docx (ZIP) package
#' }
#'
#' \strong{Font handling}: The renderer uses only fonts bundled in the package's
#' \code{inst/fonts/} directory, plus any additional directories specified in
#' \code{font_dirs}. No system fonts are searched. If a requested font is not
#' found, LiberationSans (bundled) is used as fallback. Font metrics are
#' computed from the OS/2 table (usWinAscent/usWinDescent) to match
#' Microsoft Word's line height calculation.
#'
#' \strong{Template}: The template controls default styles (fonts, spacing, borders),
#' page layout, and table formatting. Use the bundled template or provide a custom
#' one conforming to \code{styles_schema_v2.json}.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Create and save a report
#' spec <- create_table(mtcars)
#' spec <- add_title(spec, "Motor Trend Car Road Tests")
#' report <- create_report(spec)
#' saved <- save_report(report, docFileName = "demo.docx")
#'
#' # Render to DOCX
#' render_docx(
#'   spec_json = file.path(saved$metaPath, saved$spec_file),
#'   output_path = "output/demo.docx"
#' )
#'
#' # With custom template and fonts
#' render_docx(
#'   spec_json = file.path(saved$metaPath, saved$spec_file),
#'   template_json = "my_template.json",
#'   output_path = "output/demo.docx",
#'   font_dirs = c("/usr/local/share/fonts/custom"),
#'   verbose = TRUE
#' )
#' }
render_docx <- function(spec_json,
                         template_json = NULL,
                         output_path,
                         font_dirs = NULL,
                         fallback_font = NULL,
                         verbose = FALSE) {
  # ---- Input validation ----
  checkmate::assert_string(spec_json)
  checkmate::assert_file_exists(spec_json, access = "r")
  checkmate::assert_string(output_path)
  checkmate::assert_flag(verbose)

  if (!is.null(template_json)) {
    checkmate::assert_string(template_json)
    checkmate::assert_file_exists(template_json, access = "r")
  } else {
    # Resolve template from docTemplate name stored in the spec JSON, then
    # fall back to the bundled default if the name is absent or unresolvable.
    template_json <- .resolve_template_path(spec_json)
  }

  if (!is.null(font_dirs)) {
    checkmate::assert_character(font_dirs, min.len = 1L)
    for (fd in font_dirs) {
      if (!dir.exists(fd)) {
        cli::cli_warn(c(
          "Font directory does not exist:",
          x = "{.path {fd}}"
        ))
      }
    }
  }

  if (!is.null(fallback_font)) {
    checkmate::assert_string(fallback_font)
    checkmate::assert_file_exists(fallback_font, access = "r")
  } else {
    # Use bundled fallback font if available
    fb_path <- system.file("fonts", "LiberationSans-Regular.ttf",
                           package = "ksTFL")
    if (nzchar(fb_path)) {
      fallback_font <- fb_path
    } else {
      fallback_font <- ""
    }
  }

  # ---- Ensure output directory exists ----
  out_dir <- dirname(output_path)
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = TRUE)
  }

  # ---- Always include bundled package fonts (inst/fonts/) ----
  pkg_fonts_dir <- system.file("fonts", package = "ksTFL")
  if (nzchar(pkg_fonts_dir)) {
    font_dirs <- c(pkg_fonts_dir, font_dirs)
  }

  # ---- Call C++ renderer ----
  n_pages <- render_docx_impl(
    spec_json_path = spec_json,
    template_json_path = template_json,
    output_path = output_path,
    font_dirs = font_dirs,
    fallback_font = fallback_font,
    verbose = verbose
  )

  page_label <- if (!is.null(n_pages) && length(n_pages) == 1L && n_pages != 1L) "pages" else "page"
  cli::cli_alert_success("DOCX rendered: {.path {output_path}} ({n_pages} {page_label})")
  invisible(output_path)
}
