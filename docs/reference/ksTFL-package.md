# ksTFL Package

Generate metadata for clinical Tables, Figures, and Listings (TFLs). You
build specs with
[`create_table()`](https://crow16384.github.io/ksTFL-release/reference/create_table.md),
[`create_figure()`](https://crow16384.github.io/ksTFL-release/reference/create_figure.md),
or
[`create_text()`](https://crow16384.github.io/ksTFL-release/reference/create_text.md),
then add titles, column definitions, styles, and options. Combine specs
with
[`create_report()`](https://crow16384.github.io/ksTFL-release/reference/create_report.md),
and render to DOCX with
[`write_doc()`](https://crow16384.github.io/ksTFL-release/reference/write_doc.md)
in one step.

## Details

**Typical workflow:** (1) Create one or more specs with
[`create_table()`](https://crow16384.github.io/ksTFL-release/reference/create_table.md),
[`create_figure()`](https://crow16384.github.io/ksTFL-release/reference/create_figure.md),
or
[`create_text()`](https://crow16384.github.io/ksTFL-release/reference/create_text.md).
(2) Add content and styling (e.g.
[`add_title()`](https://crow16384.github.io/ksTFL-release/reference/add_title.md),
[`define_cols()`](https://crow16384.github.io/ksTFL-release/reference/define_cols.md),
[`add_style()`](https://crow16384.github.io/ksTFL-release/reference/add_style.md),
[`set_document()`](https://crow16384.github.io/ksTFL-release/reference/set_document.md)).
(3) Combine specs with
[`create_report()`](https://crow16384.github.io/ksTFL-release/reference/create_report.md).
(4) Render to DOCX with
[`write_doc()`](https://crow16384.github.io/ksTFL-release/reference/write_doc.md)
(recommended). For JSON inspection, use
[`save_report()`](https://crow16384.github.io/ksTFL-release/reference/save_report.md)
and
[`replay_report()`](https://crow16384.github.io/ksTFL-release/reference/replay_report.md).

To get started, see the vignettes:

- [`vignette("Getting_Started_with_ksTFL")`](https://crow16384.github.io/ksTFL-release/articles/Getting_Started_with_ksTFL.md)
  — Quick start and full workflow overview

- [`vignette("Styling_Guide_with_ksTFL")`](https://crow16384.github.io/ksTFL-release/articles/Styling_Guide_with_ksTFL.md)
  — Complete styling reference and built-in atoms

- [`vignette("Reporting_Examples_with_ksTFL")`](https://crow16384.github.io/ksTFL-release/articles/Reporting_Examples_with_ksTFL.md)
  — Progressive real-world examples

- [`vignette("Advanced_StyleRows")`](https://crow16384.github.io/ksTFL-release/articles/Advanced_StyleRows.md)
  — Conditional formatting with
  [`compute_cols()`](https://crow16384.github.io/ksTFL-release/reference/compute_cols.md)

- [`vignette("Column_Width_Management")`](https://crow16384.github.io/ksTFL-release/articles/Column_Width_Management.md)
  — Column width locking and auto-calculation

- [`vignette("Font_Management")`](https://crow16384.github.io/ksTFL-release/articles/Font_Management.md)
  — System font discovery, fallbacks, and rescanning

- [`vignette("Rendering_Pipeline")`](https://crow16384.github.io/ksTFL-release/articles/Rendering_Pipeline.md)
  — Full C++ renderer architecture and internals

## See also

Useful links:

- <https://crow16384.github.io/ksTFL-release/>

- <https://github.com/crow16384/ksTFL>

- Report bugs at <https://github.com/crow16384/ksTFL/issues>

## Author

**Maintainer**: Igor Aleschenkov <igor.aleschenkov@gmail.com>
\[copyright holder\]

Authors:

- Igor Aleschenkov <igor.aleschenkov@gmail.com> \[copyright holder\]

- Vladimir Larchenko <crow16384@gmail.com> \[copyright holder\]
