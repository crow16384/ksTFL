# s_borders(top = NULL, bottom = NULL, left = NULL, right = NULL)

Purpose: Group borders for table styles; accepts nested `s_border()`.

Parameters:
- `top`, `bottom`, `left`, `right` (each may be `s_border()` result)

Direct package callees:
- `.assert_context`, `.set_context`, `.borders_spec`, `.validate_params`

Nested allowed modifiers:
- `s_border()`

Usage notes:
- `s_borders()` must be used inside `s_table_style()`; `.set_context` enforces nested modifier rules.
