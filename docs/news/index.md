# Changelog

## ksTFL 0.5.0

### C++20 Modernization

- Adopted `operator<=>` (three-way comparison) for `Length`, replacing 6
  hand-written comparison operators.
- Introduced `Mergeable` concept constraining style merge templates.
- Replaced runtime `std::unordered_map` lookup tables with
  `constexpr std::array` for OOXML enum conversions.
- Added `[[nodiscard]]` attributes to all pure/value-returning functions
  across headers.
- Converted `std::sort`, `std::any_of`, and `std::transform` calls to
  `std::ranges` equivalents.
- Used `using enum` in switch statements for `TagType` and
  `FootnotePlace`.
- Replaced `std::snprintf(buf, "%.17g", ...)` with `std::to_chars()` for
  double formatting.

### Performance Improvements

- Font directory indexing: `add_font_dir()` now scans once and builds an
  `O(1)` lookup map. Previously, `find_font_file()` did a recursive
  directory walk on every call.
- Replaced `std::regex` in `is_safe_numeric_format()` with a single-pass
  manual parser, eliminating regex overhead in the per-cell formatting
  hot path.
- Pre-computed column index map (`col_id_to_idx`) once in
  `LogicalTableBuilder::build()` and passed to both
  `build_header_grid()` and `apply_style_rows()`, avoiding redundant map
  construction.
- Short-circuit `parse_inline_markup()`: skip `has_inline_markup()` tag
  classification when the input contains no `<` character.

### Bug Fixes

- Fixed ODR violation: `font_map` in `font_cache.h` changed from
  `static const` to `inline const`.
- Eliminated `goto` in logical table post-pass, replaced with structured
  [`break`](https://rdrr.io/r/base/Control.html).

### Code Quality

- Extracted `restore_dedupe_at_page_boundaries()` as a free function
  from the 500-line `render_from_strings()` method.
- Unified three content style resolvers (`resolve_title_style`,
  `resolve_subtitle_style`, `resolve_footnote_style`) into a shared
  `resolve_content_style()` method.
- Unified row height computation via
  `compute_row_heights_impl<WidthFn, FilterFn>()` template.
- Consolidated margin parsing with `parse_margins_fields<T>()` template.
- Consolidated alignment parsing to use existing `parse_alignment()`
  throughout.
- Translated remaining Russian comments to English.

### Tests

- Added 31 new C++ unit tests for the `is_safe_numeric_format()` manual
  parser covering valid formats, invalid specifiers, edge cases, and
  multiple conversions.
