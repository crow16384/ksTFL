# Column Width Management in ksTFL

![ksTFL logo](figures/ksTFL-logo.svg)

## Overview

This vignette explains how column widths are managed in ksTFL, including
the LOCKED/UNLOCKED/VISIBLE partitioning system, automatic recalculation
behavior, and strategies for fine-tuning table layouts.

## Category and scope

This is a layout and pagination control vignette.

- Audience: users optimizing table readability and page-fit behavior
- Focus: width locking, auto-recalculation, invisible columns, and
  tradeoffs
- Outcome: predictable, reproducible table geometry in rendered DOCX
  output

## Core Concepts

### Column States

ksTFL partitions table columns into four categories that determine how
widths are calculated:

1.  **VISIBLE Columns** (`isVisible != FALSE`)
    - Displayed in the report output
    - Participate in width calculations
    - This is the default state for all columns
2.  **LOCKED Columns** (width explicitly set via `colWidth`)
    - Maintain their exact specified width (any unit: %, cm, in, mm, pt)
    - Fixed during automatic recalculation
    - Can use relative (%) or absolute (cm, in) units
3.  **UNLOCKED Columns** (no `colWidth` set)
    - Automatically recalculated to fill available space
    - Normalized proportionally based on initial auto-detected weights
    - Only visible unlocked columns participate in recalculation
