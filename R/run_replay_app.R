#' Launch the Combined Replay Shiny App
#'
#' Opens an interactive Shiny application for selecting, reordering, and
#' replaying multiple saved reports into a single combined DOCX document.
#' Reports can be loaded from one or more meta folders, reordered via
#' drag-and-drop, and rendered with optional TOC settings.
#'
#' This function requires the \code{shiny}, \code{sortable}, and
#' \code{shinyFiles} packages.
#'
#' @param meta_dir Character string (optional). Default meta folder path
#'   to pre-populate in the app.  If \code{NULL}, the user must enter a
#'   path manually.
#' @param ... Additional arguments passed to [shiny::runApp()], such as
#'   \code{launch.browser = TRUE}.
#'
#' @return Invisibly returns the result of [shiny::runApp()].
#'
#' @seealso [list_reports()], [replay_report()], [clean_reports()]
#'
#' @examples
#' \dontrun{
#' run_replay_app()
#' run_replay_app(meta_dir = "path/to/meta")
#' }
#'
#' @export
run_replay_app <- function(meta_dir = NULL, ...) {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    cli_abort("The {.pkg shiny} package is required. Please install it.")
  }
  if (!requireNamespace("sortable", quietly = TRUE)) {
    cli_abort("The {.pkg sortable} package is required for drag-and-drop reordering. Please install it.")
  }
  if (!requireNamespace("shinyFiles", quietly = TRUE)) {
    cli_abort("The {.pkg shinyFiles} package is required for directory choosers. Please install it.")
  }

  app_dir <- system.file("shiny", "replay_app", package = "ksTFL")
  if (!nzchar(app_dir)) {
    cli_abort("Cannot find the replay app directory inside the ksTFL package.")
  }

  old_opt <- getOption("ksTFL.replay_app.meta_dir")
  options(ksTFL.replay_app.meta_dir = meta_dir)
  on.exit(options(ksTFL.replay_app.meta_dir = old_opt), add = TRUE)

  shiny::runApp(app_dir, ...)
}
