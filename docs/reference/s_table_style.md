# Define table-specific styling

This function can only be used inside
[`add_style`](https://example.com/reference/add_style.md).

## Usage

``` r
s_table_style(
  background_color = NULL,
  row_height = NULL,
  vertical_alignment = NULL,
  text_orientation = NULL,
  borders = NULL
)
```

## Arguments

- background_color:

  Cell background color as hex code or color name

- row_height:

  Row height, e.g. "15mm" or "auto"

- vertical_alignment:

  Vertical alignment: "top", "center", "bottom"

- text_orientation:

  Text orientation: "horizontal", "vertical_90", "vertical_270"

- borders:

  Borders object created with
  [`s_borders`](https://example.com/reference/s_borders.md)

## Value

A table style specification object

## See also

[`add_style()`](https://example.com/reference/add_style.md) for applying
styles, [`s_borders()`](https://example.com/reference/s_borders.md),
[`s_border()`](https://example.com/reference/s_border.md) for border
components, [`s_font()`](https://example.com/reference/s_font.md),
[`s_paragraph()`](https://example.com/reference/s_paragraph.md) for
other style components

## Examples

``` r
if (FALSE) { # \dontrun{
spec <- create_text() |>
  add_style("header_style",
    s_table_style(
      background_color = "#D9D9D9",
      vertical_alignment = "center",
      borders = s_borders(
        bottom = s_border(color = "#000000", width = "2pt")
      )
    )
  )
} # }
```
