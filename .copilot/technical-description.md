# ksTFL — Technical Description

> **Last updated:** February 24, 2026  
> **Version:** 0.1.0  
> **Author:** Igor Aleschenkov, CRO Example Solutions

---

## 1. What is ksTFL?

**ksTFL** is an R package that generates structured JSON metadata for clinical Tables, Figures, and Listings (TFLs) used in pharmaceutical and clinical research (FDA/EMA submissions). It implements a **specification-first architecture**: R creates validated metadata; a companion Python backend (not included) renders the final styled DOCX documents.

### Design Goals
- **Separation of concerns** — metadata generation (R) is fully decoupled from document rendering (Python)
- **Schema-driven validation** — all specifications conform to a JSON Schema (`spec_schema_v1.json`)
- **Declarative API** — users describe *what* to render, the system handles *how*
- **Reproducibility** — specs are deterministic, serializable, and version-controllable
- **Type safety** — comprehensive input validation with informative error messages via `checkmate` + `cli`

---

## 2. Architecture Overview

```
Data Frame / Image File
       │
       ▼
create_table() / create_figure() / create_text()
       │
       ▼
TFL_spec  ←── customize with define_cols(), add_style(), add_title(), compute_cols()
       │
       ▼
create_report()  ←── 6-phase pipeline: flatten, validate, finalize, consolidate, order, build
       │
       ▼
TFL_report  (named list of TFL_spec objects)
       │
       ▼
save_report()  ←── schema validation + JSON export + data files
       │
       ▼
JSON spec + data files → Python Renderer → Styled DOCX
```

---

## 3. Core Data Structures

### 3.1 TFL_spec (S3 class)

The central object created by `create_table()`, `create_figure()`, or `create_text()`. Structure:

| Field | Type | Description |
|-------|------|-------------|
| `document` | list | Doc metadata: `docType`, `hasData`, `docPrefix`, `docOrder`, `isContinues`, `contentWidth`, `bodyTitles`, `bodySubtitles`, `footnotePlace`, `gluePrefix` |
| `attribs` | list | `documentStyle` (template, page settings) and `styles` (named style definitions) |
| `headers` | list | Header row entries |
| `footers` | list | Footer row entries |
| `dataRef` | character | Data file reference(s) for serialization |
| `stubColumns` | list | Spanning column header definitions |
| `columns` | named list | Column specs: `colOrder`, `label`, `isVisible`, `isID`, `isGrouping`, `isPaging`, `labelStyleRef`, `isColBreak`, `dedupe`, `format` |
| `styleRows` | list | Conditional row style rules (serialized as JSON during `create_report()`) |
| `titles` | list | Title text groups |
| `subtitles` | list | Subtitle text groups |
| `footnotes` | list | Footnote text groups |
| `bodyText` | list | Body text entries |
| `.metadata` | list | **Internal only** (not serialized): `report_cols`, `data_env`, `colWidths`, `compute_cols`, `hash` |

### 3.2 TFL_report (S3 class)

A named list of `TFL_spec` objects produced by `create_report()`. Keys follow `<varname>_<hash>` pattern. Class: `c("TFL_report", "list")`.

### 3.3 TFL_options (S3 class)

Package settings container. Used by `tfl_set_options()` and related. Supports S3 dispatch for `add_style`, `add_body_text`, `add_header`, `add_footer`.

### 3.4 Data Environment (`.metadata$data_env`)

A 3-layer `rlang` environment created by `.create_data_env()`:

1. **Functions layer** — helper functions (`firstOf`, `lastOf`, `rowNumber`, etc.) with access to data
2. **Data layer** (`__data__`) — shadow copy of the input data.frame
3. **Mask layer** (`__mask__`) — tidyselect data mask for column filtering

Expressions in `compute_cols()` are captured as quosures and evaluated in this environment during `create_report()`.

---

## 4. Three Document Types

| Type | `create_*()` | `data` arg | Has columns? | Notes |
|------|-------------|------------|--------------|-------|
| **Table** | `create_table(df, cols)` | data.frame (required) | Yes, auto-detected | Tidyselect for column selection |
| **Figure** | `create_figure(plot_or_path, width, height, dpi, device)` | file path string OR ggplot2 object | No | File path: validates readability; ggplot2 object: renders to temp file via `ggsave()` |
| **Text** | `create_text()` | NULL | No | Narrative-only |

