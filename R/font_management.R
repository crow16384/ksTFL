#' Rescan system fonts
#'
#' Re-runs the font discovery process using the current value of
#' \code{getOption("ksTFL.font_dirs")}. This is useful after installing
#' new fonts or after changing the \code{ksTFL.font_dirs} option.
#'
#' @return Invisibly returns the font scan report (a list with
#'   \code{resolutions} and \code{dirs_scanned}).
#' @export
tfl_rescan_fonts <- function() {
  pkg_fonts_dir <- system.file("fonts", package = "ksTFL")
  extra_dirs <- getOption("ksTFL.font_dirs", default = character(0))
  report <- init_font_registry_impl(pkg_fonts_dir, extra_dirs)
  .pkg_env[["font_report"]] <- report
  .print_font_report(report)
  invisible(report)
}

#' Show current font status
#'
#' Prints the font resolution report from the most recent scan without
#' re-scanning. Use \code{\link{tfl_rescan_fonts}} to perform a fresh scan.
#'
#' @return Invisibly returns the cached font scan report.
#' @export
tfl_font_status <- function() {
  report <- .pkg_env[["font_report"]]
  if (is.null(report)) {
    message("No font scan has been performed yet.")
    return(invisible(NULL))
  }
  .print_font_report(report)
  invisible(report)
}

#' Print font scan report
#'
#' @param report A list returned by \code{init_font_registry_impl()}.
#' @keywords internal
#' @noRd
.print_font_report <- function(report) {
  n_fallback <- sum(vapply(report$resolutions, function(r) r$is_fallback, logical(1)))
  n_ok <- length(report$resolutions) - n_fallback

  message(sprintf("ksTFL font scan: %d target(s) resolved, %d using fallback",
                  n_ok, n_fallback))

  for (r in report$resolutions) {
    status <- if (r$is_fallback) "[fallback]" else "[ok]"
    resolved <- if (nzchar(r$resolved_family)) r$resolved_family else "(not found)"
    message(sprintf("  %-10s %-20s -> %s", status, r$target, resolved))
  }

  message(sprintf("  Scanned %d directories", length(report$dirs_scanned)))
}
