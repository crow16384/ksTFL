# Save and Render a TFL Report to DOCX

Convenience wrapper around
[`save_report()`](https://example.com/reference/save_report.md) and the
internal DOCX renderer that saves a `TFL_report` object to JSON (plus
any required data/figure files) and immediately renders it to a DOCX
file in a single call.

## Usage

``` r
write_doc(
  report,
  name,
  outDir = tfl_get_option("output_directory"),
  metaPath = tfl_get_option("meta_directory") %||% tempdir(),
  prettify = FALSE,
  toc = tfl_get_option("insertTOC"),
  tocTitle = tfl_get_option("tocTitle"),
  overrideTemplate = NULL,
  font_dirs = NULL,
  fallback_font = NULL,
  verbose = FALSE
)
```

## Arguments

- report:

  A `TFL_report` object created by
  [`create_report()`](https://example.com/reference/create_report.md).

- name:

  Character(1). Base file name (without extension) for the output DOCX
  document. The `.docx` extension is appended automatically.

- outDir:

  Character(1). Directory where the final DOCX file will be written.
  Defaults to `tfl_get_option("output_directory")`.

- metaPath:

  Character(1). Directory where the intermediate specification JSON and
  associated data/figure files will be stored. Defaults to
  `tfl_get_option("meta_directory")`.

- prettify:

  Logical. When `TRUE`, pretty‑prints the JSON written by
  [`save_report()`](https://example.com/reference/save_report.md) for
  easier inspection. Default `FALSE` (compact JSON).

- toc:

  Logical. When `TRUE`, enables automatic insertion of a Table of
  Contents page via
  [`save_report()`](https://example.com/reference/save_report.md).
  Defaults to `tfl_get_option("insertTOC")`.

- tocTitle:

  Character(1). Heading placed above the TOC field on the TOC page.
  Defaults to `tfl_get_option("tocTitle")`.

- overrideTemplate:

  Optional character string. Global template override used by the
  internal renderer for all specs. Accepts either:

  - A predefined bundled template name (e.g. `"Navy_Pro"`).

  - A file path (absolute or relative) to an external template JSON
    file.

  If `NULL` (default), templates are resolved per-spec from each spec's
  `docTemplate` value (allowing mixed templates in multi-spec reports).
  If a provided name/path cannot be resolved, a warning is emitted and
  `CRO Example_default` is used.

- font_dirs:

  Optional character vector of additional directories to search for
  fonts during rendering.

- fallback_font:

  Optional character string. Path to a fallback font file used by the
  renderer. If `NULL`, the package default is used.

- verbose:

  Logical. If `TRUE`, prints renderer progress messages.

## Value

Invisibly returns the full path to the generated `.docx` file.

## Details

This mirrors the helper used in the example `inst/examples/init.R`
script (previously called `save_and_render()`), but is provided as a
public, documented API function named `write_doc()`.

## See also

[`create_report()`](https://example.com/reference/create_report.md),
[`save_report()`](https://example.com/reference/save_report.md),
[`replay_report()`](https://example.com/reference/replay_report.md),
[`tfl_set_options()`](https://example.com/reference/tfl_set_options.md),
[`tfl_get_option()`](https://example.com/reference/tfl_get_option.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic end-to-end workflow ----------------------------------------------
library(ksTFL)

# Create a simple table spec
tbl <- create_table(mtcars) |>
  add_title("Table 1: Motor Trend Car Road Tests") |>
  set_document(hasData = TRUE)

# Combine into a report
rpt <- create_report(tbl)

# Write DOCX to the default output directory (getwd() by default)
doc_path <- write_doc(
  report = rpt,
  name   = "mtcars_demo"
)

cat("DOCX written to:", doc_path, "\n")

# Custom output and meta directories, with TOC ---------------------------
tfl_set_options(
  output_directory = "output",
  insertTOC = TRUE,
  tocTitle  = "List of Tables"
)

rpt2 <- create_report(tbl)
write_doc(
  report   = rpt2,
  name     = "mtcars_with_toc",
  outDir   = "output",
  metaPath = file.path(tempdir(), "ksTFL_meta"),
  prettify = TRUE,
  toc      = TRUE
)
} # }
```
