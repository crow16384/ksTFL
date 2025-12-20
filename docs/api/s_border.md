# s_border(color = NULL, width = NULL, line_style = NULL)

Purpose: Create a single-side border (used inside `s_borders`).

Parameters:
- `color`, `width`, `line_style`

Direct package callees:
- `.assert_context`, `.border_spec`, `.validate_params`

Usage notes:
- Must be used inside `s_borders()`; validated by `.assert_context`.
