# Core Data Structures

## TFL_spec (S3 class)
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
- titles, subtitles, footnotes, bodyText: lists of text group entries (text, styleRef, order)
- .metadata: internal state (report_cols, data_env, colWidths, compute_cols, hash) - NOT serialized

## TFL_report (S3 class inheriting from list)
Created by create_report(). Named list of TFL_spec objects keyed by "<varname>_<hash>".
Class: c("TFL_report", "list")

## TFL_options (S3 class)
Used for package settings (headers, footers, bodyText, styles, page).
Supports add_style, add_body_text, add_header, add_footer via S3 dispatch.

## Data Environment (.metadata$data_env)
3-layer rlang environment:
- Functions layer: helper functions (firstOf, lastOf, rowNumber, etc.) with access to data
- Data layer (__data__): copy of input data.frame
- Mask layer (__mask__): tidyselect data mask for column filtering
Expressions in compute_cols are evaluated in this environment during create_report().

## Style System
Styles stored in spec$attribs$styles as named list.
Each style can have: font, paragraph, table_style sub-objects.
Style refs: single string or f_combine() for multi-style combos.
create_report() consolidates combos into merged "style_<hash>" entries.
Context enforcement: s_borders() only inside s_table_style(), s_spacing()/s_indents() only inside s_paragraph().

## Column Format 
Auto-detected by .guess_table_layout() during init.
Format spec: list(type = "string"|"numeric", format = NULL|pattern, missings = value, colWidth = "xx%", valueStyleRef = NULL)
Column widths auto-calculated and sum to 100%. Locked widths via define_cols() trigger redistribution.
