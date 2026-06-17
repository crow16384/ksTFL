# FAQ and Practical Gotchas in ksTFL

![ksTFL logo](figures/ksTFL-logo.svg)

## Overview

This vignette collects short answers to the ksTFL questions that usually
appear after the first successful output: hidden helper columns, width
recalculation, span header levels, replay metadata, template precedence,
Table of Contents behavior, and practical
[`define_cols()`](https://crow16384.github.io/ksTFL-release/reference/define_cols.md)
/
[`compute_cols()`](https://crow16384.github.io/ksTFL-release/reference/compute_cols.md)
recipes.

It is intentionally practical:

- Audience: users who already built at least one spec and now need to
  debug or sharpen a workflow
- Focus: small but important behaviors that are easy to miss on a first
  read
- Outcome: faster diagnosis and cleaner report programs

When a source program is mentioned below, it refers to the corresponding
script under `inst/examples/showcase/`.

Related reading:

- [Getting
  Started](https://crow16384.github.io/ksTFL-release/articles/Getting_Started_with_ksTFL.md)
  for the core pipeline and object model
- [Reporting
  Examples](https://crow16384.github.io/ksTFL-release/articles/Reporting_Examples_with_ksTFL.md)
  for minimal end-to- end patterns
- [Real
  Examples](https://crow16384.github.io/ksTFL-release/articles/Real_Examples_with_ksTFL.md)
  for fuller clinical-style outputs
- [Advanced
  StyleRows](https://crow16384.github.io/ksTFL-release/articles/Advanced_StyleRows.md)
  for
  [`compute_cols()`](https://crow16384.github.io/ksTFL-release/reference/compute_cols.md)
  and row actions
- [Column Width
  Management](https://crow16384.github.io/ksTFL-release/articles/Column_Width_Management.md)
  for width locking and hidden-column rules
- [Font
  Management](https://crow16384.github.io/ksTFL-release/articles/Font_Management.md)
  for font discovery and fallback
- [Rendering
  Pipeline](https://crow16384.github.io/ksTFL-release/articles/Rendering_Pipeline.md)
  for renderer internals

------------------------------------------------------------------------

## Data and spec behavior

### 1. Why does `cols` not drop the other columns from my data?

Because `cols` is a presentation lens, not a data-mutation step. ksTFL
keeps the full input data inside the spec’s shadow data so later
[`compute_cols()`](https://crow16384.github.io/ksTFL-release/reference/compute_cols.md)
calls can still reference helper fields that never appear in the
document.

See also: [Getting
Started](https://crow16384.github.io/ksTFL-release/articles/Getting_Started_with_ksTFL.md),
[Reporting
Examples](https://crow16384.github.io/ksTFL-release/articles/Reporting_Examples_with_ksTFL.md),
`01_clinical_table_showcase.R`.

### 2. Can I hide a column and still use it in `compute_cols()`?

Yes. This is the standard helper-column pattern: set `isVisible = FALSE`
and keep using that column in conditions or `value_from` arguments. The
package examples do this with fields such as `SECTION`, `SECTION_ID`,
`MODELVAL`, and `SOC_GROUP`.

See also: [Real
Examples](https://crow16384.github.io/ksTFL-release/articles/Real_Examples_with_ksTFL.md),
[Advanced
StyleRows](https://crow16384.github.io/ksTFL-release/articles/Advanced_StyleRows.md),
`01_clinical_table_showcase.R`, `10_ae_template_ru_real_counts.R`.

### 3. Why can I not set `colWidth` on an invisible column?

Invisible columns are forced to width `"0.0cm"` and removed from width
recalculation entirely. If a column must reserve visual space, it is not
truly invisible and should stay visible.

See also: [Column Width
Management](https://crow16384.github.io/ksTFL-release/articles/Column_Width_Management.md),
[Getting
Started](https://crow16384.github.io/ksTFL-release/articles/Getting_Started_with_ksTFL.md).

### 4. Why did the other column widths change after I locked one column?

Setting `colWidth` locks those columns. With `autoColWidth = TRUE` (the
default), ksTFL re-normalizes the remaining visible unlocked columns so
they fill the leftover width.

See also: [Column Width
Management](https://crow16384.github.io/ksTFL-release/articles/Column_Width_Management.md),
`16_table_layout_options.R`.

### 5. Why did `c_glue()` not modify a repeated value?

If a cell was already suppressed by `dedupe = TRUE`,
[`c_glue()`](https://crow16384.github.io/ksTFL-release/reference/c_glue.md)
skips it on purpose. The same skip happens for non-leader cells inside a
merge, so glue the leader column or turn deduplication off for that
field.

See also: [Advanced
StyleRows](https://crow16384.github.io/ksTFL-release/articles/Advanced_StyleRows.md),
`02_listing_paging_colbreak.R`, `13_dm_table.R`.

------------------------------------------------------------------------

## Row actions and layout rules

### 6. Why does `compute_cols()` not like aggregate logic such as `mean(x)`?

[`compute_cols()`](https://crow16384.github.io/ksTFL-release/reference/compute_cols.md)
conditions are captured lazily and evaluated row-wise. If you need
section-level or whole-table aggregates, calculate them upstream or
write them into a helper column before creating the spec.

See also: [Advanced
StyleRows](https://crow16384.github.io/ksTFL-release/articles/Advanced_StyleRows.md),
[Real
Examples](https://crow16384.github.io/ksTFL-release/articles/Real_Examples_with_ksTFL.md).

### 7. Can I nest `c_*()` actions inside each other?

No. Row actions are siblings, not nested verbs. Either pass multiple
actions to one
[`compute_cols()`](https://crow16384.github.io/ksTFL-release/reference/compute_cols.md)
call or use several
[`compute_cols()`](https://crow16384.github.io/ksTFL-release/reference/compute_cols.md)
calls with the same condition.

See also: [Advanced
StyleRows](https://crow16384.github.io/ksTFL-release/articles/Advanced_StyleRows.md),
[Getting
Started](https://crow16384.github.io/ksTFL-release/articles/Getting_Started_with_ksTFL.md).

### 8. Why does every `add_span_header()` call create a new row of headers?

Because `stubOrder` auto-increments when you omit it. Reuse the same
`stubOrder` for sibling span headers that belong on one header row, and
only increase it when you really want a new level.

See also: [Getting
Started](https://crow16384.github.io/ksTFL-release/articles/Getting_Started_with_ksTFL.md),
[Real
Examples](https://crow16384.github.io/ksTFL-release/articles/Real_Examples_with_ksTFL.md),
`12_ae_table.R`.

### 9. Can span headers overlap?

Yes across different levels, no within the same level. Headers at the
same `stubOrder` must not share columns, but parent and child levels can
overlap freely.

See also: [Getting
Started](https://crow16384.github.io/ksTFL-release/articles/Getting_Started_with_ksTFL.md),
[Real
Examples](https://crow16384.github.io/ksTFL-release/articles/Real_Examples_with_ksTFL.md).

### 10. How do I keep a small table under a figure on the same page?

Set `continuousSection = TRUE` on the following spec, not the first one.
Keep page size and margins compatible across both sections, and use this
pattern for short follow-on content because Word still handles overflow
naturally.

See also: `03.1_table_under_figure.R`, `03_narrative_figure_table.R`.

### 11. When should I use `isGrouping`, `isPaging`, and `isColBreak`?

Use `isGrouping` when a value change defines a logical section,
`isPaging` when that value change should start a new vertical page
group, and `isColBreak` when a wide listing should split horizontally
into segments while repeating ID columns.

See also: [Real
Examples](https://crow16384.github.io/ksTFL-release/articles/Real_Examples_with_ksTFL.md),
[Rendering
Pipeline](https://crow16384.github.io/ksTFL-release/articles/Rendering_Pipeline.md),
`02_listing_paging_colbreak.R`.

### 12. Why do my footnotes repeat on every page?

That is the default: `footnotePlace = "repeated"`. Switch to
`"last_page"` when you want a final note block only, or `"doc_footer"`
when the note belongs in the Word footer area.

See also: [Getting
Started](https://crow16384.github.io/ksTFL-release/articles/Getting_Started_with_ksTFL.md),
[Real
Examples](https://crow16384.github.io/ksTFL-release/articles/Real_Examples_with_ksTFL.md).

------------------------------------------------------------------------

## Rendering, replay, and reproducibility

### 13. What is the practical difference between `write_doc()`,

[`save_report()`](https://crow16384.github.io/ksTFL-release/reference/save_report.md),
and
[`replay_report()`](https://crow16384.github.io/ksTFL-release/reference/replay_report.md)?

[`write_doc()`](https://crow16384.github.io/ksTFL-release/reference/write_doc.md)
is the one-step path for everyday use.
[`save_report()`](https://crow16384.github.io/ksTFL-release/reference/save_report.md)
writes the spec JSON plus table/figure payloads without rendering, while
[`replay_report()`](https://crow16384.github.io/ksTFL-release/reference/replay_report.md)
renders later from those saved artifacts and can also combine previously
saved outputs into one document.

See also: [Getting
Started](https://crow16384.github.io/ksTFL-release/articles/Getting_Started_with_ksTFL.md),
`04_meta_replay_clean.R`, `19_join_outputs_with_toc.R`.

### 14. When do I need a persistent `metaPath` instead of `tempdir()`?

Use [`tempdir()`](https://rdrr.io/r/base/tempfile.html) when you only
need the final DOCX right now. Use a persistent `metaPath` when you want
exact replays, QC comparison, report inventories, or a later combined
replay workflow.

If you replay by DOCX name, ksTFL resolves the latest saved spec in that
meta folder; if you need an exact historical version, replay by the
saved JSON file name instead.

See also: [Getting
Started](https://crow16384.github.io/ksTFL-release/articles/Getting_Started_with_ksTFL.md),
`04_meta_replay_clean.R`, `06_premium_qc_repro.R`.

### 15. Can I delete the original figure file after saving a report?

For replay-based workflows, yes after a successful save, because ksTFL
copies the figure into `metaPath` under its `dataRef`. The saved meta
folder becomes the durable rendering input.

See also: [Getting
Started](https://crow16384.github.io/ksTFL-release/articles/Getting_Started_with_ksTFL.md),
`14_figures.R`.

### 16. Why did different sections of one report use different templates?

That is the default behavior for multi-spec reports. Each spec resolves
its own `docTemplate`, so a table can use one bundled template while a
text or figure section uses another.

See also: [Getting
Started](https://crow16384.github.io/ksTFL-release/articles/Getting_Started_with_ksTFL.md),
`09_template_override_multi_spec.R`.

### 17. How do I force one template across every section?

Use `overrideTemplate` in
[`write_doc()`](https://crow16384.github.io/ksTFL-release/reference/write_doc.md)
or
[`replay_report()`](https://crow16384.github.io/ksTFL-release/reference/replay_report.md).
That global override wins over per-spec `docTemplate` values and is the
cleanest way to re-skin a finished bundle.

See also: `09_template_override_multi_spec.R`, `17_combined_replay.R`.

------------------------------------------------------------------------

## TOC and report assembly

### 18. Why does a Table of Contents not appear even though I asked for one?

You need both parts of the contract: request a TOC (`toc = TRUE`,
`insertTOC = TRUE`, or the package option) and mark at least one title
or subtitle with `toclevel`. A TOC request with no `toclevel` entries
has nothing to index.

See also: [Getting
Started](https://crow16384.github.io/ksTFL-release/articles/Getting_Started_with_ksTFL.md),
[Real
Examples](https://crow16384.github.io/ksTFL-release/articles/Real_Examples_with_ksTFL.md).

### 19. Why is the TOC still just a placeholder when I open the DOCX?

ksTFL writes a Word TOC field, not a pre-expanded static table. Open the
file in Word, click inside the TOC, and update fields with `F9` to
populate it.

See also: [Getting
Started](https://crow16384.github.io/ksTFL-release/articles/Getting_Started_with_ksTFL.md),
`19_join_outputs_with_toc.R`.

### 20. Can `create_report()` accept a named list of specs built in a loop?

Yes.
[`create_report()`](https://crow16384.github.io/ksTFL-release/reference/create_report.md)
accepts named lists of `TFL_spec` objects, which is useful when specs
are created dynamically or in separate program files. The list names
become the key prefixes inside the final `TFL_report`.

See also: `18_list_of_specs_bundle.R`, \[Reporting Examples\]
(Reporting_Examples_with_ksTFL.html).

------------------------------------------------------------------------

## Practical column and action recipes

These are short copy-paste patterns for the
[`define_cols()`](https://crow16384.github.io/ksTFL-release/reference/define_cols.md)
and
[`compute_cols()`](https://crow16384.github.io/ksTFL-release/reference/compute_cols.md)
cases that usually come up after the first working table.

### 21. How do I define several display columns in one place?

Use one
[`define_cols()`](https://crow16384.github.io/ksTFL-release/reference/define_cols.md)
call when the columns share the same labels, widths, or base value
styles.

``` r

spec <- create_table(adsl) |>
  define_cols(
    c(AGE, WEIGHT, HEIGHT),
    label = c("Age", "Weight\n(kg)", "Height\n(cm)"),
    colWidth = c("12%", "14%", "14%"),
    valueStyleRef = c("ar", "ar", "ar")
  )
```

This keeps aligned numeric columns easy to maintain.

### 22. How do I use `NA` to skip one column inside a batch `define_cols()` call?

Use `NA` at the position you want to leave unchanged. This is handy when
most columns share one update but one column should keep its existing
definition.

``` r

spec <- create_table(adsl) |>
  define_cols(
    c(USUBJID, AGE, TRT01A),
    label = c("Subject ID", NA, "Treatment"),
    colWidth = c("18%", NA, "20%"),
    valueStyleRef = c("mono", "ar", NA)
  )
```

Here `AGE` keeps its current label and width, and `TRT01A` keeps its
current value style. This also works well with hidden helper columns
when you want to skip `colWidth` because invisible columns are forced to
`"0.0cm"`.

### 23. How do I hide a helper column but still use it to drive formatting?

Hide the helper with `isVisible = FALSE`, then refer to it in
[`compute_cols()`](https://crow16384.github.io/ksTFL-release/reference/compute_cols.md)
as usual.

``` r

spec <- create_table(df) |>
  define_cols(FLAG, isVisible = FALSE) |>
  define_cols(c(PARAM, VALUE), label = c("Parameter", "Value")) |>
  add_style("flagged", s_font(color = "#8B0000", bold = TRUE)) |>
  compute_cols(
    FLAG == "Y",
    c_style(c(PARAM, VALUE), styleRef = "flagged")
  )
```

This is the standard pattern for QC flags, section ids, and hidden
totals.

### 24. How do I turn a hidden grouping column into a stub header?

Use
[`c_addrow()`](https://crow16384.github.io/ksTFL-release/reference/c_addrow.md)
on the first row of each group and pull the display text from the hidden
column.

``` r

spec <- create_table(df) |>
  add_style(
    "section_header",
    s_font(bold = TRUE, color = "#FFFFFF"),
    s_table_style(background_color = "#4682B4")
  ) |>
  define_cols(REGION, isVisible = FALSE) |>
  define_cols(c(PRODUCT, REVENUE), label = c("Product", "Revenue")) |>
  compute_cols(
    firstOf(REGION),
    c_addrow(
      pos = "above",
      value_from = REGION,
      styleRef = "section_header"
    )
  )
```

This is usually cleaner than repeating the region on every detail row.

### 25. How do I insert subtotals from a hidden total column?

Precompute the subtotal upstream, hide that helper column, and insert it
on the last row of each group.

``` r

spec <- create_table(df) |>
  add_style(
    "subtotal_row",
    s_font(bold = TRUE),
    s_table_style(background_color = "#D9D9D9")
  ) |>
  define_cols(TOTAL, isVisible = FALSE) |>
  compute_cols(
    lastOf(REGION),
    c_addrow(
      pos = "below",
      value_from = TOTAL,
      styleRef = f_combine("subtotal_row", "ar")
    )
  )
```

This works well when the display row is just a formatted version of
stored summary text.

### 26. How do I apply one condition to several visible columns at once?

Pass a column vector to
[`c_style()`](https://crow16384.github.io/ksTFL-release/reference/c_style.md)
instead of repeating the same condition in separate calls.

``` r

spec <- create_table(labs) |>
  add_style("out_of_range", s_font(color = "#FF4500", bold = TRUE)) |>
  compute_cols(
    VISIT == "Week 8" & AVAL > AVAL_ULN,
    c_style(c(PARAM, AVAL, UNIT), styleRef = "out_of_range")
  )
```

Use this when the flag belongs to the row but only a few columns should
show it.

### 27. How do I combine font and background styles for one rule?

Compose styles with
[`f_combine()`](https://crow16384.github.io/ksTFL-release/reference/f_combine.md)
instead of defining a new style for every font-plus-fill pairing.

``` r

spec <- create_table(df) |>
  add_style(
    "warn_bg",
    s_table_style(background_color = "#FFF4E5")
  ) |>
  compute_cols(
    CRITFL == "Y",
    c_style(c(PARAM, VALUE), styleRef = f_combine("b", "warn_bg"))
  )
```

This is a good fit for one-off emphasis rules.

### 28. How do I give columns a base style and still add row-level

highlighting later?

Put default alignment or indentation in
[`define_cols()`](https://crow16384.github.io/ksTFL-release/reference/define_cols.md),
then add the conditional layer in
[`compute_cols()`](https://crow16384.github.io/ksTFL-release/reference/compute_cols.md).

``` r

spec <- create_table(df) |>
  add_style(
    "warn_row",
    s_table_style(background_color = "#FFF4E5")
  ) |>
  define_cols(PARAM, valueStyleRef = "indent_1") |>
  define_cols(VALUE, valueStyleRef = "ar") |>
  compute_cols(
    FLAG == "Y",
    c_style(everything(), styleRef = "warn_row")
  )
```

The base column styles stay in place; the row style adds on top.

### 29. How do I build a total line by combining `c_merge()`, `c_clear()`,

and
[`c_glue()`](https://crow16384.github.io/ksTFL-release/reference/c_glue.md)?

Use one
[`compute_cols()`](https://crow16384.github.io/ksTFL-release/reference/compute_cols.md)
call when the same rows need several sibling actions.

``` r

spec <- create_table(df) |>
  compute_cols(
    PRODUCT == "TOTAL",
    c_merge(c(PRODUCT, REVENUE), styleRef = f_combine("b", "ar")),
    c_clear(PRODUCT),
    c_glue(PRODUCT, "after", REGION),
    c_glue(PRODUCT, "after", text = " total: "),
    c_glue(PRODUCT, "after", REVENUE)
  )
```

This is useful when the display string does not exist as one input
column.

### 30. How do I apply more than one action to the same condition without

nested `c_*()` calls?

Keep the actions as separate arguments inside one
[`compute_cols()`](https://crow16384.github.io/ksTFL-release/reference/compute_cols.md)
call.

``` r

spec <- create_table(df) |>
  add_style("boundary", s_font(bold = TRUE)) |>
  compute_cols(
    firstOf(GROUP),
    c_addrow(pos = "above", value_from = GROUP, styleRef = "boundary"),
    c_style(c(PARAM, VALUE), styleRef = "boundary")
  )
```

Row actions are siblings, not nested verbs.

### 31. How do I build a two-level stub with one hidden column and two style

rules?

Insert the group header from the hidden column, then use separate style
rules for summary rows and detail rows.

``` r

spec <- create_table(df) |>
  define_cols(REGION, isVisible = FALSE) |>
  define_cols(c(PRODUCT, REVENUE), label = c("Product", "Revenue")) |>
  compute_cols(
    firstOf(REGION),
    c_addrow(pos = "above", value_from = REGION, styleRef = "b")
  ) |>
  compute_cols(
    PRODUCT == "TOTAL",
    c_style(PRODUCT, styleRef = f_combine("i", "indent_1")),
    c_style(REVENUE, styleRef = "i")
  ) |>
  compute_cols(
    PRODUCT != "TOTAL",
    c_style(PRODUCT, styleRef = "indent_2")
  )
```

That pattern is handy when the output stub needs visible hierarchy even
though the source data is still flat.
