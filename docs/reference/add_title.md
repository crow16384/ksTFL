# Add a title

Add a title to the specification. Multiple calls add multiple title
groups. Calling with the same ID merges with last-win strategy.

## Usage

``` r
add_title(
  spec,
  text,
  id = NULL,
  styleRef = NULL,
  order = NULL,
  toclevel = NULL
)
```

## Arguments

- spec:

  TFL spec object.

- text:

  Character vector of title text lines. Multiple elements are rendered
  as separate lines within the same title paragraph.

- id:

  Title identifier (auto-generated if `NULL`).

- styleRef:

  Character vector of style names to apply. Styles are merged with
  last-win strategy.

- order:

  Integer ordering key (auto-assigned if `NULL`).

- toclevel:

  Optional integer 1–9. When set, the **first page** occurrence of this
  title is marked as a Table of Contents entry at the given level.
  Multi-line titles are concatenated with a space for the TOC entry
  text; inline styling tags (e.g. `<b>`, `<i>`) are stripped
  automatically.

  To generate a TOC page, set `toclevel` here and either call
  `tfl_set_options(insertTOC = TRUE)` for the whole session or pass
  `insertTOC = TRUE` to
  [`save_report()`](https://example.com/reference/save_report.md). The
  renderer will prepend a "Table of Contents" page with a
  `{ TOC \f \h \z }` field. Open the generated document in Word, click
  inside the TOC area, and press **F9** to populate it.

## Value

Updated spec object.

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic multi-line title (no TOC)
spec <- create_table(adsl) |>
  add_title(c("Study ABC-123", "Table 1: Demographics")) |>
  add_title("Full Analysis Set", styleRef = "subtitle_style")

# Title marked for TOC at level 1 — renderer will emit a TC field on the first page
spec <- create_table(adsl) |>
  add_title("Table 1: Demographics", toclevel = 1)

# Full TOC workflow across a multi-spec report
t1 <- create_table(adsl) |>
  add_title("Table 1: Demographics", toclevel = 1) |>
  set_document(hasData = TRUE)

t2 <- create_table(advs) |>
  add_title("Table 2: Vital Signs", toclevel = 1) |>
  set_document(hasData = TRUE)

report <- create_report(t1, t2)
save_report(report, docFileName = "tables.docx", insertTOC = TRUE)
# Open tables.docx in Word, click the TOC placeholder, press F9 to update.
} # }
```
