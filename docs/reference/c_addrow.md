# Insert Additional Row in Conditional Rows

Declares an additional row to be inserted above or below rows matching
the parent
[`compute_cols()`](https://example.com/reference/compute_cols.md)
condition. Content can optionally be copied from a specified column; if
omitted, creates an empty separator row.

## Usage

``` r
c_addrow(pos, value_from = NULL, styleRef = NULL)
```

## Arguments

- pos:

  Character. Position for insertion: "above" or "below".

- value_from:

  Character or unquoted column name. Optional source column for the
  inserted row's content. If NULL or missing, creates an empty separator
  row.

- styleRef:

  Character vector or result of
  [`f_combine()`](https://example.com/reference/f_combine.md). Optional
  style to apply to the inserted row. If NULL, no special styling.

## Value

Quosure structure (internal use within
[`compute_cols()`](https://example.com/reference/compute_cols.md))

## Details

Must be called inside
[`compute_cols()`](https://example.com/reference/compute_cols.md).

**Behavior:**

- Multiple `c_addrow()` calls in one
  [`compute_cols()`](https://example.com/reference/compute_cols.md)
  accumulate

- Order of appearance is preserved

- Coexists with other actions on same row

- If `value_from` is provided, must exist in spec columns (data_env
  reference)

- If `value_from` is NULL or missing, creates an empty separator row

## See also

[`compute_cols()`](https://example.com/reference/compute_cols.md) for
conditional row actions,
[`c_style()`](https://example.com/reference/c_style.md),
[`c_merge()`](https://example.com/reference/c_merge.md) for other action
types

## Examples

``` r
if (FALSE) { # \dontrun{
  compute_cols(spec, lastOf(treatment), c_addrow(pos = "below", value_from = "treatment"))
  compute_cols(spec, firstOf(visit), c_addrow(pos = "above"))
} # }
```
