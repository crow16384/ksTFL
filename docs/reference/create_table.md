# Create a Table Specification

Create and initialize a TFL specification for tabular output. This
wrapper captures the tidyselect `cols` expression and forwards it to the
internal initializer. Use `create_table()` when you have a data frame
that should be rendered as a table.

## Usage

``` r
create_table(data = NULL, cols = everything())
```

## Arguments

- data:

  A data frame to build the table from (required).

- cols:

  Tidyselect expression indicating which columns from `data` to include
  in the report. Defaults to `everything()`.

## Value

A `TFL_spec` object with `docType = "Table"`.

## Details

Column Width Initialization: Initial column widths are automatically
calculated based on data values and their types and sum to 100%. To lock
specific columns and trigger automatic recalculation of others, use
[`define_cols()`](https://example.com/reference/define_cols.md) with the
`colWidth` parameter (when `autoColWidth = TRUE` in the tfl_options, the
default).

Example workflow:

- Create table: widths auto-distributed

- `define_cols(id, colWidth="20%")`: locks id at 20%, others
  recalculated to fill 80% keeping intially detected proportions

- `define_cols(age, colWidth="2cm")`: locks age at fixed 2cm width,
  other relative columns recalculated to fill remaining space

## See also

[`create_text()`](https://example.com/reference/create_text.md),
[`create_figure()`](https://example.com/reference/create_figure.md),
[`define_cols()`](https://example.com/reference/define_cols.md),
[`add_title()`](https://example.com/reference/add_title.md),
[`create_report()`](https://example.com/reference/create_report.md)

## Examples

``` r
if (FALSE) { # \dontrun{
## Basic usage with the built-in `mtcars` dataset
spec <- create_table(mtcars)

## Select specific columns using tidyselect
spec <- create_table(mtcars, cols = c(cyl, mpg, hp))

## or using ranges:
spec <- create_table(mtcars, cyl:hp)

## or by excluding columns
spec <- create_table(mtcars, cols = -c(gear, carb))

## or simple by names
spec <- create_table(mtcars, cols = c("cyl", "mpg", "hp"))
} # }
```
