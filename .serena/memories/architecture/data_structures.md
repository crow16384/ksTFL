# Core Data Structures

## R-Side Structures

### TFL_spec (S3 class)
Created by create_table/create_text/create_figure via internal .tfl_init().
Structure:
- document: list(docType, hasData, docPrefix, docOrder, isContinues, contentWidth, bodyTitles, bodySubtitles, bodyFootnotes, gluePrefix)
- attribs: list(documentStyle = list(docTemplate, page = list(size, orientation, margins)), styles = list(...named styles...))
- headers: list of header entries
- footers: list of footer entries
- dataRef: character vector of data references
- stubColumns: list of spanning column definitions
- columns: named list of column specs (colOrder, label, isVisible, isID, isGrouping, isPaging, labelStyleRef, isColBreak, dedupe, blankAfter, format)
- styleRows: list of row style definitions (serialized as JSON strings during create_report)
- titles, subtitles, footnotes, bodyText: lists of text group entries (text, styleRef (array), order) — C++ side stores all refs in `style_refs` vector and merges in order
- .metadata: internal state (report_cols, data_env, colWidths, compute_cols, hash) — NOT serialized

### TFL_report (S3 class inheriting from list)
Created by create_report(). Named list of TFL_spec objects keyed by "<varname>_<hash>".
Class: c("TFL_report", "list")

### TFL_options (S3 class)
Used for package settings (headers, footers, bodyText, styles, page).
Supports add_style, add_body_text, add_header, add_footer via S3 dispatch.
Note: tfl_set_options() REPLACES previous headers/footers, not accumulates.

### Data Environment (.metadata$data_env)
3-layer rlang environment:
- Functions layer: helper functions (firstOf, lastOf, rowNumber, etc.) with access to data
- Data layer (__data__): copy of input data.frame
- Mask layer (__mask__): tidyselect data mask for column filtering
Expressions in compute_cols are evaluated in this environment during create_report().

### Style System (R)
Styles stored in spec$attribs$styles as named list.
Each style can have: font, paragraph, table_style sub-objects.
Style refs: single string or f_combine() for multi-style combos.
create_report() consolidates combos into merged "style_<hash>" entries.
Context enforcement: s_borders() only inside s_table_style(), s_spacing()/s_indents() only inside s_paragraph().

### Column Format (R)
Auto-detected by .guess_table_layout() during init.
Format spec: list(type = "string"|"numeric", format = NULL|pattern, missings = value, colWidth = "xx%", valueStyleRef = NULL)
Column widths auto-calculated and sum to 100%. Locked widths via define_cols() trigger redistribution.

## C++-Side Structures (types.h, namespace kstfl)

### Core Value Types
- Length: EMU-based (1in = 914400 EMU), static parse() from "12pt"/"1.5in"/"5%"/etc
- Color: hex string (#RRGGBB)
- RenderError: std::runtime_error subclass for all renderer errors

### Style Types
- Border: color, width (Length), line_style (enum: single, double, dashed, dotted, thick, none)
- Borders: top, bottom, left, right Border + insideH, insideV
- FontProps: name, size, bold, italic, underline, color, highlight
- SpacingProps: before, after, line_spacing (all Length)
- IndentProps: left, right, first_line (all Length)
- ParagraphProps: alignment (enum), spacing, indents
- TableCellProps: background_color, row_height, vertical_alignment, text_orientation, borders
- StyleDef: font + paragraph + table_style props (combined)
- StyleMap: unordered_map<string, StyleDef>

### Page/Document Types
- PageSize enum: Letter, A4, Legal, etc.
- Orientation enum: Portrait, Landscape
- PageMargins: top/bottom/left/right/header/footer (all Length)
- PageConfig: size, orientation, margins, computed content_width/content_height
- TableStyleConfig: defaults for table formatting
- TextStyles: defaults for various text groups (title, subtitle, footnote, etc.)
- StylesTemplate: complete template (page defaults, table config, text styles, styles map)

### Spec Types
- ColumnFormat: type, format_str, missings, col_width_raw (string for deferred % parsing)
- ColumnSpec: name, label, col_order, format, is_id/is_visible/is_grouping/is_paging/is_col_break, dedupe, blank_after, value_style_ref, label_style_ref
- StubColumn: label, col_indices, label_style_ref (spanning headers)
- TextGroup: text (vector<string>), style_refs (vector<string>, merged in order), order, body_placement
- HeaderFooterRow: left/center/right parts
- DataTable: col_names + rows (vector<vector<string>>)

### StyleRows Action Types
- StyleAction: column indices + style_ref
- MergeAction: column indices + style_ref
- AddRowAction: position (above/below), value_from column, style_ref
- PageBreakAction: (empty, marker only)
- RowActionSet: per-row aggregation of all actions above

### Document Types
- DocType enum: Table, Figure, Text
- DocumentInfo: doc_type, has_data, doc_prefix, doc_order, is_continues, content_width, glue_prefix
- TFLSpec: document info, columns, stub_columns, styles, titles/subtitles/footnotes/body_text, headers/footers, data_ref, style_rows
- ReportMetadata: datetime, version
- TFLDocument: metadata + vector<TFLSpec>
- RendererConfig: verbose, font_dirs, fallback_font, template_path

### Logical Table Types
- LogicalRowType enum: Header, Data, AddedRow, PageBreak
- LogicalCell: text + resolved StyleDef + merge span
- LogicalRow: type, cells vector, is_paging_header, original row index, measured_height (set by Paginator::paginate())
- HeaderGridCell: text, style, col_span
- HeaderGrid: vector<vector<HeaderGridCell>>

### Pagination Types
- PageSlice: column range, row range, is_continuation, repeat_header flag
- HorizontalSegment: column subset for horizontal pagination
