# ============================================================
# ksTFL Package Loader
# ============================================================
# This file is loaded first (alphabetically) to set up
# package initialization and load-time behaviors

#' @keywords internal
.onLoad <- function(libname, pkgname) {
  # Get package version
  pkg_version <- utils::packageVersion(pkgname)
  
  # Display welcome message
  packageStartupMessage(
    sprintf(
      "ksTFL v%s - Clinical TFL Framework\n",
      pkg_version
    ),
    "For help, type: ?tfl_init"
  )
  
  # Initialize package environment if needed
  # (settings are already initialized in pkg_settings.R)
  
  # Register S3 methods (if you have any custom printing/methods)
  # e.g., registerS3method("print", "TFL_spec", print.TFL_spec)
  
  # Set package-specific options for users
  # These can be overridden by users with options()
  invisible(NULL)
}

#' @keywords internal
.onAttach <- function(libname, pkgname) {
  # Called after package is attached
  # Useful for checking dependencies or system requirements
  invisible(NULL)
}

#' @keywords internal
.onUnload <- function(libpath) {
  # Cleanup when package is unloaded
  invisible(NULL)
}
