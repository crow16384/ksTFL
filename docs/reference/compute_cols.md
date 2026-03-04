# Define Conditional Row Actions for Tables

Declares a set of styling, merging, and row insertion actions to be
applied to rows matching a condition. Actions are captured as
unevaluated expressions and evaluated later during
[`create_report()`](https://example.com/reference/create_report.md).
Supports complex conditions using data columns and helper functions.

## Usage

``` r
compute_cols(spec, cond, ...)
```

## Arguments

- spec:

  A TFL_spec object (must have docType = "Table")

- cond:

  An unquoted logical expression to be evaluated in the data
  environment. Can reference:

  - Data columns directly (e.g., `col1 > 10`, `Parameter == "Pulse"`)

  - Helper functions (e.g., `firstOf()`, `lastOf()`, `uniqueOf()`)

  Must return a logical vector of length equal to `nrow(data)`.

- ...:

  Action function calls:
  [`c_style()`](https://example.com/reference/c_style.md),
  [`c_merge()`](https://example.com/reference/c_merge.md),
  [`c_addrow()`](https://example.com/reference/c_addrow.md),
  [`c_glue()`](https://example.com/reference/c_glue.md),
  [`c_clear()`](https://example.com/reference/c_clear.md). Multiple
  actions allowed, including duplicates. Actions are captured
  unevaluated.

## Value

Modified `spec` object with appended action metadata in
`spec$.metadata$compute_cols`. Invisibly returns the updated spec to
enable piping workflows.

## Details

**Execution Timeline:**

1.  `compute_cols()` captures condition and actions (no evaluation)

2.  Appends to `spec$.metadata$compute_cols` list

3.  During
    [`create_report()`](https://example.com/reference/create_report.md),
    conditions are evaluated and matched rows identified

4.  Actions are applied to matching rows (styling, merging, row
    insertion)

5.  StyleRows are serialized to JSON

**Constraints:**

- Only allowed for docType = "Table"

- Multiple `compute_cols()` calls accumulate on the same spec

- Actions on the same row from different `compute_cols()` blocks are
  aggregated

- Conditions must be deterministic (no NA values allowed)

**Action Functions** (used inside `compute_cols()`):

- `c_style(cols, styleRef)`: Apply style(s) to columns in matching rows

- `c_merge(cols, styleRef = NULL)`: Merge adjacent columns in matching
  rows

- `c_addrow(pos, value_from = NULL, styleRef = NULL)`: Insert row
  above/below matching rows

- [`c_pageBreak()`](https://example.com/reference/c_pageBreak.md):
  Insert a page break at the matching row (no args)

- `c_glue(cols, position, glue_col = NULL, text = NULL, separator = NULL)`:
  Concatenate a data column value or literal text to matching cell text

- `c_clear(cols)`: Clear the display text of matching cells (render as
  blank)

## See also

[`c_style()`](https://example.com/reference/c_style.md),
[`c_merge()`](https://example.com/reference/c_merge.md),
[`c_addrow()`](https://example.com/reference/c_addrow.md) for action
functions used within `compute_cols()`

## Examples

``` r
if (FALSE) { # \dontrun{
  spec <- create_table(mtcars)
  spec <- add_style(spec, id = "bold", s_font(bold = TRUE))
  spec <- add_style(spec, id = "red", s_font(color = "red"))
  spec <- add_style(spec, id = "highlight", s_table_style(background_color = "yellow"))

  # Style columns in rows where cyl is first occurrence
  spec <- compute_cols(spec, firstOf(cyl), c_style(c(mpg, hp), styleRef = "bold"))

  # Style and merge columns in rows with high hp
  spec <- compute_cols(spec, hp > 200, 
    c_style(hp, styleRef = "red"),
    c_merge(c(wt, qsec), styleRef = "highlight")
  )

  # Add empty separator row above first occurrence
  spec <- compute_cols(spec, firstOf(cyl), c_addrow(pos = "above"))

  # Add row with content from a column
  spec <- compute_cols(spec, lastOf(cyl), c_addrow(pos = "below", value_from = "mpg"))
} # }
```
