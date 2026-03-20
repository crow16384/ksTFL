# Launch the Combined Replay Shiny App

Opens an interactive Shiny application for selecting, reordering, and
replaying multiple saved reports into a single combined DOCX document.
Reports can be loaded from one or more meta folders, reordered via
drag-and-drop, and rendered with optional TOC settings.

## Usage

``` r
run_replay_app(meta_dir = NULL, ...)
```

## Arguments

- meta_dir:

  Character string (optional). Default meta folder path to pre-populate
  in the app. If `NULL`, the user must enter a path manually.

- ...:

  Additional arguments passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html), such
  as `launch.browser = TRUE`.

## Value

Invisibly returns the result of
[`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Details

This function requires the `shiny`, `sortable`, and `shinyFiles`
packages.

## See also

[`list_reports()`](https://example.com/reference/list_reports.md),
[`replay_report()`](https://example.com/reference/replay_report.md),
[`clean_reports()`](https://example.com/reference/clean_reports.md)

## Examples

``` r
if (FALSE) { # \dontrun{
run_replay_app()
run_replay_app(meta_dir = "path/to/meta")
} # }
```
