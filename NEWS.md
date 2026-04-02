# ksTFL 0.10.1

## Fixes

* **Style deep-merge across `compute_cols()` blocks**: `.append_style_action()` no longer removes entire multi-column style actions when a later block partially overlaps columns; only the overlapping columns are surgically replaced, preserving styles on non-overlapping columns.
* **True recursive style merge**: `.merge_recursive()` now recurses into nested named sub-lists instead of performing a shallow `modifyList()` replace. Combining styles that share a top-level category (e.g. two styles both setting `font` properties) no longer silently drops properties from the first style.
* **Style application order preserved**: `._consolidate_styles_in_spec()` now merges styles in the order specified by the user (e.g. `f_combine("a", "b")` applies `a` first, then `b` wins) instead of sorting alphabetically.
* **`f_combine()` accepted in `c_style()`, `c_merge()`, `c_addrow()`**: `styleRef` parameters in row-action functions now accept multi-element style vectors produced by `f_combine()`.
* **`.combine_column_styles()` handles nested `f_combine()`**: replaced `do.call(f_combine, ...)` with direct `unlist()` + class assignment to correctly flatten style refs that already contain multi-element vectors.
* **`compute_cols()` accepts scalar `TRUE`/`FALSE`**: a scalar logical condition is now recycled to match `nrow(data)`, allowing `compute_cols(spec, TRUE, ...)` as shorthand for "all rows".
* **Missing `rlang::expr()` qualifier**: fixed unqualified `expr()` call in `.env_select()` that caused `could not find function "expr"` in clean R sessions.

# ksTFL 0.10.0

## New Features

* **Paragraph-level borders**: styles now support `<w:pBdr>` (paragraph borders) in addition to existing cell-level `<w:tcBorders>`. Paragraph borders underline only the text content within a cell, enabling visual gaps between spanning header groups without inserting dummy columns.
  - New `borders` parameter in `s_paragraph()` accepts a border spec built with `s_borders()` / `s_border()`.
  - C++ rendering engine emits `<w:pBdr>` elements in paragraph properties.
  - JSON schema (`styles_schema_v2.json`) updated to allow `borders` within paragraph definitions.
* New built-in atomic styles: `brw_thick` (4pt white right border), `blw_thick` (4pt white left border), `pb` (1pt paragraph bottom border), `pb_th` (0.5pt thin paragraph bottom border).

## Shiny Styles Editor

* Paragraph border controls (top, bottom, left, right) added to all text-style panels in the Shiny styles editor.

## Documentation

* Updated roxygen documentation for `s_paragraph()`, `s_borders()`, and `s_border()` to describe paragraph border usage.
* New "Paragraph-level borders" subsection and updated atom reference table in the Styling Guide vignette.
* New Example 3 (paragraph borders on spanning headers) in the Reporting Examples vignette.
* New Example 6 (spanning header gap technique) in the Real Examples vignette.

# ksTFL 0.9.0

## Build System

* HarfBuzz, FreeType, and minizip are now always compiled from vendored source during package installation, removing the runtime dependency on system `libharfbuzz`, `libfreetype`, and `libminizip` packages on Linux.
* The Linux build path now uses a committed vendored-source toolchain (`src/vendor/` plus `src/Makevars`) instead of `pkg-config` detection or optional system-library fallbacks.

## Documentation

* Updated installation instructions to remove the obsolete Linux runtime-package prerequisite step.
* Updated renderer architecture/build docs to describe vendored static compilation.

# ksTFL 0.8.0

## New Features

* Page settings (`p_page()` / `set_page_style()`) now support partial overrides — only explicitly specified fields override the template defaults, enabling lighter per-spec customisation.
* Per-column style mapping: character vector `style_refs` in `add_style()` now accepts a vector of length equal to the number of columns, with `NA` to skip individual columns.
* New `Listings_times` built-in template (Times New Roman variant of the Listings template).

## Fixes

* `add_header()` / `add_footer()` with `level` replacement now correctly returns the right `TFL_options_header` / `TFL_options_footer` class when used via `tfl_set_options()`.
* Default page settings changed from a fixed `A4 / portrait` override to `NULL`, so bare specs inherit all page properties from the active template without unintended overrides.

## Template Updates

* Refined font sizes, spacing, margins, and border widths across Carbon Dark, Classic (landscape/portrait), Default, and Listings templates.

## Documentation

* Added ksTFL cheat sheet (PDF and PowerPoint) to `inst/extdata`.

# ksTFL 0.7.9

## CI/CD

* Added CRAN-like repository structure for Linux binaries (Ubuntu and Fedora), enabling `install.packages()` from the release repo on Linux.
* Added Red Hat / Fedora binary build using a Fedora container in CI.
* GitHub Releases are now published to both the private and public (ksTFL-release) repositories.
* New manual workflow ("Upload Binary to Release Repo") for adding locally built packages (e.g., macOS) to the release repository.
* Added explicit pandoc setup to ensure vignettes build correctly on all platforms.
* Updated README installation instructions with per-platform sections.

# ksTFL 0.7.6

## Fixes

* Fixed inline markup paragraph handling so <p> produces real paragraph boundaries in emitted DOCX text groups (titles, subtitles, body text, footnotes), aligned with pagination measurement logic.
* Improved spacer-row border behavior: left/right borders are preserved through top/bottom empty spacer rows, while top/bottom lines remain suppressed as intended.

# ksTFL 0.7.5

## Documentation

* New vignette: "Real Examples with ksTFL" — five end-to-end clinical reporting examples (demographics table, UTF-8/multilingual table, AE spanning-header table, data listing with two-level TOC, and multi-figure combined report), each with embedded PDF output.
* Improved code comments and narrative descriptions across all example vignettes.
* Translated example scripts (`lb_lst_01_en.R`, `ae_tbl_exmpl.R`, `tmp_example.R`) from Russian to English.

# ksTFL 0.7.0

## New Features

* Added built-in style atoms for target font families: `font_arial`, `font_courier_new`, `font_times_new_roman`, `font_georgia`, `font_verdana`, and `font_trebuchet_ms`. These atoms set `font_name` only and are intended for composition with existing size, colour, alignment, and spacing atoms via `f_combine()`.

## Documentation

* Updated the styling and font-management articles to document target font family atoms and show how to combine them with other built-in style atoms.

