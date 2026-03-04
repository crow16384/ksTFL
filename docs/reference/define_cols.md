# Define or modify column properties

Modify properties of existing columns. Can modify single column or batch
update multiple columns. All parameters support 1-to-many recycling:
provide a single value to apply to all columns, or a vector matching the
length of `cols` for one-to-one mapping. Multiple calls merge with
last-win strategy.

## Usage

``` r
define_cols(
  spec,
  cols,
  label = NULL,
  isID = NULL,
  isVisible = NULL,
  isGrouping = NULL,
  isPaging = NULL,
  labelStyleRef = NULL,
  isColBreak = NULL,
  dedupe = NULL,
  blankAfter = NULL,
  type = NULL,
  format = NULL,
  missings = NULL,
  colWidth = NULL,
  valueStyleRef = NULL
)
```

## Arguments

- spec:

  TFL spec object (must be initialized with
  [`create_table`](https://example.com/reference/create_table.md))

- cols:

  Columns to modify using tidyselect syntax. Accepts:

  - Named columns: `c("age", "group")`

  - Column ranges: `age:group`

  - Helper functions: `starts_with("age_")`, `contains("_pct")`

  - Negation: `-id` or `!matches("^temp")`

- label:

  Column label (length 1 or length of cols; `NA` skips that position)

- isID:

  Whether column is identifier (length 1 or length of cols; `NA` skips
  that position)

- isVisible:

  Whether column is visible in report output (length 1 or length of
  cols; `NA` skips that position). When set to FALSE, column is hidden
  from output and automatically assigned width "0.0cm". Invisible
  columns do NOT participate in width recalculation; only visible
  columns are included. Cannot set `colWidth` for invisible columns
  (error raised if attempted).

- isGrouping:

  Whether column defines groups (length 1 or length of cols; `NA` skips
  that position)

- isPaging:

  Whether column defines pages (length 1 or length of cols; `NA` skips
  that position)

- labelStyleRef:

  List of style names to be applied. Provided styles will be merged with
  last-win strategy for report. Can be: single string (recycled),
  character vector from
  [`f_combine`](https://example.com/reference/f_combine.md) (recycled),
  or list of [`f_combine`](https://example.com/reference/f_combine.md)
  results or `NA` sentinels (one-to-one mapping to columns). Use `NA` as
  a list element to skip updating `labelStyleRef` for that column.

- isColBreak:

  Whether column triggers page break (length 1 or length of cols; `NA`
  skips that position)

- dedupe:

  Whether to deduplicate values (length 1 or length of cols; `NA` skips
  that position)

- blankAfter:

  Whether to add blank after value change (length 1 or length of cols;
  `NA` skips that position)

- type:

  Data type for column format: "string" or "numeric" (length 1 or length
  of cols; `NA` skips that position). Optional; omit to preserve
  existing.

- format:

  Format string for numeric data (sprintf style), e.g. "%.1f" (length 1
  or length of cols; `NA` skips that position). Optional.

- missings:

  How to display missing values in columns (length 1 or length of cols;
  `NA` skips that position). Optional.

- colWidth:

  Column width, e.g. "2in", "5cm", "20%" (length 1 or length of cols;
  `NA` skips that position — the column's width is left unchanged).
  Optional. When at least one non-`NA` value is specified, affected
  columns are marked as LOCKED and automatic recalculation of remaining
  unlocked columns is triggered if `autoColWidth = TRUE` in
  [`tfl_set_options()`](https://example.com/reference/tfl_set_options.md).
  Locked columns maintain their exact width while unlocked columns
  normalize to fill remaining available space.

- valueStyleRef:

  Style names to apply to cell values. Provided styles will be merged
  with last-win strategy for report. Use `NA` as a list element to skip
  updating `valueStyleRef` for that column.

## Value

Updated spec object

## Details

Column Width Management:

Widths are managed through a LOCKED/UNLOCKED/VISIBLE partitioning
system:

- VISIBLE columns: included in width calculations (isVisible != FALSE)

- LOCKED columns: exact width specified via colWidth parameter (any
  unit: %, cm, in, mm, pt)

- UNLOCKED columns: automatically recalculated to fill available space

- INVISIBLE columns: hidden from output (isVisible = FALSE), assigned
  width "0.0cm", excluded from calculations

When `colWidth` is specified (or visibility changes), columns are marked
as LOCKED and remaining UNLOCKED columns are automatically recalculated
(if `autoColWidth = TRUE`, the default):

- Only VISIBLE UNLOCKED columns participate in recalculation

- Locked columns (any unit) maintain their exact specified width

- Unlocked visible columns normalize proportionally to fill remaining
  available space

- All visible columns' widths sum to 100% with 1 decimal place precision

- Invisible columns stay at "0.0cm" and don't affect other widths

To disable auto-recalculation, use
`tfl_set_options(autoColWidth = FALSE)`.

Invisible Column Behavior:

- `isVisible = FALSE` automatically sets `colWidth = "0.0cm"`

- Cannot set `colWidth` on invisible columns (raises error)

- Invisible columns are excluded from width recalculation entirely

- Shown with "hidden" flag in spec preview

## Examples

``` r
if (FALSE) { # \dontrun{
data <- data.frame(id = 1:10, age = rnorm(10, 45, 10), group = rep(c("A", "B"), 5))

# Single column with format
spec <- create_table(data) |>
  define_cols("age",
    label = "Age (years)",
    type = "numeric", format = "%.1f", colWidth = "10%"
  )

# Batch update with single value
spec <- create_table(data) |>
  define_cols(c("id", "age", "group"),
    isVisible = TRUE  # Applied to all three
  )

# Batch update with mapped values
spec <- create_table(data) |>
  define_cols(c("id", "age"),
    label = c("Subject ID", "Age (years)"),  # One-to-one mapping
    isID = c(TRUE, FALSE)
  )

# Batch format update with mixed recycling
spec <- create_table(data) |>
  define_cols(c("id", "age"),
    type = "numeric",  # Single value recycled to both columns
    colWidth = c("10%", "15%")  # Different widths for each column
  )

# Multiple calls merge
spec <- create_table(data) |>
  define_cols("age",
    label = "Age",
    type = "numeric", format = "%.0f"
  ) |>
  define_cols("age",
    label = "Age (years)",  # Overrides previous label
    colWidth = "15%"  # Merges with format, keeping type and format
  )

# Apply style references - single value recycled to all columns
spec <- create_table(data) |>
  define_cols(c("age", "id"),
    labelStyleRef = f_combine("label_style", "emphasis")
  )

# Apply different styles combinations to different columns
spec <- create_table(data) |>
  define_cols(c("id", "age", "group"),
    labelStyleRef = c(
      f_combine("id_label", "key"),
      f_combine("numeric_label", "emphasis"),
      f_combine("categorical_label")
    )
  )

# Column width auto-recalculation (when autoColWidth = TRUE, the default):
# Initial widths are automatically distributed (e.g., id=33.3%, age=33.3%, group=33.4%)
spec <- create_table(data) |>
  define_cols("id", colWidth = "20%")  # Lock id at 20%
  # Result: id=20%, age and group auto-recalculate to fill remaining 80%
  # 
# Multiple colWidth calls preserve previous locks:
spec <- create_table(data) |>
  define_cols("id", colWidth = "20%") |>
  define_cols("age", colWidth = "15%")
  # Result: id=20% (locked), age=15% (locked), group=65% (fills remaining)

# Disable auto-recalculation to manage widths manually:
tfl_set_options(autoColWidth = FALSE)  # Turn off auto-recalculation
spec <- create_table(data) |>
  define_cols(c("id", "age", "group"), colWidth = c("25%", "30%", "45%"))
  # Widths stay exactly as specified, no automatic recalculation
tfl_set_options(autoColWidth = TRUE)  # Re-enable (restore default)


# Using tidyselect helpers
spec <- create_table(data) |>
  define_cols(starts_with("age"),
    label = "Age-related metric",
    type = "numeric", format = "%.1f"
  )

# Using negation with tidyselect
spec <- create_table(data) |>
  define_cols(-id,  # Exclude id column
    isVisible = TRUE
  )

# Using column range
spec <- create_table(data) |>
  define_cols(age:group,  # All columns from age to group
    labelStyleRef = "emphasis"
  )

# Hide column from output while keeping data for conditional logic
spec <- create_table(data) |>
  define_cols("age",
    isVisible = FALSE  # Automatically sets width to "0.0cm"
  )
  # Result: age column hidden, other columns recalculated to sum to 100%
} # }
```
