#' ksTFL Package
#' 
#' @description
#' Generate metadata for clinical Tables, Figures, and Listings (TFLs).
#' 
#' @details
#' To get started, see the vignettes:
#' - `vignette("Getting Started with ksTFL")` - Quick start guide
#' - `vignette("Comprehensive Styling Guide")` - Styling reference
#' - `vignette("Advanced Examples & Complex Workflows")` - Real-world examples
#' - `vignette("ksTFL Documentation Index")` - Complete documentation index
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
.onUnload <- function(libpath) {
  # Cleanup when package is unloaded
  invisible(NULL)
}
