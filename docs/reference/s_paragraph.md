# Define paragraph properties for a style

This function can only be used inside
[`add_style`](https://example.com/reference/add_style.md).

## Usage

``` r
s_paragraph(
  alignment = NULL,
  spacing = NULL,
  indents = NULL,
  word_style = NULL,
  borders = NULL
)
```

## Arguments

- alignment:

  Text alignment: "left", "right", "center", "justify", "distributed"

- spacing:

  Spacing object created with
  [`s_spacing`](https://example.com/reference/s_spacing.md) or a list
  with keys: before, after, line_spacing

- indents:

  Indents object created with
  [`s_indents`](https://example.com/reference/s_indents.md) or a list
  with keys: left, right, first_line

- word_style:

  Base Word style to inherit from

- borders:

  Borders object created with
  [`s_borders`](https://example.com/reference/s_borders.md). Applied as
  paragraph-level borders (`<w:pBdr>` in OOXML), distinct from
  cell-level borders set via
  [`s_table_style`](https://example.com/reference/s_table_style.md).

## Value

A paragraph specification object

## See also

[`add_style()`](https://example.com/reference/add_style.md) for applying
styles, [`s_spacing()`](https://example.com/reference/s_spacing.md),
[`s_indents()`](https://example.com/reference/s_indents.md),
[`s_borders()`](https://example.com/reference/s_borders.md) for nested
components, [`s_font()`](https://example.com/reference/s_font.md),
[`s_table_style()`](https://example.com/reference/s_table_style.md) for
other style components

## Examples

``` r
if (FALSE) { # \dontrun{
spec <- create_text() |>
  add_style("my_style",
    s_paragraph(
      alignment = "center",
      spacing = s_spacing(before = "12pt", after = "6pt"),
      word_style = "Normal"
    )
  )

# Paragraph with a bottom border (applied to the text, not the cell)
spec <- create_table(mtcars) |>
  add_style("para_border",
    s_paragraph(
      alignment = "center",
      borders = s_borders(
        bottom = s_border(color = "#000000", width = "0.5pt", line_style = "single")
      )
    )
  )
} # }
```
