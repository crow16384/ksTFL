# s_table_style(background_color = NULL, row_height = NULL, vertical_alignment = NULL, text_orientation = NULL, borders = NULL)

Purpose: Table-specific style modifier used inside `add_style()`.

Parameters:
- `background_color`, `row_height`, `vertical_alignment`, `text_orientation`, `borders`

Direct package callees:
- `.assert_context`, `.set_context`, `.table_style_spec`, `.validate_params`

Nested allowed modifiers:
- `s_borders()` -> `s_border()`

Usage notes:
- Valid inside `add_style()`; nested borders validated per side.
