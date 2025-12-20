# define_cols(spec, cols, ...)

Purpose: Define column metadata and per-column formats/styles for a `TFL_spec`.

Parameters (key ones):
- `cols` (tidyselect) — columns to define
- `label`, `isID`, `isVisible`, `isGrouping`, `isPaging`, `labelStyleRef`, `isColBreak`, `dedupe`, `blankAfter`
- `type`, `format`, `missings`, `colWidth`, `valueStyleRef`

Direct package callees:
- `assert_class`, `enquos` (external), `.get_data_column_names`, `._resolve_style_refs`, `.col_format_spec`, `.merge_recursive`, `.validate_params`

Behavior notes:
- `labelStyleRef` and `valueStyleRef` accept single values (recycled), character vectors, or lists of `f_combine()` results for explicit one-to-one mappings.
- Parameter lengths must be 1 or equal to number of columns.

Transitive example:
- `define_cols` -> `._resolve_style_refs` (may interpret `f_combine()` outputs) -> `f_combine` (user-supplied)
