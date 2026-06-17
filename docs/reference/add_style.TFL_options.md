# Add or update a style definition for TFL_options

Add or update a style definition for TFL_options

## Usage

``` r
# S3 method for class 'TFL_options'
add_style(spec, id = NULL, ...)
```

## Arguments

- spec:

  TFL_options style branch object

- id:

  Style identifier (name)

- ...:

  Style modifiers created with s\_\* functions

  - Allowed modifiers:
    [`s_font()`](https://crow16384.github.io/ksTFL-release/reference/s_font.md),
    [`s_paragraph()`](https://crow16384.github.io/ksTFL-release/reference/s_paragraph.md),
    [`s_table_style()`](https://crow16384.github.io/ksTFL-release/reference/s_table_style.md).

  - [`s_paragraph()`](https://crow16384.github.io/ksTFL-release/reference/s_paragraph.md)
    may itself contain nested modifiers
    [`s_spacing()`](https://crow16384.github.io/ksTFL-release/reference/s_spacing.md)
    and
    [`s_indents()`](https://crow16384.github.io/ksTFL-release/reference/s_indents.md).

  - Modifiers are merged into the named style using a last-win strategy.

## Value

Updated spec object