4.  **INVISIBLE Columns** (`isVisible = FALSE`)
    - Hidden from output completely
    - Automatically assigned width “0.0cm”
    - Excluded from all width calculations
    - Data still accessible for conditional logic (e.g.,
      [`compute_cols()`](https://example.com/reference/compute_cols.md))

### Initial Width Distribution

When you create a table, ksTFL automatically:

1.  Analyzes each column’s data type and content
2.  Estimates visual width based on:
    - Maximum value length
    - Column name length
    - Label length (if provided)
3.  Distributes widths proportionally so they sum to 100%
4.  Applies minimum width constraints (0.5% for relative widths)

``` r
library(ksTFL)

# Create sample data
data <- data.frame(
  id = 1:100,
  patient_id = sprintf("PAT-%04d", 1:100),
  age = round(rnorm(100, 45, 10)),
  weight_kg = round(rnorm(100, 70, 15), 1),
  treatment_group = sample(c("Placebo", "Treatment A", "Treatment B"), 100, replace = TRUE)
)

# Initial spec with auto-detected widths
spec <- create_table(data)
print(spec)  # Shows auto-calculated widths for all columns
```

### The `autoColWidth` Option

The `autoColWidth` option (default: `TRUE`) controls whether widths are
automatically recalculated when you lock columns:

``` r
# Check current setting
tfl_get_option("autoColWidth")  # TRUE by default

# Disable for manual width management
tfl_set_options(autoColWidth = FALSE)

# Re-enable (restore default behavior)
tfl_set_options(autoColWidth = TRUE)
```

## Width Locking Workflow

### Basic Locking

When you set `colWidth` for a column, it becomes LOCKED:

``` r
# Lock the 'id' column at 15%
spec <- create_table(data) |>
  define_cols(id, colWidth = "15%")

# Result:
# - id: 15% (LOCKED)
# - Other visible columns: auto-recalculated to fill remaining 85%
```

### Multiple Locked Columns

You can lock multiple columns; unlocked columns fill the remaining
space:

``` r
spec <- create_table(data) |>
  define_cols(id, colWidth = "10%") |>           # Lock at 10%
  define_cols(patient_id, colWidth = "20%") |>   # Lock at 20%
  define_cols(treatment_group, colWidth = "25%") # Lock at 25%

# Result:
# - id: 10% (LOCKED)
# - patient_id: 20% (LOCKED)
# - treatment_group: 25% (LOCKED)
# - age, weight_kg: share remaining 45% proportionally
```

### Mixing Relative and Absolute Units

You can mix percentage widths with absolute units:

``` r
spec <- create_table(data) |>
  define_cols(id, colWidth = "2.5cm") |>      # Fixed width (doesn't reduce % space)
  define_cols(patient_id, colWidth = "20%")   # Takes 20% of available

# Result:
# - id: 2.5cm (LOCKED, absolute)
# - patient_id: 20% (LOCKED, relative)
# - Other columns: share remaining 80% proportionally
```

**Important:** Fixed-unit columns (cm, in, mm, pt) don’t reduce the
available percentage space—only locked percentage columns do.

## Width Recalculation Algorithm

When `autoColWidth = TRUE` and you lock a column, ksTFL:

1.  **Partitions columns** into LOCKED and UNLOCKED
2.  **Calculates available space**: 100% minus sum of locked percentage
    widths
3.  **Normalizes unlocked widths** to fill available space
    proportionally
4.  **Rounds to 1 decimal place** with drift correction

### Example Walkthrough

``` r
# Initial auto-distribution (example values):
# id: 15%, patient_id: 25%, age: 20%, weight_kg: 20%, treatment_group: 20%

spec <- create_table(data) |>
  define_cols(id, colWidth = "10%")
  
# After locking id at 10%:
# - Available space: 100% - 10% = 90%
# - Unlocked weights: patient_id=25, age=20, weight_kg=20, treatment_group=20 (sum=85)
# - Normalized: patient_id=26.5%, age=21.2%, weight_kg=21.2%, treatment_group=21.2%
# - Result sums to 100.1% (rounding), drift corrected to largest column
```

### Drift Correction

To ensure widths sum exactly to 100%, ksTFL applies drift correction:

- Rounds all widths to 1 decimal place
- Calculates total rounding error (drift)
- Adds/subtracts drift from the largest unlocked column

This guarantees valid output while maintaining proportions.

## Invisible Columns

### Making Columns Invisible

Use `isVisible = FALSE` to hide columns from output:

``` r
spec <- create_table(data) |>
  define_cols(id, isVisible = FALSE)

# Result:
# - id: hidden, width = "0.0cm" (automatic)
# - Other columns: recalculated to fill 100%
```

### Important Constraints

**You cannot set `colWidth` for invisible columns:**

``` r
# This will error:
spec <- create_table(data) |>
  define_cols(id, isVisible = FALSE, colWidth = "15%")
  
# Error message:
# "Cannot set colWidth for invisible column 'id'"
```

**Why?** Invisible columns are always “0.0cm”—setting a width would be
contradictory.

### Using Invisible Columns for Logic

Invisible columns are perfect for conditional formatting:

``` r
spec <- create_table(data) |>
  # Hide the flag column but keep data available
  define_cols(patient_id, isVisible = FALSE) |>
  # Use it in compute_cols() for conditional styling
  compute_cols(
    startsWith(patient_id, "PAT-001"),
    c_style(age, styleRef = "highlight_yellow")
  )
```

## Manual Width Management

### Disabling Auto-Recalculation

For complete manual control:

``` r
# Disable auto-recalculation
tfl_set_options(autoColWidth = FALSE)

# Set exact widths - no automatic adjustment
spec <- create_table(data) |>
  define_cols(
    c(id, patient_id, age, weight_kg, treatment_group),
    colWidth = c("10%", "25%", "20%", "20%", "25%")
  )

# Widths stay exactly as specified (sum = 100%)

# Re-enable for other tables
tfl_set_options(autoColWidth = TRUE)
```

### Why Use Manual Mode?

- **Precision**: When you need exact widths without rounding
- **Complex layouts**: Multi-level headers with specific alignments
- **Pre-calculated**: When you’ve determined optimal widths externally

## Validation and Constraints

### Minimum Width Thresholds

ksTFL enforces minimum widths to prevent unreadable columns:

**Relative widths (%):** - Minimum: 0.5%

**Absolute widths (cm, in, mm, pt):** - Minimum: 0.2cm (~0.08in)

``` r
# This will error:
spec <- create_table(data) |>
  define_cols(id, colWidth = "0.1%")  # Below 0.5% minimum
  
# Error: "Column width '0.1%' is below minimum allowed"
```

### Space Constraint Validation

ksTFL prevents you from locking widths that leave insufficient space for
other columns:

``` r
# 5 columns with minColWidth = 0.5% (default)
# Minimum space needed for 4 unlocked columns: 4 × 0.5% = 2%

# This will error:
spec <- create_table(data) |>
  define_cols(id, colWidth = "99%")  # Leaves only 1% for 4 columns
  
# Error: "Cannot set column 'id' to '99%'"
# "This would leave insufficient space for the remaining 4 unlocked columns"
# "Maximum allowed relative width for id: 98.0%"
```

### Adjusting Minimum Width

You can customize the minimum width threshold:

``` r
# Allow tighter columns (use with caution)
tfl_set_options(minColWidth = 0.3)

# Now you can use narrower relative widths
spec <- create_table(data) |>
  define_cols(id, colWidth = "95%")  # More space for this column

# Reset to default
tfl_set_options(minColWidth = 0.5)
```

## Common Patterns

### Pattern 1: ID Column + Auto Widths

``` r
spec <- create_table(data) |>
  define_cols(id, colWidth = "8%", isID = TRUE) |>
  define_cols(patient_id, colWidth = "15%")
  
# Result: ID columns fixed, others auto-distribute
```

### Pattern 2: Fixed-Width Text + Flex Numeric

``` r
spec <- create_table(data) |>
  define_cols(
    c(id, patient_id, treatment_group),
    colWidth = c("8%", "20%", "22%")
  )
  # age and weight_kg auto-fill remaining 50%
```

### Pattern 3: All Manual Widths

``` r
tfl_set_options(autoColWidth = FALSE)

spec <- create_table(data) |>
  define_cols(
    c(id, patient_id, age, weight_kg, treatment_group),
    colWidth = c("8%", "22%", "15%", "18%", "37%")
  )  # Sum = 100% exactly

tfl_set_options(autoColWidth = TRUE)
```

### Pattern 4: Progressive Locking

``` r
# Lock columns one at a time, observing effects
spec <- create_table(data)
print(spec)  # See initial distribution

spec <- spec |>
  define_cols(id, colWidth = "10%")
print(spec)  # See after first lock

spec <- spec |>
  define_cols(patient_id, colWidth = "20%")
print(spec)  # See after second lock
```

## Troubleshooting

### Issue: “Insufficient space for remaining columns”

**Cause:** Locked columns leave \< `minColWidth` % per unlocked column

**Solutions:** 1. Reduce the locked width you’re trying to set 2. Lower
`minColWidth` via `tfl_set_options(minColWidth = 0.3)` 3. Lock more
columns explicitly to reduce unlocked count 4. Make some columns
invisible to exclude them

### Issue: Widths don’t sum to exactly 100%

**Cause:** Rounding errors from drift correction

**Solution:** This is expected and handled automatically. Drift is
always ≤ 0.1% and applied to the largest column. The rendered output
will be correct.

### Issue: Can’t set width for invisible column

**Cause:** Trying to use `colWidth` with `isVisible = FALSE`

**Solution:** Remove `colWidth` parameter—invisible columns are always
“0.0cm”

### Issue: Widths change unexpectedly after define_cols()

**Cause:** Auto-recalculation triggered by locking a column

**Solution:** - This is expected behavior when `autoColWidth = TRUE` -
Disable with `tfl_set_options(autoColWidth = FALSE)` for manual
control - Or lock all columns explicitly

## Advanced: Width Metadata

> **Note**: `spec$.metadata` is an internal field. Its structure may
> change between package versions. Use `print(spec)` and
> [`define_cols()`](https://example.com/reference/define_cols.md) for
> all user-facing width inspection and control.

ksTFL stores width metadata internally in `spec$.metadata$colWidths`.
This is used by the package itself to: - Recalculate widths without
re-parsing width strings - Track which columns are locked vs. unlocked -
Preserve initial proportions for normalization

You do not need to read or write this field directly. Use `print(spec)`
to inspect current widths and `define_cols(spec, col, colWidth = ...)`
to modify them.

## Best Practices

1.  **Start with defaults**: Let ksTFL auto-detect widths initially
2.  **Lock strategically**: Fix only the columns that need exact widths
3.  **Use print()**: Inspect the spec after each
    [`define_cols()`](https://example.com/reference/define_cols.md) call
4.  **Test rendering**: Verify widths in actual output documents
5.  **Document intent**: Add comments explaining width choices
6.  **Use invisibility**: Hide helper columns instead of tiny widths

## Summary

- **Four states**: VISIBLE/LOCKED/UNLOCKED/INVISIBLE determine width
  behavior
- **Auto-recalculation**: Triggered when you lock widths (if enabled)
- **Validation**: Minimum thresholds and space constraints prevent
  errors
- **Flexibility**: Mix relative (%) and absolute (cm, in) units
- **Control**: Disable auto-recalculation for manual width management

For more examples, see:

- [Reporting
  Examples](https://example.com/articles/Reporting_Examples_with_ksTFL.Rmd)
  — complete end-to-end workflows including column width patterns
- [Getting
  Started](https://example.com/articles/Getting_Started_with_ksTFL.Rmd)
  — overview of the full pipeline
- [Advanced
  StyleRows](https://example.com/articles/Advanced_StyleRows.Rmd) —
  using invisible columns with
  [`compute_cols()`](https://example.com/reference/compute_cols.md) for
  conditional logic