---

## 5. File Structure and Responsibilities

### R Source Files

| File | Lines | Responsibility |
|------|-------|----------------|
| `constants.R` | 474 | All package constants: enums, validation patterns, schema properties, default values, predefined styles, cache environments |
| `spec_init.R` | 605 | Spec initialization: `.tfl_init()`, `.fill_spec_defaults()`, `.init_column_specs()`, type detection, `create_table/text/figure()` wrappers |
| `spec_context.R` | 2975 | **Largest file.** Style system, content functions, column definitions. Context enforcement, validation, all `s_*()` style builders, `add_style()`, `define_cols()`, `add_title/subtitle/footnote()`, `add_body_text()`, `add_header/footer()`, `add_span_header()`, `set_document()`, `set_page_style()` |
| `env_eval_helpers.R` | 524 | Data environment creation (`.create_data_env()`), tidyselect wrappers, evaluation helpers (`firstOf`, `lastOf`, `rowNumber`, `everyNth`, etc.) |
| `rowstyle_actions.R` | 970 | Conditional row styling: `compute_cols()`, `c_style()`, `c_merge()`, `c_addrow()`, `c_pageBreak()`, finalization and serialization of row actions |
| `create_report.R` | 570 | Report assembly: `._consolidate_styles_in_spec()` (2-pass style consolidation), `create_report()` (6-phase pipeline) |
| `report_writer.R` | 360 | `save_report()` — serialization to JSON + data file export |
| `schema_serialize.R` | 1141 | Schema-driven validation: `$ref` resolution, `allOf` merging, type coercion, `serialize_spec()` |
| `pkg_settings.R` | 291 | Package options: `.options_env`, `tfl_get/set/reset_options()` |
| `utility_functions.R` | 770 | General utilities: merge, hash, file checks, column width calculation, layout guessing |
| `spec_print.R` | ~650 | `print.TFL_spec()` (console only), `view_tfl_spec()`, `.render_TFL_spec_viewer()` for HTML preview |
| `ksTFL.R` | ~80 | Package docs, `.onLoad()`, `.onAttach()`, `.onUnload()` |

### Schemas (`inst/schemas/`)

| File | Status | Purpose |
|------|--------|---------|
| `spec_schema_v1.json` | **Active** (941 lines) | Main spec validation schema |
| `row_style_actions_schema_v0.json` | Active | StyleRows validation |
| `styles_schema_v0.json` / `v1.json` | Active | Style definitions |
| `spec_schema_v0.json` | Legacy | Deprecated |

### Tests (`tests/testthat/`)

18 test files covering all major functionality:

| Test | Focus |
|------|-------|
| `test-01-basic-creation.R` | create_table/text/figure, docType validation |
| `test-02-define-cols.R` | Column definition, tidyselect, vectorized params |
| `test-03-add-style.R` | Style creation, context nesting, validation |
| `test-04-content.R` | Titles, subtitles, footnotes |
| `test-04b-stub-column.R` | Spanning column headers |
| `test-05-headers-footers.R` | Header/footer management |
| `test-05b-text-groups.R` | Text group operations |
| `test-06-options.R` | Package options get/set/reset |
| `test-07-create-report.R` | Report assembly, style consolidation, mixed inputs |
| `test-08-edge-cases.R` | Edge cases and error conditions |
| `test-09-integration.R` | End-to-end workflows |
| `test-10-serialization.R` | Schema validation, JSON export |
| `test-11-width-recalc.R` | Column width auto-calculation |
| `test-12-report-writer.R` | save_report() functionality |
| `test-13-compute-cols.R` | Conditional row actions |
| `test-14-stylerows-consolidation.R` | StyleRows consolidation |
| `test-15-guess-layout.R` | Column format auto-detection |
| `test-16-optimization-fixes.R` | Performance and regression tests |

---

## 6. Key Subsystems

### 6.1 Style System

