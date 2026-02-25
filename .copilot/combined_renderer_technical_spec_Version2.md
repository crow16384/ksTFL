# ksTFL Deterministic DOCX Renderer — Unified Technical Specification (Renderer Notes + C++ Architecture Draft)

**Current date:** 2026-02-25  
**Purpose:** Provide a single, implementation-ready technical plan for VS Code Copilot to build a C++20 renderer (R-callable via Rcpp) that consumes ksTFL JSON specs and emits **deterministically paginated**, submission-quality **DOCX** (OOXML).

**Copilot skill requirements:** Principal C++ engineer + Principal R/Rcpp engineer + clinical statistical programmer (TFLs) + HarfBuzz/FreeType + OOXML/WordprocessingML.

Use **Boost** library in case of unavailable futures in C++20 standard (check it first!).

This document is a **careful merge** of:
- `renderer_notes.md` (behavioral requirements + pagination/styleRows rules)
- `cpp-renderer-architecture.html` (end-to-end architecture + data structures + OOXML emission plan + build/deps)

---

## 1) Scope, Goals, and Non‑Negotiables

### 1.1 What the engine does
Pipeline (single report render call):

```
R (ksTFL save_report) → spec.json + data JSON(s)[link to SVG or PNG file to render a figure] + template.json → C++ Renderer → .docx
```

### 1.2 Design goals (from architecture draft, kept intact)
- **Pixel-accurate clinical tables** (FDA/EMA submission quality)
- **No Python dependency**
- **R-callable via Rcpp**
- **HarfBuzz-based measurement**
- **Font cache** (amortize face loading)
- **Inline markup** in cell values: `<sup> <sub> <br> <p> <b> <i> <u>`
- **Streaming OOXML** (no in-memory DOM)
- **Thread-safe** where feasible (stateless rendering; future parallelism)

### 1.3 Determinism constraints (from renderer_notes, elevated)
- Pagination must be computed by renderer; **do not rely on MS Word pagination**.
- Output must be stable and predictable given the same inputs:
  - Same data/spec/template + same fonts → same pagination and layout.
- Pagination must consider:
  - measured heights/width [remember about multyline cells] (HarfBuzz-based)
  - header/titles/subtitles/footnotes
  - table header repetition
  - `styleRows.page_break`
  - grouping breaks (`isGrouping`)
  - vertical and horizontal pagination interactions

---

## 2) Inputs, Contracts, and What Is/Is Not Provided

### 2.1 Inputs received by C++ engine (architecture §2.1)
1. **Spec JSON**: a single JSON with `_metadata` and N spec entries (keyed `<name>_<hash16>`).
2. **Data JSON(s)**: one per table spec (column-oriented `{ "col": [values...] }`).
3. **Styles Template JSON**: resolved template referenced by `docTemplate` (if not provided using default).

### 2.2 Cleaned JSON contract (important)
- `save_report()` already strips `.metadata` from specs before export.
- C++ engine **does not receive** R-only structures (`data_env`, quosures, etc.).

### 2.3 Spec JSON structure (combined view)
At minimum each spec includes:
- `document` (docType, hasData, docPrefix, ordering, contentWidth, gluePrefix/glueNumType)
- `attribs.documentStyle.page` (size, orientation, optional margin overrides)
- `attribs.styles` (per-spec style definitions)
- `headers`, `footers` (multi-row, typically 3-column semantics)
- `stubColumns` (spanning header bands)
- `columns` (format, colWidth, flags: isID/isGrouping/isColBreak/dedupe/...)
- `styleRows` (array of JSON strings; aligned to data rows)
- `titles`, `subtitles`, `footnotes`, `bodyText`
- `dataRef` (links to data JSON file(s))

### 2.4 Data JSON contract (renderer_notes vs html resolved)
There is a contradiction between the docs:
- HTML draft says: “All values are **pre-formatted strings** — C++ never needs numeric formatting.”
- renderer_notes says: “You must format numeric values before layout” based on `format`.

**Resolution rule for implementation (must be configurable but deterministic):**
- **Default:** treat data JSON values as already formatted strings (match architecture draft and real export behaviour).
- **Optional compatibility mode:** if numeric values are raw, apply `columns[col].format` and `missings` replacement prior to layout.

