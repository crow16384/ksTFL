# Add body text for TFL_spec

When adding body text to a spec that has default body text entries (IDs
starting with \_*default*), they are automatically removed to avoid
mixing defaults with user-defined content.

## Usage

``` r
# S3 method for class 'TFL_spec'
add_body_text(spec, text = NULL, id = NULL, styleRef = NULL, order = NULL)
```

## Arguments

- spec:

  TFL_spec object

- text:

  Character vector of body text lines

- id:

  Body text identifier (auto-generated if NULL)

- styleRef:

  Character vector of style names or result of
  [`f_combine()`](https://example.com/reference/f_combine.md). Merged
  with last-win strategy.

- order:

  Order of body text group (auto-assigned if NULL)

## Value

Updated spec object
