# create_table(data = NULL, cols = everything(), docPrefix = NULL)

Purpose: Create a `TFL_spec` for tabular output from a data.frame.

Parameters:
- `data` (data.frame): source data
- `cols` (tidyselect expression): which columns to include
- `docPrefix` (character, optional)

Direct package callees:
- `.tfl_init` (via wrapper)

Transitive/package-only chain:
- `create_table` -> `.tfl_init` -> `.create_data_env`, `.init_column_specs`, `.guess_table_layout`, `.auto_id`
- `.guess_table_layout` now returns both `$formats` and `$metadata` for column width recalculation support

Column Width Initialization:
- Initial column widths are auto-calculated by `.guess_table_layout()` based on data properties
- Width metadata (unit, value, locked, auto_weight) is stored in `spec$.metadata$colWidths` for later recalculation
- All columns start with `locked=FALSE` and `unit="%"`
- Auto-weights are preserved and used when user calls `define_cols(colWidth=...)` with `autoColWidth=TRUE`

Usage notes:
- `cols` supports tidyselect; the wrapper captures `cols` with `enquo`/`enquos` (external) and forwards to `.tfl_init`.
- Initial column widths sum to exactly 100% (with 1 decimal place precision)
- Call `define_cols(colWidth=...)` to lock specific columns and trigger automatic recalculation of remaining columns