Make this a renderer option (e.g., `RendererConfig::data_values_preformatted = true`).

---

## 3) High-Level Rendering Workflow (Exact Phasing)

The combined execution order must follow renderer_notes §17 + architecture pipeline §4:

### 3.1 Full execution sequence (authoritative)
1. Parse JSON inputs (spec JSON + template JSON)
2. Resolve styles dictionary:
   - parse template `textStyles` and `tableStyle`
   - parse spec `attribs.styles`
3. Compute page geometry (page size/orientation/margins; template + spec overrides)
4. Load data JSON(s)
5. Preprocess columns:
   - ordered list using `colOrder`
   - filter `isVisible != false`
   - identify ID columns (`isID`)
   - identify grouping columns (`isGrouping`) and their sequence number (for `#ByGroupX`)
   - compute horizontal segments from `isColBreak`
6. Preprocess raw data rows:
   - (optional) apply formatting/missing
   - apply `dedupe` (or mark for later)
7. Parse and apply `styleRows` actions:
   - insert synthetic rows (`add_row`)
   - register merges
   - register per-row style overrides
   - register explicit `page_break`
8. Build **logical row stream** (final row list including synthetic rows)
9. If `document.hasData == false`:
   - render `bodyText` and stop for this spec
10. Build table header grid (stub header rows + column label row)
11. Split into horizontal segments if needed (`isColBreak`)
12. For each segment:
   - measure header and rows (HarfBuzz)
   - paginate vertically
13. For each page:
   - render header section (doc header)
   - render titles/subtitles (rules: header vs body, repetition, dynamic subtitles)
   - render repeated table header
   - render page body rows
   - render footnotes (body vs footer rules)
   - render footer section

---

## 4) Page Model and Section Mapping

### 4.1 Page structure (renderer_notes §2)
- PAGE
  - Header section (row of 3 columns, as many rows as needed)
  - Titles
  - Subtitles
  - Table (header + body) OR Figure file
  - Footnotes
  - Footer section (row of 3 columns, as many rows as needed)

### 4.2 Mapping to JSON sections (renderer_notes table)
| Page element | JSON section |
|---|---|
| Doc header (3 cols) | `headers` |
| Titles | `titles` |
| Subtitles | `subtitles` |
| Table header | `stubColumns` + `columns` |
| Table body | `columns` + `styleRows` + `data` |
| Footnotes | `footnotes` |
| Doc footer (3 cols) | `footers` |

---

## 5) Page Geometry and Usable Layout Area

### 5.1 Physical page size and margins (renderer_notes §3 + html PageConfig)
From template + spec overrides (`attribs.documentStyle.page`):

Compute:
- `page_width`, `page_height` from size + orientation
- margins:
  - `top`, `bottom`, `left`, `right`
  - `header_distance`, `footer_distance`

Distinction (renderer_notes):
- `top/bottom` affect content area
- `header/footer` are offsets for header/footer placement

Derived:
- `usable_width  = page_width  - left - right`
- `usable_height = page_height - top  - bottom`

### 5.2 Vertical budgeting (renderer_notes §3.2)
Subtract dynamic blocks to derive available table-body height:
- header block height
- titles height
- subtitles height (dynamic per page if `#ByGroupX`)
- table header height (repeated)
- footnotes height (if `bodyFootnotes = true` and on the page where they appear)

The remaining height is table body capacity.

---

## 6) Styles System — Data Model, Merging, and Precedence

### 6.1 Style definitions (renderer_notes §4 + html types.h)
Spec styles live in:
- `attribs.styles` (per-spec StyleMap)
Template styles live in:
- `textStyles` (default/docHeader/docFooter/titles/subtitles/footnotes/tableHeader/tableBody)
- `tableStyle` (layout + structural + header/body row styles + defaults)

### 6.2 Style content capabilities (renderer_notes + html)
A style may include:
- `font` props (name, size, bold/italic/underline, color, highlight)
- `paragraph` props (alignment, spacing before/after, line spacing multiplier, indents, widow control)
- `table_style` props (background, borders, cell margins, vertical alignment, text orientation, row height)

### 6.3 Merge semantics (both docs)
- Style merge is overlay-based:
  - Later overrides earlier
  - Null does not override
