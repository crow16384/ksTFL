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

Usage notes:
- `cols` supports tidyselect; the wrapper captures `cols` with `enquo`/`enquos` (external) and forwards to `.tfl_init`.
