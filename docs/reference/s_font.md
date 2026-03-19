# Define font properties for a style

This function can only be used inside
[`add_style`](https://example.com/reference/add_style.md).

## Usage

``` r
s_font(
  font_name = NULL,
  font_size = NULL,
  bold = NULL,
  italic = NULL,
  underline = NULL,
  strikethrough = NULL,
  color = NULL,
  highlight = NULL
)
```

## Arguments

- font_name:

  Font family name. One of: "Arial", "Courier New", "Times New Roman",
  "Georgia", "Verdana", "Trebuchet MS", "Liberation Sans"

- font_size:

  Font size with units, e.g. "12pt"

- bold:

  Logical, whether text is bold

- italic:

  Logical, whether text is italic

- underline:

  Logical, whether text is underlined

- strikethrough:

  Logical, whether text has strikethrough

- color:

  Text color as hex (e.g., "#000000") or color name (e.g., "red",
  "blue")

- highlight:

  Background highlight color as hex (e.g., "#FFFF00") or color name
  (e.g., "yellow")

## Value

A font specification object (for internal use)

## See also

[`add_style()`](https://example.com/reference/add_style.md) for applying
styles, [`s_paragraph()`](https://example.com/reference/s_paragraph.md),
[`s_table_style()`](https://example.com/reference/s_table_style.md) for
other style components

## Examples

``` r
if (FALSE) { # \dontrun{
spec <- create_text() |>
  add_style("my_style",
    s_font(font_name = "Arial", font_size = "12pt", bold = TRUE)
  )
} # }
```
