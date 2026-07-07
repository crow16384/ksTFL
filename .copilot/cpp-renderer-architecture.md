# ksTFL C++ DOCX Renderer — Architecture Design

> **Created:** 2026-02-24  
> **Status:** Design Draft  
> **Scope:** C++ rendering engine that consumes ksTFL JSON specs and produces styled DOCX for clinical TFLs

---

## Table of Contents

1. [Overview & Goals](#1-overview--goals)
2. [Cleaned JSON Contract](#2-cleaned-json-contract)
3. [C++ Data Structures](#3-c-data-structures)
4. [Rendering Pipeline](#4-rendering-pipeline)
5. [Font & Text Subsystem (HarfBuzz)](#5-font--text-subsystem-harfbuzz)
6. [Inline Markup](#6-inline-markup)
7. [Table Layout Engine](#7-table-layout-engine)
8. [OOXML Emission](#8-ooxml-emission)
9. [R Integration (Rcpp)](#9-r-integration-rcpp)
10. [Build & Dependencies](#10-build--dependencies)
11. [Directory Structure](#11-directory-structure)
12. [Performance Considerations](#12-performance-considerations)
13. [Open Questions](#13-open-questions)

---

## 1. Overview & Goals

### What this engine does

```
┌─────────────┐       ┌──────────────┐       ┌─────────────────┐       ┌──────────┐
│ R (ksTFL)   │──────▶│ spec.json +  │──────▶│  C++ Renderer   │──────▶│  .docx   │
│ save_report │       │ data JSON(s) │       │  (this engine)  │       │  output  │
│             │       │ + template   │       │                 │       │          │
└─────────────┘       └──────────────┘       └─────────────────┘       └──────────┘
```

### Design Goals

| Goal | Rationale |
|------|-----------|
| **Pixel-accurate clinical tables** | FDA/EMA submission quality — exact column widths, borders, fonts |
| **No Python dependency** | Replace Python backend with single compiled library |
| **R-callable via Rcpp** | `render_docx(spec_json, data_dir, template_json, output_path)` |
| **HarfBuzz-based text measurement** | Accurate glyph-level widths for table layout and pagination |
| **Font cache** | Amortize FreeType face loading across the entire report |
| **Inline markup** | Support `<sup>`, `<sub>`, `<br>`, `<p>`, `<b>`, `<i>`, `<u>`, `<s>` in cell values |
| **Streaming OOXML** | Memory-efficient XML generation; no DOM tree in memory |
| **Thread-safe** | Stateless rendering; parallel spec processing possible |

---

## 2. Cleaned JSON Contract

### 2.1 What the C++ engine receives

The R function `save_report()` already strips `.metadata` from all specs before export. The C++ engine receives **three inputs**:

| Input | Format | Description |
|-------|--------|-------------|
| **Spec JSON** | Single `.json` file | Contains `_metadata` + N spec entries (keyed `<name>_<hash16>`) |
| **Data JSON(s)** | One `.json` per table spec | Column-oriented: `{"col": [values...]}` |
| **Styles Template** | Single `.json` file | Resolved from `docTemplate` name → full template |

### 2.2 Spec JSON — Structure consumed by C++

```jsonc
{
  "_metadata": {
    "outDir": "/output/path",        // Where to write the .docx
    "docFileName": "table_14.5",     // Base filename (no extension)
    "datetime": "2025-12-26T08:29:24"
  },
  "spec_8a86766b288e790b": {         // Key pattern: ^[A-Za-z0-9][A-Za-z0-9_-]*_[a-f0-9]{16}$
    "document": {
      "docType": "Table",            // "Table" | "Text" | "Figure"
      "hasData": true,
      "docPrefix": "Table 14.5",
      "docOrder": 1,                 // Sequential position in report
      "isContinues": false,          // Whether this continues prev spec
      "contentWidth": "90%",         // Table width relative to printable area
      "gluePrefix": true             // Prepend docPrefix to first title
    },
    "attribs": {
      "documentStyle": {
        "docTemplate": "Default",  // Template name → look up in styles template
        "page": {
          "size": "A4",                     // A4 | A3 | Letter | Legal | Executive
          "orientation": "landscape"        // portrait | landscape
          // margins may be present here (override template)
        }
      },
      "styles": {                           // Per-spec style definitions
        "<style_id>": {
          "font": { "bold": true, "font_size": "12pt", ... },
          "paragraph": { "alignment": "left", "spacing": {...}, "indents": {...} },
          "table_style": { "background_color": "#E6E6E6", "borders": {...}, ... }
        }
      }
    },
    "headers": [                     // Page headers: array of arrays (each inner = one header line)
      ["Protocol: Miracle Drug", "Page x of y"],
      ["Confidential"]
    ],
    "footers": [                     // Page footers: same structure
      ["Program: vitals.R", "Date:2025-12-26"]
    ],
    "dataRef": ["0001_8a86766b288e790b"],  // Links to data JSON file(s)
    
    "stubColumns": {                 // Spanning column headers
      "stub_0001": {
        "label": "Treatments",
        "labelStyleRef": ["font_bold"],
        "stubOrder": 1,
        "cols": ["trtA", "trtB", "Total"]  // Which data columns this spans
      }
    },
    
    "columns": {                     // Column definitions (ordered by colOrder)
      "<col_name>": {
        "colOrder": 1,
        "label": "Display Name",
        "isVisible": true,           // false = hidden from table but present in data
        "isID": false,               // ID column (leftmost, usually)
        "isGrouping": false,         // Group-by column for dedup
        "isPaging": false,           // Force page break on change
        "isColBreak": false,
        "dedupe": false,             // Suppress repeated values
        "labelStyleRef": ["style_id"],      // Optional: header cell styles
        "format": {
          "type": "string",          // string | numeric | integer | date | logical
          "format": "%s",            // sprintf-like format
          "colWidth": "29.9%",       // Column width (% | cm | in | pt)
          "missings": "NA",          // Missing value representation
          "valueStyleRef": ["style_id"]    // Optional: body cell styles
        }
      }
    },
    
    "styleRows": [                   // Per-row action sets (JSON strings — MUST PARSE)
      "{\"merge\":[{\"cols\":[\"A\",\"B\"],\"styleRef\":\"bold\"}],\"add_row\":[{\"pos\":\"above\",\"value_from\":\"grp\",\"styleRef\":\"hdr\"}]}",
      "{}",
      "{\"style\":[{\"cols\":[\"val\"],\"styleRef\":\"red\"}]}"
    ],
    
    "titles": {
      "title_0001": {
        "text": ["Line 1", "Line 2"],      // Multi-line text
        "styleRef": ["font_bold"],
        "order": 1
      }
    },
    "subtitles": { /* same structure */ },
    "footnotes": { /* same structure */ },
    "bodyText": { /* same structure; order=999 = appended at end */ }
  }
}
```

### 2.3 Data JSON — Column-oriented

```json
{
  "age_grp": ["Age Group: <40", "Age Group: <40", ...],
  "visit":   ["Baseline",       "Baseline",       ...],
  "parameter": ["Systolic BP (mmHg)", ...],
  "trtA":    ["120.5 (14.2)", ...],
  "trtB":    ["118.3 (13.8)", ...],
  "Total":   ["119.4 (14.0)", ...]
}
```

All values are **pre-formatted strings** — the C++ engine never needs numeric formatting.

### 2.4 Styles Template JSON — Resolved structure

```jsonc
{
  "document": {
    "page": {
      "size": "A4", "orientation": "landscape",
      "margins": { "top": "1.5cm", "bottom": "1.5cm", "left": "1.5cm", "right": "1.5cm", "header": "1.0cm", "footer": "1.0cm" }
    },
    "paragraphDefaults": { "widow_control": true }
  },
  "textStyles": {
    "default":     { "font": {...}, "paragraph": {...} },
    "docHeader":   { "font": {...}, "paragraph": {...} },
    "docFooter":   { "font": {...}, "paragraph": {...} },
    "titles":      { "font": {...}, "paragraph": {...} },
    "subtitles":   { "font": {...}, "paragraph": {...} },
    "footnotes":   { "font": {...}, "paragraph": {...} },
    "tableHeader": { "font": {...}, "paragraph": {...} },
    "tableBody":   { "font": {...}, "paragraph": {...} }
  },
  "tableStyle": {
    "layout": {
      "allow_row_break_across_pages": false,
      "repeat_header_on_each_page": true,
      "table_alignment": "center"
    },
    "structural": {
      "header_top_border":    { "color": "#000000", "width": "1pt", "line_style": "single" },
      "header_bottom_border": { "color": "#000000", "width": "1pt", "line_style": "single" },
      "table_bottom_border":  { "color": "#000000", "width": "1pt", "line_style": "single" },
      "allHeaders": { "background_color": null, "cell_margins": {...}, "vertical_alignment": "center" },
      "tableBody":  { "background_color": null, "cell_margins": {...}, "vertical_alignment": "center" }
    },
    "cellDefaults": {
      "cell_margins": { "top": "0pt", "bottom": "0pt", "left": "2pt", "right": "2pt" },
      "vertical_alignment": "center"
    },
    "header": {
      "textStyleRef": "tableHeader",
      "row": { "background_color": null, "row_height": "auto", ... }
    },
    "body": {
      "textStyleRef": "tableBody",
      "row": { "background_color": null, "row_height": "auto", ... }
    }
  }
}
```

### 2.5 What the C++ engine does NOT receive

These are R-internal and never serialized:

| Stripped | Reason |
|----------|--------|
| `.metadata` (entire section) | R-only: `data_env`, `report_cols`, `compute_cols`, `hash`, `colWidths` |
| `data_env` environment | Replaced by flat data JSON file |
| `compute_cols` quosures | Already materialized into `styleRows` by `create_report()` |
| R class attributes | JSON has no class info; C++ knows structure from schema |

---

## 3. C++ Data Structures

### 3.1 Core Type Hierarchy

```
TFLDocument (top-level)
├── ReportMeta              // _metadata
├── StylesTemplate          // resolved template
│   ├── PageConfig
│   ├── TextStyleMap         // named text styles
│   └── TableStyleConfig
│       ├── TableLayout
│       ├── StructuralStyle
│       └── RowStyle (header, body)
└── TFLSpec[]               // ordered by docOrder
    ├── DocumentInfo
    ├── StyleMap              // per-spec styles
    ├── HeaderFooter[]
    ├── StubColumn[]
    ├── ColumnDef[]
    ├── RowActionSet[]        // parsed styleRows
    ├── TextGroup[] (titles, subtitles, footnotes, bodyText)
    └── DataTable             // loaded from data JSON
```

### 3.2 Header Definitions (C++)

```cpp
#pragma once
#include <string>
#include <vector>
#include <unordered_map>
#include <optional>
#include <variant>
#include <cstdint>

namespace kstfl {

// ============================================================================
// Unit system — all physical measurements normalized to EMU (English Metric Units)
// 1 inch = 914400 EMU, 1 cm = 360000 EMU, 1 pt = 12700 EMU
// ============================================================================

using Emu = int64_t;

struct Length {
    Emu value = 0;
    
    static Length from_pt(double pt);
    static Length from_cm(double cm);
    static Length from_inch(double in);
    static Length from_percent(double pct, Length reference);
    static Length parse(const std::string& s);       // "1.5cm", "12pt", "1in", "29.9%"
    static Length parse_pct(const std::string& s, Length ref); // "29.9%" resolved against ref
    
    double to_pt() const;
    double to_cm() const;
    int to_twips() const;   // OOXML uses twips (1/20 pt) for many measurements
    int to_emu() const;
    int to_half_pt() const; // OOXML font size = half-points
};

// ============================================================================
// Color
// ============================================================================

struct Color {
    uint8_t r = 0, g = 0, b = 0;
    bool is_null = true;  // null = "no color specified"
    
    static Color parse(const std::string& hex);  // "#FF0000" or "FF0000"
    std::string to_hex6() const;                  // "FF0000" (no #, OOXML format)
};

// ============================================================================
// Border
// ============================================================================

enum class LineStyle : uint8_t {
    None, Single, Double, Dashed, Dotted, Thick
};

struct Border {
    Color color;
    Length width;
    LineStyle line_style = LineStyle::None;
    
    bool is_visible() const { return line_style != LineStyle::None && !color.is_null; }
    std::string to_ooxml_val() const; // "single", "double", "dashed", "dotted", "thick", "none"
};

struct Borders {
    std::optional<Border> top, bottom, left, right;
};

// ============================================================================
// Font Properties
// ============================================================================

struct FontProps {
    std::optional<std::string> font_name;   // "Arial", "Times New Roman"
    std::optional<Length> font_size;         // in half-points for OOXML
    std::optional<bool> bold;
    std::optional<bool> italic;
    std::optional<bool> underline;
    std::optional<Color> color;
    std::optional<Color> highlight;
    
    // Merge: overlay `other` on top of `this` (other wins for non-null)
    FontProps merged_with(const FontProps& other) const;
};

// ============================================================================
// Paragraph Properties
// ============================================================================

enum class Alignment : uint8_t {
    Left, Right, Center, Justify, Distributed
};

struct Spacing {
    std::optional<Length> before;
    std::optional<Length> after;
    std::optional<double> line_spacing;  // multiplier (1.0, 1.5, 2.0, ...)
};

struct Indents {
    std::optional<Length> left;
    std::optional<Length> right;
    std::optional<Length> first_line;
};

struct ParagraphProps {
    std::optional<Alignment> alignment;
    std::optional<std::string> word_style;  // MS Word built-in style name
    Spacing spacing;
    Indents indents;
    
    ParagraphProps merged_with(const ParagraphProps& other) const;
};

// ============================================================================
// Table Cell / Row Properties
// ============================================================================

enum class VerticalAlignment : uint8_t { Top, Center, Bottom };
enum class TextOrientation : uint8_t { Horizontal, Vertical90, Vertical270 };

struct CellMargins {
    std::optional<Length> top, bottom, left, right;
};

struct TableCellProps {
    std::optional<Color> background_color;
    std::optional<Length> row_height;
    std::optional<VerticalAlignment> vertical_alignment;
    std::optional<TextOrientation> text_orientation;
    std::optional<Borders> borders;
    std::optional<CellMargins> cell_margins;
    
    TableCellProps merged_with(const TableCellProps& other) const;
};

// ============================================================================
// Style Definition (named style in spec.attribs.styles)
// ============================================================================

struct StyleDef {
    std::string id;
    FontProps font;
    ParagraphProps paragraph;
    TableCellProps table_style;
    
    StyleDef merged_with(const StyleDef& other) const;
};

using StyleMap = std::unordered_map<std::string, StyleDef>;

// ============================================================================
// Text Group (titles, subtitles, footnotes, bodyText)
// ============================================================================

struct TextGroup {
    std::string key;                       // "title_0001"
    std::vector<std::string> text;         // multi-line
    std::vector<std::string> style_refs;   // references into StyleMap
    int order = 0;
};

// ============================================================================
// Column Definition
// ============================================================================

struct ColumnFormat {
    std::string type;           // "string", "numeric", "integer", "date", "logical"
    std::string format;         // sprintf-like: "%s", "%.2f", etc.
    std::string col_width_raw;  // raw string from JSON: "29.9%", "2.5cm"
    Length col_width;           // resolved absolute width
    std::string missings;       // missing value repr: "NA", "", etc.
    std::vector<std::string> value_style_refs;
};

struct ColumnDef {
    std::string name;           // JSON key = column name in data
    int col_order = 0;
    std::string label;          // display label
    bool is_visible = true;
    bool is_id = false;
    bool is_grouping = false;
    bool is_paging = false;
    bool is_col_break = false;
    bool dedupe = false;
    std::vector<std::string> label_style_refs;
    ColumnFormat format;
};

// ============================================================================
// Stub Column (spanning header)
// ============================================================================

struct StubColumn {
    std::string key;
    std::string label;
    std::vector<std::string> label_style_refs;
    int stub_order = 0;
    std::vector<std::string> cols; // column names this stub spans
};

// ============================================================================
// Row Actions (parsed from styleRows JSON strings)
// ============================================================================

struct StyleAction {
    std::vector<std::string> cols;
    std::string style_ref;
};

struct MergeAction {
    std::vector<std::string> cols;  // min 2 consecutive
    std::string style_ref;          // optional
};

enum class InsertPos : uint8_t { Above, Below };

struct AddRowAction {
    InsertPos pos = InsertPos::Above;
    std::string value_from;         // column name to pull value from (optional)
    std::string style_ref;          // optional
};

struct RowActionSet {
    std::vector<StyleAction> styles;
    std::vector<MergeAction> merges;
    std::vector<AddRowAction> add_rows;
    bool page_break = false;
    bool is_empty() const;
};

// ============================================================================
// Data Table (column-oriented, loaded from data JSON)
// ============================================================================

class DataTable {
public:
    size_t num_rows() const;
    size_t num_cols() const;
    
    const std::vector<std::string>& column(const std::string& name) const;
    const std::vector<std::string>& column(size_t idx) const;
    const std::string& cell(size_t row, size_t col) const;
    const std::string& cell(size_t row, const std::string& col) const;
    
    // Column name → index mapping
    size_t col_index(const std::string& name) const;
    bool has_column(const std::string& name) const;
    
    // Load from JSON
    static DataTable from_json(const std::string& json_path);
    
private:
    std::vector<std::string> col_names_;
    std::unordered_map<std::string, size_t> col_index_;
    std::vector<std::vector<std::string>> data_; // data_[col_idx][row_idx]
};

// ============================================================================
// Header / Footer
// ============================================================================

struct HeaderFooterLine {
    std::vector<std::string> segments; // ["Left text", "Right text"]
};

// ============================================================================
// Document Info (per-spec)
// ============================================================================

enum class DocType : uint8_t { Table, Text, Figure };

struct DocumentInfo {
    DocType doc_type = DocType::Table;
    bool has_data = false;
    std::string doc_prefix;     // "Table 14.5"
    int doc_order = 0;
    bool is_continues = false;
    std::string content_width;  // "90%", "100%"
    bool glue_prefix = true;
};

// ============================================================================
// Page Configuration (from template + overrides)
// ============================================================================

enum class PageSize : uint8_t { A4, A3, Letter, Legal, Executive };
enum class Orientation : uint8_t { Portrait, Landscape };

struct PageConfig {
    PageSize size = PageSize::A4;
    Orientation orientation = Orientation::Landscape;
    
    struct Margins {
        Length top, bottom, left, right;
        Length header_distance;  // page edge → header
        Length footer_distance;  // page edge → footer
    } margins;
    
    // Derived
    Length page_width() const;   // based on size + orientation
    Length page_height() const;
    Length printable_width() const;  // page_width - left - right
    Length printable_height() const; // page_height - top - bottom
};

// ============================================================================
// Table Layout Config (from styles template)
// ============================================================================

struct TableLayoutConfig {
    bool allow_row_break = false;
    bool repeat_header = true;
    bool prevent_header_break = true;
    Alignment table_alignment = Alignment::Center;
};

struct StructuralStyle {
    Border header_top_border;
    Border header_bottom_border;
    Border table_bottom_border;
    TableCellProps all_headers;   // non-overridable
    TableCellProps table_body;    // non-overridable
};

struct TableStyleConfig {
    TableLayoutConfig layout;
    StructuralStyle structural;
    CellMargins default_cell_margins;
    VerticalAlignment default_vertical_alignment = VerticalAlignment::Center;
    
    // Overridable header/body row styles + textStyleRef
    std::string header_text_style_ref;  // → textStyles["tableHeader"]
    TableCellProps header_row;
    std::string body_text_style_ref;    // → textStyles["tableBody"]
    TableCellProps body_row;
};

// ============================================================================
// Styles Template (resolved from docTemplate)
// ============================================================================

struct StylesTemplate {
    PageConfig page;
    bool widow_control = true;
    
    // Named text styles
    std::unordered_map<std::string, StyleDef> text_styles;
    // "default", "docHeader", "docFooter", "titles", "subtitles",
    // "footnotes", "tableHeader", "tableBody"
    
    TableStyleConfig table_style;
};

// ============================================================================
// TFL Spec (one per spec entry in the JSON)
// ============================================================================

struct TFLSpec {
    std::string key;             // e.g. "spec_8a86766b288e790b"
    DocumentInfo document;
    StyleMap styles;              // per-spec styles (attribs.styles)
    PageConfig page;              // merged: template defaults + spec overrides
    
    std::vector<HeaderFooterLine> headers;
    std::vector<HeaderFooterLine> footers;
    std::vector<std::string> data_refs;
    
    std::vector<StubColumn> stub_columns;  // sorted by stubOrder
    std::vector<ColumnDef> columns;        // sorted by colOrder
    std::vector<RowActionSet> style_rows;  // one per data row
    
    std::vector<TextGroup> titles;
    std::vector<TextGroup> subtitles;
    std::vector<TextGroup> footnotes;
    std::vector<TextGroup> body_text;
    
    DataTable data;              // loaded from dataRef JSON
};

// ============================================================================
// Report Metadata
// ============================================================================

struct ReportMeta {
    std::string out_dir;
    std::string doc_file_name;
    std::string datetime;
};

// ============================================================================
// TFL Document (top-level container)
// ============================================================================

struct TFLDocument {
    ReportMeta meta;
    StylesTemplate styles_template;
    std::vector<TFLSpec> specs;  // sorted by doc_order
};

} // namespace kstfl
```

### 3.3 Style Resolution Order

When rendering a cell, styles cascade in this order (later wins):

```
1. StylesTemplate.text_styles["default"]         ── base defaults from template
2. StylesTemplate.text_styles["tableBody"]        ── region-level (header or body)
3. StylesTemplate.table_style.body_row            ── table row defaults from template
4. StylesTemplate.table_style.structural.tableBody ── non-overridable structural
5. spec.styles[column.format.valueStyleRef]       ── column-level style
6. spec.styles[rowAction.style.styleRef]          ── row-level conditional style
7. (inline markup)                                ── cell-level inline <b>, <i>, <u>, <s>, <sup>, <sub>
```

Merge algorithm for `StyleDef`:

```cpp
StyleDef StyleDef::merged_with(const StyleDef& overlay) const {
    StyleDef result;
    result.font = this->font.merged_with(overlay.font);
    result.paragraph = this->paragraph.merged_with(overlay.paragraph);
    result.table_style = this->table_style.merged_with(overlay.table_style);
    return result;
}
```

Each sub-struct (`FontProps`, `ParagraphProps`, `TableCellProps`) uses the same pattern:
- If `overlay.field.has_value()` → use overlay
- Else → use base

---

## 4. Rendering Pipeline

### 4.1 High-Level Pipeline

```
                    ┌─────────────────────────────────────┐
                    │        render_report(paths)          │
                    └──────────┬──────────────────────────┘
                               │
                    ┌──────────▼──────────────────────────┐
                    │  Phase 1: PARSE                      │
                    │  ● Load spec JSON → TFLDocument       │
                    │  ● Load styles template JSON          │
                    │  ● Load data JSON(s) → DataTable      │
                    │  ● Parse styleRows JSON strings       │
                    │  ● Phase 1b: Enforce isColBreak       │
                    │    layout constraints (warn + force   │
                    │    allow_row_break=F, repeat_header=T)│
                    └──────────┬──────────────────────────┘
                               │
                    ┌──────────▼──────────────────────────┐
                    │  Phase 2: RESOLVE                     │
                    │  ● Merge template + spec page config  │
                    │  ● Merge template + spec styles        │
                    │  ● Resolve style references            │
                    │  ● Compute absolute column widths      │
                    └──────────┬──────────────────────────┘
                               │
                    ┌──────────▼──────────────────────────┐
                    │  Phase 3: MODEL                       │
                    │  ● Build logical table model           │
                    │  ● Apply styleRows actions:            │
                    │    - insert add_rows                   │
                    │    - apply merges (horizontal spans)   │
                    │    - apply style overrides             │
                    │    - mark page breaks                  │
                    │  ● Apply dedupe/isPaging               │
                    └──────────┬──────────────────────────┘
                               │
                    ┌──────────▼──────────────────────────┐
                    │  Phase 4: MEASURE                     │
                    │  ● Initialize font cache               │
                    │  ● Measure all cell text widths+heights│
                    │  ● Determine row heights               │
                    │  ● (Optional) auto-fit column widths   │
                    └──────────┬──────────────────────────┘
                               │
                    ┌──────────▼──────────────────────────┐
                    │  Phase 5: PAGINATE                    │
                    │  ● Split rows into pages               │
                    │  ● Repeat headers on each page         │
                    │  ● Handle isPaging column breaks        │
                    │  ● Handle explicit page_break actions   │
                    │  ● Reserve space for titles/footnotes   │
                    └──────────┬──────────────────────────┘
                               │
                    ┌──────────▼──────────────────────────┐
                    │  Phase 6: EMIT                        │
                    │  ● Generate OOXML parts:               │
                    │    - document.xml (body)               │
                    │    - styles.xml                        │
                    │    - header1..N.xml                    │
                    │    - footer1..N.xml                    │
                    │    - [Content_Types].xml               │
                    │    - _rels/.rels                       │
                    │    - media/ (figures)                  │
                    │  ● ZIP into .docx                      │
                    └──────────┬──────────────────────────┘
                               │
                    ┌──────────▼──────────────────────────┐
                    │  OUTPUT: .docx file                    │
                    └─────────────────────────────────────┘
```

### 4.2 Phase 1: Parse + Layout Constraint Enforcement

```cpp
namespace kstfl {

class JsonParser {
public:
    // Main entry point
    TFLDocument parse_report(
        const std::string& spec_json_path,
        const std::string& template_json_path
    );
    
private:
    ReportMeta parse_metadata(const json& j);
    TFLSpec parse_spec(const std::string& key, const json& j);
    DocumentInfo parse_document(const json& j);
    StyleMap parse_styles(const json& j);
    ColumnDef parse_column(const std::string& name, const json& j);
    StubColumn parse_stub(const std::string& key, const json& j);
    RowActionSet parse_row_action(const std::string& json_str);
    TextGroup parse_text_group(const std::string& key, const json& j);
    
    StylesTemplate parse_template(const json& j);
    PageConfig parse_page_config(const json& j);
    TableStyleConfig parse_table_style(const json& j);
    
    // Data file loading
    DataTable load_data(const std::string& data_ref, const std::string& base_dir);
};

} // namespace kstfl
```

#### Phase 1b: isColBreak Layout Constraints

After parsing, the renderer inspects every spec for `is_col_break` columns.
When any column uses `isColBreak`, horizontal segmentation requires:
- `allow_row_break_across_pages = false` — rows must not split across pages
  because each segment may have different row heights.
- `repeat_header_on_each_page = true` — headers must repeat so every segment
  page is self-contained.

If the current template has incompatible values, the renderer:
1. Creates a per-spec template copy (avoids mutating the shared default).
2. Forces both flags to the required values.
3. Emits an R warning via `Rcpp::warning()` identifying the spec key and the
   overridden options.

Specs without `isColBreak` columns are unaffected.

### 4.3 Phase 2: Resolve

```cpp
class StyleResolver {
public:
    // Merge template defaults → spec styles → produce resolved style map
    ResolvedStyles resolve(
        const StylesTemplate& tmpl,
        const StyleMap& spec_styles
    );
    
    // Resolve a chain of style references into one composite StyleDef
    StyleDef resolve_refs(
        const std::vector<std::string>& refs,
        const ResolvedStyles& resolved
    );
    
    // Compute absolute column widths from percentages/units
    void resolve_column_widths(
        std::vector<ColumnDef>& columns,
        Length printable_width,
        const std::string& content_width  // "90%", "100%"
    );
    
    // Merge template page config with spec overrides
    PageConfig merge_page_config(
        const PageConfig& tmpl_page,
        const json& spec_page_overrides
    );
};
```

### 4.4 Phase 3: Model (Logical Table)

The logical table is built from raw data + styleRows:

```cpp
// A single cell in the logical table
struct LogicalCell {
    std::string text;           // cell value (may contain inline markup)
    StyleDef resolved_style;    // fully resolved style for this cell
    
    int row_span = 1;          // vertical merge (for add_row expansions)
    int col_span = 1;          // horizontal merge (from merge actions)
    bool is_merged_continuation = false;  // spanned-into cell
    
    bool is_header = false;    // header row cell
    bool is_inserted = false;  // from add_row action
};

// A single row in the logical table
struct LogicalRow {
    std::vector<LogicalCell> cells;
    bool page_break_before = false;
    bool page_break_after = false;
    bool is_blank = false;     // blank separator row
    bool is_header = false;
    Length computed_height;     // from text measurement
};

// The full logical table for one TFLSpec
class LogicalTable {
public:
    void build(const TFLSpec& spec, const ResolvedStyles& styles);
    
    const std::vector<LogicalRow>& rows() const;
    size_t num_visible_cols() const;
    const std::vector<ColumnDef>& visible_columns() const;
    
private:
    // --- Build steps ---
    void build_header_rows(const TFLSpec& spec, const ResolvedStyles& styles);
    void build_stub_header_row(const TFLSpec& spec, const ResolvedStyles& styles);
    void build_data_rows(const TFLSpec& spec, const ResolvedStyles& styles);
    void apply_row_actions(const TFLSpec& spec, const ResolvedStyles& styles);
    void apply_dedupe(const TFLSpec& spec);
    
    std::vector<LogicalRow> rows_;
    std::vector<ColumnDef> visible_cols_;
};
```

### 4.5 Phase 4: Measure

```cpp
class TextMeasurer {
public:
    explicit TextMeasurer(FontCache& cache);
    
    // Measure single-line text
    struct TextExtent {
        Length width;
        Length height;
        Length ascent;
        Length descent;
    };
    
    TextExtent measure(const std::string& text, const FontProps& font);
    
    // Measure text with word-wrap into given column width
    Length measure_wrapped_height(
        const std::string& text, 
        const FontProps& font,
        Length available_width,
        const ParagraphProps& para  // for indents, spacing
    );
    
    // Measure a cell (handles inline markup, paragraph spacing)
    Length measure_cell_height(
        const LogicalCell& cell,
        Length col_width,
        const CellMargins& margins
    );
    
    // Measure table row (max cell height in row)
    Length measure_row_height(
        const LogicalRow& row,
        const std::vector<Length>& col_widths,
        const CellMargins& default_margins
    );
    
private:
    FontCache& font_cache_;
    InlineParser inline_parser_; // parse <sup>, <sub>, etc.
};
```

### 4.6 Phase 5: Paginate

```cpp
struct Page {
    std::vector<LogicalRow> header_rows;  // repeated on each page
    std::vector<LogicalRow> body_rows;
    
    // Text groups for this page
    std::vector<TextGroup> titles;        // first page only (or all pages if body*)
    std::vector<TextGroup> subtitles;
    std::vector<TextGroup> footnotes;
    std::vector<TextGroup> body_text;     // appended after table
    
    bool is_first = false;
    bool is_last = false;
};

class Paginator {
public:
    std::vector<Page> paginate(
        const LogicalTable& table,
        const TFLSpec& spec,
        const PageConfig& page,
        const TableStyleConfig& table_style,
        const TextMeasurer& measurer
    );
    
private:
    Length compute_available_height(
        const PageConfig& page,
        bool has_titles,
        bool has_footnotes
    );
    
    bool should_break(
        const LogicalRow& row,
        Length accumulated_height,
        Length available_height,
        const TableLayoutConfig& layout
    );
};
```

---

## 5. Font & Text Subsystem (HarfBuzz)

### 5.1 Font Cache Architecture

```
┌──────────────────────────────────────────────────────────┐
│ FontCache                                                 │
│                                                           │
│  ┌──────────────────────┐     ┌─────────────────────┐    │
│  │  FaceCache            │     │  ShapedTextCache      │    │
│  │  key: (name, bold,    │     │  key: (face_key +     │    │
│  │       italic)          │     │       text + size)    │    │
│  │  val: FT_Face +        │     │  val: ShapedResult    │    │
│  │       HB_Font          │     │       (glyphs, width, │    │
│  │                        │     │        height)        │    │
│  └──────────────────────┘     └─────────────────────┘    │
│                                                           │
│  ┌──────────────────────┐     ┌─────────────────────┐    │
│  │  MetricsCache         │     │  FontSearchPaths     │    │
│  │  key: (face_key +     │     │  - /usr/share/fonts  │    │
│  │       size)            │     │  - ~/.fonts           │    │
│  │  val: FontMetrics      │     │  - C:\Windows\Fonts  │    │
│  │       (ascent, descent,│     │  - embedded fonts     │    │
│  │        line_height,    │     │                       │    │
│  │        avg_char_width) │     │                       │    │
│  └──────────────────────┘     └─────────────────────┘    │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

### 5.2 Core Classes

```cpp
// Font face key for cache lookups
struct FaceKey {
    std::string font_name;     // "Arial"
    bool bold = false;
    bool italic = false;
    
    bool operator==(const FaceKey& o) const;
    size_t hash() const;
};

struct FaceKeyHash {
    size_t operator()(const FaceKey& k) const { return k.hash(); }
};

// Font metrics at a specific size
struct FontMetrics {
    Length ascent;
    Length descent;
    Length line_height;
    Length avg_char_width;    // for quick estimates
    Length space_width;       // width of ' '
    Length em_width;          // width of 'M'
};

// Result of HarfBuzz shaping
struct ShapedGlyph {
    uint32_t glyph_id;
    Length x_advance;
    Length y_advance;
    Length x_offset;
    Length y_offset;
};

struct ShapedResult {
    std::vector<ShapedGlyph> glyphs;
    Length total_width;
    Length ascent;
    Length descent;
};

// Main font cache — instantiated once per render_report() call
class FontCache {
public:
    FontCache();
    ~FontCache();
    
    // Initialize with font search paths
    void add_search_path(const std::string& path);
    void add_embedded_font(const std::string& name, const uint8_t* data, size_t len);
    
    // Core operations
    FontMetrics get_metrics(const FaceKey& face, Length font_size);
    ShapedResult shape_text(const FaceKey& face, Length font_size, const std::string& text);
    Length measure_text_width(const FaceKey& face, Length font_size, const std::string& text);
    
    // Cache stats (for debugging)
    size_t face_cache_size() const;
    size_t metrics_cache_size() const;
    size_t shaped_cache_size() const;
    size_t shaped_cache_hits() const;
    
private:
    // FreeType library handle (one per cache lifetime)
    FT_Library ft_library_;
    
    // Face cache: FaceKey → (FT_Face, hb_font_t*)
    struct FaceEntry {
        FT_Face ft_face = nullptr;
        hb_font_t* hb_font = nullptr;
        std::string file_path;
    };
    std::unordered_map<FaceKey, FaceEntry, FaceKeyHash> face_cache_;
    
    // Metrics cache: (FaceKey, size) → FontMetrics
    struct MetricsKey {
        FaceKey face;
        int size_half_pt;  // font size in half-points for discrete key
        bool operator==(const MetricsKey& o) const;
        size_t hash() const;
    };
    struct MetricsKeyHash {
        size_t operator()(const MetricsKey& k) const { return k.hash(); }
    };
    std::unordered_map<MetricsKey, FontMetrics, MetricsKeyHash> metrics_cache_;
    
    // Shaped text cache: (face + size + text) → ShapedResult
    struct ShapedKey {
        FaceKey face;
        int size_half_pt;
        std::string text;
        bool operator==(const ShapedKey& o) const;
        size_t hash() const;
    };
    struct ShapedKeyHash {
        size_t operator()(const ShapedKey& k) const { return k.hash(); }
    };
    std::unordered_map<ShapedKey, ShapedResult, ShapedKeyHash> shaped_cache_;
    size_t shaped_hits_ = 0;
    
    // Font file resolution
    std::vector<std::string> search_paths_;
    std::unordered_map<std::string, std::string> font_name_to_path_;
    
    FaceEntry& get_or_load_face(const FaceKey& key);
    std::string find_font_file(const FaceKey& key);
    void scan_font_directory(const std::string& dir);
};
```

### 5.3 HarfBuzz Integration Flow

```
Input: text="Systolic BP", font=Arial, size=10pt, bold=true

1. FaceKey{Arial, bold=true, italic=false}
2. FontCache::get_or_load_face()
   → cache miss? find "arialbd.ttf" → FT_New_Face() → hb_font_create()
3. hb_buffer_create() + hb_buffer_add_utf8(text)
4. hb_buffer_set_direction(LTR)
5. hb_buffer_set_script(Latin)
6. hb_shape(hb_font, buffer, features, 0)
7. hb_buffer_get_glyph_infos() + glyph_positions()
8. Sum x_advance → total_width
9. Return ShapedResult + cache it
```

### 5.4 Font Fallback Strategy

```cpp
// Default font fallback chain
const std::vector<std::string> kDefaultFontFallback = {
    "Arial",
    "Liberation Sans",        // Linux equivalent of Arial
    "DejaVu Sans",
    "Noto Sans",
    "FreeSans"
};

// For each FaceKey, try:
//   1. Exact match (font_name + bold/italic variant)
//   2. Base family with style synthesis (FT_GlyphSlot_Oblique, FT_GlyphSlot_Embolden)
//   3. Fallback chain
//   4. "Last resort" embedded font (e.g., Liberation Sans bundled with package)
```

---

## 6. Inline Markup

### 6.1 Supported Tags

Cell text values may contain simple HTML-like markup for mixed-style runs:

| Tag | Effect | OOXML Mapping |
|-----|--------|---------------|
| `<sup>text</sup>` | Superscript | `<w:vertAlign w:val="superscript"/>` |
| `<sub>text</sub>` | Subscript | `<w:vertAlign w:val="subscript"/>` |
| `<b>text</b>` | Bold | `<w:b/>` |
| `<i>text</i>` | Italic | `<w:i/>` |
| `<u>text</u>` | Underline | `<w:u w:val="single"/>` |
| `<s>text</s>` | Strikethrough | `<w:strike/>` |
| `<br>` or `<br/>` | Line break | `<w:br/>` |
| `<p>text</p>` | Separate paragraph | New `<w:p>` element |

### 6.2 Parser Design

```cpp
// Inline markup produces a list of "runs" (OOXML concept)
struct TextRun {
    std::string text;
    
    // Overlay on base FontProps
    bool is_superscript = false;
    bool is_subscript = false;
    std::optional<bool> bold_override;
    std::optional<bool> italic_override;
    std::optional<bool> underline_override;
    std::optional<bool> strikethrough_override;
    
    bool is_line_break = false;      // <br>
    bool is_paragraph_break = false; // <p>
};

struct ParsedParagraph {
    std::vector<TextRun> runs;
};

struct ParsedCell {
    std::vector<ParsedParagraph> paragraphs; // split by <p>
};

class InlineParser {
public:
    // Parse cell text → structured runs
    ParsedCell parse(const std::string& text);
    
    // Check if text contains any markup (fast check — avoid parsing plain text)
    static bool has_markup(const std::string& text);
    
private:
    // State machine parser (no regex dependency)
    enum class State { Text, TagOpen, TagName, TagClose, ClosingTag };
    
    void emit_text(const std::string& text, std::vector<TextRun>& runs);
    void push_tag(const std::string& tag);
    void pop_tag(const std::string& tag);
    
    // Tag stack for nesting: <b><sup>text</sup></b>
    struct TagState {
        bool bold = false;
        bool italic = false;
        bool underline = false;
        bool superscript = false;
        bool subscript = false;
    };
    std::vector<TagState> tag_stack_;
};
```

### 6.3 Superscript/Subscript Metrics

For accurate layout, superscript and subscript text uses different metrics:

```cpp
struct SuperSubMetrics {
    double size_factor = 0.65;       // 65% of base font size
    double super_offset_factor = 0.35; // baseline shift up = 35% of base ascent
    double sub_offset_factor = 0.20;   // baseline shift down = 20% of base descent
};

// When measuring a cell with <sup>/<sub>:
// 1. Shape sup/sub text at (base_font_size * size_factor)
// 2. Adjust height: max(base_ascent + super_offset, base_ascent)
// 3. Width: sum of all run widths
```

---

## 7. Table Layout Engine

### 7.1 Column Width Resolution

```
Input:  column widths from spec (mix of %, cm, pt)
        printable_width from page config
        content_width from document ("90%")

Step 1: Compute available width = printable_width * content_width%
Step 2: Convert all absolute widths (cm, pt, in) to EMU
Step 3: Convert all % widths to EMU relative to available_width
Step 4: Filter to visible columns only
Step 5: Validate sum ≈ available_width (warn if >5% deviation)

Output: vector<Length> absolute column widths
```

### 7.2 Row Height Calculation

For each row:

```
row_height = max(
    for each visible cell in row:
        cell_height = (
            cell_top_margin
            + sum_of_paragraph_heights(
                for each paragraph in cell:
                    para_height = (
                        spacing_before
                        + max(
                            run_line_height * ceil(total_run_width / col_width)
                          ) // word-wrap approximation
                        + spacing_after
                    )
              )
            + cell_bottom_margin
        )
)

// If row_height is specified explicitly (not "auto"), use max(specified, computed)
```

### 7.3 Pagination Algorithm

```
function paginate(header_rows, body_rows, available_height):
    pages = []
    current_page = new_page(header_rows, is_first=true)
    
    header_block_height = sum(header_rows heights)
    titles_height = measure_text_groups(spec.titles)
    footnotes_height = measure_text_groups(spec.footnotes)
    
    for each row in body_rows:
        row_height = row.computed_height
        
        // Check for explicit page break
        if row.page_break_before:
            finalize_page(current_page)
            pages.push(current_page)
            current_page = new_page(header_rows, is_first=false)
        
        // Check if row fits on current page
        space_used = header_block_height + sum(current_page.body heights)
        space_for_footnotes = (current_page.is_last ? footnotes_height : 0)
        remaining = available_height - space_used - space_for_footnotes
        
        if row_height > remaining AND !allow_row_break:
            // Row doesn't fit — start new page
            finalize_page(current_page)
            pages.push(current_page)
            current_page = new_page(header_rows, is_first=false)
        
        current_page.body_rows.push(row)
        
        if row.page_break_after:
            finalize_page(current_page)
            pages.push(current_page)
            current_page = new_page(header_rows, is_first=false)
    
    // Finalize last page
    current_page.is_last = true
    finalize_page(current_page)
    pages.push(current_page)
    
    return pages
```

### 7.4 Horizontal Merge Handling

When `MergeAction{cols: ["A", "B"]}` is applied:

```
Before merge (visible columns: ID, A, B, C):
┌──────┬──────┬──────┬──────┐
│ ID   │  A   │  B   │  C   │
├──────┼──────┼──────┼──────┤
│ Row1 │ ValA │ ValB │ ValC │
└──────┴──────┴──────┴──────┘

After merge (cell A spans 2 columns):
┌──────┬─────────────┬──────┐
│ ID   │     ValA    │  C   │
├──────┼─────────────┼──────┤

LogicalCell for A: col_span = 2, text = "ValA"
LogicalCell for B: is_merged_continuation = true (not emitted)
```

### 7.5 Add Row Handling

When `AddRowAction{pos: above, value_from: "age_grp", styleRef: "font_bold"}`:

```
Before: row N has age_grp = "Age Group: <40"

After: inserted row above N:
┌──────────────────────────────────────────┐
│  Age Group: <40                           │  ← inserted, spans all visible cols
├──────┬──────┬──────┬──────┬──────┬───────┤
│ ID   │ ...  │ ValA │ ValB │ ValC │ Total │  ← original row N
```

The inserted row:
- Spans all visible columns (single merged cell)
- Text = value of `value_from` column at that row
- Style = resolved from `styleRef`

---

## 8. OOXML Emission

### 8.1 DOCX Structure

```
output.docx (ZIP archive)
├── [Content_Types].xml
├── _rels/
│   └── .rels
├── word/
│   ├── document.xml           ← main document body
│   ├── styles.xml             ← style definitions
│   ├── settings.xml           ← document settings
│   ├── fontTable.xml          ← font declarations
│   ├── header1.xml            ← page header(s)
│   ├── footer1.xml            ← page footer(s)
│   ├── _rels/
│   │   └── document.xml.rels  ← relationships
│   └── media/                 ← embedded images (figures)
│       └── image1.png
└── docProps/
    ├── app.xml
    └── core.xml
```

### 8.2 XML Writer (Streaming)

```cpp
// Streaming XML writer — never builds DOM, writes directly to buffer
class XmlWriter {
public:
    explicit XmlWriter(std::string& output);
    
    void declaration(const std::string& version = "1.0", const std::string& encoding = "UTF-8");
    void start_element(const std::string& name);
    void start_element(const std::string& ns, const std::string& name);
    void attr(const std::string& name, const std::string& value);
    void attr(const std::string& name, int value);
    void attr(const std::string& name, bool value);
    void end_element();
    void text(const std::string& content);
    void self_closing(); // emit as <tag attr="val"/> 
    
    // Convenience: write element with text content
    void element(const std::string& name, const std::string& text);
    
private:
    std::string& buf_;
    std::vector<std::string> tag_stack_;
    bool in_start_tag_ = false;
    
    void close_start_tag();
    void escape_text(const std::string& s);
    void escape_attr(const std::string& s);
};
```

### 8.3 Document Emitter

```cpp
class DocxEmitter {
public:
    void emit(
        const TFLDocument& doc,
        const std::vector<Page>& pages,  // per-spec, flattened across all specs
        const std::string& output_path
    );
    
private:
    // Part generators
    std::string emit_document_xml(const TFLDocument& doc, const std::vector<Page>& pages);
    std::string emit_styles_xml(const TFLDocument& doc);
    std::string emit_content_types();
    std::string emit_rels();
    std::string emit_document_rels(bool has_header, bool has_footer, bool has_images);
    std::string emit_header_xml(const std::vector<HeaderFooterLine>& lines, const StyleDef& style);
    std::string emit_footer_xml(const std::vector<HeaderFooterLine>& lines, const StyleDef& style);
    std::string emit_settings_xml(bool widow_control);
    std::string emit_font_table_xml(const std::vector<std::string>& fonts_used);
    
    // Sub-emitters
    void emit_section_properties(XmlWriter& w, const PageConfig& page);
    void emit_table(XmlWriter& w, const Page& page, const TFLSpec& spec, const ResolvedStyles& styles);
    void emit_table_properties(XmlWriter& w, const TFLSpec& spec, const TableStyleConfig& ts);
    void emit_table_grid(XmlWriter& w, const std::vector<Length>& col_widths);
    void emit_row(XmlWriter& w, const LogicalRow& row, const std::vector<Length>& col_widths, const TableStyleConfig& ts);
    void emit_cell(XmlWriter& w, const LogicalCell& cell, Length col_width);
    void emit_cell_properties(XmlWriter& w, const LogicalCell& cell, Length col_width);
    void emit_paragraph(XmlWriter& w, const ParsedParagraph& para, const StyleDef& style);
    void emit_run(XmlWriter& w, const TextRun& run, const FontProps& base_font);
    void emit_run_properties(XmlWriter& w, const TextRun& run, const FontProps& font);
    void emit_text_groups(XmlWriter& w, const std::vector<TextGroup>& groups, const ResolvedStyles& styles);
    void emit_border(XmlWriter& w, const std::string& side, const Border& border);
    
    // ZIP assembly
    void write_docx(
        const std::string& output_path,
        const std::unordered_map<std::string, std::string>& parts,
        const std::vector<std::pair<std::string, std::string>>& media_files  // (dest, source)
    );
};
```

### 8.4 Key OOXML Patterns

#### Table definition

```xml
<w:tbl>
  <w:tblPr>
    <w:tblStyle w:val="TableGrid"/>
    <w:tblW w:w="5000" w:type="pct"/>  <!-- 100% = 5000 pct units -->
    <w:jc w:val="center"/>              <!-- table alignment -->
    <w:tblLayout w:type="fixed"/>       <!-- fixed column widths -->
    <w:tblBorders>
      <!-- structural borders from template -->
    </w:tblBorders>
    <w:tblCellMar>
      <w:top w:w="0" w:type="dxa"/>
      <w:bottom w:w="0" w:type="dxa"/>
      <w:start w:w="40" w:type="dxa"/>
      <w:end w:w="40" w:type="dxa"/>
    </w:tblCellMar>
  </w:tblPr>
  <w:tblGrid>
    <w:gridCol w:w="2835"/>  <!-- column widths in twips (1/20 pt) -->
    <w:gridCol w:w="1417"/>
    ...
  </w:tblGrid>
  <!-- rows follow -->
</w:tbl>
```

#### Row with repeated header

```xml
<w:tr>
  <w:trPr>
    <w:tblHeader/>  <!-- repeat on each page -->
    <w:cantSplit/>   <!-- prevent header row break -->
    <w:trHeight w:val="340" w:hRule="atLeast"/>
  </w:trPr>
  <!-- cells -->
</w:tr>
```

#### Cell with horizontal merge

```xml
<!-- Merged cell (first) -->
<w:tc>
  <w:tcPr>
    <w:gridSpan w:val="3"/>   <!-- spans 3 columns -->
    <w:vAlign w:val="center"/>
    <w:shd w:val="clear" w:fill="E6E6E6"/>
    <w:tcBorders>
      <w:top w:val="single" w:sz="4" w:color="000000"/>
      <w:bottom w:val="single" w:sz="4" w:color="000000"/>
    </w:tcBorders>
  </w:tcPr>
  <w:p>
    <w:pPr>
      <w:jc w:val="center"/>
    </w:pPr>
    <w:r>
      <w:rPr>
        <w:rFonts w:ascii="Arial" w:hAnsi="Arial"/>
        <w:sz w:val="20"/>     <!-- font size in half-points -->
        <w:b/>
      </w:rPr>
      <w:t>Cell Text</w:t>
    </w:r>
  </w:p>
</w:tc>
```

#### Superscript run

```xml
<w:r>
  <w:rPr>
    <w:vertAlign w:val="superscript"/>
    <w:sz w:val="14"/>  <!-- smaller size for sup -->
  </w:rPr>
  <w:t>2</w:t>
</w:r>
```

#### Page break

```xml
<w:p>
  <w:r>
    <w:br w:type="page"/>
  </w:r>
</w:p>
```

#### Header with left/right alignment (tab stops)

```xml
<!-- Header line: "Protocol: Miracle Drug" [tab] "Page x of y" -->
<w:p>
  <w:pPr>
    <w:tabs>
      <w:tab w:val="right" w:pos="14400"/>  <!-- right tab at page width -->
    </w:tabs>
  </w:pPr>
  <w:r><w:t>Protocol: Miracle Drug</w:t></w:r>
  <w:r><w:tab/></w:r>
  <w:r><w:t xml:space="preserve">Page </w:t></w:r>
  <w:r><w:fldChar w:fldCharType="begin"/></w:r>
  <w:r><w:instrText>PAGE</w:instrText></w:r>
  <w:r><w:fldChar w:fldCharType="separate"/></w:r>
  <w:r><w:t>1</w:t></w:r>
  <w:r><w:fldChar w:fldCharType="end"/></w:r>
  <w:r><w:t xml:space="preserve"> of </w:t></w:r>
  <w:r><w:fldChar w:fldCharType="begin"/></w:r>
  <w:r><w:instrText>NUMPAGES</w:instrText></w:r>
  <w:r><w:fldChar w:fldCharType="separate"/></w:r>
  <w:r><w:t>1</w:t></w:r>
  <w:r><w:fldChar w:fldCharType="end"/></w:r>
</w:p>
```

---

## 9. R Integration (Rcpp)

### 9.1 Exported R Function

```r
#' Render DOCX from ksTFL Report
#'
#' @param spec_json Character. Path to the spec JSON file.
#' @param template_json Character. Path to the styles template JSON file.
#' @param output_path Character. Path for the output .docx file.
#' @param font_dirs Character vector. Additional font search directories.
#'
#' @return Invisible logical TRUE on success.
#' @export
render_docx <- function(spec_json, template_json, output_path, font_dirs = NULL) {
    checkmate::assert_file_exists(spec_json, extension = "json")
    checkmate::assert_file_exists(template_json, extension = "json")
    checkmate::assert_path_for_output(output_path, overwrite = TRUE)
    
    if (is.null(font_dirs)) font_dirs <- character(0)
    
    .Call("_ksTFL_render_docx_impl", spec_json, template_json, output_path, font_dirs)
    
    invisible(TRUE)
}
```

### 9.2 Rcpp Binding

```cpp
#include <Rcpp.h>
#include "kstfl/renderer.h"

// [[Rcpp::export(name = ".render_docx_impl")]]
void render_docx_impl(
    std::string spec_json,
    std::string template_json,
    std::string output_path,
    std::vector<std::string> font_dirs
) {
    try {
        kstfl::Renderer renderer;
        
        // Add font search paths
        renderer.add_default_font_paths();
        for (const auto& dir : font_dirs) {
            renderer.add_font_path(dir);
        }
        
        // Render
        renderer.render(spec_json, template_json, output_path);
        
    } catch (const kstfl::RenderError& e) {
        Rcpp::stop("DOCX render failed: %s", e.what());
    } catch (const std::exception& e) {
        Rcpp::stop("Unexpected error in render_docx: %s", e.what());
    }
}
```

### 9.3 Integrated Workflow

```r
# Full ksTFL workflow with C++ renderer
spec <- create_table(mtcars, cols = c(mpg, cyl, hp, wt)) |>
    add_title("Motor Trend Cars") |>
    add_style(id = "bold", s_font(bold = TRUE)) |>
    define_cols(mpg, label = "MPG", colWidth = "25%")

report <- create_report(spec)

# Save JSON intermediates
result <- save_report(report, docFileName = "cars")

# Render to DOCX
render_docx(
    spec_json = file.path(result$metaPath, result$spec_file),
    template_json = system.file("templates", "Default.json", package = "ksTFL"),
    output_path = file.path(result$metaPath, "cars.docx")
)
```

---

## 10. Build & Dependencies

### 10.1 External Libraries

| Library | Version | Purpose | License | Linking |
|---------|---------|---------|---------|---------|
| [nlohmann/json](https://github.com/nlohmann/json) | 3.11+ | JSON parsing | MIT | Header-only |
| [HarfBuzz](https://harfbuzz.github.io/) | 8.0+ | Text shaping | MIT | Dynamic/static |
| [FreeType](https://freetype.org/) | 2.13+ | Font loading/metrics | FreeType License | Dynamic/static |
| [minizip-ng](https://github.com/zlib-ng/minizip-ng) | 4.0+ | ZIP (DOCX) creation | zlib | Static preferred |
| [Rcpp](https://www.rcpp.org/) | 1.0+ | R ↔ C++ bridge | GPL-2+ | R package |

### 10.2 Build System

The package uses R's standard build system via `Makevars` / `Makevars.win`:

```makefile
# src/Makevars
PKG_CXXFLAGS = -std=c++17 \
    -I../inst/include \
    $(shell pkg-config --cflags harfbuzz freetype2)

PKG_LIBS = $(shell pkg-config --libs harfbuzz freetype2) \
    -lminizip

# If static linking is preferred (for CRAN):
# PKG_LIBS = -L../inst/lib -lharfbuzz -lfreetype -lminizip -lz -lpng -lbz2
```

### 10.3 System Requirements in DESCRIPTION

```
SystemRequirements: C++17, HarfBuzz (>= 8.0), FreeType (>= 2.13),
    pkg-config
```

---

## 11. Directory Structure

```
src/                           ← C++ source (compiled by R CMD INSTALL)
├── init.cpp                   ← Rcpp module registration
├── rcpp_bindings.cpp          ← R-facing exported functions
├── kstfl/
│   ├── renderer.h / .cpp     ← Top-level Renderer class (orchestrates pipeline)
│   ├── types.h                ← All struct definitions (Section 3)
│   ├── units.h / .cpp         ← Length, Color, Border parsing
│   ├── json_parser.h / .cpp   ← Phase 1: JSON → C++ structs
│   ├── style_resolver.h / .cpp← Phase 2: style merging + resolution
│   ├── logical_table.h / .cpp ← Phase 3: build logical model
│   ├── text_measurer.h / .cpp ← Phase 4: HarfBuzz text measurement
│   ├── paginator.h / .cpp     ← Phase 5: page splitting
│   ├── docx_emitter.h / .cpp  ← Phase 6: OOXML generation
│   ├── xml_writer.h / .cpp    ← Streaming XML writer
│   ├── font_cache.h / .cpp    ← Font cache (FreeType + HarfBuzz)
│   ├── inline_parser.h / .cpp ← Inline markup parser
│   └── zip_writer.h / .cpp    ← minizip wrapper for DOCX assembly
├── vendor/                    ← Vendored headers (if needed)
│   └── nlohmann/
│       └── json.hpp
inst/
├── templates/                 ← Resolved style templates (JSON)
│   ├── Default.json
│   ├── Navy_Pro.json
│   └── (other bundled templates)
├── fonts/                     ← Embedded fallback fonts (optional)
│   └── LiberationSans-*.ttf
└── schemas/                   ← Existing schemas (unchanged)
```

---

## 12. Performance Considerations

### 12.1 Expected Scale

| Metric | Typical | Worst Case |
|--------|---------|------------|
| Specs per report | 1–20 | 200+ |
| Rows per table | 50–500 | 10,000+ |
| Columns per table | 5–15 | 50 |
| Styles per spec | 5–20 | 100+ |
| styleRows per table | 50–500 | 10,000 |
| Output DOCX size | 50KB–2MB | 50MB+ (with figures) |

### 12.2 Optimization Strategy

1. **Font cache** — amortize `FT_New_Face` across entire report (not per-spec)
2. **Shaped text cache** — clinical tables have many repeated values (treatments, statistics labels)
3. **Streaming XML** — never build DOM; write directly to string buffer
4. **Column-oriented data** — matches JSON input format; no row-major conversion needed
5. **Style precomputation** — resolve all style chains once during Phase 2, store per-cell
6. **Inline markup fast-path** — `has_markup()` check avoids parsing plain text cells (>95% of cells)
7. **Reserve memory** — pre-allocate vectors based on `num_rows * num_cols`

### 12.3 Memory Budget

For a worst-case 10,000-row × 50-column table:

| Component | Estimate |
|-----------|----------|
| DataTable (strings) | ~50MB (if avg cell = 100 bytes) |
| LogicalTable | ~100MB (with styles per cell) |
| XML output buffer | ~20MB |
| Font cache | ~5MB (10 faces × 3 sizes) |
| **Total peak** | **~175MB** |

For typical 200-row × 10-column: **< 10MB**

---

## 13. Open Questions

### Q1: Static vs dynamic linking for HarfBuzz/FreeType?
**Impact:** CRAN compatibility

- [ ] **Static** — easier install, larger binary, no system deps needed
- [ ] **Dynamic** — smaller binary, requires system libraries installed

**Decision:** _________________

---

### Q2: Embed Liberation Sans as fallback font?
**Impact:** Cross-platform reliability

- [ ] **Yes** — adds ~500KB to package, guaranteed font availability
- [ ] **No** — fail/warn if requested font not found on system

**Decision:** _________________

---

### Q3: "Page x of y" — literal text or DOCX field codes?
**Impact:** Page numbering accuracy

- [ ] **Field codes** — dynamic, updated by Word on open (`PAGE` / `NUMPAGES` fields)
- [ ] **Literal text** — simpler emission, but requires pre-computing page count

**Decision:** _________________

---

### Q4: Dedupe algorithm — suppress at logical model or at emit time?
**Impact:** Performance vs correctness

- [ ] **At model (Phase 3)** — simpler, cells cleared early, one pass
- [ ] **At emit (Phase 6)** — preserves raw data in logical model, dedup only at render

**Decision:** _________________

---

### Q5: Figure spec rendering — embed image or reference file?
**Impact:** Portability

- [ ] **Embed in DOCX** — self-contained document, larger file
- [ ] **External reference** — smaller DOCX, requires image file alongside

**Decision:** _________________

---

### Q6: isPaging column — page break on value change
**Impact:** Pipeline complexity

- [ ] **Single pass** — detect changes during model build, mark `page_break_before`
- [ ] **Two-pass** — first pass scans for value changes, second pass inserts breaks

**Decision:** _________________

---

### Q7: Multi-spec DOCX — one document or many?
**Impact:** API design

- [ ] **Single DOCX with section breaks** — one file per report, specs separated by `w:sectPr`
- [ ] **One DOCX per spec** — N files per report, simpler per-spec rendering

**Decision:** _________________

---

### Q8: Template file location
**Impact:** Extensibility

- [ ] **Bundled only** — `inst/templates/` within the package
- [ ] **User-supplied only** — user provides template path
- [ ] **Both** — search bundled first, allow user override path

**Decision:** _________________

---

### Q9: Thread safety — should one render call be parallelizable?
**Impact:** Complexity

- [ ] **Per-spec parallelism** — specs rendered in parallel threads, shared font cache
- [ ] **Sequential** — one spec at a time, simpler implementation

**Decision:** _________________

---

### Q10: colWidth "0.0cm" for hidden columns
**Impact:** OOXML correctness

- [ ] **Skip entirely** — don't emit `<w:gridCol>` for hidden columns
- [ ] **Emit with zero width** — include in grid but `w:w="0"`

**Decision:** _________________

---

## Appendix A: Unit Conversion Reference

| From | To Twips (1/20 pt) | To EMU |
|------|-------|--------|
| 1 pt | 20 | 12,700 |
| 1 cm | 567 | 360,000 |
| 1 in | 1,440 | 914,400 |
| 1 px (96 dpi) | 15 | 9,525 |
| 1 half-point | 10 | 6,350 |

## Appendix B: OOXML Namespace Reference

| Prefix | URI | Usage |
|--------|-----|-------|
| `w` | `http://schemas.openxmlformats.org/wordprocessingml/2006/main` | Main document |
| `r` | `http://schemas.openxmlformats.org/officeDocument/2006/relationships` | Relationships |
| `wp` | `http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing` | Inline images |
| `a` | `http://schemas.openxmlformats.org/drawingml/2006/main` | Drawing ML |
| `pic` | `http://schemas.openxmlformats.org/drawingml/2006/picture` | Pictures |
| `mc` | `http://schemas.openxmlformats.org/markup-compatibility/2006` | Compatibility |

## Appendix C: Border Line Style Mapping

| ksTFL value | OOXML `w:val` |
|-------------|---------------|
| `"single"` | `"single"` |
| `"double"` | `"double"` |
| `"dashed"` | `"dashed"` |
| `"dotted"` | `"dotted"` |
| `"thick"` | `"thick"` |
| `"none"` | `"none"` |

Border width in OOXML: `w:sz` = eighths of a point (1pt → `w:sz="8"`)
