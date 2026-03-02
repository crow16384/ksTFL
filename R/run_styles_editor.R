#' Launch the styles template editor Shiny app
#'
#' Opens an interactive Shiny application for creating and editing ksTFL
#' styles templates that conform to `styles_schema_v1.json`. Templates can be
#' loaded from the bundled `inst/templates/` directory or uploaded from disk,
#' then edited and downloaded as JSON for use with `set_page_style()` /
#' `render_docx()`.
#'
#' This function requires the `shiny` package to be installed.
#'
#' @param ... Additional arguments passed to [shiny::runApp()], such as
#'   `launch.browser = TRUE`.
#'
#' @return Invisibly returns the result of [shiny::runApp()].
#'
#' @examples
#' \dontrun{
#' run_styles_editor()
#' }
#'
#' @export
run_styles_editor <- function(...) {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("The 'shiny' package is required to run the styles editor. Please install it.",
         call. = FALSE)
  }

  app_dir <- system.file("shiny", "styles_editor", package = "ksTFL")
  if (!nzchar(app_dir)) {
    stop("Cannot find the styles editor app directory inside the ksTFL package.",
         call. = FALSE)
  }

  shiny::runApp(app_dir, ...)
}

