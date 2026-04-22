# Changelog

## ksTFL 0.11.1

### Vendor library upgrades

- **FreeType** upgraded 2.13.3 → 2.14.3 (latest upstream). Picks up ~18
  months of glyph loader, CFF, and auto-hinter fixes. Customised
  `ftmodule.h` (restricting the compiled module set to what ksTFL
  actually uses) preserved on top of the new tree.
- **HarfBuzz** upgraded 10.2.0 → 14.2.0 (latest upstream). Incorporates
  four major releases of shaping/OpenType improvements and bug fixes.
  Our feature-disable flags (`HB_NO_SUBSET`, `HB_NO_COLOR`,
  `HB_NO_PAINT`, `HB_NO_STYLE`) carry over unchanged.

No behavioural change in ksTFL itself; all 19 test files continue to
pass, including measurement-sensitive paths (width recalc, column
computation, ggplot figure rendering, end-to-end DOCX write).

## ksTFL 0.11.0

### Code audit: bug fixes, correctness & performance

Three-batch sweep over the R and C++ codebases covering
project-convention compliance, thread safety, numeric correctness,
locale independence, and hot paths in the rendering engine.

#### R — convention & correctness

- [`stop()`](https://rdrr.io/r/base/stop.html) /
  [`warning()`](https://rdrr.io/r/base/warning.html) replaced with
  `cli_abort()` / `cli_warn()` in `run_replay_app.R`,
  `run_styles_editor.R`, `ksTFL.R`.
- Figure scale modes now consistently reference
  `.const_figure_scale_modes` (in `spec_context.R`, `pkg_settings.R`).
- [`sapply()`](https://rdrr.io/r/base/lapply.html) →
  [`vapply()`](https://rdrr.io/r/base/lapply.html) (type-safe) across
  `spec_print.R`, `spec_context.R`, `pkg_settings.R`,
  `schema_serialize.R`.
- **`.env_eval()` no longer silently defaults to
  `spec$.metadata$data_env`**: the `env` argument is validated
  (non-null,
  [`is.environment()`](https://rdrr.io/r/base/environment.html)) and
  `cli_abort()` is raised otherwise. Eliminates a class of subtle
  dispatch bugs where an evaluation could bind against a stale `spec`.
- Removed dead schema fallbacks (`cs$label %||% cs$colLabel`, etc.) in
  `spec_print.R`; schema uses `label` / `format` only.

#### C++ — correctness & safety

- **Font registry thread-safety** (`font_scanner.h/.cpp`): migrated to
  `std::shared_mutex`; reader accessors take `std::shared_lock` and
  return by value, so
  [`tfl_rescan_fonts()`](https://example.com/reference/tfl_rescan_fonts.md)
  remains safe to call while renders run. (`std::call_once` rejected
  because rescanning is an explicit user feature.)
- **UTF-8 decoder validation** (`text_measurer.cpp`): each continuation
  byte is now checked for `10xxxxxx` bits; on malformed sequences the
  decoder emits U+FFFD and advances exactly one byte to resync.
- **Locale-independent numeric formatting** (`logical_table.cpp`):
  `apply_column_format()` switched from `std::strtod` to
  `std::from_chars<double>`; column format parsing is no longer affected
  by the process locale.
- **Column-width scaling precision** (`paginator.cpp`):
  `compute_segment_column_widths()` performs all arithmetic in `double`
  and clamps to `[0, INT64_MAX]` before narrowing to int64 EMU.
- **TOC style id generation** (`docx_emitter.cpp`): replaced `snprintf`
  into a fixed 64-byte buffer with `std::to_string` concatenation;
  buffer truncation is no longer possible.
- **Header-grid span/gap mismatch** (`logical_table.cpp`): previously a
  silent [`break`](https://rdrr.io/r/base/Control.html); now emits an
  `Rcpp::warning` with row and span info (falls back to rendering
  without promotion).

#### C++ — performance

- **Inline parser stack container** (`inline_parser.cpp`): replaced
  `std::stack<TagType>` with `std::vector<TagType>`;
  `ParserState::from_stack()` reduced from two full stack copies to a
  single reverse-iterator pass with inline Sup/Sub mutual exclusion.
  Closing-tag lookup uses `rbegin()`
  - `erase()` instead of a copy/push/pop loop.
- **Dedupe restoration at page boundaries** (`renderer.cpp`): reworked
  `restore_dedupe_at_page_boundaries()` from
  `O(pages · dedupe_cols · rows)` backward scans to a single forward
  pass with running per-column last-non-empty state,
  `O(rows + pages · dedupe_cols)`.
- **Redundant `FT_Set_Char_Size`** (`font_cache.cpp`): `CachedFace` now
  tracks `last_size_pt`; `get_hb_font()` skips FreeType resizing and
  `hb_ft_font_changed` when the face is already set to the requested
  size.
- **`try_emplace` in style-ref cache** (`paginator.cpp`): single hash
  lookup on both hit and miss paths.
- **`reserve()`** for output vectors in `parse_text_groups`,
  `parse_header_footer`, `parse_stub_columns`, `parse_columns`
  (`json_parser.cpp`) and for segment `column_indices`
  (`paginator.cpp`).
- **Cache `page_config.usable_width()`** once at the top of
  `Paginator::paginate()` instead of recomputing per segment.
- Removed redundant `dest.reserve()` calls in `xml_writer.cpp`
  `escape_text_into` / `escape_attr_into` (buffer pre-reserved 64KB).

#### Polish

- `extract_number()` in `units.cpp`: renamed out-param and clarified
  contract (`end_pos` written at end, internal `pos` local).

## ksTFL 0.10.4

### Fixes

- **`continuousSection` semantics corrected in DOCX renderer**: section
  break type is now taken from the section/spec being emitted (not the
  next spec), so `continuousSection = TRUE` applies to the intended
  spec.
- **Body-level section properties honor `continuousSection`**: the last
  spec can now emit a body-level `w:type="continuous"`, allowing
  figure-to-table flow without an unintended final next-page break.
- **TOC-to-body transition behavior restored**: TOC remains separated
  with a `nextPage` break while in-body specs can still flow
  continuously as requested.
- Added/updated regression tests for multi-spec section break typing,
  including body-level `sectPr` behavior.

## ksTFL 0.10.3

### Internal C++ Engine

- **Optimised `get_plain_text()`** (`inline_parser.cpp`): replaced the
  parse-full-AST-then-extract approach with a single-pass tag-stripping
  scanner that reuses `extract_tag()`/`classify_tag()` directly,
  eliminating all intermediate `ParsedCell`/`TextRun` allocations.
- Added 16 unit tests for `get_plain_text()` covering all recognised tag
  types, `<br>` → space conversion, nested tags, and literal angle
  brackets.

## ksTFL 0.10.2

### Internal C++ Engine — Safety, Performance & Modernisation

- **Exception-safe font loading** (`font_cache.cpp`): `load_face()` now
  wraps `hb_ft_font_create_referenced()` in a try/catch block that calls
  `FT_Done_Face()` before rethrowing, preventing a FreeType handle leak
  on any HarfBuzz construction failure.
- **Eliminated redundant string lowering** (`font_cache.cpp`,
  `font_scanner.cpp`): `font_name_to_stem_hint()` already returns a
  lowercase string, so the second `to_lower` pass in `find_font_file()`
  was removed. `TargetFallback` structs now pre-compute a `target_lower`
  field so per-call lowering inside `get_fallback_family()` is avoided
  entirely.
- **In-place style cascade application** (`style_resolver.h`,
  `style_resolver.cpp`): new
  `apply_style_ref_inplace(StyleDef &, const std::string &)` mutates the
  target directly instead of copy-merge-return. All callers in
  `resolve_header_cell_style()`, `resolve_body_cell_style()`,
  `resolve_content_style()`, `resolve_body_text_style()` and
  `resolve_figure_caption_style()` converted to the in-place variant,
  eliminating one `StyleDef` copy per style-ref application.
- **Per-column base-style caches in paginator** (`paginator.cpp`): the
  row loop in `compute_row_heights_impl` now pre-computes
  `base_style_cache` and `addrow_style_cache` (indexed by column index)
  *before* iterating over rows, cutting repeated template-cascade merges
  (steps 1–5) to a one-time cost. A `style_ref_cache`
  (`std::unordered_map<std::string, const StyleDef*>`) is built once per
  segment to cache `find_style()` pointer lookups. A
  `requires std::invocable<…>` constraint was added to the template for
  earlier type-checking.
- **Pre-computed style caches in DOCX table emission**
  (`docx_emitter.h`, `docx_table.cpp`): `emit_table()` builds
  `base_style_cache` and `addrow_style_cache` once per segment and
  passes them to `emit_table_row()`, which now applies only row/cell
  overrides on top of the cached base instead of recomputing the full
  cascade for every cell.
- **Stack-allocated tag buffer** (`inline_parser.cpp`): `classify_tag()`
  replaced a heap-allocated `std::string lower` with a
  `char lower_buf[8]` stack buffer — tag names are at most 3 characters,
  so no heap allocation is needed per tag.
- **`std::format` for error messages** (`json_parser.cpp`,
  `renderer.cpp`, `font_cache.cpp`): all
  `throw RenderError("…" + var + "…")` patterns replaced with
  `std::format("…{}", var)`, removing temporary string concatenations
  (15 call sites total).

## ksTFL 0.10.1

### Fixes

- **Style deep-merge across
  [`compute_cols()`](https://example.com/reference/compute_cols.md)
  blocks**: `.append_style_action()` no longer removes entire
  multi-column style actions when a later block partially overlaps
  columns; only the overlapping columns are surgically replaced,
  preserving styles on non-overlapping columns.
- **True recursive style merge**: `.merge_recursive()` now recurses into
  nested named sub-lists instead of performing a shallow
  [`modifyList()`](https://rdrr.io/r/utils/modifyList.html) replace.
  Combining styles that share a top-level category (e.g. two styles both
  setting `font` properties) no longer silently drops properties from
  the first style.
- **Style application order preserved**:
  `._consolidate_styles_in_spec()` now merges styles in the order
  specified by the user (e.g. `f_combine("a", "b")` applies `a` first,
  then `b` wins) instead of sorting alphabetically.
- **[`f_combine()`](https://example.com/reference/f_combine.md) accepted
  in [`c_style()`](https://example.com/reference/c_style.md),
  [`c_merge()`](https://example.com/reference/c_merge.md),
  [`c_addrow()`](https://example.com/reference/c_addrow.md)**:
  `styleRef` parameters in row-action functions now accept multi-element
  style vectors produced by
  [`f_combine()`](https://example.com/reference/f_combine.md).
- **`.combine_column_styles()` handles nested
  [`f_combine()`](https://example.com/reference/f_combine.md)**:
  replaced `do.call(f_combine, ...)` with direct
  [`unlist()`](https://rdrr.io/r/base/unlist.html) + class assignment to
  correctly flatten style refs that already contain multi-element
  vectors.
- **[`compute_cols()`](https://example.com/reference/compute_cols.md)
  accepts scalar `TRUE`/`FALSE`**: a scalar logical condition is now
  recycled to match `nrow(data)`, allowing
  `compute_cols(spec, TRUE, ...)` as shorthand for “all rows”.
- **Missing
  [`rlang::expr()`](https://rlang.r-lib.org/reference/expr.html)
  qualifier**: fixed unqualified
  [`expr()`](https://rlang.r-lib.org/reference/expr.html) call in
  `.env_select()` that caused `could not find function "expr"` in clean
  R sessions.

## ksTFL 0.10.0

### New Features

- **Paragraph-level borders**: styles now support `<w:pBdr>` (paragraph
  borders) in addition to existing cell-level `<w:tcBorders>`. Paragraph
  borders underline only the text content within a cell, enabling visual
  gaps between spanning header groups without inserting dummy columns.
  - New `borders` parameter in
    [`s_paragraph()`](https://example.com/reference/s_paragraph.md)
    accepts a border spec built with
    [`s_borders()`](https://example.com/reference/s_borders.md) /
    [`s_border()`](https://example.com/reference/s_border.md).
  - C++ rendering engine emits `<w:pBdr>` elements in paragraph
    properties.
  - JSON schema (`styles_schema_v2.json`) updated to allow `borders`
    within paragraph definitions.
- New built-in atomic styles: `brw_thick` (4pt white right border),
  `blw_thick` (4pt white left border), `pb` (1pt paragraph bottom
  border), `pb_th` (0.5pt thin paragraph bottom border).

### Shiny Styles Editor

- Paragraph border controls (top, bottom, left, right) added to all
  text-style panels in the Shiny styles editor.

### Documentation

- Updated roxygen documentation for
  [`s_paragraph()`](https://example.com/reference/s_paragraph.md),
  [`s_borders()`](https://example.com/reference/s_borders.md), and
  [`s_border()`](https://example.com/reference/s_border.md) to describe
  paragraph border usage.
- New “Paragraph-level borders” subsection and updated atom reference
  table in the Styling Guide vignette.
- New Example 3 (paragraph borders on spanning headers) in the Reporting
  Examples vignette.
- New Example 6 (spanning header gap technique) in the Real Examples
  vignette.

## ksTFL 0.9.0

### Build System

- HarfBuzz, FreeType, and minizip are now always compiled from vendored
  source during package installation, removing the runtime dependency on
  system `libharfbuzz`, `libfreetype`, and `libminizip` packages on
  Linux.
- The Linux build path now uses a committed vendored-source toolchain
  (`src/vendor/` plus `src/Makevars`) instead of `pkg-config` detection
  or optional system-library fallbacks.

### Documentation

- Updated installation instructions to remove the obsolete Linux
  runtime-package prerequisite step.
- Updated renderer architecture/build docs to describe vendored static
  compilation.

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
