#' Resolve a single template value to an absolute JSON path
#' @keywords internal
#' @noRd
.resolve_template_value <- function(doc_template, spec_key = NULL) {
  key_hint <- if (!is.null(spec_key)) paste0("[", spec_key, "] ") else ""

  if (!is.null(doc_template) && nzchar(doc_template)) {
    is_file_path <- grepl("[/\\\\]", doc_template) ||
      grepl("\\.json$", doc_template, ignore.case = TRUE)

    if (is_file_path) {
      if (file.exists(doc_template)) {
        return(normalizePath(doc_template))
      }
      cli::cli_warn(c(
        paste0(key_hint, "External template file {.path ", doc_template, "} not found."),
        i = "Falling back to {.val CRO Example_default}."
      ))
    } else {
      resolved <- system.file(
        "templates", paste0(doc_template, ".json"),
        package = "ksTFL"
      )
      if (!nzchar(resolved)) {
        # Keep backward compatibility with template names containing spaces
        sanitized <- gsub(" ", "_", doc_template, fixed = TRUE)
        if (!identical(sanitized, doc_template)) {
          resolved <- system.file(
            "templates", paste0(sanitized, ".json"),
            package = "ksTFL"
          )
        }
      }
      if (nzchar(resolved)) {
        return(resolved)
      }
      available_templates <- .list_bundled_templates()
      cli::cli_warn(c(
        paste0(key_hint, "Template {.val ", doc_template, "} not found in package templates."),
        i = "Falling back to {.val CRO Example_default}.",
        i = "Available templates: {.val {available_templates}}"
      ))
    }
  }

  system.file("templates", "CRO_Example_default.json",
              package = "ksTFL", mustWork = TRUE)
}

#' Resolve templates for all specs from a spec JSON file
#' @keywords internal
#' @noRd
.resolve_template_paths_by_spec <- function(spec_json_path) {
  spec_data <- jsonlite::fromJSON(spec_json_path, simplifyVector = FALSE)
  spec_keys <- setdiff(names(spec_data), "_metadata")

  out <- list()
  for (k in spec_keys) {
    doc_template <- spec_data[[k]][["attribs"]][["documentStyle"]][["docTemplate"]]
    out[[k]] <- .resolve_template_value(doc_template, spec_key = k)
  }
  out
}

#' Build renderer payload for per-spec templates
#' @keywords internal
#' @noRd
.build_multi_template_payload <- function(paths_by_spec) {
  stopifnot(length(paths_by_spec) > 0L)
  default_path <- unname(paths_by_spec[[1L]])

  payload <- list(
    `_ksTFL_multi_template` = TRUE,
    default = jsonlite::fromJSON(default_path, simplifyVector = FALSE),
    per_spec = lapply(paths_by_spec, function(path) {
      jsonlite::fromJSON(path, simplifyVector = FALSE)
    })
  )

  jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null")
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
#'   If provided, this template is used for all specs (global override).
#'   If \code{NULL} (default), each spec resolves its own template from
#'   \code{docTemplate} (set via
#'   \code{\link{set_page_style}(docTemplate = "Navy_Pro")}). For multi-spec
#'   reports, different specs may therefore use different templates. Template
#'   names are looked up in the package's bundled \code{inst/templates/}
#'   directory. Missing values or unknown names fall back to
#'   \code{CRO Example_default} with a warning.
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
#' page layout, and table formatting. By default (\code{template_json = NULL}),
#' template selection is per-spec using each spec's \code{docTemplate}. Set
#' \code{template_json} to force one template for the full document. Custom
#' templates must conform to \code{styles_schema_v2.json}.
#'
#' @keywords internal
#' @noRd
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
  if (!is.null(template_json)) {
    # Backward-compatible global override: one template for all specs.
    n_pages <- render_docx_impl(
      spec_json_path = spec_json,
      template_json_path = template_json,
      output_path = output_path,
      font_dirs = font_dirs,
      fallback_font = fallback_font,
      verbose = verbose
    )
  } else {
    # Per-spec template resolution from each spec's docTemplate.
    paths_by_spec <- .resolve_template_paths_by_spec(spec_json)
    unique_paths <- unique(unname(unlist(paths_by_spec, use.names = FALSE)))

    if (length(unique_paths) == 1L) {
      # Fast path: all specs use same template.
      n_pages <- render_docx_impl(
        spec_json_path = spec_json,
        template_json_path = unique_paths[[1L]],
        output_path = output_path,
        font_dirs = font_dirs,
        fallback_font = fallback_font,
        verbose = verbose
      )
    } else {
      # Multi-template path: embed per-spec templates in payload.
      spec_json_str <- paste(readLines(spec_json, warn = FALSE), collapse = "\n")
      template_payload <- .build_multi_template_payload(paths_by_spec)
      data_dir <- normalizePath(dirname(spec_json), mustWork = TRUE)

      n_pages <- render_docx_from_strings_impl(
        spec_json = spec_json_str,
        template_json = template_payload,
        output_path = output_path,
        data_dir = data_dir,
        font_dirs = font_dirs,
        fallback_font = fallback_font,
        verbose = verbose
      )
    }
  }

  page_label <- if (!is.null(n_pages) && length(n_pages) == 1L && n_pages != 1L) "pages" else "page"
  cli::cli_alert_success("DOCX rendered: {.path {output_path}} ({n_pages} {page_label})")
  invisible(output_path)
}
