# Create a Text Document Specification

Create and initialize a TFL specification for narrative (text)
documents. This is a user-facing wrapper around the internal
`.tfl_init()` initializer and provides a clear, intention-revealing name
for creating text-only specifications. Text documents do not accept
`data` and will have `docType = "Text"` set on the resulting spec.

## Usage

``` r
create_text()
```

## Value

A `TFL_spec` object with `docType = "Text"`.

## See also

[`create_table()`](https://example.com/reference/create_table.md),
[`create_figure()`](https://example.com/reference/create_figure.md),
[`add_body_text()`](https://example.com/reference/add_body_text.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Create a text-only spec and add narrative content
spec <- create_text() |>
  add_title("Listing of Adverse Events") |>
  set_document(hasData = FALSE) |>
  add_body_text("No adverse events were reported during the study.")
} # }
```
