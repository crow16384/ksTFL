# Save TFL Report to JSON with Data Files

Serializes a TFL_report object to JSON format along with associated data
files (for tables) or figure files (for figures). Validates the report
structure, processes each specification by its docType, and writes all
outputs to disk.

## Usage

``` r
save_report(
  report,
  docFileName,
  outDir = NULL,
  metaPath = NULL,
  prettify = FALSE,
  insertTOC = NULL,
  tocTitle = NULL
)
```

## Arguments

- report:

  A TFL_report object (output from
  [`create_report()`](https://example.com/reference/create_report.md))

- docFileName:

  Character string. Name of the rendered document file that will be
  created by the C++ renderer (e.g., "report.docx"). This value is
  stored in the `_metadata/docFileName` property of the exported JSON
  spec.

- outDir:

  Character string. Output directory where the C++ renderer will save
  the rendered document. This path is stored in the `_metadata/outDir`
  property. If not provided, defaults to
  `tfl_get_option("output_directory")`.

- metaPath:

  Character string. Directory where this function will save the JSON
  spec and associated data files. If not provided, a temporary directory
  is created. Default:
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html)

- prettify:

  Logical. If TRUE, format JSON output with indentation and line breaks
  for readability. Default: FALSE (compact format)

- insertTOC:

  Logical. When `TRUE` the renderer prepends a Table of Contents page
  (using a `{ TOC \f \h \z }` field) before the first spec. Requires at
  least one [`add_title()`](https://example.com/reference/add_title.md)
  or [`add_subtitle()`](https://example.com/reference/add_subtitle.md)
  call with `toclevel` set. Defaults to the `insertTOC` package option
  (see
  [`tfl_set_options()`](https://example.com/reference/tfl_set_options.md)).
  Default `FALSE`.

- tocTitle:

  Character. Heading text placed above the TOC field on the TOC page.
  Defaults to the `tocTitle` package option (default
  `"Table of Contents"`). Set to `""` to omit the heading.

## Value

Invisibly returns a list with:

- `spec_file`: Name of the saved spec JSON file (hash-based filename)

- `datetime`: Timestamp when the report was saved (ISO 8601 format)

- `metaPath`: Directory where files were saved

## Details

The function performs the following steps:

1.  Validates input is a TFL_report object

2.  Serializes the report using `serialize_spec()` to validate against
    schema

3.  Processes each specification by docType:

4.  Text: Drops `.metadata` (no additional files needed)

5.  Table: Extracts data, filters to included columns, saves as JSON

6.  Figure: Copies image file with original extension preserved

7.  Creates `_metadata` section with `outDir` and `docFileName`

8.  Serializes the complete fixed object to JSON

9.  Returns information about saved files

Error Conditions:

- Report class is not TFL_report

- Table/Figure spec has `hasData=TRUE` but no actual data available

- dataRef has multiple entries (currently only single file references
  supported)

- File I/O errors when writing JSON or copying files

## Examples

``` r
if (FALSE) { # \dontrun{
spec1 <- create_table(mtcars)
spec2 <- create_text()
report <- create_report(spec1, spec2)

# Save with explicit parameters
result <- save_report(
  report,
  docFileName = "report.docx",
  outDir = "/output/path",
  metaPath = "/meta/path"
)

# Save with defaults (uses tempdir and tfl_options)
result <- save_report(report, docFileName = "report.docx")

cat("Spec saved as:", result$spec_file, "\n")
cat("Saved to:", result$metaPath, "\n")

# Generate a report with an auto-populated TOC page
t1 <- create_table(adsl) |>
  add_title("Table 1: Demographics", toclevel = 1) |>
  set_document(hasData = TRUE)

t2 <- create_table(advs) |>
  add_title("Table 2: Vital Signs by Visit", toclevel = 1) |>
  add_subtitle("#ByGroup1", toclevel = 2) |>
  set_document(hasData = TRUE)

report <- create_report(t1, t2)
save_report(
  report,
  docFileName  = "tables.docx",
  outDir       = "output/",
  insertTOC    = TRUE,
  tocTitle     = "List of Tables"
)
# Open tables.docx in Word, click the TOC placeholder, press F9 to populate it.
} # }
```
