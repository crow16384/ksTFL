# Launch the styles template editor Shiny app

Opens an interactive Shiny application for creating and editing ksTFL
styles templates that conform to `styles_schema_v1.json`. Templates can
be loaded from the bundled `inst/templates/` directory or uploaded from
disk, then edited and downloaded as JSON for use with
[`set_page_style()`](https://example.com/reference/set_page_style.md) /
[`render_docx()`](https://example.com/reference/render_docx.md).

## Usage

``` r
run_styles_editor(...)
```

## Arguments

- ...:

  Additional arguments passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html), such
  as `launch.browser = TRUE`.

## Value

Invisibly returns the result of
[`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Details

This function requires the `shiny` package to be installed.

## Examples

``` r
if (FALSE) { # \dontrun{
run_styles_editor()
} # }
```
