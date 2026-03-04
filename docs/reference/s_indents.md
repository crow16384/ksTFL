# Define indentation properties for paragraphs

This function can only be used inside
[`s_paragraph`](https://example.com/reference/s_paragraph.md).

## Usage

``` r
s_indents(left = NULL, right = NULL, first_line = NULL)
```

## Arguments

- left:

  Left indent, e.g. "10mm"

- right:

  Right indent, e.g. "10mm"

- first_line:

  First line indent (negative for hanging), e.g. "-5mm"

## Value

An indents specification object

## Examples

``` r
if (FALSE) { # \dontrun{
spec <- create_text() |>
  add_style("my_style",
    s_paragraph(
      indents = s_indents(left = "10mm", first_line = "-5mm")
    )
  )
} # }
```
