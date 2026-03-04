# Clear Cell Content in Conditional Rows

Declares a clear action that blanks the display text of specified cells
in rows matching the parent
[`compute_cols()`](https://example.com/reference/compute_cols.md)
condition. The cells are rendered empty without affecting their column
structure, width, or styling.

## Usage

``` r
c_clear(cols)
```

## Arguments

- cols:

  Tidyselect expression for the target columns to blank (e.g., `col1`,
  `c(col1, col2)`, `starts_with("x")`). Must resolve to visible
  (non-hidden) report columns only.

## Value

Quosure-style marker (internal use within
[`compute_cols()`](https://example.com/reference/compute_cols.md))

## Details

Must be called inside
[`compute_cols()`](https://example.com/reference/compute_cols.md).

**Behavior:**

- Sets the rendered cell text to `""` for matching rows.

- Processed before
  [`c_merge()`](https://example.com/reference/c_merge.md) and
  [`c_glue()`](https://example.com/reference/c_glue.md) in the rendering
  chain, so the cleared state participates in subsequent actions. In
  particular: combining `c_clear()` +
  [`c_glue()`](https://example.com/reference/c_glue.md) on the same
  column effectively *replaces* the original cell content with the glued
  value.

- Compatible with
  [`c_style()`](https://example.com/reference/c_style.md): styling is
  independent of text content.

- When [`c_merge()`](https://example.com/reference/c_merge.md) targets a
  cleared leader cell, the merged span renders as a blank merged cell.

## See also

[`compute_cols()`](https://example.com/reference/compute_cols.md),
[`c_style()`](https://example.com/reference/c_style.md),
[`c_merge()`](https://example.com/reference/c_merge.md),
[`c_glue()`](https://example.com/reference/c_glue.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  # Blank label column in total rows
  spec <- compute_cols(spec, is_total,
    c_clear(label))

  # Clear then replace with a value from another column (full replacement)
  spec <- compute_cols(spec, condition,
    c_clear(display_col),
    c_glue(display_col, "after", glue_col = replacement_col))
} # }
```
