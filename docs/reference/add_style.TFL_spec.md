# Add or update a style definition for TFL_spec

Add or update a style definition for TFL_spec

## Usage

``` r
# S3 method for class 'TFL_spec'
add_style(spec, id, ...)
```

## Arguments

- spec:

  TFL_spec object

- id:

  Style identifier (auto-generated if NULL)

- ...:

  Style modifiers created with s\_\* functions

  - Allowed modifiers:
    [`s_font()`](https://example.com/reference/s_font.md),
    [`s_paragraph()`](https://example.com/reference/s_paragraph.md),
    [`s_table_style()`](https://example.com/reference/s_table_style.md).

  - [`s_paragraph()`](https://example.com/reference/s_paragraph.md) may
    itself contain nested modifiers
    [`s_spacing()`](https://example.com/reference/s_spacing.md) and
    [`s_indents()`](https://example.com/reference/s_indents.md).

  - Modifiers are merged into the named style using a last-win strategy.

## Value

Updated spec object
