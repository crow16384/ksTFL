# add_header(spec = NULL, ..., level = NULL)

Purpose: Add header rows to a spec or global options (S3 dispatch).

Parameters:
- `...` up to 3 character parts (left, center, right)
- `level` optional index to replace existing row

Direct package callees:
- `UseMethod` (dispatch), `checkmate::assert_class`, `cli_abort`

Usage notes:
- `add_header.TFL_spec` appends or replaces `spec$headers` rows.
- `add_header.TFL_options` appends to options defaults and sets class accordingly.
