# Define page settings

This function can only be used inside
[`set_page_style`](https://example.com/reference/set_page_style.md).

## Usage

``` r
p_page(
  size = .const_default_page_size,
  orientation = .const_default_page_orientation,
  margins = NULL
)
```

## Arguments

- size:

  Page size: "A4", "A3", "Letter", "Legal", "Executive"

- orientation:

  Page orientation: "portrait" or "landscape"

- margins:

  Margins object created with
  [`p_margins`](https://example.com/reference/p_margins.md) or a list
  with keys: top, bottom, left, right, header, footer

## Value

A page specification object

## Examples

``` r
if (FALSE) { # \dontrun{
spec <- create_text() |>
  set_page_style(
    docTemplate = "CRO Example_default",
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
