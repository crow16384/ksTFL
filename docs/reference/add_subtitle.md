# Add a subtitle

Add a subtitle to the specification. Multiple calls add multiple
subtitle groups. Calling with the same ID merges with last-win strategy.

## Usage

``` r
add_subtitle(
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

  Character vector of subtitle text lines. May contain `#ByGroup1`,
  `#ByGroup2`, … placeholders that are replaced at render time with the
  current value of the first, second, … grouping/paging column on each
  page.

- id:

  Subtitle identifier (auto-generated if `NULL`).

- styleRef:

  Character vector of style names to apply. Styles are merged with
  last-win strategy.

- order:

  Integer ordering key (auto-assigned if `NULL`).

- toclevel:

  Optional integer 1–9. When set, this subtitle is marked as a Table of
  Contents entry at the given level.

  **Static subtitles** (no `#ByGroupX` placeholders): the TC entry is
  emitted only on the **first page** of the spec, producing a single TOC
  entry.

  **Dynamic subtitles** (containing `#ByGroupX`): a TC entry is emitted
  on **every page**, so each distinct group value gets its own TOC
  entry. The resolved (substituted) text is used as the TOC entry text.

  In both cases, multi-line subtitles are concatenated with a space and
  inline styling tags are stripped for the TOC entry text. Use together
  with `add_title(toclevel = )` and `tfl_set_options(insertTOC = TRUE)`
  or `save_report(insertTOC = TRUE)`.

## Value

Updated spec object.

## Examples

``` r
if (FALSE) { # \dontrun{
# Static subtitle — one TOC entry for the whole report
spec <- create_table(adsl) |>
  add_title("Table 1: Demographics", toclevel = 1) |>
  add_subtitle("Safety Analysis Set", toclevel = 2) |>
  add_subtitle("Data Cutoff: 2025-12-14")

# Dynamic subtitle — one TOC entry per group value (e.g. one per visit)
spec <- create_table(advs) |>
  add_title("Table 2: Vital Signs by Visit and Parameter", toclevel = 1) |>
  add_subtitle("#ByGroup1 - #ByGroup2", toclevel = 2)

# Generate the TOC page
report <- create_report(spec)
save_report(report, docFileName = "tables.docx", insertTOC = TRUE)
# Open tables.docx in Word, click the TOC placeholder, press F9 to update.
} # }
```
