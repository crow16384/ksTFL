# Combine multiple style names for explicit grouping

Helper function to group multiple style names together for explicit
application to columns or elements. Useful when using
[`define_cols`](https://example.com/reference/define_cols.md) or other
functions with multiple columns and you want to either:

- Recycle the same group of styles to all columns:
  `labelStyleRef = f_combine("style1", "style2")`

- Create explicit one-to-one mappings:
  `labelStyleRef = c(f_combine("s1", "s2"), f_combine("s3"), "style4")`

## Usage

``` r
f_combine(...)
```

## Arguments

- ...:

  Character strings representing style names to combine

  - Each argument must be a single character string naming a style.

  - Returned object has class `tfl_style_combine` to signal grouped
    style application.

## Value

Character vector with class "tfl_style_combine" containing all provided
style names. This special class signals to style resolution functions
that these styles should be applied together as a group (merged with
last-win strategy during
[`create_report()`](https://example.com/reference/create_report.md)).

## Examples

``` r
if (FALSE) { # \dontrun{
# Combine styles for recycling to all columns
styles <- f_combine("label_style", "emphasis", "bold")

# Use in define_cols for one-to-one mapping
spec <- create_table(data) |>
  define_cols(c("id", "age"),
    labelStyleRef = c(
      f_combine("id_label", "key"),
      f_combine("numeric_label")
    )
  )
} # }
```
