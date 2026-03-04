# Add a footnote

Add a footnote to the specification. Multiple calls add multiple
footnote groups. Calling with the same ID merges with last-win strategy.

## Usage

``` r
add_footnote(spec, text, id = NULL, styleRef = NULL, order = NULL)
```

## Arguments

- spec:

  TFL spec object

- text:

  Character vector of footnote text lines

- id:

  Footnote identifier (auto-generated if NULL)

- styleRef:

  Character vector of style names or result of
  [`f_combine()`](https://example.com/reference/f_combine.md). Merged
  with last-win strategy.

- order:

  Order of footnote group (auto-assigned if NULL)

## Value

Updated spec object

## Examples

``` r
if (FALSE) { # \dontrun{
spec <- create_text() |>
  add_footnote("Data source: Clinical database lock 2025-12-01") |>
  add_footnote("Missing values displayed as 'N/A'", styleRef = c("footnote_style", "emphasis"))
} # }
```
