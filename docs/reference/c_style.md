# Apply Style to Columns in Conditional Rows

Declares a style or combination of styles to be applied to specified
columns in rows matching the parent
[`compute_cols()`](https://example.com/reference/compute_cols.md)
condition.

## Usage

``` r
c_style(cols, styleRef)
```

## Arguments

- cols:

  Tidyselect expression for column selection (e.g., `c(col1, col2)`,
  `everything()`, `starts_with("x")`)

- styleRef:

  Character. Name of the style to apply (defined via
  [`add_style()`](https://example.com/reference/add_style.md)). Can be a
  single style name or result of
  [`f_combine()`](https://example.com/reference/f_combine.md) for
  combining multiple styles.

## Value

Quosure structure (internal use within
[`compute_cols()`](https://example.com/reference/compute_cols.md))

## Details

Must be called inside
[`compute_cols()`](https://example.com/reference/compute_cols.md).
Columns are resolved using tidyselect syntax against the table data.

## See also

[`compute_cols()`](https://example.com/reference/compute_cols.md) for
conditional row actions,
[`c_merge()`](https://example.com/reference/c_merge.md),
[`c_addrow()`](https://example.com/reference/c_addrow.md) for other
action types

**Behavior:**

- Same column styled multiple times in one row: last style wins, warning
  issued

- Same column styled from different
  [`compute_cols()`](https://example.com/reference/compute_cols.md)
  calls on same row: automatic style combination (merged via
  [`create_report()`](https://example.com/reference/create_report.md))

- Multiple columns in one call: all receive the same style(s)

**Style Combination:**

- Use `f_combine("style1", "style2")` to apply multiple styles together

- During
  [`create_report()`](https://example.com/reference/create_report.md),
  combined styles are consolidated into a single hash

- Consolidation only happens for new specs (not pre-processed reports)

## Examples

``` r
if (FALSE) { # \dontrun{
  spec <- create_table(mtcars) |>
    add_style("bold", s_font(bold = TRUE)) |>
    add_style("red", s_font(color = "red"))

  # Single style on one column
  spec <- compute_cols(spec, cyl == 6, c_style(mpg, styleRef = "bold"))

  # Single style on multiple columns
  spec <- compute_cols(spec, hp > 100, c_style(c(mpg, wt), styleRef = "red"))

  # Combined styles on columns
  spec <- compute_cols(spec, cyl == 8, c_style(mpg, styleRef = f_combine("bold", "red")))
} # }
```
