# Print method for TFL specification objects

Provides a comprehensive, human-readable overview of a TFL specification
object with formatted tables, colors, and legends. Shows document
metadata, columns with types and formats, titles, headers, footers, and
sample data.

## Usage

``` r
# S3 method for class 'TFL_spec'
print(
  x,
  layout = c("full", "compact"),
  width = getOption("width", 80L),
  colors = TRUE,
  ...
)
```

## Arguments

- x:

  A `TFL_spec` object (required). The specification to print.

- layout:

  Display mode as a character string:

  - `"compact"`: Brief overview (default)

  - `"full"`: Detailed view with all sections

- width:

  Integer. Terminal width for text wrapping (default: from
  `getOption("width", 80L)`). Used to calculate column widths and text
  truncation.

- colors:

  Logical. If `TRUE` (default), uses ANSI color codes for visual
  distinction (section headers in cyan/yellow/green, column names in
  blue). If `FALSE`, plain text.

- ...:

  Additional arguments passed to print methods (ignored).

## Value

The spec object (invisibly). This allows print to be called on a spec
object for side effects while preserving the spec in piped workflows.

## Details

The full layout displays:

- Document type and data availability

- Summary counts (columns, titles, headers, footers, etc.)

- Page settings (size, orientation)

- Headers and footers content

- Titles, subtitles, and footnotes

- Column metadata table (Name, Label, Type, Format, Missings, Width,
  Flags, Styles)

- Flag legend explaining special column properties

- Body text content

- Sample data (first 3 rows)

**Flags Legend:**

- `*` = ID column (primary identifier)

- `x` = Hidden column (not visible in output)

- `#` = Grouping column (used for grouping rows)

- `>` = Page break (trigger page break)

- `v` = Column break (trigger column break)

- `d` = Deduplicate (remove duplicate values)

- `_` = Blank after (insert blank row after value change)

## Examples

``` r
if (FALSE) { # \dontrun{
data <- data.frame(id = 1:10, age = rnorm(10, 45, 10), group = rep(c("A", "B"), 5))
spec <- create_table(data) |>
  add_title("Motor Trend Study") |>
  add_subtitle("Vehicle Performance Analysis") |>
  add_header("ABC Research", "Confidential", "2024") |>
  add_footnote("Source: mtcars dataset")

# Print with full details (calls print.TFL_spec)
print(spec)

# Compact view
print(spec, layout = "compact")

# Without colors
print(spec, colors = FALSE)
} # }
```
