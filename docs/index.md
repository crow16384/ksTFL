# ksTFL: Clinical Tables, Figures, and Listings Framework

[![License: GPL
v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://example.com/LICENSE)

![ksTFL logo](reference/figures/ksTFL-logo.svg)

## Overview

**ksTFL** is a professional R package designed to fill a long-standing
gap in the R ecosystem: the lack of a dedicated, end-to-end solution for
producing well-formatted, regulatory-compliant clinical Tables, Figures,
and Listings (TFLs). While R excels at statistical analysis, generating
submission-quality DOCX outputs that meet pharmaceutical industry
standards has traditionally required fragile workarounds or external
tooling. ksTFL solves this by distilling the best ideas from existing
reporting solutions into a simple, minimalistic, yet highly flexible
declarative language — a compact set of composable functions whose
combinations can produce virtually any clinical output format.

The core philosophy is **data–presentation separation**: input data
stays clean and planar, free of reporting artefacts such as merged
cells, indentation columns, or display-only rows. Formatting,
pagination, grouping, and styling are declared independently and applied
at render time. This keeps datasets maintainable, traceable, and
validation-ready — exactly what regulated environments demand.

Under the hood, a built-in **rendering engine** with text shaping
converts declarative specs into styled DOCX documents with
deterministic, pixel-perfect pagination. Rendering is extremely fast
even on large datasets, making ksTFL practical for batch production of
hundreds of outputs in a single pipeline run.

### Key Design Principles

- **Separation of Concerns**: Metadata generation (R) is decoupled from
  document rendering; input data remain clean and analysis-ready
- **Declarative Syntax**: Users describe *what* to render, not *how* to
  render it — a small function vocabulary covers the full range of
  clinical outputs
- **Deterministic Pagination**: font shaping guarantees pixel-perfect,
  reproducible layouts and pagination
- **High Performance**: C++ engine renders large multi-spec reports in
  seconds
- **Type Safety**: Comprehensive input validation with informative error
  messages
- **Reproducibility**: Specifications are serializable. That allows to
  store the metadata for replay without re-runnig of the whole code

------------------------------------------------------------------------

## Installation

ksTFL is distributed as **pre-compiled binaries** for R 4.4 and R 4.5 on
Windows, Ubuntu/Debian, and Fedora/RHEL.

### Windows

``` r
install.packages("ksTFL",
                 repos = "https://crow16384.github.io/ksTFL-release",
                 type  = "binary")
```

### Linux — Ubuntu / Debian

``` r
install.packages("ksTFL",
                 repos = "https://crow16384.github.io/ksTFL-release/bin/linux/ubuntu-noble")
```

No extra HarfBuzz, FreeType, or minizip runtime packages are required.
Linux builds are shipped with those libraries compiled from vendored
source.

### Linux — Fedora / RHEL

``` r
install.packages("ksTFL",
                 repos = "https://crow16384.github.io/ksTFL-release/bin/linux/fedora")
```

No extra HarfBuzz, FreeType, or minizip runtime packages are required.
Linux builds are shipped with those libraries compiled from vendored
source.

### macOS

macOS binaries are published as GitHub Release assets and can be
installed from a downloaded `.tgz` file:

``` r
install.packages("ksTFL_<version>.tgz", repos = NULL)
```

When a macOS binary is available in the CRAN-like repo, you can also
use:

``` r
install.packages("ksTFL",
                 repos = "https://crow16384.github.io/ksTFL-release",
                 type  = "binary")
```

### From a downloaded file

Pre-built packages can be downloaded from the
[Releases](https://github.com/crow16384/ksTFL-release/releases) page and
installed directly:

``` r
# Linux (.tar.gz binary)
install.packages("ksTFL_<version>_R_x86_64-pc-linux-gnu.tar.gz", repos = NULL)

# Windows (.zip)
install.packages("ksTFL_<version>.zip", repos = NULL)

# macOS (.tgz)
install.packages("ksTFL_<version>.tgz", repos = NULL)
```

Release repository: <https://github.com/crow16384/ksTFL-release>

### Fonts note

Proprietary Microsoft fonts (Arial, Times New Roman, etc.) are **not
bundled** due to licensing restrictions; open-source Liberation fonts
are included as metrically compatible fallbacks. Windows and macOS
systems with Microsoft Office installed typically have the original
fonts already available. On Linux, additional steps may be required —
see [Font Management](#id_7-font-management) for details.

------------------------------------------------------------------------

## Quick Start Example

``` r
library(ksTFL)

# 1. Initialize a table specification
spec <- create_table(mtcars, cols = c(cyl, mpg, hp, wt))

# 2. Add document content
spec <- spec |>
  add_title("Motor Trend Car Road Tests", styleRef = "i") |>
  add_title("Performance Metrics by Cylinder Count", styleRef = 'i') |>
  add_subtitle("Number of Cylinders: #ByGroup1", styleRef = f_combine('fc_blue','tw_50')) |>
  add_footnote("Source: 1974 Motor Trend US magazine", styleRef = 'tw_50')

# 3. Define column properties
spec <- spec |>
  define_cols(c(mpg, hp, wt), 
              label = c("Miles/(US) gallon", "Horsepower", "Weight<br>(1000 lbs)"),
              valueStyleRef = 'ac'
              ) |>
  define_cols(cyl, 
              isGrouping = TRUE, 
              isVisible =  FALSE)

# 4. Apply conditional row styling
spec <- spec |>
  compute_cols(hp > 200, 
               c_style(hp, styleRef = "fc_red"))

spec <- spec |> set_document(contentWidth = '50%')

# 5. Create report and render to DOCX
report <- create_report(spec)
```

------------------------------------------------------------------------

## API Reference

### Document Initialization

Create specification objects for different document types:

| Function                                                        | Purpose                                                  | Returns    |
|-----------------------------------------------------------------|----------------------------------------------------------|------------|
| `create_table(data, cols = everything())`                       | Initialize table spec with data frame                    | `TFL_spec` |
| `create_figure(plot_or_path, dpi = 300L)`                       | Initialize figure spec from image path or ggplot2 object | `TFL_spec` |
| [`create_text()`](https://example.com/reference/create_text.md) | Initialize text-only spec (no data)                      | `TFL_spec` |

### Content Functions

Add document elements to specifications:

| Function                                                           | Purpose                                            | Supports Style References |
|--------------------------------------------------------------------|----------------------------------------------------|---------------------------|
| `add_title(spec, text, id, styleRef, order)`                       | Add title(s) to document                           | Yes                       |
| `add_subtitle(spec, text, id, styleRef, order)`                    | Add subtitle(s) to document                        | Yes                       |
| `add_footnote(spec, text, id, styleRef, order)`                    | Add footnote(s) to document                        | Yes                       |
| `add_body_text(spec, text, id, styleRef, order)`                   | Add body text paragraphs                           | Yes                       |
| `add_header(spec, ..., level)`                                     | Add header row(s) (max 3 parts: left/center/right) | Yes                       |
| `add_footer(spec, ..., level)`                                     | Add footer row(s) (max 3 parts: left/center/right) | Yes                       |
| `add_span_header(spec, cols, label, stubOrder, id, labelStyleRef)` | Add spanning column header                         | Yes                       |

### Column Configuration

Define column properties and formatting:

``` r
define_cols(spec, cols, label, isVisible, isID, isGrouping, isPaging,
            labelStyleRef, isColBreak, dedupe, blankAfter,
            type, format, missings, colWidth, valueStyleRef)
```

**Column Parameters** (all support 1-or-n vectorized values):

| Parameter       | Purpose                                                           | Example                  |
|-----------------|-------------------------------------------------------------------|--------------------------|
| `label`         | Column display labels                                             | `"Age (years)"`          |
| `isVisible`     | Show/hide columns (hidden = 0 width, data still accessible)       | `TRUE` / `FALSE`         |
| `isID`          | Identify key columns                                              | `TRUE`                   |
| `isGrouping`    | Enable grouping behavior (boundary detection for dedup/subtitles) | `TRUE`                   |
| `isPaging`      | Force page breaks on value change                                 | `TRUE`                   |
| `labelStyleRef` | Style reference for column headers                                | `"header_bold"`          |
| `valueStyleRef` | Style reference for cell values                                   | `"numeric_right"`        |
| `isColBreak`    | Mark horizontal pagination break point                            | `TRUE`                   |
| `dedupe`        | Remove duplicate consecutive values                               | `TRUE`                   |
| `blankAfter`    | Insert blank row after value change                               | `TRUE`                   |
| `type`          | Override auto-detected column type                                | `"numeric"` / `"string"` |
| `format`        | Override auto-detected display format                             | `"%.1f"` / `"%d"`        |
| `missings`      | Custom representation for missing values                          | `"N/A"`                  |
| `colWidth`      | Set width (%, cm, pt, in, mm, auto)                               | `"25%"` / `"3cm"`        |

### Conditional Row Styling

Apply dynamic styling based on data conditions:

| Function                                                        | Purpose                                     | Example                                                            |
|-----------------------------------------------------------------|---------------------------------------------|--------------------------------------------------------------------|
| `compute_cols(spec, condition, ...)`                            | Evaluate condition and apply set of actions | `compute_cols(spec, age > 65, c_style(value, styleRef = "alert"))` |
| `c_style(cols, styleRef)`                                       | Apply style to specified cells              | `c_style(c(col1, col2), styleRef = "bold")`                        |
| `c_merge(cols, styleRef)`                                       | Merge specified cells into one cell         | `c_merge(c(col1, col2, col3))`                                     |
| `c_addrow(position, value_from, styleRef)`                      | Insert row above/below                      | `c_addrow("above", group_col, styleRef = "header")`                |
| [`c_pageBreak()`](https://example.com/reference/c_pageBreak.md) | Insert page break at matching rows          | [`c_pageBreak()`](https://example.com/reference/c_pageBreak.md)    |

**Helper Functions for Conditions**:

- `firstOf(...)`: TRUE for first occurrence of each value combination
- `lastOf(...)`: TRUE for last occurrence of each value combination
- `firstRow()`: TRUE only for first data row
- `lastRow()`: TRUE only for last data row
- `everyNth(n)`: TRUE every n-th row (e.g., `everyNth(3)` for rows 1, 4,
  7, …)
- `rowNumber()`: Row index (1-based)
- `firstOfBlock(col, n, offset)`: Logical vector marking first row of
  every n-th block defined by `col`

Note: The `cols` argument passed to
[`c_merge()`](https://example.com/reference/c_merge.md) must resolve to
at least two consecutive columns in the final report column order. The
merged cell’s displayed value is taken from the first column in the
`cols` sequence.

### Style Definitions

Define and compose styles:

| Function                                                                                                                    | Purpose                           | Returns                  |
|-----------------------------------------------------------------------------------------------------------------------------|-----------------------------------|--------------------------|
| `add_style(spec, id, ...)`                                                                                                  | Add named style to spec           | `TFL_spec`               |
| `s_font(font_name, font_size, bold, italic, underline, color, highlight)`                                                   | Font properties                   | Style component          |
| `s_paragraph(word_style, alignment, spacing, indents)`                                                                      | Paragraph formatting              | Style component          |
| `s_spacing(before, after, line_spacing)`                                                                                    | Spacing settings                  | Style component          |
| `s_indents(left, right, first_line)`                                                                                        | Indentation settings              | Style component          |
| `s_table_style(background_color, row_height, topEmptyLine, bottomEmptyLine, vertical_alignment, text_orientation, borders)` | Table cell styling                | Style component          |
| `s_borders(top, bottom, left, right)`                                                                                       | Border definitions                | Style component          |
| `s_border(color, width, line_style)`                                                                                        | Individual border                 | Style component          |
| `f_combine(...)`                                                                                                            | Combine multiple style references | Combined style reference |

**Context-Based Nesting Rules**:

- [`s_font()`](https://example.com/reference/s_font.md),
  [`s_paragraph()`](https://example.com/reference/s_paragraph.md),
  [`s_table_style()`](https://example.com/reference/s_table_style.md) —
  direct children of
  [`add_style()`](https://example.com/reference/add_style.md)
- [`s_borders()`](https://example.com/reference/s_borders.md) — must be
  inside `s_table_style(borders = s_borders(...))`
- [`s_spacing()`](https://example.com/reference/s_spacing.md),
  [`s_indents()`](https://example.com/reference/s_indents.md) — must be
  inside [`s_paragraph()`](https://example.com/reference/s_paragraph.md)
- Built-in target font atoms are available for direct `styleRef`
  composition: `font_arial`, `font_courier_new`, `font_times_new_roman`,
  `font_georgia`, `font_verdana`, `font_trebuchet_ms`

**Example Style Definition**:

``` r
spec <- add_style(spec, id = "header_style",
  s_font(font_name = "Arial", font_size = "12pt", bold = TRUE, color = "#333333"),
  s_paragraph(alignment = "center", spacing = s_spacing(after = "6pt")),
  s_table_style(background_color = "#E8E8E8", borders = s_borders(
    bottom = s_border(color = "black", width = "2pt", line_style = "double")
  ))
)

spec <- define_cols(spec, mpg,
  valueStyleRef = f_combine("font_verdana", "fs_10", "ar"))
```

### Document Configuration

Configure document-level settings:

| Function                                              | Purpose                          | Key Parameters                                                                                                                                                                |
|-------------------------------------------------------|----------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `set_document(spec, ...)`                             | Set document metadata            | `isContinues`, `contentWidth`, `topEmptyLine`, `bottomEmptyLine`, `footnotePlace`, `hasData`, `docTemplate`, `figureWidth`, `figureHeight`, `figureDevice`, `figureScaleMode` |
| `set_page_style(spec, docTemplate, page)`             | Configure page layout & template | Template name, page settings                                                                                                                                                  |
| `p_page(size, orientation, margins)`                  | Page settings helper             | A4/Letter/Legal, portrait/landscape                                                                                                                                           |
| `p_margins(top, bottom, left, right, header, footer)` | Margin settings helper           | Dimensions with units (in, cm, pt, mm)                                                                                                                                        |

### Report Assembly & Rendering

Combine specifications into reports and render to DOCX:

| Function                                                                                                         | Purpose                                  | Returns                                       |
|------------------------------------------------------------------------------------------------------------------|------------------------------------------|-----------------------------------------------|
| `create_report(...)`                                                                                             | Combine specs/reports into single report | `TFL_report`                                  |
| `save_report(report, docFileName, outDir, metaPath, prettify)`                                                   | Serialize and export report              | List with `spec_file`, `datetime`, `metaPath` |
| `write_doc(report, name, outDir, metaPath, overrideTemplate, font_dirs, fallback_font, verbose)`                 | Save and render DOCX in one call         | Output file path (invisibly)                  |
| `replay_report(spec_json, meta_dir, output_path, template_json, overrideTemplate, insertTOC, tocTitle, verbose)` | Re-render DOCX from stored JSON metadata | Output file path (invisibly)                  |

**create_report() Features**:

- Consolidates styles across specs (deduplicates merged styles)
- Validates all style references exist
- Assigns sequential document order
- Generates unique data references
- Evaluates deferred
  [`compute_cols()`](https://example.com/reference/compute_cols.md)
  conditions against data environment
- Supports mixing `TFL_spec` and `TFL_report` objects

**save_report() Parameters**:

- `report`: A `TFL_report` object from
  [`create_report()`](https://example.com/reference/create_report.md)
- `docFileName`: Output filename (e.g., `"report.docx"`)
- `outDir`: Output directory (defaults to tfl_options)
- `metaPath`: Directory for metadata/data files (defaults to
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html))
- `prettify`: If `TRUE`, formats JSON output for debugging

**write_doc() Parameters**:

- `report`: A `TFL_report` object from
  [`create_report()`](https://example.com/reference/create_report.md)
- `name`: Base output filename (without `.docx`)
- `outDir`: Output directory for the final DOCX
- `metaPath`: Directory for metadata/data files
- `overrideTemplate`: Optional global template override (name or JSON
  path)
- `font_dirs`: Additional font search directories (optional)
- `fallback_font`: Custom fallback font path (optional)
- `verbose`: Print progress messages (default: `FALSE`)

### Package Options

Configure global defaults that apply to all specs in a session:

| Function                                                                      | Purpose                                               |
|-------------------------------------------------------------------------------|-------------------------------------------------------|
| `tfl_set_options(...)`                                                        | Set package-level options (replaces, not accumulates) |
| [`tfl_get_options()`](https://example.com/reference/tfl_get_options.md)       | Retrieve all current options                          |
| `tfl_get_option(name)`                                                        | Retrieve single option value                          |
| [`tfl_reset_options()`](https://example.com/reference/tfl_reset_options.md)   | Reset all options to defaults                         |
| [`tfl_list_templates()`](https://example.com/reference/tfl_list_templates.md) | List available bundled document templates             |

**All Configurable Parameters**:

| Parameter          | Default                 | Type      | Description                                                                                                                                                                                                                           |
|--------------------|-------------------------|-----------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `docTemplate`      | `"CRO Example_default"` | Character | Document style template (bundled name or path to JSON). Use [`tfl_list_templates()`](https://example.com/reference/tfl_list_templates.md) to list available embedded templates, or use template editor shiny addin to create your own |
| `contentWidth`     | `"100%"`                | Character | Main content area width (e.g., `"95%"`, `"16.51cm"`, `"6.5in"`)                                                                                                                                                                       |
| `footnotePlace`    | `"repeated"`            | Character | Footnote placement: `"repeated"` (every page), `"last_page"`, or `"doc_footer"`                                                                                                                                                       |
| `isContinues`      | `FALSE`                 | Logical   | Suppress repeating headers on every page of the document                                                                                                                                                                              |
| `missings`         | `"NA"`                  | Character | Default representation for missing/NA values (e.g., `"."`, `"---"`, `"N/A"`)                                                                                                                                                          |
| `autoColWidth`     | `TRUE`                  | Logical   | Auto-recalculate unlocked column widths; when `FALSE` manage all widths manually                                                                                                                                                      |
| `minColWidth`      | `0.5`                   | Numeric   | Minimum relative width (%) for unlocked columns during auto-recalculation                                                                                                                                                             |
| `figureWidth`      | `"6in"`                 | Character | Default figure width (e.g., `"70%"`, `"6.5in"`, `"16.51cm"`)                                                                                                                                                                          |
| `figureHeight`     | `"4in"`                 | Character | Default figure height (same format as `figureWidth`)                                                                                                                                                                                  |
| `figureDevice`     | `"svg"`                 | Character | Graphics device for ggplot2 rendering: `"svg"`, `"png"`, `"jpeg"`                                                                                                                                                                     |
| `figureScaleMode`  | `"fixed"`               | Character | Figure scaling: `"fixed"`, `"fitWidth"` (scale to page width), `"fitPage"`                                                                                                                                                            |
| `insertTOC`        | `FALSE`                 | Logical   | Prepend a Table of Contents page (requires `toclevel` on titles)                                                                                                                                                                      |
| `tocTitle`         | `"Table of Contents"`   | Character | TOC page heading; use `""` to omit                                                                                                                                                                                                    |
| `output_directory` | `"."`                   | Character | Default output directory for rendered documents                                                                                                                                                                                       |
| `meta_directory`   | `NULL`                  | Character | Directory for intermediate metadata files; `NULL` defaults to output dir or temp                                                                                                                                                      |

**Page Layout** (via
[`set_page_style()`](https://example.com/reference/set_page_style.md) or
`tfl_set_options(set_page_style(...))`):

| Parameter          | Default          | Valid Values                                                                                                                                     |
|--------------------|------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| `page.size`        | `"A4"`           | `"A4"`, `"A3"`, `"Letter"`, `"Legal"`, `"Executive"`                                                                                             |
| `page.orientation` | `"landscape"`    | `"portrait"`, `"landscape"`                                                                                                                      |
| `page.margins`     | Template default | Created via `p_margins(top, bottom, left, right, header, footer)` — all accept dimension strings (e.g., `"25mm"`, `"1in"`, `"2.54cm"`, `"72pt"`) |

**Shared Content** — define once, applied to every spec:

- Predefined **styles**:
  `tfl_set_options(add_style(id = "my_style", s_font(bold = TRUE)))` —
  available in all specs via `styleRef`
- Default **headers/footers**:
  `tfl_set_options(add_header("Left", "Center", "Right"))` — up to 3
  cells per row
- Default **body text**:
  `tfl_set_options(add_body_text("No data to report"))` — shown when
  spec has no data

``` r
# Example: configure session-wide defaults
tfl_set_options(
  contentWidth = "95%",
  missings     = ".",
  footnotePlace = "last_page",
  set_page_style(
    page = p_page(size = "Letter", orientation = "landscape",
                  margins = p_margins(top = "1in", bottom = "1in",
                                      left = "0.75in", right = "0.75in"))
  ),
  add_header("Company Name", "", "Page {page} of {pages}"),
  add_footer("Confidential", "", "{date}"),
  add_style(id = "alert", s_font(color = "#FF0000", bold = TRUE))
)
```

### Atomic Styles (Built-in Style Atoms)

ksTFL ships with 100+ **atomic styles** — single-property building
blocks that can be used directly as `styleRef` values or combined with
[`f_combine()`](https://example.com/reference/f_combine.md). Each atom
sets exactly **one** visual property, making styles composable and
predictable. Use
[`tfl_print_style_atoms()`](https://example.com/reference/tfl_print_style_atoms.md)
to print all avaialbe atomic styles, or use addin to call this function.

**Usage**: pass atom IDs directly to any `styleRef` parameter, or
combine multiple atoms:

``` r
# Single atom
spec <- add_title(spec, "Demographics", styleRef = "b")

# Combine atoms with f_combine()
spec <- define_cols(spec, mpg,
  # `f_combine` used to merge atomic style to build the complex style on the fly
  valueStyleRef = f_combine("font_verdana", "fs_10", "ar"))

spec <- add_footnote(spec, "Source: study database.",
  styleRef = f_combine("i", "fc_gray", "tw_80"))
```

**Font — Decoration**

| Atom | Alias            | Effect    |
|------|------------------|-----------|
| `b`  | `font_bold`      | Bold      |
| `i`  | `font_italic`    | Italic    |
| `u`  | `font_underline` | Underline |

**Font — Family**

| Atom                   | Font            |
|------------------------|-----------------|
| `font_arial`           | Arial           |
| `font_courier_new`     | Courier New     |
| `font_times_new_roman` | Times New Roman |
| `font_georgia`         | Georgia         |
| `font_verdana`         | Verdana         |
| `font_trebuchet_ms`    | Trebuchet MS    |

**Font — Size** (`fs_7` through `fs_11`): `fs_7`, `fs_8`, `fs_9`,
`fs_10`, `fs_11` (7–11 pt)

**Font — Color**

| Atom                  | Hex      | Use Case              |
|-----------------------|----------|-----------------------|
| `fc_black`            | \#000000 | Default / reset       |
| `fc_red`              | \#FF0000 | Alert / out-of-range  |
| `fc_blue`             | \#0000FF | Informational         |
| `fc_green`            | \#008000 | Within-range / pass   |
| `fc_gray` / `fc_grey` | \#595959 | Secondary / reference |
| `fc_navy`             | \#1F3864 | Dark formal headers   |
| `fc_teal`             | \#2E75B6 | Medium blue           |
| `fc_olive`            | \#5C7A29 | Muted green           |
| `fc_rust`             | \#C0392B | Muted red / caution   |
| `fc_plum`             | \#7B2D8B | Purple / special      |
| `fc_slate`            | \#44546A | Blue-gray / subdued   |

**Text Highlight** (background shading behind text)

| Atom                  | Hex      | Atom       | Hex      |
|-----------------------|----------|------------|----------|
| `hl_yellow`           | \#FFFF00 | `hl_peach` | \#FADADD |
| `hl_red`              | \#FF0000 | `hl_mint`  | \#D5F5E3 |
| `hl_green`            | \#90EE90 | `hl_sky`   | \#D6EAF8 |
| `hl_gray` / `hl_grey` | \#EEEEEE | `hl_lemon` | \#FEFBD8 |
|                       |          | `hl_lilac` | \#E8DAEF |

**Paragraph — Alignment**

| Atom | Alias         | Alignment |
|------|---------------|-----------|
| `al` | `text_left`   | Left      |
| `ac` | `text_center` | Center    |
| `ar` | `text_right`  | Right     |

**Paragraph — Indentation** (0.5 cm steps): `ind0`–`ind4` (left),
`rind0`–`rind4` (right). Aliases: `indent_0`–`indent_4`,
`rindent_0`–`rindent_4`.

**Paragraph — Table-Width Shrink** (`tw_95`–`tw_50` in 5% steps):
symmetric left+right indent to align titles/footnotes/body text with a
narrower table. Calculated for A4 landscape with 0.5 in margins.

**Paragraph — Spacing**: `sp_0` (0 pt), `sp_2` (2 pt), `sp_4` (4 pt) —
before and after, line spacing 1.0.

**Paragraph — Pagination**: `kl` (keep lines together on same page),
`kn` (keep with next row).

**Cell — Vertical Alignment**: `va_t` / `va_top`, `va_m` / `va_center`,
`va_b` / `va_bottom`.

**Cell — Text Orientation**: `to_h` / `text_horizontal`, `to_90` /
`text_vertical_90` (bottom-to-top), `to_270` / `text_vertical_270`
(top-to-bottom).

**Cell — Background Color**

| Atom                  | Hex      | Atom       | Hex      |
|-----------------------|----------|------------|----------|
| `bg_blue`             | \#D9E1F2 | `bg_peach` | \#FADADD |
| `bg_gray` / `bg_grey` | \#F2F2F2 | `bg_mint`  | \#D5F5E3 |
| `bg_navy`             | \#1F3864 | `bg_sky`   | \#D6EAF8 |
| `bg_slate`            | \#44546A | `bg_lemon` | \#FEFBD8 |
| `bg_steel`            | \#BDD7EE | `bg_lilac` | \#E8DAEF |

**Row Height** (spacer rows): `row_h2` (2 pt), `row_h4` (4 pt), `row_h6`
(6 pt).

**Borders**: `bt`, `bb`, `bl`, `br` (1 pt black, single line); `bt_th`,
`bb_th` (0.5 pt thin); `bc_gray`/`bc_grey` (color override to gray),
`bc_white` (suppress all borders).

**Group Header Composites**: `grp_hdr` (bold + indent reset + 4 pt
space-before), `grp_hdr_i` (bold + italic + indent reset + 4 pt
space-before).

``` r
# Compose atoms for a styled separator row
spec <- compute_cols(spec, lastOf(category),
  c_addrow("below", category,
           styleRef = f_combine("row_h2", "bb_th", "bc_gray")))

# Group header with bold + space above
spec <- compute_cols(spec, firstOf(param),
  c_addrow("above", param, styleRef = "grp_hdr"))
```

### Inline Text Markup

ksTFL supports HTML-like inline markup tags in any text content — cell
values, column labels, titles, subtitles, footnotes, headers, footers,
and body text. Tags are parsed by the C++ rendering engine and converted
to styled OOXML runs in the output DOCX.

**Supported Tags**:

| Tag               | Effect                                   | Example                                |
|-------------------|------------------------------------------|----------------------------------------|
| `<b>...</b>`      | **Bold**                                 | `"Total: <b>125</b> subjects"`         |
| `<i>...</i>`      | *Italic*                                 | `"p-value<i>(two-sided)</i>"`          |
| `<u>...</u>`      | Underline                                | `"See <u>Table 14.1</u>"`              |
| `<s>...</s>`      | ~~Strikethrough~~                        | `"<s>Deprecated</s> Updated"`          |
| `<sup>...</sup>`  | Superscript                              | `"E=mc<sup>2</sup>"`                   |
| `<sub>...</sub>`  | Subscript                                | `"H<sub>2</sub>O"`                     |
| `<br>` or `<br/>` | Line break (soft, within same paragraph) | `"Revenue<br>(Millions of $)"`         |
| `<p>`             | Paragraph break (starts a new paragraph) | `"First paragraph<p>Second paragraph"` |

**Key Characteristics**:

- **Nesting**: fully supported — `<b><i>bold italic</i></b>`
- **Case-insensitive**: `<B>`, `<b>`, both work
- **No attributes**: tags carry no attributes; use the style system for
  colors, fonts, etc.
- **Unknown tags are ignored**: unrecognized tags are silently stripped,
  content preserved
- **Priority**: inline markup overrides all style-system settings
  (template, column, row styles)

**Common Patterns**:

``` r
# Multi-line column headers
define_cols(spec, c(drug, placebo, total),
  label = c("DrugX<br>(N=160)", "Placebo<br>(N=158)", "Total<br>(N=318)"))

# Superscripts in footnotes
add_footnote(spec, "* p<0.05; <sup>†</sup> adjusted for baseline")

# Bold key values in titles
add_title(spec, "Table 14.1: <b>Demographics</b> and Baseline Characteristics")

# Subscript in chemical formulas
add_body_text(spec, "Concentration of CO<sub>2</sub> measured in ppm")

# Nested formatting
add_footnote(spec, "<b><i>Note:</i></b> All values are <u>least-squares means</u>")

# Paragraph breaks in body text
add_body_text(spec, "Section 1 summary.<p>Section 2 begins here.")
```

Note: `<sup>` and `<sub>` are mutually exclusive — if nested, the
innermost tag takes effect.

------------------------------------------------------------------------

## Workflow Architecture

    1. Specification Creation
       └─> create_table() / create_figure() / create_text()
           └─> Returns TFL_spec with initialized structure

    2. Content & Styling
       └─> add_title(), add_subtitle(), add_footnote()
       └─> define_cols() — column configuration
       └─> add_style() — define named styles
       └─> compute_cols() — conditional row styling
       └─> set_document() — document metadata
       └─> set_page_style() — page layout & template

    3. Report Assembly
       └─> create_report() — combines multiple specs
           └─> Style consolidation & validation
           └─> Sequential ordering & data references
           └─> Deferred condition evaluation

    4. Export
       └─> save_report() — JSON spec + data files to disk

    5. Rendering
      └─> write_doc() / replay_report() — C++ engine produces styled .docx
           └─> HarfBuzz text shaping → deterministic pagination
           └─> OOXML emission → valid .docx (ZIP) package

------------------------------------------------------------------------

## Key Features

### 1. Tidyselect Integration

Use tidyselect expressions for intuitive column selection:

``` r
define_cols(spec, starts_with("lab_"), colWidth = "15%")
define_cols(spec, c(id, age, sex), isID = TRUE)
define_cols(spec, where(is.numeric), colWidth = "auto")
```

### 2. Style Consolidation

[`create_report()`](https://example.com/reference/create_report.md)
automatically:

- Merges `f_combine("style1", "style2")` into single `style_<hash>`
- Detects and reuses identical merged styles
- Removes unreferenced styles
- Validates all style references exist

### 3. Schema Validation

All specifications validated against JSON schema: - Type checking for
all fields - Enum validation for constrained values - Pattern matching
for formatted strings (colors, dimensions) - Ensures compatibility with
C++ renderer

### 4. Data Environment

Original data preserved (shadow-copy) in `.metadata$data_env` for: -
Conditional expressions in
[`compute_cols()`](https://example.com/reference/compute_cols.md) -
Helper functions (`firstOf()`, `lastOf()`, etc.) - Deferred evaluation
until
[`create_report()`](https://example.com/reference/create_report.md)

### 5. Vectorized Parameters

Most functions support vectorized inputs:

``` r
# Single value recycled
define_cols(spec, c(col1, col2, col3), colWidth = "33%")

# Individual values per column
define_cols(spec, c(col1, col2, col3), colWidth = c("20%", "30%", "50%"))
```

### 6. Built-in DOCX Renderer

The rendering engine provides a complete end-to-end pipeline:

- **Pixel-perfect text shaping** for deterministic text measurement
- **FreeType font loading** with automatic system font scanning and
  open-source fallback chain (Arial → Liberation Sans, Times New Roman →
  Liberation Serif, Courier New → Liberation Mono, Georgia → Liberation
  Serif, Verdana → Liberation Sans, Trebuchet MS → Liberation Sans)
- **Vertical & horizontal pagination** with configurable page break
  rules
- Support for all 3 document types (Table, Figure, Text)
- **Per-spec template rendering** in multi-spec reports (mixed
  `docTemplate` values)
- **Automatic TOC embedding** to the created documents
- Configurable style templates (`CRO Example_default` bundled)

### 7. Font Management

ksTFL automatically discovers fonts installed on the operating system at
package load time. The C++ font scanner inspects platform-specific
directories (Windows font folders, macOS system/user Library, Linux
freedesktop paths) and builds a font registry. System-installed
proprietary fonts are always preferred; only when a target font is
missing does the package fall back to a bundled open-source alternative.

**Target fonts and fallbacks:**

| Target Font     | Fallback (bundled) | License     |
|-----------------|--------------------|-------------|
| Arial           | Liberation Sans    | SIL OFL 1.1 |
| Times New Roman | Liberation Serif   | SIL OFL 1.1 |
| Courier New     | Liberation Mono    | SIL OFL 1.1 |
| Georgia         | Liberation Serif   | SIL OFL 1.1 |
| Verdana         | Liberation Sans    | SIL OFL 1.1 |
| Trebuchet MS    | Liberation Sans    | SIL OFL 1.1 |

#### Why proprietary fonts are not bundled

Arial, Times New Roman, Courier New, Georgia, Verdana, and Trebuchet MS
are proprietary fonts owned by Microsoft and/or Monotype. Their license
prohibits redistribution inside open-source packages. ksTFL therefore
bundles only the Liberation family (SIL OFL 1.1) as metrically
compatible fallbacks. For pixel-perfect output matching corporate
templates, install the original Microsoft fonts on the host system.

#### Installing Microsoft core fonts on Linux

The **`ttf-mscorefonts-installer`** package downloads and installs the
Microsoft TrueType core fonts (Arial, Times New Roman, Courier New,
Georgia, Verdana, Trebuchet MS, and others) from SourceForge. It is
available in most Linux distribution repositories.

**Debian / Ubuntu:**

``` bash
sudo apt-get update
sudo apt-get install -y ttf-mscorefonts-installer
sudo fc-cache -f
```

**Fedora / RHEL / CentOS (via RPM Fusion or manual SPEC):**

``` bash
# Fedora (requires RPM Fusion free repository to be enabled)
sudo dnf install -y curl cabextract xorg-x11-font-utils fontconfig
sudo rpm -i https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm
sudo fc-cache -f
```

**openSUSE:**

``` bash
sudo zypper install -y fetchmsttfonts
sudo fc-cache -f
```

**Arch Linux:**

``` bash
# Available from the AUR
yay -S ttf-ms-fonts
sudo fc-cache -f
```

After installing, restart R (or call
[`tfl_rescan_fonts()`](https://example.com/reference/tfl_rescan_fonts.md)
in a running session) so ksTFL picks up the new fonts.

#### Rocker Docker images

[Rocker](https://rocker-project.org/) images are Debian-based, so
`ttf-mscorefonts-installer` can be added directly. Include the following
in your Dockerfile:

``` dockerfile
FROM rocker/r-ver:4.4

# Accept the Microsoft EULA non-interactively and install core fonts
RUN echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" \
      | debconf-set-selections \
    && apt-get update \
    && apt-get install -y --no-install-recommends ttf-mscorefonts-installer fontconfig \
    && fc-cache -f \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

> **Tip:** The `debconf-set-selections` line automatically accepts the
> Microsoft EULA, which is required for non-interactive installs (CI/CD
> pipelines, Docker builds).

#### Custom font directories

Point the `ksTFL.font_dirs` option to directories containing proprietary
or additional fonts. These are scanned alongside system directories:

``` r
options(ksTFL.font_dirs = c("/opt/company-fonts", "~/my-fonts"))
tfl_rescan_fonts()
```

**Font management functions:**

| Function                                                                  | Purpose                                               |
|---------------------------------------------------------------------------|-------------------------------------------------------|
| [`tfl_font_status()`](https://example.com/reference/tfl_font_status.md)   | Print current font resolution report                  |
| [`tfl_rescan_fonts()`](https://example.com/reference/tfl_rescan_fonts.md) | Re-scan all font directories and print updated report |

------------------------------------------------------------------------

## Full Pipeline Example

``` r
library(ksTFL)

# 1. Create and customize spec
spec <- create_table(mtcars[1:10, ]) |>
  add_title("Motor Trend Car Road Tests") |>
  add_subtitle("Performance Metrics") |>
  add_footnote("Source: 1974 Motor Trend US magazine.") |>
  define_cols(c(mpg, cyl, hp), label = c("MPG", "Cylinders", "Horsepower"))

# 2. Assemble report
report <- create_report(spec)

# 3. Save + render to DOCX
write_doc(report, name = "demo", outDir = "output", metaPath = tempdir())
```

------------------------------------------------------------------------

## Dependencies

### R Packages

| Package        | Purpose                                    |
|----------------|--------------------------------------------|
| **cli**        | Formatted error messages and user feedback |
| **checkmate**  | Type-safe argument validation              |
| **jsonlite**   | JSON serialization/deserialization         |
| **tidyselect** | Column selection semantics                 |
| **rlang**      | Quasiquotation and evaluation              |
| **digest**     | Hash generation for style deduplication    |
| **purrr**      | Functional programming utilities           |
| **htmltools**  | Interactive spec preview (print method)    |
| **rstudioapi** | RStudio viewer integration                 |
| **Rcpp**       | R/C++ interface for rendering engine       |

------------------------------------------------------------------------

## License

This project is licensed under the GNU General Public License v3.0 or
later — see the [LICENSE](https://example.com/LICENSE) file for details.

------------------------------------------------------------------------

## Authors

**Igor Aleschenkov** **Vladimir Larchenko** ksTFL Team(C)

------------------------------------------------------------------------

## Architecture Note

**ksTFL** integrates metadata generation and document rendering in a
single R package:

- The **R layer** generates validated JSON specifications describing
  document structure, content, column formats, and styles
- The **C++ rendering engine** (built-in, C++20, used by
  [`write_doc()`](https://example.com/reference/write_doc.md) /
  [`replay_report()`](https://example.com/reference/replay_report.md))
  consumes these specifications and produces styled DOCX documents with
  deterministic pagination

This architecture enables: - Metadata generation (R) and rendering (C++)
are independently optimizable - Specifications are reusable,
serializable, and version-controllable - The complete pipeline runs
within a single R session — no external tools required - End-to-end
auditability from data to final document
