# ksTFL Package

Generate metadata for clinical Tables, Figures, and Listings (TFLs). You
build specs with
[`create_table()`](https://example.com/reference/create_table.md),
[`create_figure()`](https://example.com/reference/create_figure.md), or
[`create_text()`](https://example.com/reference/create_text.md), then
add titles, column definitions, styles, and options. Combine specs with
[`create_report()`](https://example.com/reference/create_report.md), and
render to DOCX with
[`write_doc()`](https://example.com/reference/write_doc.md) in one step.

## Details

**Typical workflow:** (1) Create one or more specs with
[`create_table()`](https://example.com/reference/create_table.md),
[`create_figure()`](https://example.com/reference/create_figure.md), or
[`create_text()`](https://example.com/reference/create_text.md). (2) Add
content and styling (e.g.
[`add_title()`](https://example.com/reference/add_title.md),
[`define_cols()`](https://example.com/reference/define_cols.md),
[`add_style()`](https://example.com/reference/add_style.md),
[`set_document()`](https://example.com/reference/set_document.md)). (3)
Combine specs with
[`create_report()`](https://example.com/reference/create_report.md). (4)
Render to DOCX with
[`write_doc()`](https://example.com/reference/write_doc.md)
(recommended). For JSON inspection, use
[`save_report()`](https://example.com/reference/save_report.md) and
[`replay_report()`](https://example.com/reference/replay_report.md).

To get started, see the vignettes:

- [`vignette("Getting_Started_with_ksTFL")`](https://example.com/articles/Getting_Started_with_ksTFL.md)
  — Quick start and full workflow overview

- [`vignette("Styling_Guide_with_ksTFL")`](https://example.com/articles/Styling_Guide_with_ksTFL.md)
  — Complete styling reference and built-in atoms

- [`vignette("Reporting_Examples_with_ksTFL")`](https://example.com/articles/Reporting_Examples_with_ksTFL.md)
  — Progressive real-world examples

- [`vignette("Advanced_StyleRows")`](https://example.com/articles/Advanced_StyleRows.md)
  — Conditional formatting with
  [`compute_cols()`](https://example.com/reference/compute_cols.md)

- [`vignette("Column_Width_Management")`](https://example.com/articles/Column_Width_Management.md)
  — Column width locking and auto-calculation

- [`vignette("Font_Management")`](https://example.com/articles/Font_Management.md)
  — System font discovery, fallbacks, and rescanning

- [`vignette("Rendering_Pipeline")`](https://example.com/articles/Rendering_Pipeline.md)
  — Full C++ renderer architecture and internals

## See also

Useful links:

- <https://crow16384.github.io/ksTFL-release/>

## Author

**Maintainer**: Igor Aleschenkov <igor.aleschenkov@gmail.com>
\[copyright holder\]

Authors:

- Vladimir Larchenko <crow16384@gmail.com> \[copyright holder\]