**Style definition:**
```r
spec <- add_style(spec, id = "header_bold",
  s_font(bold = TRUE, font_size = "12pt"),
  s_paragraph(alignment = "center"),
  s_table_style(background_color = "#E8E8E8")
)
```

**Context enforcement** via `.set_context()` / `.assert_context()`:
- `s_borders()` only inside `s_table_style()`
- `s_spacing()`, `s_indents()` only inside `s_paragraph()`

**Style combination:**
```r
define_cols(spec, col1, valueStyleRef = f_combine("bold", "text_red"))
```
During `create_report()`, `f_combine()` references are resolved into merged `style_<hash>` entries via `._consolidate_styles_in_spec()`.

**Predefined styles** (30+ in `.const_options_styles`): `font_bold`, `font_italic`, `text_center`, `text_right`, `cell_highlight_yellow`, `cell_border_bottom`, `indent_1/2/3`, etc.

### 6.2 Column Width Management

1. During `create_table()`: `.guess_table_layout()` auto-calculates initial widths summing to 100%
2. `define_cols(spec, cols, colWidth = "20%")` locks specific columns
3. When `autoColWidth = TRUE` (default): unlocked columns are redistributed to fill remaining space preserving proportions
4. Supports units: `%`, `cm`, `in`, `pt`
5. Minimum width enforcement via `minColWidth` option

### 6.3 Conditional Row Styling (`compute_cols`)

**Deferred evaluation pattern:**
1. `compute_cols()` captures condition + actions as quosures (not evaluated)
2. Stored in `spec$.metadata$compute_cols`
3. During `create_report()` → `.finalize_compute_cols()` evaluates conditions in data_env
4. Actions applied per row, serialized to JSON for `styleRows`

**Available actions:**
- `c_style(cols, styleRef)` — apply named style to columns in matching rows
- `c_merge(cols, styleRef)` — merge adjacent columns (requires consecutive columns)
- `c_addrow(pos, value_from, styleRef)` — insert row above/below matched rows
- `c_pageBreak()` — insert page break at matched row

**Helper functions** (available in condition expressions):
- `firstOf(...)`, `lastOf(...)` — first/last occurrence of value combination
- `firstRow()`, `lastRow()` — absolute position
- `everyNth(n)` — periodic selection
- `rowNumber()` — row index
- `firstOfBlock(col, n, offset)` — block-based selection
- `eval(expr)` — arbitrary expression evaluation

### 6.4 Schema Serialization Pipeline

```
serialize_spec(report)
    → .serialize_json_internal(data, schema)
        → .fix_types(): schema-aware type coercion
        → .resolve_refs(): $ref / $defs resolution
        → .resolve_allOf(): allOf combinator merging
        → .protect_arrays(): ensure arrays serialize correctly
    → jsonlite::toJSON()
```

### 6.5 `create_report()` — 6-Phase Pipeline

1. **Flatten inputs** — extract specs from `TFL_report` objects, preserve keys
2. **Validate keys** — reject duplicate spec keys
3. **Finalize compute_cols** — evaluate deferred conditions and build styleRows  
4. **Consolidate styles** — only for new `TFL_spec` objects (reports already consolidated)
5. **Renumber docOrder & create dataRef** — global sequential numbering
6. **Build result** — serialize styleRows to JSON, assemble `TFL_report`

---

## 7. Package Options

Managed via `.options_env` environment in `pkg_settings.R`.

| Option | Default | Description |
|--------|---------|-------------|
| `doc_style_template` | `"Default"` | Document template name |
| `page` | `list(size="A4", orientation="landscape")` | Page settings |
| `bodyTitles` | `TRUE` | Include titles in body |
| `bodySubtitles` | `TRUE` | Include subtitles in body |
| `footnotePlace` | `"repeated"` | Footnote placement: `"doc_footer"`, `"repeated"`, or `"last_page"` |
| `gluePrefix` | `TRUE` | Glue docPrefix to title |
| `isContinues` | `FALSE` | Continuation flag |
| `contentWidth` | `"100%"` | Content width |
| `missings` | `"NA"` | Missing value representation |
| `autoColWidth` | `TRUE` | Auto-recalculate column widths |
| `minColWidth` | `0.5` | Minimum relative column width % |
| `headers` | `list()` | Default headers |
| `footers` | `list()` | Default footers |
| `bodyText` | `list(__default_001 = ...)` | Default body text |
| `styles` | 30+ predefined styles | Global style definitions |
| `output_directory` | `"."` | Default output directory |

