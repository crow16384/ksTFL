# ksTFL: Clinical Tables, Figures, and Listings Framework

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

<img src="man/figures/ksTFL-logo.svg" alt="ksTFL logo" width="700" />

## Overview

**ksTFL** is a professional R package designed to fill a long-standing gap in the R ecosystem: the lack of a dedicated, end-to-end solution for producing well-formatted, regulatory-compliant clinical Tables, Figures, and Listings (TFLs). While R excels at statistical analysis, generating submission-quality DOCX outputs that meet pharmaceutical industry standards has traditionally required fragile workarounds or external tooling. ksTFL solves this by distilling the best ideas from existing reporting solutions into a simple, minimalistic, yet highly flexible declarative language — a compact set of composable functions whose combinations can produce virtually any clinical output format.

The core philosophy is **data–presentation separation**: input data stays clean and planar, free of reporting artefacts such as merged cells, indentation columns, or display-only rows. Formatting, pagination, grouping, and styling are declared independently and applied at render time. This keeps datasets maintainable, traceable, and validation-ready — exactly what regulated environments demand.

Under the hood, a built-in **rendering engine** with text shaping converts declarative specs into styled DOCX documents with deterministic, pixel-perfect pagination. Rendering is extremely fast even on large datasets, making ksTFL practical for batch production of hundreds of outputs in a single pipeline run.

### Key Design Principles

- **Separation of Concerns**: Metadata generation (R) is decoupled from document rendering; input data remain clean and analysis-ready
- **Declarative Syntax**: Users describe *what* to render, not *how* to render it — a small function vocabulary covers the full range of clinical outputs
- **Deterministic Pagination**: font shaping guarantees pixel-perfect, reproducible layouts and pagination
- **High Performance**: C++ engine renders large multi-spec reports in seconds
- **Type Safety**: Comprehensive input validation with informative error messages
- **Reproducibility**: Specifications are serializable. This allows storing metadata for replay without re-running the full pipeline

---

## Installation

Install the CRAN release with:

```r
install.packages("ksTFL")
```

Documentation: <https://crow16384.github.io/ksTFL/>