- Must implement `merged_with()` for:
  - `FontProps`, `ParagraphProps`, `TableCellProps`, `StyleDef`

### 6.4 Table cell style application priority (renderer_notes §4.1) — preserved
For table cells (later wins):
1. Base column format style (`columns[col].format.valueStyleRef`)
2. Column label style (`columns[col].labelStyleRef`)
3. Stub label style (`stubColumns[*].labelStyleRef`)
4. Row-style (`styleRows`)
5. Merge-level style
6. Add-row style
7. Explicit style overrides (if present)

### 6.5 Template + spec cascade order (html §3.3) — integrated
For a **body cell**, compute effective style in layers (later wins):
1. Template `textStyles["default"]`
2. Region style:
   - body: `textStyles["tableBody"]`
   - header cells: `textStyles["tableHeader"]`
3. Template row defaults:
   - `table_style.body_row` or `table_style.header_row`
4. Template structural “non-overridable” props:
   - `table_style.structural.tableBody` / `allHeaders`
5. Column `valueStyleRef` (body) or label style refs (header)
6. RowAction `style` refs for that cell
7. Merge styleRef for merged cell (if any)
8. Add-row styleRef if the row is synthetic (applied at row build time)
9. Inline markup modifies run properties (`<b>`, `<i>`, `<sup>`, `<sub>`)

**Note:** This merges both precedence lists: renderer_notes covers table-specific sources; html adds template baseline layers. Implementation must include both.

---

## 7) Titles and Subtitles Logic (Exact)

### 7.1 Inputs (renderer_notes §5)
- `document.docPrefix`
- `document.glueNumType` / `document.gluePrefix` (naming differs; treat as same intent)
- `titles`, `subtitles`
- `bodyTitles`, `bodySubtitles`

### 7.2 Rendering rules (renderer_notes)
Each text group:
- sort by `order`
- concatenate `text[]` with soft line break
- render as **ONE paragraph** per group

Prefix glue rule:
- If glue enabled:
  - `"Table 14.2: " + first title` (prefix glued into first title paragraph)
- Else:
  - prefix is a separate paragraph before titles

Placement:
- If `bodyTitles=true` -> in body else in header section
- Subtitles follow same pattern

### 7.3 Dynamic subtitles from grouping (renderer_notes §6.1 isGrouping)
- Placeholders like `#ByGroupX`:
  - X refers to the sequence number among `isGrouping` columns (1-based)
- When subtitles are dynamic:
  - subtitle height must be measured **in advance per page** using the group values on that page
  - group value changes force page breaks (see pagination)

---

## 8) Column Model (Ordered, Filtered, and Interpreted)

### 8.1 Building column order (renderer_notes §6)
- ordered by `colOrder`
- filtered by `isVisible != false`

### 8.2 Flag meanings (renderer_notes §6.1) — preserved in full
- `isID` + `isColBreak`: repeat ID column on subsequent pages if table spans pages; also repeat across horizontal segments
- `isGrouping`:
  - dynamic subtitles (`#ByGroupX`)
  - when specified, table breaks when group values change
  - logical grouping; not direct layout change
- `isPaging` (deprecated):
  - value change forces page break (but renderer_notes says grouping change must break)
- `isColBreak`:
  - splits table horizontally into page segments
  - height/row-count calculations must account for all columns so parts fit equally
  - multiple columns may have `isColBreak=true`
- `dedupe`: suppress consecutive repeats
- `blankAfter` deprecated (use rowstyles/add_row instead)
- `format`: includes `colWidth`, `missings`, `valueStyleRef`, etc.

---

## 9) Stub Columns (Spanning Headers)

From `stubColumns` (renderer_notes §7):
- sort by `stubOrder` (descending)
- build multi-row header:
  - top rows: spanning headers
  - bottom row: individual column labels

Algorithm (renderer_notes §7):
1. Determine maximum stub depth
2. Build header grid
3. Each stub spans width of its `cols`
4. Render label with `styleRef`

---

## 10) Header Layout and Measurement

### 10.1 Header height (renderer_notes §8)
Compute before pagination:
- measure each header cell text
- apply wrapping within its cell width
- compute cell height
- row height = max(cell height)
- table header height = sum of header row heights

---

## 11) Body Rendering and Row Stream Construction

