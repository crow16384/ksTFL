# Define borders for table cells

This function can only be used inside
[`s_table_style`](https://example.com/reference/s_table_style.md).

## Usage

``` r
s_borders(top = NULL, bottom = NULL, left = NULL, right = NULL)
```

## Arguments

- top:

  Top border created with
  [`s_border`](https://example.com/reference/s_border.md)

- bottom:

  Bottom border created with
  [`s_border`](https://example.com/reference/s_border.md)

- left:

  Left border created with
  [`s_border`](https://example.com/reference/s_border.md)

- right:

  Right border created with
  [`s_border`](https://example.com/reference/s_border.md)

## Value

A borders specification object

## Examples

``` r
if (FALSE) { # \dontrun{
spec <- create_text() |>
  add_style("my_style",
    s_table_style(
      borders = s_borders(
        top = s_border(width = "1pt"),
        bottom = s_border(width = "2pt", line_style = "double")
      )
    )
  )
} # }
```
