# add_stub_column(spec, cols, label, stubOrder = NULL, id = NULL, labelStyleRef = NULL)

Purpose: Define a spanning stub/header that covers multiple columns.

Direct package callees:
- `assert_class`, `assert_character`, `.auto_id`, `.validate_required`, `.auto_stub_order`, `._resolve_style_refs`, `.validate_params`, `.merge_recursive`

Notes:
- Validates overlapping columns at same stubOrder.
- `labelStyleRef` is resolved via `._resolve_style_refs` (expects single mapping for stub).