From renderer_notes §9:
For each data row:
1. Format values (if applicable; see §2.4)
2. Apply `dedupe`
3. Apply `styleRows` actions
4. Insert synthetic rows (`add_row`)
5. Measure row height
6. Fit into page

**Important correction from renderer_notes numbering:** step “3” missing; keep semantic order, not numbering.

---

## 12) `styleRows` System (CRITICAL) — Full Behaviour

`styleRows[i]` is a JSON string conforming to `row_style_actions_schema_v0.json`.

### 12.1 `style`
Apply style to specific cols in this row; overrides column-level:
```json
"style": [ { "cols": ["col1","col2"], "styleRef": "styleA" } ]
```

### 12.2 `merge`
Horizontally merge cells:
```json
"merge": [ { "cols": ["col1","col2","col3"], "styleRef": "optional" } ]
```
Rules:
- Combined width = sum(column widths)
- Only first cell renders; others suppressed
- Apply merge styleRef if provided
- HarfBuzz measurement must use the combined width

### 12.3 `add_row`
Insert synthetic row above/below:
```json
"add_row": [
  { "pos": "above"|"below", "value_from": "col_id", "styleRef": "styleX" }
]
```
Rules:
- Synthetic row participates fully in pagination and measurement
- New row has one visible value, rest blank
- Apply styleRef to entire row
- Multiple add_row entries allowed; apply in recorded order
- Clarification: synthetic row can also have styleRows entry (renderer_notes §19.3 says YES)  
  => Implementation must allow action application to synthetic rows too (see §18.4).

### 12.4 `page_break`
Force page break **before** rendering this row:
```json
"page_break": [ {} ]
```

---

## 13) Pagination Algorithm (Deterministic; Not Word-Driven)

### 13.1 Must consider (renderer_notes §11)
- Header height (constant per page)
- Titles/subtitles (repeated; subtitles can have dynamic heights from grouping)
- Repeated table header
- ID column repetition
- `styleRows.page_break`
- available vertical space
- grouping breaks
- deprecated `isPaging` column changes

### 13.2 Vertical pagination requirements (renderer_notes §11.1)
- Must be “smart” and fit each part exactly into free page space based on measured heights.
- Must guarantee Word will not break pagination:
  - use OOXML flags: cantSplit, fixed table layout, explicit page breaks, etc.

### 13.3 Horizontal pagination (`isColBreak`) (renderer_notes §11.2)
- Split columns into segments.
- Example: ID A B C |break| D E F:
  - Page segment 1: ID A B C
  - Segment 2: ID D E F
- Each segment paginated vertically.
- HarfBuzz row-height computation must “take into account all columns” so split parts fit equally.

**Implementation rule (recommended and consistent with both docs):**
- Compute row heights from the full logical row (all visible columns) once.
- Reuse those heights for all segments.
- Segment emission is a “view” over the row.

### 13.4 Deprecated `isPaging` (renderer_notes §11.3)
If still used:
- if paging column value changes -> force page break.

### 13.5 Precedence of break triggers (renderer_notes §19.1 clarification)
- `isPaging` deprecated, but grouping value changes must break page.
- If both occur with styleRows.page_break, explicit page_break wins.
- Proposed deterministic precedence:
  1. `styleRows.page_break`
  2. grouping change (`isGrouping`)
  3. `isPaging` change (deprecated)
  4. row doesn’t fit

### 13.6 Titles repetition on horizontal split (renderer_notes §19.2)
- When horizontal split happens: titles repeat? **YES**.

---

## 14) Footnotes

From renderer_notes §12:
- groups: `text[]`, `styleRef`, `order`
- sort by `order`
- concatenate text via soft break
- placement:
  - if `bodyFootnotes=true`:
    - render below table on final page
    - subtract height during layout
  - else:
    - render in footer section

---

## 15) `hasData = false`

From renderer_notes §13:
- no table
- render `bodyText` instead
- apply styles
- respect placement rules

---

## 16) HarfBuzz Measurement System (Detailed)

From renderer_notes §14 + html §5:

### 16.1 Text measurement steps (renderer_notes)
For each text block:
1. Resolve style
2. Determine font family/size/bold/italic
3. Shape with HarfBuzz
4. Compute glyph advances
5. Soft line break within cell width
6. Apply paragraph spacing and line spacing

