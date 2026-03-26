# Changelog

## ksTFL 0.8.0

### New Features

- Page settings ([`p_page()`](https://example.com/reference/p_page.md) /
  [`set_page_style()`](https://example.com/reference/set_page_style.md))
  now support partial overrides — only explicitly specified fields
  override the template defaults, enabling lighter per-spec
  customisation.
- Per-column style mapping: character vector `style_refs` in
  [`add_style()`](https://example.com/reference/add_style.md) now
  accepts a vector of length equal to the number of columns, with `NA`
  to skip individual columns.
- New `Listings_times` built-in template (Times New Roman variant of the
  Listings template).

### Fixes

- [`add_header()`](https://example.com/reference/add_header.md) /
  [`add_footer()`](https://example.com/reference/add_footer.md) with
  `level` replacement now correctly returns the right
  `TFL_options_header` / `TFL_options_footer` class when used via
  [`tfl_set_options()`](https://example.com/reference/tfl_set_options.md).
- Default page settings changed from a fixed `A4 / portrait` override to
  `NULL`, so bare specs inherit all page properties from the active
  template without unintended overrides.

### Template Updates

- Refined font sizes, spacing, margins, and border widths across Carbon
  Dark, Classic (landscape/portrait), Default, and Listings templates.

### Documentation

- Added ksTFL cheat sheet (PDF and PowerPoint) to `inst/extdata`.

## ksTFL 0.7.9

### CI/CD

- Added CRAN-like repository structure for Linux binaries (Ubuntu and
  Fedora), enabling
  [`install.packages()`](https://rdrr.io/r/utils/install.packages.html)
  from the release repo on Linux.
- Added Red Hat / Fedora binary build using a Fedora container in CI.
- GitHub Releases are now published to both the private and public
  (ksTFL-release) repositories.
- New manual workflow (“Upload Binary to Release Repo”) for adding
  locally built packages (e.g., macOS) to the release repository.
- Added explicit pandoc setup to ensure vignettes build correctly on all
  platforms.
- Updated README installation instructions with per-platform sections.

## ksTFL 0.7.6

### Fixes

- Fixed inline markup paragraph handling so

  produces real paragraph boundaries in emitted DOCX text groups
  (titles, subtitles, body text, footnotes), aligned with pagination
  measurement logic.

- Improved spacer-row border behavior: left/right borders are preserved
  through top/bottom empty spacer rows, while top/bottom lines remain
  suppressed as intended.

## ksTFL 0.7.5

### Documentation

- New vignette: “Real Examples with ksTFL” — five end-to-end clinical
  reporting examples (demographics table, UTF-8/multilingual table, AE
  spanning-header table, data listing with two-level TOC, and
  multi-figure combined report), each with embedded PDF output.
- Improved code comments and narrative descriptions across all example
  vignettes.
- Translated example scripts (`lb_lst_01_en.R`, `ae_tbl_exmpl.R`,
  `tmp_example.R`) from Russian to English.

## ksTFL 0.7.0

### New Features

- Added built-in style atoms for target font families: `font_arial`,
  `font_courier_new`, `font_times_new_roman`, `font_georgia`,
  `font_verdana`, and `font_trebuchet_ms`. These atoms set `font_name`
  only and are intended for composition with existing size, colour,
  alignment, and spacing atoms via
  [`f_combine()`](https://example.com/reference/f_combine.md).

### Documentation

- Updated the styling and font-management articles to document target
  font family atoms and show how to combine them with other built-in
  style atoms.

## ksTFL 0.6.0

### Breaking Changes

- **System font scanning replaces bundled proprietary fonts.** The
  package no longer ships proprietary TTF fonts (Arial, Courier New,
  Times New Roman, Georgia, Verdana, Trebuchet MS, Aptos). Instead,
  fonts are discovered from the operating system at package load time
  via FreeType-based scanning. If a requested font is not installed on
  the system, a metrically compatible open-source fallback is used
  automatically:
  - Arial → Liberation Sans (bundled)
  - Times New Roman → Liberation Serif (bundled)
  - Courier New → Liberation Mono (bundled)
  - Georgia → Liberation Serif (bundled)
  - Verdana → Liberation Sans (bundled)
  - Trebuchet MS → Liberation Sans (bundled)
- **Aptos font family dropped.** Aptos is no longer a target font.
  Existing specs referencing Aptos will fall back to Liberation Sans.
- The hardcoded `font_map` in the C++ font cache has been removed. Font
  resolution is now fully dynamic.

### New Features

- **Runtime font discovery.** At package load (`.onLoad()`), the C++
  font scanner inspects system font directories (platform-specific) and
  builds a global font registry. System-installed fonts are always
  preferred over bundled fallbacks.
- **[`tfl_rescan_fonts()`](https://example.com/reference/tfl_rescan_fonts.md)**
  — Re-run font discovery after installing new fonts or changing
  `ksTFL.font_dirs`. Prints a resolution report to the console.
- **[`tfl_font_status()`](https://example.com/reference/tfl_font_status.md)**
  — Print the current font resolution report without rescanning.
- **`ksTFL.font_dirs` option** — Point
  `options(ksTFL.font_dirs = c("/path/to/fonts"))` to additional
  directories containing proprietary or custom fonts. These directories
  are scanned alongside system directories.
- **Startup font report.** When the package is attached, a message
  reports any target fonts that use a fallback, with guidance to run
  [`tfl_font_status()`](https://example.com/reference/tfl_font_status.md)
  for details.

### Internals

- New C++ module: `font_scanner.h` / `font_scanner.cpp` —
  platform-specific font directory enumeration (Windows registry, macOS
  standard dirs, Linux XDG/freedesktop dirs) and FreeType-based
  family/style classification.
- `font_cache.cpp` now resolves fonts via the scanner’s global path map,
  with a two-tier fallback chain: designated fallback family
  (e.g. Georgia → Liberation Serif), then Liberation Sans as last
  resort.
- `rcpp_bindings.cpp` exports `init_font_registry_impl()` and
  `get_font_dirs_impl()` to R.
- `render_docx.R` now collects font directories from the scanner cache
  via `get_font_dirs_impl()` instead of using only the bundled
  `inst/fonts/` directory.

### Bundled Fonts

Only license-free fallback fonts are included in `inst/fonts/`:

| Font Family                 | License     | Replaces        |
|-----------------------------|-------------|-----------------|
| Liberation Sans (4 styles)  | SIL OFL 1.1 | Arial           |
| Liberation Serif (4 styles) | SIL OFL 1.1 | Times New Roman |
| Liberation Mono (4 styles)  | SIL OFL 1.1 | Courier New     |

## ksTFL 0.5.5

### New Features

- HTML “TFL Specification Preview” is no longer triggered by
  `print(spec)`;
  [`print.TFL_spec()`](https://example.com/reference/print.TFL_spec.md)
  is now console-only. Use the new `view_tfl_spec(spec)` function or
  RStudio Addins to open the HTML preview.
- Added `view_tfl_spec(spec)` to open the TFL Specification Preview in
  the RStudio Viewer pane.
- Added RStudio Addins: “TFL Spec Preview (Selection)” (evaluate
  selected code as a `TFL_spec` and show HTML preview) and “TFL Spec
  Preview (by name)” (prompt for an object name in `.GlobalEnv` and show
  preview).
- Added “Style Atoms Catalog” RStudio Addin and
  [`tfl_print_style_atoms()`](https://example.com/reference/tfl_print_style_atoms.md)
  to print all built-in style atoms from `.const_options_styles` to the
  console with coloured, grouped output via cli.

### Changes

- Removed the `TFL.viewer` option; HTML preview is only available via
  [`view_tfl_spec()`](https://example.com/reference/view_tfl_spec.md) or
  the addins.

## ksTFL 0.5.4

### New Features

- Added inline strikethrough support via `<s>...</s>` in the C++
  renderer, including OOXML emission (`<w:strike/>`), JSON parsing, and
  style API support (`s_font(strikethrough = ...)`).
- [`replay_report()`](https://example.com/reference/replay_report.md)
  now supports `overrideTemplate` (bundled template name or custom JSON
  path), matching
  [`write_doc()`](https://example.com/reference/write_doc.md) behavior.
- Combined replay Shiny app now supports both predefined template
  selection and custom template JSON paths.

### Improvements

- [`list_reports()`](https://example.com/reference/list_reports.md),
  [`replay_report()`](https://example.com/reference/replay_report.md),
  and
  [`clean_reports()`](https://example.com/reference/clean_reports.md)
  now default `meta_dir` to `tfl_get_option("meta_directory")`.
- [`write_doc()`](https://example.com/reference/write_doc.md) now safely
  falls back to [`tempdir()`](https://rdrr.io/r/base/tempfile.html) when
  `meta_directory` is not configured.
- Improved Aptos font resolution in the font cache (`Aptos.ttf` regular
  face lookup).

### Bug Fixes

- Functions that rely on meta artifacts now raise a clear error when
  neither `meta_dir` argument nor `meta_directory` option is set.

## ksTFL 0.5.3

### New Features

- [`replay_report()`](https://example.com/reference/replay_report.md)
  now supports replaying multiple reports into one combined DOCX.
- Added
  [`run_replay_app()`](https://example.com/reference/run_replay_app.md)
  and a new replay Shiny app for selecting reports across multiple meta
  folders, drag-and-drop reordering, and combined rendering.
- Added an RStudio addin entry for the replay app.

### Improvements

- Added optional `data_dir` handling in `render_docx()` to support
  robust replay of specs from different meta directories.
- Replay app now supports folder browsing for both input meta
  directories and output directory selection.

### Bug Fixes

- Fixed latest-spec selection logic in `.resolve_spec_path()` when
  datetimes are character values.
- Fixed merged replay `dataRef` serialization so C++ receives JSON
  arrays (restores table data loading in combined replay).
- Improved replay resource resolution for figure assets (`.png`, `.jpg`,
  `.jpeg`, `.svg`).

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