---

## 8. Dependencies

| Package | Purpose |
|---------|---------|
| `cli` | Formatted error/warning messages |
| `checkmate` | Type-safe argument validation |
| `jsonlite` | JSON serialization/deserialization |
| `tidyselect` | Column selection semantics |
| `rlang` | Quasiquotation, data masks, environments |
| `purrr` | Functional programming helpers |
| `digest` | Hash generation for style deduplication |
| `htmltools` | Interactive spec preview |
| `rstudioapi` | RStudio viewer integration |

---

## 9. Development Conventions

### Code Style
- **Internal functions:** `.` prefix (e.g., `.merge_recursive`, `.fix_types`)
- **Constants:** `.const_` prefix
- **Column iterators:** `col_idx` (not `var` or `i`)
- **Quotes:** Double quotes throughout
- **Integer literals:** `1L` not `1`

### Error Handling
```r
cli_abort(c(
  "Main error message:",
  x = "Problem description",
  i = "Remediation or info"
))
```
Never use base `stop()` or `warning()`.

### Validation
- `checkmate::assert_*()` with `.var.name` parameter for user-friendly errors
- Validate early, before processing/mutating data
- Schema property validation via `.validate_params()`

### S3 Methods
- `add_style`, `add_body_text`, `add_header`, `add_footer`, `set_page_style` dispatch on `TFL_spec`, `TFL_options`, `default`
- Registered in `NAMESPACE` with `S3method()` directives

### Testing
- `testthat` framework, 18 test files
- Numbered `test-NN-*.R` pattern
- Cover: all parameters, edge cases, error conditions, integration

---

## 10. Current Status

### Fully Implemented ✅
- Spec initialization for all 3 docTypes
- Column auto-detection and format assignment
- Auto column width calculation and redistribution
- Style consolidation with hash-based merging
- Context-based function nesting validation
- 30+ predefined clinical styles
- Conditional row styling (compute_cols with c_style, c_merge, c_addrow, c_pageBreak)
- Schema-driven serialization and validation
- Report assembly with mixed TFL_spec/TFL_report support
- save_report() for JSON + data file export
- Package options management
- Print method (console + HTML viewer)
- Spanning column headers
- Comprehensive test suite

### Still TODO ⏳
- `row_style_schema` validation rules (schema file exists, enforcement pending)
- `styles_schema` validation rules (schema file exists, enforcement pending)
- Python backend integration (out of R scope)

---

## 11. Docker Development Environment

```yaml
# docker-compose.yml
services:
  r-dev:
    build: .           # rocker/verse:latest
    container_name: kstfl-r
    ports: ["8787:8787"]
    volumes: [".:/home/rstudio/ksTFL"]
    environment: [DISABLE_AUTH=true]
```

RStudio Server available at `http://localhost:8787` (no auth).
Uses Russian CRAN mirror configured in Dockerfile.

---

## 12. Quick Reference — Common Workflows

### Create and configure a table
```r
spec <- create_table(mtcars, cols = c(mpg, cyl, hp, wt))
spec <- spec |>
  add_title("Motor Trend Cars") |>
  add_footnote("Source: 1974 Motor Trend US magazine") |>
  define_cols(c(mpg, hp), label = c("MPG", "HP"), colWidth = c("25%", "25%")) |>
  add_style(id = "bold", s_font(bold = TRUE)) |>
  compute_cols(hp > 200, c_style(hp, styleRef = "bold"))
```

### Assemble and export report
```r
report <- create_report(spec1, spec2, spec3)
save_report(report, docFileName = "output.docx", outDir = "./output")
```

### Configure global options
```r
tfl_set_options(
  missings = "",
  autoColWidth = TRUE,
  add_style(id = "custom", s_font(bold = TRUE, color = "red"))
)
```
