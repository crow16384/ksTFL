# Add stub (spanning) column definition

Define a spanning header that covers multiple columns. Can be used to
create multi-level headers by specifying different `stubOrder` values.

## Usage

``` r
add_span_header(
  spec,
  cols,
  label,
  stubOrder = NULL,
  id = NULL,
  labelStyleRef = NULL
)
```

## Arguments

- spec:

  TFL spec object

- cols:

  Columns to span using tidyselect syntax. Accepts:

  - Named columns: `c("age", "sex")`

  - Column ranges: `age:sex`

  - Helper functions: `starts_with("age_")`, `contains("_pct")`

  - Negation: `-id` or `!matches("^temp")`

- label:

  Spanning header label

- stubOrder:

  Order of stub header (auto-generated if NULL). Used to create
  multi-level headers: lower numbers appear above higher numbers.
  Multiple stubs at the same order are allowed if their column sets do
  not overlap.

- id:

  Stub column identifier (auto-generated if NULL)

- labelStyleRef:

  List of style names to be applied. Provided styles will be merged with
  last-win strategy for report

## Value

Updated spec object

## Details

### Column Overlap Rules

Stubs at the **same** `stubOrder` cannot share columns (to avoid
ambiguous headers). However, stubs at **different** `stubOrder` values
can overlap freely.

This allows hierarchical header structures:

- `stubOrder = 1`: first-level grouping above the column headers

- `stubOrder = 2`: next-level grouping above the first-level etc..

Multiple calls with the same `stubOrder` are allowed as long as their
column sets do not overlap. This enables building complex header
structures incrementally.

## Examples

``` r
if (FALSE) { # \dontrun{
data <- data.frame(
  id = 1:10, 
  age = rnorm(10, 45, 10), 
  sex = sample(c("M", "F"), 10, TRUE),
  weight = rnorm(10, 70, 10),
  height = rnorm(10, 170, 10)
)

# Example 1: Single-level spanning header
spec <- create_table(data) |>
  add_span_header(
    cols = c(age, sex),  # Using tidyselect (unquoted column names)
    label = "Demographics",
    labelStyleRef = c("stub_label_style", "bold")
  )

# Example 2: Two-level header hierarchy
spec <- create_table(data) |>
  add_span_header(cols = c(age, sex, weight, height), label = "All Measurements", stubOrder = 0) |>
  add_span_header(cols = c(age, sex), label = "Demographics", stubOrder = 1) |>
  add_span_header(cols = c(weight, height), label = "Physical", stubOrder = 1)

# Example 3: Three-level header hierarchy
spec <- create_table(data) |>
  add_span_header(cols = starts_with("a") | starts_with("w") | starts_with("h"), 
                  label = "Main Data", stubOrder = 0) |>
  add_span_header(cols = c(age, sex), label = "Demographics", stubOrder = 1) |>
  add_span_header(cols = c(weight, height), label = "Physical", stubOrder = 1) |>
  add_span_header(cols = age, label = "Age Details", stubOrder = 2)

# Example 4: Using tidyselect helpers
spec <- create_table(data) |>
  add_span_header(cols = contains("age"), label = "Age-related", stubOrder = 0) |>
  add_span_header(cols = matches("^w"), label = "Weight", stubOrder = 0)

# Example 5: Negation to exclude columns
spec <- create_table(data) |>
  add_span_header(cols = -id, label = "Measurements", stubOrder = 0)

# Example 6: Multiple non-overlapping stubs at same level
spec <- create_table(data) |>
  add_span_header(cols = c(age, sex), label = "Group1", stubOrder = 1) |>
  add_span_header(cols = c(weight, height), label = "Group2", stubOrder = 1)  # OK: no overlap
} # }
```
