# ksTFL 0.5.4

## New Features

* Added inline strikethrough support via `<s>...</s>` in the C++ renderer, including OOXML emission (`<w:strike/>`), JSON parsing, and style API support (`s_font(strikethrough = ...)`).
* `replay_report()` now supports `overrideTemplate` (bundled template name or custom JSON path), matching `write_doc()` behavior.
* Combined replay Shiny app now supports both predefined template selection and custom template JSON paths.

## Improvements

* `list_reports()`, `replay_report()`, and `clean_reports()` now default `meta_dir` to `tfl_get_option("meta_directory")`.
* `write_doc()` now safely falls back to `tempdir()` when `meta_directory` is not configured.
* Improved Aptos font resolution in the font cache (`Aptos.ttf` regular face lookup).

## Bug Fixes

* Functions that rely on meta artifacts now raise a clear error when neither `meta_dir` argument nor `meta_directory` option is set.

# ksTFL 0.5.3

## New Features

* `replay_report()` now supports replaying multiple reports into one combined DOCX.
* Added `run_replay_app()` and a new replay Shiny app for selecting reports across multiple meta folders, drag-and-drop reordering, and combined rendering.
* Added an RStudio addin entry for the replay app.

## Improvements

* Added optional `data_dir` handling in `render_docx()` to support robust replay of specs from different meta directories.
* Replay app now supports folder browsing for both input meta directories and output directory selection.

## Bug Fixes

* Fixed latest-spec selection logic in `.resolve_spec_path()` when datetimes are character values.
* Fixed merged replay `dataRef` serialization so C++ receives JSON arrays (restores table data loading in combined replay).
* Improved replay resource resolution for figure assets (`.png`, `.jpg`, `.jpeg`, `.svg`).

# ksTFL 0.5.0

## C++20 Modernization

* Adopted `operator<=>` (three-way comparison) for `Length`, replacing 6 hand-written comparison operators.
* Introduced `Mergeable` concept constraining style merge templates.
* Replaced runtime `std::unordered_map` lookup tables with `constexpr std::array` for OOXML enum conversions.
* Added `[[nodiscard]]` attributes to all pure/value-returning functions across headers.
* Converted `std::sort`, `std::any_of`, and `std::transform` calls to `std::ranges` equivalents.
* Used `using enum` in switch statements for `TagType` and `FootnotePlace`.
* Replaced `std::snprintf(buf, "%.17g", ...)` with `std::to_chars()` for double formatting.

## Performance Improvements

* Font directory indexing: `add_font_dir()` now scans once and builds an `O(1)` lookup map. Previously, `find_font_file()` did a recursive directory walk on every call.
* Replaced `std::regex` in `is_safe_numeric_format()` with a single-pass manual parser, eliminating regex overhead in the per-cell formatting hot path.
* Pre-computed column index map (`col_id_to_idx`) once in `LogicalTableBuilder::build()` and passed to both `build_header_grid()` and `apply_style_rows()`, avoiding redundant map construction.
* Short-circuit `parse_inline_markup()`: skip `has_inline_markup()` tag classification when the input contains no `<` character.

## Bug Fixes

* Fixed ODR violation: `font_map` in `font_cache.h` changed from `static const` to `inline const`.
* Eliminated `goto` in logical table post-pass, replaced with structured `break`.

## Code Quality

* Extracted `restore_dedupe_at_page_boundaries()` as a free function from the 500-line `render_from_strings()` method.
* Unified three content style resolvers (`resolve_title_style`, `resolve_subtitle_style`, `resolve_footnote_style`) into a shared `resolve_content_style()` method.
* Unified row height computation via `compute_row_heights_impl<WidthFn, FilterFn>()` template.
* Consolidated margin parsing with `parse_margins_fields<T>()` template.
* Consolidated alignment parsing to use existing `parse_alignment()` throughout.
* Translated remaining Russian comments to English.

## Tests

* Added 31 new C++ unit tests for the `is_safe_numeric_format()` manual parser covering valid formats, invalid specifiers, edge cases, and multiple conversions.
