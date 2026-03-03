#' ksTFL Package
#'
#' @description
#' Generate metadata for clinical Tables, Figures, and Listings (TFLs). You
#' build specs with \code{create_table()}, \code{create_figure()}, or
#' \code{create_text()}, then add titles, column definitions, styles, and
#' options. Combine specs with \code{create_report()}, save to JSON (and data
#' files) with \code{save_report()}, and render to DOCX with \code{render_docx()}
#' or in one step with \code{write_doc()}.
#'
#' @details
#' **Typical workflow:** (1) Create one or more specs with \code{create_table()},
#' \code{create_figure()}, or \code{create_text()}. (2) Add content and styling
#' (e.g. \code{add_title()}, \code{define_cols()}, \code{add_style()},
#' \code{set_document()}). (3) Combine specs with \code{create_report()}. (4)
#' Save and render: \code{save_report()} writes the spec JSON and data files;
#' \code{render_docx()} produces the DOCX; or use \code{write_doc()} to do both
#' in one call.
#'
#' To get started, see the vignettes:
#' \itemize{
#'   \item \code{vignette("Getting Started with ksTFL")} — Quick start guide
#'   \item \code{vignette("Comprehensive Styling Guide")} — Styling reference
#'   \item \code{vignette("Advanced Examples & Complex Workflows")} — Real-world examples
#'   \item \code{vignette("ksTFL Documentation Index")} — Complete documentation index
#' }
#'
#' @keywords internal
"_PACKAGE"

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
 
  
  # Initialize package environment if needed
  # (settings are already initialized in pkg_settings.R)
  
  # Register S3 methods (if you have any custom printing/methods)
  # e.g., registerS3method("print", "TFL_spec", print.TFL_spec)
  
  # Set package-specific options for users
  # These can be overridden by users with options()
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
  # Called after package is attached
  # Useful for checking dependencies or system requirements
   # Get package version
  pkg_version <- utils::packageVersion(pkgname)
  
  # Display welcome message
  packageStartupMessage(
    sprintf(
      "ksTFL v%s - Clinical TFL Framework\n",
      pkg_version
    ),
      "For help, type: ??ksTFL"
  )

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
