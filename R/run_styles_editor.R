#' Launch the styles template editor Shiny app
#'
#' Opens an interactive Shiny application for creating and editing ksTFL
#' styles templates that conform to `styles_schema_v2.json`. Templates can be
#' loaded from the bundled `inst/templates/` directory or uploaded from disk,
#' then edited and downloaded as JSON for use with [set_page_style()] /
#' [write_doc()].
#'
#' This function requires the \pkg{shiny} package to be installed.
#'
#' @param ... Additional arguments passed to [shiny::runApp()], such as
#'   `launch.browser = TRUE` or `port = 4321`.
#'
#' @return Invisibly returns the result of [shiny::runApp()].
#'
#' @seealso [tfl_list_templates()], [set_page_style()]
#'
#' @examples
#' \dontrun{
#' run_styles_editor()
#' run_styles_editor(launch.browser = TRUE)
#' }
#'
#' @export
run_styles_editor <- function(...) {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    cli_abort("The {.pkg shiny} package is required to run the styles editor. Please install it.")
  }

  app_dir <- system.file("shiny", "styles_editor", package = "ksTFL")
  if (!nzchar(app_dir)) {
    cli_abort("Cannot find the styles editor app directory inside the ksTFL package.")
  }

  shiny::runApp(app_dir, ...)
}

