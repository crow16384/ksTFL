# Table page control map

This diagram shows the full control flow for a rendered `Table` document and maps each visible region to the ksTFL function or action that controls it.

![ksTFL table page control map](../vignettes/images/table-page-control-map-v3.svg)

## Reading the diagram

- The left panel is the R-side metadata layer: full data, column definitions, text groups, styles, and defaults.
- The middle panel is the internal renderer-preparation layer created by `create_report()`: logical rows, evaluated `compute_cols()` actions, and visibility-aware transformations.
- The right panel is the final DOCX-facing output layer: running header/footer, title/subtitle bands, visible table grid, footnotes, and the no-data body-text route.

- Page header and page footer are controlled by `add_header()` and `add_footer()`. These render into the Word header/footer parts, not into the table body.
- Title and subtitle bands are controlled by `add_title()` and `add_subtitle()`. `set_document(isContinues = TRUE)` suppresses repeated titles on later pages.
- Column labels are controlled by `define_cols(label=..., labelStyleRef=...)`.
- Spanning header rows above the column labels are controlled by `add_span_header()`.
- Column visibility, widths, ID repetition, grouping, paging, deduping, and horizontal splits are configured through `define_cols()`.
- Conditional body modifications are controlled by `compute_cols()` with `c_style()`, `c_merge()`, `c_addrow()`, `c_glue()`, `c_clear()`, and `c_pageBreak()`.
- Footnotes are added with `add_footnote()` and placed with `set_document(footnotePlace = "repeated" | "last_page" | "doc_footer")`.
- If a table has no data to render, `add_body_text()` replaces the table completely rather than appearing inside a visible empty grid.

## Important renderer behaviors

- Hidden columns still remain available to grouping, paging, and `c_glue(glue_col = ...)`; they are removed only from visible output.
- `c_merge()` excludes hidden columns from the visible span, but if the first merge column is hidden its value is moved into the first visible merge leader.
- `c_clear()` runs before merge and glue in the row-action pipeline, so a later `c_glue()` can replace the cleared content.
- `isColBreak = TRUE` starts a new horizontal segment, and `isID = TRUE` repeats those ID columns in every segment.
- `styleRef` values do not change output directly until they are defined by `add_style()` and resolved through the selected template from `set_page_style()` or session defaults.
- Session-wide defaults from `tfl_set_options()` are copied into each new spec during initialization and can then be overridden per spec.
- `create_report()` is the report-build stage that materializes style combinations and `styleRows`; it is not itself a visible page-region control.