# ksTFL: Clinical Tables, Figures, and Listings Framework

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Overview

**ksTFL** is a professional R package for generating structured metadata specifications for clinical Tables, Figures, and Listings (TFLs) in pharmaceutical and clinical research. The package employs a declarative, specification-first architecture to describe document structure, data relationships, styling, and content formatting. Generated specifications are validated against a JSON schema and exported for downstream rendering into styled DOCX documents via a Python backend.

### Key Design Principles

- **Separation of Concerns**: Metadata generation (R) is decoupled from document rendering (Python)
- **Schema-Driven Validation**: All specifications conform to a strict JSON schema ensuring consistency
- **Declarative Syntax**: Users describe *what* to render, not *how* to render it
- **Type Safety**: Comprehensive input validation with informative error messages
- **Reproducibility**: Specifications are serializable, version-controllable, and deterministic

---

## Installation

```r
# Install from source
devtools::install_github("your-org/ksTFL")
```

---

## Quick Start Example

```r
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

# 5. Create report and export
report <- create_report(spec)
save_report(report, docFileName = "mtcars_report", outDir = "./output")
```

---

## API Reference

### Document Initialization

Create specification objects for different document types:

| Function | Purpose | Returns |
|----------|---------|---------|
| `create_table(data, cols = everything(), docType = "Table", id = NULL)` | Initialize table spec with data frame | `TFL_spec` |
| `create_figure(file_path, docType = "Figure", id = NULL)` | Initialize figure spec with image path | `TFL_spec` |
| `create_text(docType = "Text", id = NULL)` | Initialize text-only spec (no data) | `TFL_spec` |

### Content Functions

Add document elements to specifications:

| Function | Purpose | Supports Style References |
|----------|---------|---------------------------|
| `add_title(spec, text, styleRef = NULL)` | Add title(s) to document | Yes |
| `add_subtitle(spec, text, styleRef = NULL)` | Add subtitle(s) to document | Yes |
| `add_footnote(spec, text, styleRef = NULL)` | Add footnote(s) to document | Yes |
| `add_body_text(spec, text, styleRef = NULL)` | Add body text paragraphs | Yes |
| `add_header(spec, text, styleRef = NULL)` | Add header row(s) | Yes |
| `add_footer(spec, text, styleRef = NULL)` | Add footer row(s) | Yes |
| `add_span_header(spec, cols, label, labelStyleRef = NULL)` | Add spanning column header | Yes |

### Column Configuration

Define column properties and formatting:

| Function | Purpose | Key Parameters |
|----------|---------|----------------|
| `define_cols(spec, cols, label, isVisible, isID, isGrouping, dedupe, colWidth, valueStyleRef, labelStyleRef, ...)` | Configure column properties | Supports tidyselect; vectorized parameters |

**Column Parameters**:
- `label`: Column display labels
- `isVisible`: Show/hide columns (invisible columns have 0 width)
- `isID`: Identify key columns
- `isGrouping`: Enable grouping behavior
- `dedupe`: Remove duplicate consecutive values
- `colWidth`: Set width (%, cm, pt, in, auto)
- `valueStyleRef`: Style for cell values
- `labelStyleRef`: Style for column headers

### Conditional Row Styling

Apply dynamic styling based on data conditions:

| Function | Purpose | Example |
|----------|---------|---------|
| `compute_cols(spec, condition, ...)` | Evaluate condition and apply actions | `compute_cols(spec, age > 65, c_style(value, styleRef = "alert"))` |
| `c_style(cols, styleRef)` | Apply style to specified columns | `c_style(c(col1, col2), styleRef = "bold")` |
| `c_merge(cols)` | Merge specified columns into one cell | `c_merge(c(col1, col2, col3))` |
| `c_addrow(position, value_from, styleRef)` | Insert row above/below | `c_addrow("above", group_col, styleRef = "header")` |

**Helper Functions for Conditions**:
- `firstOf(...)`: TRUE for first occurrence of each value combination
- `lastOf(...)`: TRUE for last occurrence of each value combination
- `firstRow()` : TRUE only for first data row
- `lastRow()` : TRUE only for last data row
- `everyNth(n)`: TRUE every n-th row (e.g., `everyNth(3)` for rows 1, 4, 7, ...)
- `rowNumber()`: Row index (1-based)
- `.get_names(...)`: Returns column names as character vector (hidden helper)
- `firstOfBlock(col, n, offset)`: Logical vector marking first row of every n-th block defined by `col`
- `eval(expr)`: Evaluate expression with data masking

Note: The `cols` argument passed to `c_merge()` must resolve to at least two consecutive
columns in the final report column order. The merged cell's displayed value is taken
from the first column in the `cols` sequence.

