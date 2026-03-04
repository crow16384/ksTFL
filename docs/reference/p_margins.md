# Define page margins

This function can only be used inside
[`p_page`](https://example.com/reference/p_page.md).

## Usage

``` r
p_margins(
  top = NULL,
  bottom = NULL,
  left = NULL,
  right = NULL,
  header = NULL,
  footer = NULL
)
```

## Arguments

- top:

  Top margin, e.g. "25mm"

- bottom:

  Bottom margin, e.g. "25mm"

- left:

  Left margin, e.g. "20mm"

- right:

  Right margin, e.g. "20mm"

- header:

  Header margin, e.g. "12mm"

- footer:

  Footer margin, e.g. "12mm"

## Value

A margins specification object

## Examples

``` r
if (FALSE) { # \dontrun{
spec <- create_text() |>
  set_page_style(
    page = p_page(
      size = "A4",
      orientation = "landscape",
      margins = p_margins(
        top = "25mm", bottom = "25mm",
        left = "20mm", right = "20mm",
        header = "12mm", footer = "12mm"
      )
    )
  )
} # }
```
