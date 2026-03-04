# Insert a page break at the matching row

Used inside
[`compute_cols()`](https://example.com/reference/compute_cols.md) to
signal the renderer to start a new page at every row matching the
condition. Takes no arguments.

## Usage

``` r
c_pageBreak()
```

## Value

Action marker (internal use within
[`compute_cols()`](https://example.com/reference/compute_cols.md))

## See also

[`compute_cols()`](https://example.com/reference/compute_cols.md),
[`c_style()`](https://example.com/reference/c_style.md),
[`c_addrow()`](https://example.com/reference/c_addrow.md),
[`c_merge()`](https://example.com/reference/c_merge.md)

## Examples

``` r
if (FALSE) { # \dontrun{
data <- data.frame(
  group = c("A", "A", "B", "B", "C"),
  value = c(1, 2, 3, 4, 5)
)

# Force a new page at the start of each group
spec <- create_table(data) |>
  compute_cols(firstOf(group), c_pageBreak())
} # }
```
