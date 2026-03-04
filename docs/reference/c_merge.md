# Merge Adjacent Columns in Conditional Rows

Declares adjacent columns to be merged in rows matching the parent
[`compute_cols()`](https://example.com/reference/compute_cols.md)
condition. Merged columns appear as a single spanned cell.

## Usage

``` r
c_merge(cols, styleRef = NULL)
```

## Arguments

- cols:

  Tidyselect expression for column selection. Must resolve to at least 2
  columns that are consecutive in the report column order.

- styleRef:

  Character vector or result of
  [`f_combine()`](https://example.com/reference/f_combine.md). Optional
  style to apply to the merged cell. If NULL, no special styling.

## Value

Quosure structure (internal use within
[`compute_cols()`](https://example.com/reference/compute_cols.md))

## Details

Must be called inside
[`compute_cols()`](https://example.com/reference/compute_cols.md).
Columns must be adjacent in the final report column order.

## See also

[`compute_cols()`](https://example.com/reference/compute_cols.md) for
conditional row actions,
[`c_style()`](https://example.com/reference/c_style.md),
[`c_addrow()`](https://example.com/reference/c_addrow.md) for other
action types

**Validation:**

- Immediate: columns exist and are consecutive (error if not)

- Deferred: overlapping merge ranges from multiple
  [`compute_cols()`](https://example.com/reference/compute_cols.md)
  calls (warning if resolvable, error if ambiguous)

**Behavior:**

- Multiple merge actions in one row: all applied if non-overlapping

- Overlapping merges from different
  [`compute_cols()`](https://example.com/reference/compute_cols.md)
  blocks: raises warning/error

## Examples

``` r
if (FALSE) { # \dontrun{
  spec <- create_table(mtcars) |>
    add_style("group_header", s_table_style(background_color = "#D9D9D9"))

  # Merge multiple columns for group header
  spec <- compute_cols(spec, group == "A", 
    c_merge(c(col1, col2, col3), styleRef = "group_header"))

  # Merge without style
  spec <- compute_cols(spec, group == "B", c_merge(c(disp, hp)))
} # }
```
