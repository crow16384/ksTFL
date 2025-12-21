# define_cols(spec, cols, ..., colWidth = NULL)

Purpose: Define column metadata and per-column formats/styles for a `TFL_spec`.

Parameters (key ones):
- `cols` (tidyselect) — columns to define
- `label`, `isID`, `isVisible`, `isGrouping`, `isPaging`, `labelStyleRef`, `isColBreak`, `dedupe`, `blankAfter`
- `type`, `format`, `missings`, `colWidth`, `valueStyleRef`

Direct package callees:
- `assert_class`, `enquos` (external), `.get_data_column_names`, `._resolve_style_refs`, `.col_format_spec`, `.merge_recursive`, `.validate_params`
- `.parse_colwidth()` for parsing colWidth strings
- `.recalculate_col_widths()` for auto-recalculation when autoColWidth=TRUE

ColWidth Auto-Recalculation Behavior:
- When `colWidth` is specified via `define_cols()`, the function marks columns as LOCKED
- If `autoColWidth` option is TRUE (default), remaining UNLOCKED columns are automatically recalculated
- Algorithm: Locked columns keep exact width; unlocked columns normalize to fill remaining available space
- Supported formats: `"25%"`, `"3.5cm"`, `"2in"` (no mm support in current spec)
- Example:
  - Initial: id=33.3%, value=33.3%, ratio=33.3%
  - After `define_cols(id, colWidth="20%")`: id=20% (locked), value/ratio normalized to fill 80%
  - After `define_cols(value, colWidth="15%")`: id=20% (unchanged), value=15% (locked), ratio=65% (fills remaining)

Behavior notes:
- `labelStyleRef` and `valueStyleRef` accept single values (recycled), character vectors, or lists of `f_combine()` results for explicit one-to-one mappings.
- Parameter lengths must be 1 or equal to number of columns.
- Column metadata (locked, auto_weight) is preserved in `spec$.metadata$colWidths` for future recalculations

Transitive example:
- `define_cols` -> `._resolve_style_refs` (may interpret `f_combine()` outputs) -> `f_combine` (user-supplied)
- `define_cols` (with colWidth) -> `.parse_colwidth()` -> `.recalculate_col_widths()` (if autoColWidth=TRUE)