Final paragraph/cell height:
- `(sum line heights) * line_spacing_multiplier + spacing.before + spacing.after`
- plus cell margins top/bottom (from table cell props/defaults)

Row height:
- `row_height = max(cell_heights)` unless overridden by explicit row height.

### 16.2 Font cache architecture (html §5.1)
Implement caches:
- FaceCache: key `(name, bold, italic)` → `FT_Face` + `hb_font_t*`
- MetricsCache: key `(face_key + size)` → ascent/descent/line height etc.
- ShapedTextCache: key `(face_key + size + text)` → shaped glyphs + width

### 16.3 Font fallback strategy (html §5.4)
Deterministic fallback chain example:
- Arial → Liberation Sans → DejaVu Sans → Noto Sans → FreeSans
Fallback policy:
1. exact match
2. synthesize bold/italic
3. fallback chain
4. embedded last-resort font (optional)

### 16.4 Inline markup metrics (html §6.3)
Superscript/subscript:
- render at reduced font size (e.g., factor 0.65)
- baseline shift affects total line metrics deterministically

---

## 17) `contentWidth` and Column Width Resolution

From renderer_notes §15 + html §7.1:

- If `document.contentWidth` defined: table width = that (percent of printable/usable width)
- Else: table width = usable width

Resolve `colWidth`:
- Absolute units: `cm`, `in`, `pt` → EMU
- Percent: resolve against table width
- Remaining width: distribute deterministically among unspecified columns

Validation:
- Warn if total width deviates significantly (e.g., >5%).

---

## 18) Merging Cells — Layout and OOXML Details

### 18.1 Layout behavior (renderer_notes §16 + html §7.4)
- Combined width = sum widths
- measure text once with combined width
- adjust grid mapping
- remove internal vertical borders (“Word-like” collapse)

### 18.2 OOXML emission for horizontal merge (html §8.4)
Use `<w:gridSpan w:val="N"/>` on the leading cell.

### 18.3 Border collapsing (renderer_notes §19.5)
- Must be Word-like (not strict grid). Practically:
  - internal borders removed or set to none for merged interior.
  - preserve outer borders.

### 18.4 Synthetic rows and styleRows interaction (renderer_notes §19.3)
“If synthetic row created by add_row also has styleRows entry? YES.”
Implementation detail:
- After expanding add_row into the logical row stream, you must still allow row actions to apply to those synthetic rows.
- Deterministic mapping required:
  - Option A (recommended): synthetic rows inherit the parent row index but have “sub-index”; apply parent row’s actions only when explicitly directed; apply synthetic row’s own styleRows if present in expanded stream.
  - Option B: generate a parallel action stream for inserted rows.  
Choose one; document it and keep stable.

---

## 19) OOXML Emission Plan (Streaming; Complete)

From html §8:

### 19.1 DOCX package structure
```
output.docx (ZIP)
├── [Content_Types].xml
├── _rels/.rels
├── word/document.xml
├── word/styles.xml
├── word/settings.xml
├── word/fontTable.xml
├── word/header1.xml (optional)
├── word/footer1.xml (optional)
├── word/_rels/document.xml.rels
└── word/media/* (optional; figures)
```

### 19.2 Streaming XML writer (html §8.2)
- Implement `XmlWriter` that writes to string buffer; no DOM.
- Must escape text and attributes properly.
- Manage tag stack and start-tag closing.

### 19.3 Key OOXML patterns (html §8.4 + renderer_notes determinism)
- Table:
  - `<w:tblLayout w:type="fixed"/>`
  - `<w:tblGrid>` with `<w:gridCol w:w="..."/>` widths in **twips**
  - `<w:tblW>` table width (pct or dxa depending on design)
- Header rows:
  - `<w:tblHeader/>`
  - `<w:cantSplit/>`
- Row height:
  - `<w:trHeight w:val="..." w:hRule="atLeast|exact"/>` as needed
- Page breaks:
  - `<w:br w:type="page"/>` in a paragraph at break points
- Header/footer layout (tab stops) (html §8.4):
  - left text + tab + right aligned content
  - `PAGE` and `NUMPAGES` fields (recommended over literal)

