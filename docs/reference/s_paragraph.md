# Define paragraph properties for a style

This function can only be used inside
[`add_style`](https://example.com/reference/add_style.md).

## Usage

``` r
s_paragraph(
  alignment = NULL,
  spacing = NULL,
  indents = NULL,
  word_style = NULL
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

## Value

A paragraph specification object

## See also

[`add_style()`](https://example.com/reference/add_style.md) for applying
styles, [`s_spacing()`](https://example.com/reference/s_spacing.md),
[`s_indents()`](https://example.com/reference/s_indents.md) for nested
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
} # }
```
