# S3 method for c() with tfl_style_combine objects

When combining tfl_style_combine objects with c(), preserve them as list
elements rather than flattening. This enables explicit one-to-one style
mapping.

## Usage

``` r
# S3 method for class 'tfl_style_combine'
c(..., recursive = FALSE)
```

## Arguments

- ...:

  Objects to combine

  - Accepts `tfl_style_combine` objects and plain character strings.

  - `tfl_style_combine` objects are preserved as single list elements to
    enable one-to-one mappings.

  - Character strings are added as separate list elements.

- recursive:

  Ignored

## Value

List of style references
