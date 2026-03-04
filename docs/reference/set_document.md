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
  docTemplate = NULL
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

- docTemplate:

  Character. Template to use for rendering. Accepts either:

  - Name of a bundled template (see
    [`tfl_list_templates()`](https://example.com/reference/tfl_list_templates.md)).

  - Full path to a custom styles JSON file.

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