📄 **[Download Cheatsheet (PDF)](https://github.com/crow16384/ksTFL/raw/CRAN/inst/extdata/ksTFL_cheatsheet_0_11_x.pdf)**

### Fonts note

Proprietary Microsoft fonts (Arial, Times New Roman, etc.) are **not bundled** due to licensing restrictions; open-source Liberation fonts are included as metrically compatible fallbacks. Windows and macOS systems with Microsoft Office installed typically have the original fonts already available. On Linux, additional steps may be required — see [Font Management](#7-font-management) for details.

### Dependencies

`install.packages()` resolves and installs declared `Imports` automatically from CRAN. If you need to install them manually — for example after installing from a local file — run:

```r
# Using pak (recommended)
pak::local_install_deps()

# Using remotes / devtools
remotes::install_deps(dependencies = TRUE)
```

Required packages (`Imports`): `cli`, `checkmate`, `jsonlite`, `purrr`, `rlang`, `tidyselect`, `digest`, `htmltools`, `rstudioapi`, `Rcpp`

Optional packages required for shiny addins to work: `shiny`, `colourpicker`, `sortable`, `shinyFiles`

---

## Quick Start Example

```r
library(ksTFL)

# 1. Initialize a table specification
spec <- create_table(mtcars, cols = c(cyl, mpg, hp, wt))

# 2. Add document content
spec <- spec |>
  add_title("Motor Trend Car Road Tests", styleRef = "i") |>
  add_title("Performance Metrics by Cylinder Count", styleRef = "i") |>
  add_subtitle("Number of Cylinders: #ByGroup1", styleRef = f_combine("fc_blue", "tw_50")) |>
  add_footnote("Source: 1974 Motor Trend US magazine", styleRef = "tw_50")

# 3. Define column properties
spec <- spec |>
  define_cols(c(mpg, hp, wt), 
              label = c("Miles/(US) gallon", "Horsepower", "Weight<br>(1000 lbs)"),
              valueStyleRef = "ac"
              ) |>
  define_cols(cyl, 
              isGrouping = TRUE, 
              isVisible =  FALSE)

# 4. Apply conditional row styling
spec <- spec |>
  compute_cols(hp > 200, 
               c_style(hp, styleRef = "fc_red"))

spec <- spec |> set_document(contentWidth = "50%")

# 5. Create report and render to DOCX
report <- create_report(spec)
```

---

## API Reference

### Document Initialization

Create specification objects for different document types:

| Function | Purpose | Typical usage |
|----------|---------|---------------|
| `create_table(data, cols = everything())` | Start a table specification from a data frame | `create_table(adsl, cols = c(USUBJID, AGE, TRT01A))` |
| `create_figure(plot_or_path, dpi = 300L)` | Start a figure specification from a file path or ggplot object | `create_figure(p)` or `create_figure("figures/pk_plot.png")` |
| `create_text()` | Start a text-only specification for narratives and notes | `create_text() |> add_body_text("No protocol deviations.")` |

### Content Functions

Add document elements to specifications:

| Function | What it adds | Practical usage notes |
|----------|--------------|-----------------------|
| `add_title(spec, text, id, styleRef, order)` | Main document title rows | Use `toclevel` when you want entries in TOC. `styleRef` can be a named style or `f_combine(...)`. |
| `add_subtitle(spec, text, id, styleRef, order)` | Secondary title rows | Useful for dynamic section context such as group labels. Also supports `toclevel`. |
| `add_footnote(spec, text, id, styleRef, order)` | Footnotes tied to table/figure/text output | Placement is controlled by `footnotePlace` in `set_document()` / options. |
| `add_body_text(spec, text, id, styleRef, order)` | Narrative paragraphs inside Text specs, or fallback text | Great for listings, narrative outputs, and no-data messages. |
| `add_header(spec, ..., level)` | Page header rows (left/center/right cells) | Up to 3 cells per row; combine with `tfl_set_options(add_header(...))` for session defaults. |
| `add_footer(spec, ..., level)` | Page footer rows (left/center/right cells) | Works like headers; useful for confidentiality and page metadata. |
| `add_span_header(spec, cols, label, stubOrder, id, labelStyleRef)` | Multi-column group headers above labels | `stubOrder` controls hierarchy depth; use same `stubOrder` for siblings in one header row. |

### Column Configuration

Define column properties and formatting:

```r
define_cols(spec, cols, label, isVisible, isID, isGrouping, isPaging,
            labelStyleRef, isColBreak, dedupe, blankAfter,
            type, format, missings, colWidth, valueStyleRef)
```

**Column Parameters** (all support 1-or-n vectorized values):

| Parameter | Purpose | Example |
|-----------|---------|---------|
| `label` | Column display labels | `"Age (years)"` |
| `isVisible` | Show/hide columns (hidden = 0 width, data still accessible) | `TRUE` / `FALSE` |
| `isID` | Identify key columns | `TRUE` |
| `isGrouping` | Enable grouping behavior (boundary detection for dedup/subtitles) | `TRUE` |
| `isPaging` | Force page breaks on value change | `TRUE` |
| `labelStyleRef` | Style reference for column headers | `"header_bold"` |
| `valueStyleRef` | Style reference for cell values | `"numeric_right"` |
| `isColBreak` | Mark horizontal pagination break point | `TRUE` |
| `dedupe` | Remove duplicate consecutive values | `TRUE` |
| `blankAfter` | Insert blank row after value change | `TRUE` |
| `type` | Override auto-detected column type | `"numeric"` / `"string"` |
| `format` | Override auto-detected display format | `"%.1f"` / `"%d"` |
| `missings` | Custom representation for missing values | `"N/A"` |
| `colWidth` | Set width (%, cm, pt, in, mm, auto) | `"25%"` / `"3cm"` |


### Conditional Row Styling

`compute_cols()` is the parent rule function. You define one condition and pass one or
more action helpers as sibling arguments in the same call.

| Layer | Function | What it does | Example |
|------|----------|--------------|---------|
| Parent rule | `compute_cols(spec, condition, ...)` | Evaluates `condition` row-wise during `create_report()` and applies all provided actions to matching rows | `compute_cols(spec, AGE > 65, c_style(AGE, "b"), c_addrow("above"))` |
| Action helper | `c_style(cols, styleRef)` | Apply style(s) to selected columns in matching rows | `c_style(c(PARAM, AVAL), styleRef = f_combine("b", "fc_red"))` |
| Action helper | `c_merge(cols, styleRef = NULL)` | Merge adjacent columns into one displayed span in matching rows | `c_merge(c(TRT_A, TRT_B), styleRef = "ac")` |
| Action helper | `c_addrow(pos, value_from = NULL, styleRef = NULL)` | Insert a row above/below matching rows, optionally populated from a source column | `c_addrow("below", value_from = PARAM)` |
| Action helper | `c_pageBreak()` | Force a page break at matching rows | `c_pageBreak()` |
| Action helper | `c_glue(cols, position, glue_col = NULL, text = NULL, separator = NULL)` | Append/prepend a column value or literal text to existing cell text | `c_glue(PARAM, "after", glue_col = UNIT, separator = " ")` |
| Action helper | `c_clear(cols)` | Clear displayed text in selected cells while keeping structure/styling | `c_clear(PARAM)` |

**Helper Functions for Conditions**:

These helpers exist because many reporting rules are boundary-based (first row
in a group, last row in a block, alternating stripes, etc.) and are hard to
express clearly with raw boolean logic alone.

| Helper | What it returns | When it is most useful |
|--------|------------------|------------------------|
| `firstOf(...)` | `TRUE` at first row of each unique value combination | Insert section headers, style group starts, trigger page breaks at group boundaries |
| `lastOf(...)` | `TRUE` at last row of each unique value combination | Add subtotal/summary rows, blank-after separators, final group emphasis |
| `firstRow()` | `TRUE` only for row 1 | Add top banners, first-row highlights, initial spacing rows |
| `lastRow()` | `TRUE` only for last row | Add closing notes, final-row separators, tail summaries |
| `everyNth(n)` | `TRUE` on rows `1, n+1, 2n+1, ...` | Zebra striping and periodic visual guides in dense listings |
| `rowNumber()` | 1-based integer row index | Positional rules such as “top 5”, modulo patterns, custom ranking displays |
| `firstOfBlock(col, n, offset)` | `TRUE` at first row of every `n`-th block by `col` | Controlled periodic headers/page breaks in repeating grouped structures |

### Style Definitions

Define and compose styles:

ksTFL already ships with a large set of predefined atomic styles (font,
alignment, spacing, borders, colors, indentation, etc.). In many real workflows
you do not need to author many new styles: combine existing atoms with
`f_combine()` and add only a small number of study-specific named styles.

| Function | Purpose | Affects in MS Word output |
|----------|---------|---------------------------|
| `add_style(spec, id, ...)` | Define a reusable named style | Creates/updates a style entry used later by `styleRef` fields |
| `s_font(font_name, font_size, bold, italic, underline, color, highlight)` | Run-level text appearance | Font family, size, emphasis, text color, highlight/shading |
| `s_paragraph(alignment, spacing, indents, ...)` | Paragraph block formatting | Alignment, spacing, indentation, keep-with-next / keep-lines behaviors |
| `s_spacing(before, after, line_spacing)` | Paragraph spacing micro-control | Space before/after paragraph and line spacing |
| `s_indents(left, right, first_line)` | Paragraph indentation control | Left/right indents and first-line/hanging indent behavior |
| `s_table_style(background_color, row_height, topEmptyLine, bottomEmptyLine, vertical_alignment, text_orientation, borders)` | Cell and row presentation | Cell fill, row height, vertical align, text direction, cell borders |
| `s_borders(top, bottom, left, right)` | Border set for cell edges | Border presence/style on each side of a cell |
| `s_border(color, width, line_style)` | One border edge definition | Border color, thickness, and line style (single/double/etc.) |
| `f_combine(...)` | Combine multiple style references | Merge several style refs into one effective style application |

**Context-Based Nesting Rules**:

- `s_font()`, `s_paragraph()`, `s_table_style()` — direct children of `add_style()`
- `s_borders()` — must be inside `s_table_style(borders = s_borders(...))`
- `s_spacing()`, `s_indents()` — must be inside `s_paragraph()`
- Built-in target font atoms are available for direct `styleRef` composition: `font_arial`, `font_courier_new`, `font_times_new_roman`, `font_georgia`, `font_verdana`, `font_trebuchet_ms`

**Example Style Definition**:

```r
# Define one reusable custom style (study-specific)
spec <- add_style(spec, id = "header_style",
  s_font(font_name = "Arial", font_size = "12pt", bold = TRUE, color = "#333333"),
  s_paragraph(alignment = "center", spacing = s_spacing(after = "6pt")),
  s_table_style(background_color = "#E8E8E8", borders = s_borders(
    bottom = s_border(color = "black", width = "2pt", line_style = "double")
  ))
)

# Use the custom style directly
spec <- add_title(spec, "Table 14.1 Demographics", styleRef = "header_style")

# Combine the custom style with built-in atomic styles for a specific context:
# - "tw_80": narrow text block width
# - "fc_navy": override font color to navy
spec <- add_footnote(
  spec,
  "Source: ADSL",
  styleRef = f_combine("header_style", "tw_80", "fc_navy")
)

# Use only built-in atoms when no custom style is needed
spec <- define_cols(spec, mpg, valueStyleRef = f_combine("font_verdana", "fs_10", "ar"))
```

### Document Configuration

Configure document-level settings:

| Function | What it configures | Most useful parameters and behavior |
|----------|---------------------|-------------------------------------|
| `set_document(spec, ...)` | Spec-level document behavior and figure settings | `hasData`, `footnotePlace`, `contentWidth`, `isContinues`, `continuousSection`, `docTemplate`, `figureWidth`, `figureHeight`, `figureDevice`, `figureScaleMode`, `topEmptyLine`, `bottomEmptyLine` |
| `set_page_style(spec, docTemplate, page)` | Template + page geometry for the spec | Use bundled template name or JSON path for `docTemplate`; use `page = p_page(...)` for size/orientation/margins |
| `p_page(size, orientation, margins)` | Structured page descriptor used by `set_page_style()` | Typical values: `"A4"`, `"Letter"`, `"Legal"`; `"portrait"` or `"landscape"`; margins from `p_margins(...)` |
| `p_margins(top, bottom, left, right, header, footer)` | Margin distances for page/body/header/footer zones | All inputs support dimension strings like `"1in"`, `"2.54cm"`, `"72pt"`, `"25mm"` |

Practical guidance:

- Use `set_document()` for per-spec behavior and content logic.
- Use `set_page_style()` when you need layout/template changes.
- Use `continuousSection = TRUE` only when a following spec should continue on
  the same page as the previous one.
- Use `isContinues = TRUE` when repeated titles/subtitles on each page are not desired.

### Document Templates

Templates are JSON style/layout presets used by the renderer as the visual
baseline for each spec. A template typically defines:

- Page defaults (size, orientation, margins)
- Region text styles (titles, subtitles, footnotes, body text, doc header/footer)
- Table defaults (header/body styling, structural borders/backgrounds)
- Figure defaults (caption and placement-related style defaults)

Why templates are needed:

- They provide consistent branding and submission formatting across outputs.
- They keep repeated visual rules out of analysis code.
- They let one pipeline render different document families (for example,
  CRO-internal vs sponsor-facing formats) by switching template only.

How templates interact with user-defined styles:

- Template styles are the baseline.
- `add_style()` definitions and `styleRef` values are merged on top of template defaults.
- `f_combine(...)` merges multiple refs in order (last wins for overlapping properties).
- Inline markup in text (for example `<b>...</b>`) has highest run-level priority.

Practical precedence (high level):

1. Template defaults
2. Template region/structural styles
3. Column- and content-level `styleRef`
4. Row-action style refs (`compute_cols` actions)
5. Inline text markup

Template-only controls (not overridable by `add_style()` / `styleRef`):

- Table layout switches from template layout:
  `table_alignment`, `allow_row_break_across_pages`, `repeat_header_on_each_page`
- Structural table borders from template structural section:
  `header_top_border`, `header_bottom_border`, `table_bottom_border`
- Default table cell margins from template layout (`default_cell_margin_*`)
- Figure layout behavior from template figure style:
  caption position (`above`/`below`), figure alignment, and default caption spacing
- Base document header/footer and TOC style regions (`docHeader`, `docFooter`,
  `tocTitle`, `tocEntry`) in normal API usage

Important distinction:

- `styleRef` and `add_style()` are for text/cell style composition.
- Template settings above are layout/structural controls and must be changed
  in the template JSON (or by selecting a different template), not via `styleRef`.
- Page geometry can still be overridden per spec via `set_page_style(page = p_page(...))`;
  that is a page override, not a style override.

How to choose the template source:

- Per-spec template: set `docTemplate` on each spec (`set_page_style()` or options).
- Global render override: pass `overrideTemplate` in `write_doc()`/
  `replay_report()` to force one template for the full output.
- Discover bundled templates with `tfl_list_templates()`.

```r
# Per-spec template selection
spec <- create_table(adsl) |>
  set_page_style(docTemplate = "Navy_Pro") |>
  add_style(id = "study_title", s_font(bold = TRUE, color = "#1F3864")) |>
  add_title("Table 14.1: Demographics", styleRef = f_combine("study_title", "tw_80"))

report <- create_report(spec)

# Optional global override: forces one template for all specs in this render
write_doc(report, name = "t14_1", overrideTemplate = "CRO Example_default")
```

### Report Assembly & Rendering

Combine specifications into reports and render to DOCX:

| Function | Purpose | Why/when to use it |
|----------|---------|--------------------|
| `create_report(...)` | Assemble one or many specs into a report object | Use before output to consolidate styles, finalize deferred row actions, and assign document order/data references |
| `save_report(report, docFileName, outDir, metaPath, prettify, insertTOC, tocTitle)` | Persist report metadata and payload files to disk | Use for audit trails, CI artifacts, reproducibility, or debugging JSON before rendering |
| `write_doc(report, name, outDir, metaPath, prettify, toc, tocTitle, overrideTemplate, font_dirs, fallback_font, verbose)` | One-step save + render path | Best default for production pipelines when you want final DOCX output immediately |
| `replay_report(spec_json, meta_dir, output_path, template_json, overrideTemplate, insertTOC, tocTitle, verbose)` | Render from saved JSON (single or merged multi-report inputs) | Use for exact re-rendering, delayed rendering on another machine, and combining previously saved outputs |

How the output layers fit together:

| Layer | Output | Why it matters |
|-------|--------|----------------|
| In-memory assembly (`create_report`) | A coherent in-memory report object with resolved style refs and evaluated row-action metadata | Ensures the document is fully prepared before persistence or rendering |
| Persistent metadata (`save_report`) | Spec JSON + referenced data/figure payloads + metadata index | Enables reproducibility, handoff, and diff/debug of rendering inputs |
| One-step production (`write_doc`) | Final DOCX plus persisted metadata bundle | Simplest path for routine report generation |
| Replay (`replay_report`) | DOCX rendered from saved metadata without rebuilding specs in R | Supports deterministic regeneration, centralized rendering, and multi-document merge workflows |

**create_report() Features**:

- Consolidates styles across specs (deduplicates merged styles)
- Validates all style references exist
- Assigns sequential document order
- Generates unique data references
- Evaluates deferred `compute_cols()` conditions against data environment
- Supports mixing `TFL_spec` and `TFL_report` objects

**save_report() Parameters**:

- `report`: A `TFL_report` object from `create_report()`
- `docFileName`: Output filename (e.g., `"report.docx"`)
- `outDir`: Output directory (defaults to tfl_options)
- `metaPath`: Directory for metadata/data files (defaults to `tempdir()`)
- `prettify`: If `TRUE`, formats JSON output for debugging

**write_doc() Parameters**:

- `report`: A `TFL_report` object from `create_report()`
- `name`: Base output filename (without `.docx`)
- `outDir`: Output directory for the final DOCX
- `metaPath`: Directory for metadata/data files
- `overrideTemplate`: Optional global template override (name or JSON path)
- `font_dirs`: Additional font search directories (optional)
- `fallback_font`: Custom fallback font path (optional)
- `verbose`: Print progress messages (default: `FALSE`)

### Package Options

Configure global defaults that apply to all specs in a session:

| Function | Purpose |
|----------|---------|
| `tfl_set_options(...)` | Set package-level options (replaces, not accumulates) |
| `tfl_get_options()` | Retrieve all current options |
| `tfl_get_option(name)` | Retrieve single option value |
| `tfl_reset_options()` | Reset all options to defaults |
| `tfl_list_templates()` | List available bundled document templates |

**All Configurable Parameters**:

| Parameter | Default | Type | Description |
|-----------|---------|------|-------------|
| `docTemplate` | `"Default"` | Character | Document style template (bundled name or path to JSON). Use `tfl_list_templates()` to list available embedded templates, or use template editor shiny addin to create your own |
| `contentWidth` | `"100%"` | Character | Main content area width (e.g., `"95%"`, `"16.51cm"`, `"6.5in"`) |
| `footnotePlace` | `"repeated"` | Character | Footnote placement: `"repeated"` (every page), `"last_page"`, or `"doc_footer"` |
| `isContinues` | `FALSE` | Logical | Suppress repeating headers on every page of the document |
| `missings` | `"NA"` | Character | Default representation for missing/NA values (e.g., `"."`, `"---"`, `"N/A"`) |
| `autoColWidth` | `TRUE` | Logical | Auto-recalculate unlocked column widths; when `FALSE` manage all widths manually |
| `minColWidth` | `0.5` | Numeric | Minimum relative width (%) for unlocked columns during auto-recalculation |
| `figureWidth` | `"6in"` | Character | Default figure width (e.g., `"70%"`, `"6.5in"`, `"16.51cm"`) |
| `figureHeight` | `"4in"` | Character | Default figure height (same format as `figureWidth`) |
| `figureDevice` | `"svg"` | Character | Graphics device for ggplot2 rendering: `"svg"`, `"png"`, `"jpeg"` |
| `figureScaleMode` | `"fixed"` | Character | Figure scaling: `"fixed"`, `"fitWidth"` (scale to page width), `"fitPage"` |
| `insertTOC` | `FALSE` | Logical | Prepend a Table of Contents page (requires `toclevel` on titles) |
| `tocTitle` | `"Table of Contents"` | Character | TOC page heading; use `""` to omit |
| `output_directory` | `"."` | Character | Default output directory for rendered documents |
| `meta_directory` | `NULL` | Character | Directory for intermediate metadata files; `NULL` defaults to output dir or temp |

**Page Layout** (via `set_page_style()` or `tfl_set_options(set_page_style(...))`):

| Parameter | Default | Valid Values |
|-----------|---------|--------------|
| `page.size` | `"A4"` | `"A4"`, `"A3"`, `"Letter"`, `"Legal"`, `"Executive"` |
| `page.orientation` | `"landscape"` | `"portrait"`, `"landscape"` |
| `page.margins` | Template default | Created via `p_margins(top, bottom, left, right, header, footer)` — all accept dimension strings (e.g., `"25mm"`, `"1in"`, `"2.54cm"`, `"72pt"`) |

**Shared Content** — define once, applied to every spec:

- Predefined **styles**: `tfl_set_options(add_style(id = "my_style", s_font(bold = TRUE)))` — available in all specs via `styleRef`
- Default **headers/footers**: `tfl_set_options(add_header("Left", "Center", "Right"))` — up to 3 cells per row
- Default **body text**: `tfl_set_options(add_body_text("No data to report"))` — shown when spec has no data

```r
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
  add_header("Company Name", "", "Page {PAGE} of {NUMPAGES}"),
  add_footer("Confidential", "", format(Sys.Date(), "%Y-%m-%d")),
  add_style(id = "alert", s_font(color = "#FF0000", bold = TRUE))
)
```

### Atomic Styles (Built-in Style Atoms)

ksTFL ships with 100+ **atomic styles** — single-property building blocks that can be used directly as `styleRef` values or combined with `f_combine()`. Each atom sets exactly **one** visual property, making styles composable and predictable.
Use `tfl_print_style_atoms()` to print all available atomic styles, or use the add-in to call this function.

**Usage**: pass atom IDs directly to any `styleRef` parameter, or combine multiple atoms:

```r
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

| Atom | Alias | Effect |
|------|-------|--------|
| `b` | `font_bold` | Bold |
| `i` | `font_italic` | Italic |
| `u` | `font_underline` | Underline |

**Font — Family**

| Atom | Font |
|------|------|
| `font_arial` | Arial |
| `font_courier_new` | Courier New |
| `font_times_new_roman` | Times New Roman |
| `font_georgia` | Georgia |
| `font_verdana` | Verdana |
| `font_trebuchet_ms` | Trebuchet MS |

**Font — Size** (`fs_7` through `fs_11`): `fs_7`, `fs_8`, `fs_9`, `fs_10`, `fs_11` (7–11 pt)

**Font — Color**

| Atom | Hex | Use Case |
|------|-----|----------|
| `fc_black` | #000000 | Default / reset |
| `fc_red` | #FF0000 | Alert / out-of-range |
| `fc_blue` | #0000FF | Informational |
| `fc_green` | #008000 | Within-range / pass |
| `fc_gray` / `fc_grey` | #595959 | Secondary / reference |
| `fc_navy` | #1F3864 | Dark formal headers |
| `fc_teal` | #2E75B6 | Medium blue |
| `fc_olive` | #5C7A29 | Muted green |
| `fc_rust` | #C0392B | Muted red / caution |
| `fc_plum` | #7B2D8B | Purple / special |
| `fc_slate` | #44546A | Blue-gray / subdued |

**Text Highlight** (background shading behind text)

| Atom | Hex | Atom | Hex |
|------|-----|------|-----|
| `hl_yellow` | #FFFF00 | `hl_peach` | #FADADD |
| `hl_red` | #FF0000 | `hl_mint` | #D5F5E3 |
| `hl_green` | #90EE90 | `hl_sky` | #D6EAF8 |
| `hl_gray` / `hl_grey` | #EEEEEE | `hl_lemon` | #FEFBD8 |
| | | `hl_lilac` | #E8DAEF |

**Paragraph — Alignment**

| Atom | Alias | Alignment |
|------|-------|-----------|
| `al` | `text_left` | Left |
| `ac` | `text_center` | Center |
| `ar` | `text_right` | Right |

**Paragraph — Indentation** (0.5 cm steps): `ind0`–`ind4` (left), `rind0`–`rind4` (right). Aliases: `indent_0`–`indent_4`, `rindent_0`–`rindent_4`.

**Paragraph — Table-Width Shrink** (`tw_95`–`tw_50` in 5% steps): symmetric left+right indent to align titles/footnotes/body text with a narrower table. Calculated for A4 landscape with 0.5 in margins.

**Paragraph — Spacing**: `sp_0` (0 pt), `sp_2` (2 pt), `sp_4` (4 pt) — before and after, line spacing 1.0.

**Paragraph — Pagination**: `kl` (keep lines together on same page), `kn` (keep with next row).

**Cell — Vertical Alignment**: `va_t` / `va_top`, `va_m` / `va_center`, `va_b` / `va_bottom`.

**Cell — Text Orientation**: `to_h` / `text_horizontal`, `to_90` / `text_vertical_90` (bottom-to-top), `to_270` / `text_vertical_270` (top-to-bottom).

**Cell — Background Color**

| Atom | Hex | Atom | Hex |
|------|-----|------|-----|
| `bg_blue` | #D9E1F2 | `bg_peach` | #FADADD |
| `bg_gray` / `bg_grey` | #F2F2F2 | `bg_mint` | #D5F5E3 |
| `bg_navy` | #1F3864 | `bg_sky` | #D6EAF8 |
| `bg_slate` | #44546A | `bg_lemon` | #FEFBD8 |
| `bg_steel` | #BDD7EE | `bg_lilac` | #E8DAEF |

**Row Height** (spacer rows): `row_h2` (2 pt), `row_h4` (4 pt), `row_h6` (6 pt).

**Borders**: `bt`, `bb`, `bl`, `br` (1 pt black, single line); `bt_th`, `bb_th` (0.5 pt thin); `bc_gray`/`bc_grey` (color override to gray), `bc_white` (suppress all borders).

**Group Header Composites**: `grp_hdr` (bold + indent reset + 4 pt space-before), `grp_hdr_i` (bold + italic + indent reset + 4 pt space-before).

```r
# Compose atoms for a styled separator row
spec <- compute_cols(spec, lastOf(category),
  c_addrow("below", category,
           styleRef = f_combine("row_h2", "bb_th", "bc_gray")))

# Group header with bold + space above
spec <- compute_cols(spec, firstOf(param),
  c_addrow("above", param, styleRef = "grp_hdr"))
```

### Inline Text Markup

ksTFL supports HTML-like inline markup tags in any text content — cell values, column labels, titles, subtitles, footnotes, headers, footers, and body text. Tags are parsed by the C++ rendering engine and converted to styled OOXML runs in the output DOCX.

**Supported Tags**:

| Tag | Effect | Example |
|-----|--------|---------|
| `<b>...</b>` | **Bold** | `"Total: <b>125</b> subjects"` |
| `<i>...</i>` | *Italic* | `"p-value<i>(two-sided)</i>"` |
| `<u>...</u>` | Underline | `"See <u>Table 14.1</u>"` |
| `<s>...</s>` | ~~Strikethrough~~ | `"<s>Deprecated</s> Updated"` |
| `<sup>...</sup>` | Superscript | `"E=mc<sup>2</sup>"` |
| `<sub>...</sub>` | Subscript | `"H<sub>2</sub>O"` |
| `<br>` or `<br/>` | Line break (soft, within same paragraph) | `"Revenue<br>(Millions of $)"` |
| `<p>` | Paragraph break (starts a new paragraph) | `"First paragraph<p>Second paragraph"` |

**Key Characteristics**:

- **Nesting**: fully supported — `<b><i>bold italic</i></b>`
- **Case-insensitive**: `<B>`, `<b>`, both work
- **Literal tag text**: escape `<` with backslash — e.g. `\<i>literal\</i>` renders as `<i>literal</i>`
- **No attributes**: tags carry no attributes; use the style system for colors, fonts, etc.
- **Unknown tags are ignored**: unrecognized tags are silently stripped, content preserved
- **Priority**: inline markup overrides all style-system settings (template, column, row styles)

**Common Patterns**:

```r
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

# Render literal tag markers (not parsed as markup)
add_body_text(spec, "Use \\<i>literal\\</i> to show tag text")
```

Note: `<sup>` and `<sub>` are mutually exclusive — if nested, the innermost tag takes effect.

---

## Workflow Architecture

```
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
```

---

## Key Features

### 1. Tidyselect Integration

Use tidyselect expressions for intuitive column selection:

```r
define_cols(spec, starts_with("lab_"), colWidth = "15%")
define_cols(spec, c(id, age, sex), isID = TRUE)
define_cols(spec, where(is.numeric), colWidth = "auto")
```

### 2. Style Consolidation

`create_report()` automatically:

- Merges `f_combine("style1", "style2")` into single `style_<hash>`
- Detects and reuses identical merged styles
- Removes unreferenced styles
- Validates all style references exist

### 3. Schema Validation

All specifications validated against JSON schema:

- Type checking for all fields
- Enum validation for constrained values
- Pattern matching for formatted strings (colors, dimensions)
- Ensures compatibility with C++ renderer

### 4. Data Environment

Original data preserved (shadow-copy) in spec object for:

- Conditional expressions in `compute_cols()`
- Helper functions (`firstOf()`, `lastOf()`, etc.)
- Deferred evaluation until `create_report()`

### 5. Vectorized Parameters

Most functions support vectorized inputs:

```r
# Single value recycled
define_cols(spec, c(col1, col2, col3), colWidth = "33%")

# Individual values per column
define_cols(spec, c(col1, col2, col3), colWidth = c("20%", "30%", "50%"))
```

### 6. Built-in DOCX Renderer

The rendering engine provides a complete end-to-end pipeline:

- **Pixel-perfect text shaping** for deterministic text measurement
- **FreeType font loading** with automatic system font scanning and open-source fallback chain (Arial → Liberation Sans, Times New Roman → Liberation Serif, Courier New → Liberation Mono, Georgia → Liberation Serif, Verdana → Liberation Sans, Trebuchet MS → Liberation Sans)
- **Vertical & horizontal pagination** with configurable page break rules
- Support for all 3 document types (Table, Figure, Text)
- **Per-spec template rendering** in multi-spec reports (mixed `docTemplate` values)
- **Automatic TOC embedding** in generated documents
- Configurable style templates (`CRO Example_default` bundled)

### 7. Font Management

ksTFL automatically discovers fonts installed on the operating system at package load time. The C++ font scanner inspects platform-specific directories (Windows font folders, macOS system/user Library, Linux freedesktop paths) and builds a font registry. System-installed proprietary fonts are always preferred; only when a target font is missing does the package fall back to a bundled open-source alternative.

**Target fonts and fallbacks:**

| Target Font | Fallback (bundled) | License |
|-------------|-------------------|---------|
| Arial | Liberation Sans | SIL OFL 1.1 |
| Times New Roman | Liberation Serif | SIL OFL 1.1 |
| Courier New | Liberation Mono | SIL OFL 1.1 |
| Georgia | Liberation Serif | SIL OFL 1.1 |
| Verdana | Liberation Sans | SIL OFL 1.1 |
| Trebuchet MS | Liberation Sans | SIL OFL 1.1 |

#### Why proprietary fonts are not bundled

Arial, Times New Roman, Courier New, Georgia, Verdana, and Trebuchet MS are proprietary fonts owned by Microsoft and/or Monotype. Their license prohibits redistribution inside open-source packages. ksTFL therefore bundles only the Liberation family (SIL OFL 1.1) as metrically compatible fallbacks. For pixel-perfect output matching corporate templates, install the original Microsoft fonts on the host system.

#### Installing Microsoft core fonts on Linux

The **`ttf-mscorefonts-installer`** package downloads and installs the Microsoft TrueType core fonts (Arial, Times New Roman, Courier New, Georgia, Verdana, Trebuchet MS, and others) from SourceForge. It is available in most Linux distribution repositories.

**Debian / Ubuntu:**

```bash
sudo apt-get update
sudo apt-get install -y ttf-mscorefonts-installer
sudo fc-cache -f
```

**Fedora / RHEL / CentOS (via RPM Fusion or manual SPEC):**

```bash
# Fedora (requires RPM Fusion free repository to be enabled)
sudo dnf install -y curl cabextract xorg-x11-font-utils fontconfig
sudo rpm -i https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm
sudo fc-cache -f
```

**openSUSE:**

```bash
sudo zypper install -y fetchmsttfonts
sudo fc-cache -f
```

**Arch Linux:**

```bash
# Available from the AUR
yay -S ttf-ms-fonts
sudo fc-cache -f
```

After installing, restart R (or call `tfl_rescan_fonts()` in a running session) so ksTFL picks up the new fonts.

#### Rocker Docker images

[Rocker](https://rocker-project.org/) images are Debian-based, so `ttf-mscorefonts-installer` can be added directly. Include the following in your Dockerfile:

```dockerfile
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

> **Tip:** The `debconf-set-selections` line automatically accepts the Microsoft EULA, which is required for non-interactive installs (CI/CD pipelines, Docker builds).

#### Custom font directories

Point the `ksTFL.font_dirs` option to directories containing proprietary or additional fonts. These are scanned alongside system directories:

```r
options(ksTFL.font_dirs = c("/opt/company-fonts", "~/my-fonts"))
tfl_rescan_fonts()
```

**Font management functions:**

| Function | Purpose |
|----------|---------|
| `tfl_font_status()` | Print current font resolution report |
| `tfl_rescan_fonts()` | Re-scan all font directories and print updated report |

---

## Full Pipeline Example

```r
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

---

## Dependencies

### R Packages

| Package | Purpose |
|---------|---------|
| **cli** | Formatted error messages and user feedback |
| **checkmate** | Type-safe argument validation |
| **jsonlite** | JSON serialization/deserialization |
| **tidyselect** | Column selection semantics |
| **rlang** | Quasiquotation and evaluation |
| **digest** | Hash generation for style deduplication |
| **purrr** | Functional programming utilities |
| **htmltools** | Interactive spec preview (print method) |
| **rstudioapi** | RStudio viewer integration |
| **Rcpp** | R/C++ interface for rendering engine |

---

## License

GPL-3. See <https://www.gnu.org/licenses/gpl-3.0.html>.

---

## Authors

**Igor Aleschenkov**
**Vladimir Larchenko**
ksTFL Team (C)

---

## Architecture Note

**ksTFL** integrates metadata generation and document rendering in a single R package:

- The **R layer** generates validated JSON specifications describing document structure, content, column formats, and styles
- The **C++ rendering engine** (built-in, C++20, used by `write_doc()` / `replay_report()`) consumes these specifications and produces styled DOCX documents with deterministic pagination

This architecture enables:

- Metadata generation (R) and rendering (C++) are independently optimizable
- Specifications are reusable, serializable, and version-controllable
- The complete pipeline runs within a single R session — no external tools required
- End-to-end auditability from data to final document
