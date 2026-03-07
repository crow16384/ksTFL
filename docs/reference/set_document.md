# Set document properties

Define document-level properties. Multiple calls merge with last-win
strategy. Document type (`docType`) is set automatically by
[`create_table()`](https://example.com/reference/create_table.md),
[`create_figure()`](https://example.com/reference/create_figure.md), or
[`create_text()`](https://example.com/reference/create_text.md) and
cannot be changed here. Global document order (`docOrder`) is assigned
by [`create_report()`](https://example.com/reference/create_report.md).
`docPrefix` is not an argument of `set_document()` in the current API.

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

  Whether page breaks should be ignored

- contentWidth:

  Width of content, e.g. "100%", "25cm", "10in"

- footnotePlace:

  Character; controls where footnotes are rendered. One of
  `"doc_footer"` (place inside the Word footer, below footer rows),
  `"repeated"` (place under the table on every page), or `"last_page"`
  (place under the table on the last page only). Default `"repeated"`.

- hasData:

  Whether document has data to report

- topEmptyLine:

  Empty spacer row height after table header (table-level), e.g. "6pt".
  Use NULL to disable. `0pt` is treated as no spacer row.

- bottomEmptyLine:

  Empty spacer row height before table bottom border (table-level), e.g.
  "6pt". Use NULL to disable. `0pt` is treated as no spacer row.

- docTemplate:

  Character. Template to use for rendering. Accepts either:

  - Name of a bundled template (see
    [`tfl_list_templates()`](https://example.com/reference/tfl_list_templates.md)).

  - Full path to a custom styles JSON file.

- figureWidth:

  Character or `NULL`. Figure width (for example `"6in"`, `"15cm"`, or
  `"70%"`). Applied when figure scale mode is fixed.

- figureHeight:

  Character or `NULL`. Figure height (for example `"4in"`, `"10cm"`, or
  `"50%"`). Applied when figure scale mode is fixed.

- figureDevice:

  Character or `NULL`. Default output format for ggplot-based figures.
  One of `"png"`, `"jpeg"`, `"jpg"`, or `"svg"`.

- figureScaleMode:

  Character or `NULL`. Figure sizing mode. One of `"fixed"`,
  `"fitWidth"`, or `"fitPage"`.

## Value

Updated spec object

## Examples

``` r
if (FALSE) { # \dontrun{
spec <- create_text() |>
  set_document(
    hasData = TRUE
  )
} # }
```
