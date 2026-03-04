# Define spacing properties for paragraphs

This function can only be used inside
[`s_paragraph`](https://example.com/reference/s_paragraph.md).

## Usage

``` r
s_spacing(before = NULL, after = NULL, line_spacing = NULL)
```

## Arguments

- before:

  Space before paragraph, e.g. "6pt"

- after:

  Space after paragraph, e.g. "6pt"

- line_spacing:

  Line spacing multiplier, minimum 1

## Value

A spacing specification object

## Examples

``` r
if (FALSE) { # \dontrun{
spec <- create_text() |>
  add_style("my_style",
    s_paragraph(
      alignment = "center",
      spacing = s_spacing(before = "12pt", after = "6pt")
    )
  )
} # }
```