### 19.4 Preventing Word repagination
Emit OOXML properties to ensure:
- rows do not split (`cantSplit`)
- fixed table layout
- consistent grid widths
- explicit page breaks before new pages (especially where renderer decided)
- explicit section break between specs

---

## 20) Inline Markup (Parsing + Emission)

From html §6 + renderer_notes §4:

### 20.1 Supported tags
- `<sup>`, `<sub>`, `<b>`, `<i>`, `<u>`, `<br>`, `<p>`

### 20.2 Inline parser design (html §6.2)
- Produce:
  - `ParsedCell` → paragraphs → runs
- Use stack-based state machine (no regex required)
- Runs carry overrides on base style:
  - superscript/subscript flags
  - bold/italic/underline override
  - paragraph breaks and line breaks

### 20.3 OOXML mapping (html §6.1)
- `sup/sub`: `<w:vertAlign w:val="superscript|subscript"/>`
- `<br>`: `<w:br/>`
- `<p>`: new `<w:p>`

---

## 21) C++ Data Structures (Keep the Draft’s Types, Align With Notes)

The html document contains a full `types.h` draft. Keep those structures (Length, Color, Border, styles, columns, styleRows actions, DataTable, PageConfig, TableStyleConfig, TFLSpec, TFLDocument).

**Critical additions to ensure renderer_notes coverage:**
- Add explicit support for:
  - dynamic subtitle placeholder resolution with `#ByGroupX`
  - grouping break detection
  - horizontal segmentation model for `isColBreak` with ID repetition
  - deterministic mapping of expanded row stream (after add_row) to pagination + measurement

---

## 22) Rendering Pipeline Components (Classes) — Consolidated

Use the architecture draft’s component plan, but ensure behaviour parity with renderer_notes:

### 22.1 Phase 1: Parse
- `JsonParser`
  - parse metadata
  - parse template into `StylesTemplate`
  - parse each spec:
    - `DocumentInfo`, `attribs.styles`, headers/footers, stubColumns, columns, titles/subtitles/footnotes/bodyText
    - parse styleRows strings to `RowActionSet`
  - load data JSON(s) into `DataTable`

### 22.2 Phase 2: Resolve
- `StyleResolver`
  - merge template defaults and spec overrides for page config
  - resolve style refs into a composite `StyleDef`
  - resolve column widths from mixed units/pct against content width

### 22.3 Phase 3: Model (Logical Table)
- `LogicalTableBuilder`
  - header grid from stubColumns + column labels
  - build initial row list from DataTable
  - apply:
    - dedupe
    - styleRows:
      - add_row insertion
      - merges
      - per-cell style overlays
      - explicit page breaks
    - grouping breaks (isGrouping)
    - deprecated isPaging breaks (if enabled)

### 22.4 Phase 4: Measure (HarfBuzz)
- `FontCache`
- `InlineParser`
- `TextMeasurer`
  - cell measurement with wrap and paragraph spacing
  - merged-cell measurement using combined widths
  - row height = max cell height unless overridden

### 22.5 Phase 5: Paginate
- `Paginator`
  - compute available page height per page (account for dynamic subtitles)
  - split rows deterministically
  - ensure last page reserves space for body footnotes if applicable
  - apply explicit breaks before rows where required
  - keep per-page metadata: first/last, titles/subtitles content, etc.

### 22.6 Phase 6: Emit DOCX
- `DocxEmitter` using:
  - `XmlWriter`
  - ZIP assembly (minizip-ng)
- Emit:
  - document.xml with section properties and page breaks
  - styles.xml, settings.xml, fontTable.xml
  - header/footer XML parts if using Word header/footer mechanism

---

## 23) R Integration (RcppArmadillo)

From html §9:
- R function `render_docx(spec_json, template_json, output_path, font_dirs=NULL)`
- Rcpp binding `.Call("_ksTFL_render_docx_impl", ...)`
- C++ implementation catches `RenderError` and `std::exception` and forwards via `Rcpp::stop`

---

## 24) Build, Dependencies, and Directory Structure

From html §10–11:

### 24.1 Dependencies
- `nlohmann/json` (header-only)
- HarfBuzz (latest)
- FreeType (latest)
- minizip-ng (latest) for ZIP
- RcppArmadillo (latest)

