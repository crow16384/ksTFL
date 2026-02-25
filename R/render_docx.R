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
#'   If \code{NULL}, uses the default KeyStat template bundled with the package.
#' @param output_path Character string. Path for the output .docx file. If the
#'   directory does not exist, it will be created.
#' @param font_dirs Character vector (optional). Additional directories to search
#'   for fonts. System font directories are included automatically.
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
#' \strong{Font handling}: The renderer searches system font directories plus any
#' additional directories specified in \code{font_dirs}. If a requested font is
#' not found, a fallback chain is used: Arial -> Liberation Sans -> DejaVu Sans
#' -> Noto Sans -> FreeSans.
#'
#' \strong{Template}: The template controls default styles (fonts, spacing, borders),
#' page layout, and table formatting. Use the bundled template or provide a custom
#' one conforming to \code{styles_schema_v1.json}.
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
    # Use bundled default template
    template_json <- system.file(
      "templates", "KeyStat_default.json",
      package = "ksTFL", mustWork = TRUE
    )
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

  # ---- Call C++ renderer ----
  render_docx_impl(
    spec_json_path = spec_json,
    template_json_path = template_json,
    output_path = output_path,
    font_dirs = font_dirs,
    fallback_font = fallback_font,
    verbose = verbose
  )

  cli::cli_alert_success("DOCX rendered: {.path {output_path}}")
  invisible(output_path)
}
