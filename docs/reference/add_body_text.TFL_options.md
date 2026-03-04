# Add body text for TFL_options

When adding body text to TFL options (global settings), automatically
removes any existing default body text entries (\_\_default_NNN) and
starts adding new ones from \_\_default_002 onwards.

## Usage

``` r
# S3 method for class 'TFL_options'
add_body_text(spec, text = NULL, id = NULL, styleRef = NULL, order = NULL)
```

## Arguments

- spec:

  TFL_options object

- text:

  Character vector of body text lines

- id:

  Body text identifier (auto-generated as \_\_default_NNN if NULL)

- styleRef:

  Character vector of style names or result of
  [`f_combine()`](https://example.com/reference/f_combine.md). Merged
  with last-win strategy.

- order:

  Order of body text group (auto-assigned if NULL)

## Value

Updated options object
