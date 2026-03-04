# List available bundled templates

Returns the names of all template JSON files bundled with the package in
`inst/templates/`. These names can be passed directly to
`set_page_style(docTemplate = ...)` or
`tfl_set_options(docTemplate = ...)`.

## Usage

``` r
tfl_list_templates()
```

## Value

A character vector of template names (without the `.json` extension),
sorted alphabetically.

## Examples

``` r
if (FALSE) { # \dontrun{
tfl_list_templates()
} # }
```
