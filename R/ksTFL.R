#' ksTFL Package
#'
#' @description
#' Generate metadata for clinical Tables, Figures, and Listings (TFLs). You
#' build specs with \code{create_table()}, \code{create_figure()}, or
#' \code{create_text()}, then add titles, column definitions, styles, and
#' options. Combine specs with \code{create_report()}, and render to DOCX with
#' \code{write_doc()} in one step.
#'
#' @details
#' **Typical workflow:** (1) Create one or more specs with \code{create_table()},
#' \code{create_figure()}, or \code{create_text()}. (2) Add content and styling
#' (e.g. \code{add_title()}, \code{define_cols()}, \code{add_style()},
#' \code{set_document()}). (3) Combine specs with \code{create_report()}. (4)
#' Render to DOCX with \code{write_doc()} (recommended). For JSON inspection,
#' use \code{save_report()} and \code{replay_report()}.
#'
#' To get started, see the vignettes:
#' \itemize{
#'   \item \code{vignette("Getting_Started_with_ksTFL")} — Quick start and full workflow overview
#'   \item \code{vignette("Styling_Guide_with_ksTFL")} — Complete styling reference and built-in atoms
#'   \item \code{vignette("Reporting_Examples_with_ksTFL")} — Progressive real-world examples
#'   \item \code{vignette("Advanced_StyleRows")} — Conditional formatting with \code{compute_cols()}
#'   \item \code{vignette("Column_Width_Management")} — Column width locking and auto-calculation
#'   \item \code{vignette("Font_Management")} — System font discovery, fallbacks, and rescanning
#'   \item \code{vignette("Rendering_Pipeline")} — Full C++ renderer architecture and internals
#' }
#'
#' @keywords internal
"_PACKAGE"

# Internal package environment for storing runtime state (e.g., font report)
.pkg_env <- new.env(parent = emptyenv())

#' Package load/unload hooks
#'
#' Internal package lifecycle hooks called by R when the package is loaded,
#' attached, or unloaded. These functions are used to initialize package
#' state and display a user-facing startup message. They are intentionally
#' minimal and marked internal.
#'
#' @param libname Character. Path to the package library (provided by R).
#' @param pkgname Character. Package name (provided by R).
#' @keywords internal
#' @noRd
.onLoad <- function(libname, pkgname) {
  # Scan system fonts and populate the C++ font registry
  pkg_fonts_dir <- system.file("fonts", package = pkgname)
  extra_dirs <- getOption("ksTFL.font_dirs", default = character(0))
  tryCatch(
    {
      report <- init_font_registry_impl(pkg_fonts_dir, extra_dirs)
      .pkg_env[["font_report"]] <- report
    },
    error = function(e) {
      cli_warn(c(
        "ksTFL: font scanner initialisation failed.",
        "x" = "{conditionMessage(e)}"
      ))
    }
  )
  invisible(NULL)
}

#' Package attach hook
#'
#' Called when the package is attached to the search path. Displays a
#' startup message and may perform lightweight runtime checks.
#'
#' @param libname Character. Path to the package library (provided by R).
#' @param pkgname Character. Package name (provided by R).
#' @keywords internal
#' @noRd
.onAttach <- function(libname, pkgname) {
  pkg_version <- utils::packageVersion(pkgname)
  packageStartupMessage(
    sprintf("ksTFL v%s - Clinical TFL Framework\n", pkg_version),
    "For help, type: ??ksTFL"
  )

  # Print font scan summary (if available)
  report <- .pkg_env[["font_report"]]
  if (!is.null(report)) {
    n_fb <- sum(vapply(report$resolutions, function(r) r$is_fallback, logical(1)))
    if (n_fb > 0) {
      targets <- vapply(report$resolutions[vapply(report$resolutions,
        function(r) r$is_fallback, logical(1))],
        function(r) r$target, character(1))
      packageStartupMessage(
        sprintf("Note: %d font(s) using fallback: %s", n_fb, paste(targets, collapse = ", ")),
        "\nRun tfl_font_status() for details."
      )
    }
  }

  invisible(NULL)
}

#' Package unload hook
#'
#' Called when the package is unloaded. This hook can be used to clean up
#' resources allocated at load/attach time.
#'
#' @param libpath Character. Path to the installed package (provided by R).
#' @keywords internal
#' @noRd
.onUnload <- function(libpath) {
  # Cleanup when package is unloaded
  invisible(NULL)
}
