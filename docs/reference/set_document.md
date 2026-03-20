# Set document properties

Define document-level properties. Multiple calls merge with last-win
strategy. Document type (`docType`) is set automatically by
[`create_table()`](https://example.com/reference/create_table.md),
[`create_figure()`](https://example.com/reference/create_figure.md), or
[`create_text()`](https://example.com/reference/create_text.md) and
cannot be changed here. Global document order (`docOrder`) is assigned
by [`create_report()`](https://example.com/reference/create_report.md).

## Usage

``` r
set_document(
  spec,
  isContinues = NULL,
  contentWidth = NULL,
  footnotePlace = NULL,
  hasData = NULL,
  topEmptyLine = NULL,
  bottomEmptyLine = NULL,
  docTemplate = NULL,
  figureWidth = NULL,
  figureHeight = NULL,
  figureDevice = NULL,
  figureScaleMode = NULL
)
```

## Arguments

- spec:

  TFL spec object

- isContinues:

  Logical. When `TRUE`, page breaks between specs in a multi-spec report
  are suppressed and the next spec continues on the same page.

- contentWidth:

  Width of content, e.g. `"100%"`, `"25cm"`, `"10in"`.

- footnotePlace:

  Character; controls where footnotes are rendered. One of
  `"doc_footer"` (place inside the Word footer, below footer rows),
  `"repeated"` (place under the table on every page), or `"last_page"`
  (place under the table on the last page only). Default `"repeated"`.

- hasData:

  Logical. Whether this spec has data to render. Set to `TRUE` for
  tables with data rows. When `FALSE`, the body text (if any) is
  rendered instead.

- topEmptyLine:

  Empty spacer row height after table header (table-level), e.g.
  `"6pt"`. Use `NULL` to disable. `"0pt"` is treated as no spacer row.

- bottomEmptyLine:

  Empty spacer row height before table bottom border (table-level), e.g.
  `"6pt"`. Use `NULL` to disable.

- docTemplate:

  Character. Template to use for rendering. Accepts either:

  - Name of a bundled template (see
    [`tfl_list_templates()`](https://example.com/reference/tfl_list_templates.md)).

  - Full path to a custom styles JSON file.

- figureWidth:

  Figure width with units, e.g. `"6in"`, `"70%"`, `"16.51cm"`. Only
  relevant for `docType = "Figure"`.

- figureHeight:

  Figure height with units. Same syntax as `figureWidth`.

- figureDevice:

  Character. Image format for ggplot2 rendering. One of `"svg"`,
  `"png"`, or `"jpeg"`.

- figureScaleMode:

  Character. How the figure is scaled in the DOCX. One of `"fixed"`
  (exact dimensions) or `"fitWidth"` (scale to page width, preserving
  aspect ratio).

## Value

Updated spec object

## Examples

``` r
if (FALSE) { # \dontrun{
# Table spec with data
spec <- create_table(mtcars) |>
  set_document(hasData = TRUE)

# Text spec for narrative-only output
spec <- create_text() |>
  set_document(hasData = FALSE) |>
  add_body_text("No adverse events were reported.")

# Figure spec with custom sizing
spec <- create_figure("plot.png") |>
  set_document(
    figureWidth  = "7in",
    figureHeight = "5in",
    figureScaleMode = "fitWidth"
  )

# Footnotes placed on last page only
spec <- create_table(mtcars) |>
  set_document(hasData = TRUE, footnotePlace = "last_page") |>
  add_footnote("Source: Motor Trend, 1974.")

# Use a bundled template (see tfl_list_templates() for available names)
spec <- create_table(mtcars) |>
  set_document(hasData = TRUE, docTemplate = "Navy_Pro")
} # }
```
