# Concatenate a Value to Cell Text in Conditional Rows

Declares a glue action to concatenate a value — from a data column or a
literal string — to the display text of specified cells in rows matching
the parent
[`compute_cols()`](https://example.com/reference/compute_cols.md)
condition.

## Usage

``` r
c_glue(cols, position, glue_col = NULL, text = NULL, separator = NULL)
```

## Arguments

- cols:

  Tidyselect expression for the target columns (e.g., `col1`,
  `c(col1, col2)`, `starts_with("x")`). Must resolve to visible
  (non-hidden) report columns only.

- position:

  Character. Concatenation side: `"before"` prepends the glue value to
  the existing cell text; `"after"` appends it.

- glue_col:

  Optional. Unquoted column name whose formatted value is concatenated
  onto the target cells. The column may be hidden (not in the visible
  column list). Mutually exclusive with `text`.

- text:

  Optional. A single literal character string to concatenate onto the
  target cells. Mutually exclusive with `glue_col`.

- separator:

  Character string inserted between the existing cell text and the glued
  value when both sides are non-empty. Defaults to `""` (direct
  concatenation). When either side is empty, no separator is inserted.

## Value

Quosure-style marker (internal use within
[`compute_cols()`](https://example.com/reference/compute_cols.md))

## Details

Must be called inside
[`compute_cols()`](https://example.com/reference/compute_cols.md).

**Constraints:**

- Exactly one of `glue_col` or `text` must be provided.

- `cols` resolves only visible report columns via tidyselect.

- `glue_col` can reference any data column, including hidden ones.

- `glue_col` must not overlap with `cols`.

**Behavior:**

- When the glue value (from `glue_col` or `text`) is empty or `NA`, the
  action is silently skipped for that row/cell.

- When a target cell was suppressed by deduplication (`dedupe = TRUE` on
  that column), the glue is silently skipped to preserve the visual
  suppression of repeated values.

- When a target cell is suppressed by a concurrent
  [`c_merge()`](https://example.com/reference/c_merge.md) action (i.e.,
  it is a non-leader merged cell), the glue is silently skipped.

- The merge leader cell is glued normally when `c_glue()` targets a
  column involved in
  [`c_merge()`](https://example.com/reference/c_merge.md) as the first
  column.

- Multiple `c_glue()` calls on the same column accumulate in call order.

**Interaction with other actions:**

- [`c_style()`](https://example.com/reference/c_style.md): Fully
  compatible — styling and text modification are independent.

- [`c_merge()`](https://example.com/reference/c_merge.md): Compatible.
  Glue is processed after merge in the renderer. Non-leader (suppressed)
  merge cells are skipped; the merge-leader cell is glued normally.

- [`c_addrow()`](https://example.com/reference/c_addrow.md): Fully
  compatible (affects different rows/cells).

- [`c_pageBreak()`](https://example.com/reference/c_pageBreak.md): Fully
  compatible.

## See also

[`compute_cols()`](https://example.com/reference/compute_cols.md),
[`c_style()`](https://example.com/reference/c_style.md),
[`c_merge()`](https://example.com/reference/c_merge.md),
[`c_addrow()`](https://example.com/reference/c_addrow.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  # Append a unit from a hidden column (e.g. unit_col is not in spec cols)
  spec <- compute_cols(spec, !is.na(value),
    c_glue(value, "after", glue_col = unit, separator = " "))

  # Prepend a literal marker to a label column
  spec <- compute_cols(spec, is_total,
    c_glue(label, "before", text = ">> "))

  # Combine with c_style() — independent operations
  spec <- compute_cols(spec, firstOf(group),
    c_glue(label, "before", text = "> "),
    c_style(label, styleRef = "bold"))
} # }
```