### 24.2 Build system
- R package `src/Makevars` / `Makevars.win`
- use `pkg-config` for HarfBuzz/FreeType where available

### 24.3 Directory structure (target)
```
src/
  init.cpp
  rcpp_bindings.cpp
  kstfl/
    renderer.h/.cpp
    types.h
    units.h/.cpp
    json_parser.h/.cpp
    style_resolver.h/.cpp
    logical_table.h/.cpp
    text_measurer.h/.cpp
    paginator.h/.cpp
    docx_emitter.h/.cpp
    xml_writer.h/.cpp
    font_cache.h/.cpp
    inline_parser.h/.cpp
    zip_writer.h/.cpp
inst/
  templates/
  fonts/ (optional embedded fallback)
  schemas/
```

---

## 25) Behavioural Clarifications (Renderer Notes §19) — Incorporated

1. If both `isPaging` and `styleRows.page_break` occur:
   - `isPaging` deprecated
   - grouping changes must break page
   - explicit page_break has highest precedence
2. When horizontal split happens — do titles repeat?
   - YES
3. If synthetic row created by `add_row` also has `styleRows` entry?
   - YES (must support)
4. `blankAfter`:
   - deprecated; use `add_row`
5. Merging borders collapse:
   - Word-like

---

## 26) Open Questions from Architecture Draft (Must Be Decided)

From html §13 (include as implementation decisions):
- Static vs dynamic linking for HarfBuzz/FreeType (CRAN impact)[static]
- Embed Liberation Sans fallback font?[yes]
- “Page x of y”: field codes (PAGE/NUMPAGES) vs literal[field codes (PAGE/NUMPAGES)]
- Dedupe location: model-phase vs emit-time[model-phase]
- Figure rendering: embed vs external[embed]
- `isPaging` detection: single vs two-pass[two-pass]
- Multi-spec output: single doc with section breaks vs one doc per spec[single doc with section breaks]
- Template location: bundled vs user-supplied vs both[both]
- Thread safety / parallelism: per-spec parallel vs sequential[per-spec parallel]
- Hidden columns: skip gridCol vs emit zero width[skip gridCol]

---

## 27) Implementation Acceptance Criteria (Clinical TFL Quality)

A build is acceptable only if:
- pagination matches measured heights; Word does not repaginate
- table header repeats correctly
- ID column repetition works across page breaks and horizontal segments
- grouping breaks occur on grouping value changes
- dynamic subtitles render correct group values and heights are reserved correctly
- `styleRows` actions are faithfully applied (merge/add_row/style/page_break)
- merged-cell measurement uses combined widths; internal borders removed
- DOCX opens in Word without repair prompt

---

## 28) Implementation Notes (Copilot Guidance)

### 28.1 Deterministic “layout contract”
To keep Word from interfering:
- fixed grid widths
- cantSplit rows
- explicit page breaks where pagination says
- avoid Word auto-fit

### 28.2 Measurement contract
- all text measurement must go through HarfBuzz shaping + wrap decisions
- do not use naive character counts

### 28.3 Horizontal segmentation contract
- compute row heights against the full set of visible columns
- emit segments as views with repeated ID columns
- titles/subtitles repeated on every segment page

---

## 29) Minimal API Sketch (C++ + R)

### 29.1 C++ public API
- `kstfl::Renderer`
  - `add_default_font_paths()`
  - `add_font_path(std::string)`
  - `render(spec_json_path, template_json_path, output_path)`

### 29.2 R API
- `render_docx(spec_json, template_json, output_path, font_dirs=NULL)`

---

## 30) What Copilot Must Implement First (Critical Path)

1. Unit system: `Length::parse()`, EMU/twips conversions
2. Template parser (page + styles + tableStyle)
3. Spec parser (including styleRows JSON-string parsing)
4. Column ordering + width resolution (`contentWidth`)
5. LogicalTableBuilder:
   - stub header grid
   - styleRows: add_row + merge + style + page_break
   - dedupe
   - grouping boundary detection
6. HarfBuzz measurement + wrapping + paragraph spacing
7. Paginator with dynamic subtitle measurement
8. OOXML emitter for fixed-layout tables + merged cells + header repetition
9. ZIP packaging to .docx
10. Rcpp binding + error plumbing

---