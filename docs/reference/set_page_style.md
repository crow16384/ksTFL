# Set document style properties

Set document-level style configuration. Multiple calls merge with
last-win strategy.

## Usage

``` r
set_page_style(spec, docTemplate = NULL, page = NULL)

# S3 method for class 'TFL_spec'
set_page_style(spec, docTemplate = NULL, page = NULL)

# S3 method for class 'TFL_options'
set_page_style(spec, docTemplate = NULL, page = NULL)
```

## Arguments

- spec:

  TFL spec object

- docTemplate:

  Character. Template to use for rendering. Accepts either:

  - A predefined bundled template name (e.g. `"CRO Example_default"`,
    `"Navy_Pro"`). Use
    [`tfl_list_templates()`](https://example.com/reference/tfl_list_templates.md)
    to see all available names.

  - A file path (absolute or relative) to an external template JSON
    file. The path must point to an existing file conforming to
    `styles_schema_v2.json`.

  When `NULL` (default) the current session template is used.

- page:

  Page settings object created with
  [`p_page`](https://example.com/reference/p_page.md) or a list with
  keys: size, orientation, margins

## Value

Updated spec object

## Examples

``` r
if (FALSE) { # \dontrun{
# Use a predefined bundled template
spec <- create_text() |>
  set_page_style(
    docTemplate = "Navy_Pro",
    page = p_page(size = "A4", orientation = "landscape")
  )

# Use an external template file
spec <- create_text() |>
  set_page_style(docTemplate = "/path/to/my_template.json")
} # }
```
