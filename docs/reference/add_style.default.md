# Default method for add_style

Default method for add_style

## Usage

``` r
# Default S3 method
add_style(spec, id = NULL, ...)
```

## Arguments

- spec:

  Spec object

- id:

  Style identifier

- ...:

  Style modifiers

  - Functions created with `s_*()` helpers (e.g.,
    [`s_font()`](https://example.com/reference/s_font.md),
    [`s_paragraph()`](https://example.com/reference/s_paragraph.md)).

  - These modifiers are evaluated in the
    [`add_style()`](https://example.com/reference/add_style.md) context
    and merged into the style definition.

## Value

Error if no method found
