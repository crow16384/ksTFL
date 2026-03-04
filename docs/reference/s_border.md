# Define border properties

This function can only be used inside
[`s_borders`](https://example.com/reference/s_borders.md).

## Usage

``` r
s_border(color = NULL, width = NULL, line_style = NULL)
```

## Arguments

- color:

  Border color as hex (e.g., "#000000") or color name (e.g., "black",
  "red")

- width:

  Border width, e.g. "1pt"

- line_style:

  Line style: "single", "double", "dashed", "dotted", "thick", "none"

## Value

A border specification object

## Examples

``` r
if (FALSE) { # \dontrun{
spec <- create_text() |>
  add_style("my_style",
    s_table_style(
      borders = s_borders(
        bottom = s_border(color = "#000000", width = "2pt", line_style = "single")
      )
    )
  )
} # }
```
