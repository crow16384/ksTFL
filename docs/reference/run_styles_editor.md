# Launch the styles template editor Shiny app

Opens an interactive Shiny application for creating and editing ksTFL
styles templates that conform to `styles_schema_v2.json`. Templates can
be loaded from the bundled `inst/templates/` directory or uploaded from
disk, then edited and downloaded as JSON for use with
[`set_page_style()`](https://example.com/reference/set_page_style.md) /
[`write_doc()`](https://example.com/reference/write_doc.md).

## Usage

``` r
run_styles_editor(...)
```

## Arguments

- ...:

  Additional arguments passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html), such
  as `launch.browser = TRUE` or `port = 4321`.

## Value

Invisibly returns the result of
[`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Details

This function requires the shiny package to be installed.

## See also

[`tfl_list_templates()`](https://example.com/reference/tfl_list_templates.md),
[`set_page_style()`](https://example.com/reference/set_page_style.md)

## Examples

``` r
if (FALSE) { # \dontrun{
run_styles_editor()
run_styles_editor(launch.browser = TRUE)
} # }
```