### Style Definitions

Define and compose styles:

| Function | Purpose | Returns |
|----------|---------|---------|
| `add_style(spec, id, ...)` | Add named style to spec | `TFL_spec` |
| `s_font(font_name, font_size, bold, italic, underline, color, highlight)` | Font properties | Style component |
| `s_paragraph(word_style, alignment, spacing, indents)` | Paragraph formatting | Style component |
| `s_spacing(before, after, line_spacing)` | Spacing settings | Style component |
| `s_indents(left, right, first_line, hanging)` | Indentation settings | Style component |
| `s_table_style(background_color, row_height, vertical_alignment, text_orientation, borders)` | Table cell styling | Style component |
| `s_borders(top, bottom, left, right)` | Border definitions | Style component |
| `s_border(color, width, line_style)` | Individual border | Style component |
| `f_combine(...)` | Combine multiple style references | Combined style reference |

**Example Style Definition**:
```r
spec <- add_style(spec, id = "header_style",
  s_font(font_name = "Arial", font_size = "12pt", bold = TRUE, color = "#333333"),
  s_paragraph(alignment = "center", spacing = s_spacing(after = "6pt")),
  s_table_style(background_color = "#E8E8E8", borders = s_borders(
    bottom = s_border(color = "black", width = "2pt", line_style = "double")
  ))
)
```

### Document Configuration

Configure document-level settings:

| Function | Purpose | Parameters |
|----------|---------|------------|
| `set_document(spec, docPrefix, isContinues, gluePrefix, contentWidth)` | Set document metadata | Document identifiers and width |
| `set_page_style(spec, page, margins)` | Configure page layout | Page size/orientation, margins |
| `p_page(size, orientation)` | Page settings helper | A4/Letter/Legal, portrait/landscape |
| `p_margins(top, bottom, left, right)` | Margin settings helper | Dimensions with units (in, cm, pt) |

### Report Assembly

Combine specifications into reports:

| Function | Purpose | Returns |
|----------|---------|---------|
| `create_report(...)` | Combine specs/reports into single report | `TFL_report` |
| `save_report(report, docFileName, outDir, dataDir, data, copyData)` | Serialize and export report | File paths |

**create_report() Features**:
- Consolidates styles across specs (deduplicates merged styles)
- Validates all style references exist
- Assigns sequential document order
- Generates unique data references
- Supports mixing `TFL_spec` and `TFL_report` objects

### Package Options

Configure global defaults:

| Function | Purpose |
|----------|---------|
| `tfl_set_options(...)` | Set package-level options |
| `tfl_get_options()` | Retrieve all current options |
| `tfl_get_option(name)` | Retrieve single option value |
| `tfl_reset_options()` | Reset all options to defaults |

**Configurable Options**:
- `autoColWidth`: Auto-recalculate column widths (default: TRUE)
- `missings`: Default representation for missing values (default: "")
- Predefined styles: Define styles once, use across all specs
- Default headers/footers: Apply to all documents

---

## Workflow Architecture

```
1. Specification Creation
   └─> create_table() / create_figure() / create_text()
       └─> Returns TFL_spec with initialized structure

2. Content & Styling
   └─> add_title(), add_subtitle(), add_footnote()
   └─> define_cols() - column configuration
   └─> add_style() - define named styles
   └─> compute_cols() - conditional row styling

3. Report Assembly
   └─> create_report() - combines multiple specs
       └─> Style consolidation & validation
       └─> Sequential ordering & data references

4. Export & Rendering
   └─> save_report() - JSON + data files
       └─> Python backend consumes spec
       └─> Generates styled DOCX document
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
- Ensures compatibility with Python renderer

### 4. Data Environment
Original data preserved in `.metadata$data_env` for:
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

---

## Dependencies

| Package | Purpose |
|---------|---------|
| **cli** | Formatted error messages and user feedback |
| **checkmate** | Type-safe argument validation |
| **jsonlite** | JSON serialization/deserialization |
| **tidyselect** | Column selection semantics |
| **rlang** | Quasiquotation and evaluation |
| **digest** | Hash generation for style deduplication |
| **htmltools** | Interactive spec preview (print method) |
| **rstudioapi** | RStudio viewer integration |

---

## License

MIT + file LICENSE

---

## Author

**Igor Aleschenkov**  
KeyStat Solutions

---

## Note

**ksTFL** is designed as the metadata layer of a two-component system. The R package generates validated JSON specifications; a companion Python backend renderer (not included) consumes these specifications and produces final styled DOCX documents. This separation enables:

- Independent evolution of specification format and rendering engine
- Language-specific optimization (R for data manipulation, Python for document generation)
- Reusable specifications across different rendering targets
- Version-controlled, auditable document metadata

