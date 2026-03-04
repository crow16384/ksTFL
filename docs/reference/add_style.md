# Add or update a style definition

Generic function to add or update style definitions. Dispatches to
class-specific methods, allowing different spec classes to implement
their own style handling.

## Usage

``` r
add_style(spec, id, ...)
```

## Arguments

- spec:

  Spec object (dispatches on class)

- id:

  Style identifier (auto-generated if NULL)

- ...:

  Style modifiers created with s\_\* functions

  - [`s_font`](https://example.com/reference/s_font.md) — font
    properties.

  - [`s_paragraph`](https://example.com/reference/s_paragraph.md) —
    paragraph-level formatting (may include nested
    [`s_spacing`](https://example.com/reference/s_spacing.md) and
    [`s_indents`](https://example.com/reference/s_indents.md)).

  - [`s_table_style`](https://example.com/reference/s_table_style.md) —
    table-cell styling (may include nested
    [`s_borders`](https://example.com/reference/s_borders.md) /
    [`s_border`](https://example.com/reference/s_border.md)).

## Value

Updated spec object

## Details

Define styling for various document elements. Multiple calls to the same
modifier function will merge with last-win strategy.

Available modifiers inside this function:

- [`s_font`](https://example.com/reference/s_font.md) - Font properties

- [`s_paragraph`](https://example.com/reference/s_paragraph.md) -
  Paragraph formatting

- [`s_table_style`](https://example.com/reference/s_table_style.md) -
  Table cell styling

## Examples

``` r
if (FALSE) { # \dontrun{
spec <- create_text() |>
  add_style(id = "header",
    s_font(font_name = "Arial", font_size = "14pt", bold = TRUE),
    s_paragraph(alignment = "center"),
    s_table_style(background_color = "#D9D9D9")
  ) |>
  # Multiple calls merge with last-win
  add_style(id = "header",
    s_font(color = "#FF0000")  # Adds color, keeps other font properties
  )
} # }
```
