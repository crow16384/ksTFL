# ksTFL: Clinical Tables, Figures, and Listings Framework

[![License: GPL
v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://example.com/LICENSE)

![ksTFL logo](reference/figures/ksTFL-logo.svg)

## Overview

**ksTFL** is a professional R package for generating structured metadata
specifications for clinical Tables, Figures, and Listings (TFLs) in
pharmaceutical and clinical research. The package employs a declarative,
specification-first architecture to describe document structure, data
relationships, styling, and content formatting. Generated specifications
are validated against a JSON schema and rendered into submission-quality
styled DOCX documents via a built-in C++20 rendering engine with
deterministic HarfBuzz-based text measurement.

### Key Design Principles

- **Separation of Concerns**: Metadata generation (R) is decoupled from
  document rendering (C++ engine)
- **Schema-Driven Validation**: All specifications conform to a strict
  JSON schema ensuring consistency
- **Declarative Syntax**: Users describe *what* to render, not *how* to
  render it
- **Deterministic Pagination**: HarfBuzz text shaping guarantees
  pixel-perfect, reproducible layouts
- **Type Safety**: Comprehensive input validation with informative error
  messages
- **Reproducibility**: Specifications are serializable,
  version-controllable, and deterministic

------------------------------------------------------------------------

## Installation

Installed by the system administrator to working environment.

### System Requirements

The C++ rendering engine requires: - C++20 compiler (g++ 13+ or
equivalent) - HarfBuzz (\>= 2.0) — Unicode text shaping - FreeType (\>=
2.0) — Font loading and glyph metrics - minizip (zlib) — ZIP archive
creation for .docx

These are bundled in the Docker development image.

------------------------------------------------------------------------

## Quick Start Example

``` r
library(ksTFL)

# 1. Initialize a table specification
spec <- create_table(mtcars, cols = c(mpg, cyl, hp, wt))

# 2. Add document content
spec <- spec |>
  add_title("Motor Trend Car Road Tests", styleRef = "title_main") |>
  add_subtitle("Performance Metrics by Cylinder Count") |>
  add_footnote("Source: 1974 Motor Trend US magazine")

# 3. Define column properties
spec <- spec |>
  define_cols(c(mpg, hp), 
              label = c("Miles/(US) gallon", "Horsepower"),
              colWidth = c("25%", "25%")) |>
  define_cols(cyl, 
              label = "Cylinders", 
              isGrouping = TRUE, 
              dedupe = TRUE)

# 4. Apply conditional row styling
spec <- spec |>
  compute_cols(hp > 200, 
               c_style(hp, styleRef = "highlight_red"))

# 5. Create report and render to DOCX
report <- create_report(spec)
write_doc(report, name = "mtcars_report", outDir = "output", metaPath = tempdir())
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
| `isColBreak`    | Mark horizontal pagination break point                            | `TRUE`                   |
| `dedupe`        | Remove duplicate consecutive values                               | `TRUE`                   |
| `blankAfter`    | Insert blank row after value change                               | `TRUE`                   |
| `type`          | Override auto-detected column type                                | `"numeric"` / `"string"` |
| `format`        | Override auto-detected display format                             | `"0.00"` / `"%d"`        |
| `missings`      | Custom representation for missing values                          | `"N/A"`                  |
| `colWidth`      | Set width (%, cm, pt, in, mm, auto)                               | `"25%"` / `"3cm"`        |
| `valueStyleRef` | Style reference for cell values                                   | `"numeric_right"`        |

### Conditional Row Styling

Apply dynamic styling based on data conditions:

| Function                                                        | Purpose                               | Example                                                            |
|-----------------------------------------------------------------|---------------------------------------|--------------------------------------------------------------------|
| `compute_cols(spec, condition, ...)`                            | Evaluate condition and apply actions  | `compute_cols(spec, age > 65, c_style(value, styleRef = "alert"))` |
| `c_style(cols, styleRef)`                                       | Apply style to specified columns      | `c_style(c(col1, col2), styleRef = "bold")`                        |
| `c_merge(cols, styleRef)`                                       | Merge specified columns into one cell | `c_merge(c(col1, col2, col3))`                                     |
| `c_addrow(position, value_from, styleRef)`                      | Insert row above/below                | `c_addrow("above", group_col, styleRef = "header")`                |
| [`c_pageBreak()`](https://example.com/reference/c_pageBreak.md) | Insert page break at matching rows    | [`c_pageBreak()`](https://example.com/reference/c_pageBreak.md)    |

**Helper Functions for Conditions**: - `firstOf(...)`: TRUE for first
occurrence of each value combination - `lastOf(...)`: TRUE for last
occurrence of each value combination - `firstRow()`: TRUE only for first
data row - `lastRow()`: TRUE only for last data row - `everyNth(n)`:
TRUE every n-th row (e.g., `everyNth(3)` for rows 1, 4, 7, …) -
`rowNumber()`: Row index (1-based) - `firstOfBlock(col, n, offset)`:
Logical vector marking first row of every n-th block defined by `col`

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

**Context-Based Nesting Rules**: -
[`s_font()`](https://example.com/reference/s_font.md),
[`s_paragraph()`](https://example.com/reference/s_paragraph.md),
[`s_table_style()`](https://example.com/reference/s_table_style.md) —
direct children of
[`add_style()`](https://example.com/reference/add_style.md) -
[`s_borders()`](https://example.com/reference/s_borders.md) — must be
inside `s_table_style(borders = s_borders(...))` -
[`s_spacing()`](https://example.com/reference/s_spacing.md),
[`s_indents()`](https://example.com/reference/s_indents.md) — must be
inside [`s_paragraph()`](https://example.com/reference/s_paragraph.md) -
Built-in target font atoms are available for direct `styleRef`
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

Configure global defaults:

| Function                                                                    | Purpose                                               |
|-----------------------------------------------------------------------------|-------------------------------------------------------|
| `tfl_set_options(...)`                                                      | Set package-level options (replaces, not accumulates) |
| [`tfl_get_options()`](https://example.com/reference/tfl_get_options.md)     | Retrieve all current options                          |
| `tfl_get_option(name)`                                                      | Retrieve single option value                          |
| [`tfl_reset_options()`](https://example.com/reference/tfl_reset_options.md) | Reset all options to defaults                         |

**Configurable Options**: - `autoColWidth`: Auto-recalculate column
widths (default: `TRUE`) - `missings`: Default representation for
missing values (default: `""`) - Predefined styles: Define styles once,
use across all specs via
[`add_style()`](https://example.com/reference/add_style.md) on options -
Default headers/footers: Apply to all documents via
[`add_header()`](https://example.com/reference/add_header.md) /
[`add_footer()`](https://example.com/reference/add_footer.md) on
options - Default body text, page style, and document template

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
automatically: - Merges `f_combine("style1", "style2")` into single
`style_<hash>` - Detects and reuses identical merged styles - Removes
unreferenced styles - Validates all style references exist

### 3. Schema Validation

All specifications validated against JSON schema: - Type checking for
all fields - Enum validation for constrained values - Pattern matching
for formatted strings (colors, dimensions) - Ensures compatibility with
C++ renderer

### 4. Data Environment

Original data preserved in `.metadata$data_env` for: - Conditional
expressions in
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

The C++20 rendering engine provides a complete end-to-end pipeline: -
**HarfBuzz text shaping** for deterministic text measurement -
**FreeType font loading** with automatic system font scanning and
open-source fallback chain (Arial → Liberation Sans, Times New Roman →
Liberation Serif, Courier New → Liberation Mono, Georgia → Liberation
Serif, Verdana → Liberation Sans, Trebuchet MS → Liberation Sans) -
**Vertical & horizontal pagination** with configurable page break
rules - **OOXML emission** into valid .docx ZIP packages - Support for
all 3 document types (Table, Figure, Text) - **Per-spec template
rendering** in multi-spec reports (mixed `docTemplate` values) - Inline
markup: `**bold**`, `*italic*`, `__underline__`, `~~strikethrough~~` -
Structural borders (header top/bottom, table bottom) - Title soft-break
rendering (combined paragraph with per-group font styling) -
Configurable style templates (`CRO Example_default` bundled)

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

### System Libraries

| Library                | Purpose                                            |
|------------------------|----------------------------------------------------|
| **HarfBuzz** (\>= 2.0) | Unicode text shaping for deterministic measurement |
| **FreeType** (\>= 2.0) | Font loading and glyph metrics                     |
| **minizip** (zlib)     | ZIP archive creation for .docx output              |

------------------------------------------------------------------------

## Building the pkgdown site

From the package root in R:

``` r
# Optional: longer timeout if CRAN is slow (downlit fetches packages.rds when building articles)
options(timeout = 120)
pkgdown::build_site(pkg = ".", install = FALSE, preview = FALSE)
```

- **X11 / headless**: Vignettes set `dev = "cairo_png"` so the site
  builds without an X11 display. Example plots use
  `png(..., type = "cairo")` where needed.
- **CRAN timeout**: Building articles uses **downlit**, which fetches
  `https://cran.rstudio.com/web/packages/packages.rds`. If that times
  out, run with network access and/or increase `options(timeout = 120)`
  (or higher). For fully offline builds, use the **pkgdown.offline**
  package and call `pkgdown.offline::build_site()` instead.

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
