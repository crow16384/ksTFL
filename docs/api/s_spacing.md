# s_spacing(before = NULL, after = NULL, line_spacing = NULL)

Purpose: Paragraph spacing nested modifier (use only inside `s_paragraph`).

Parameters:
- `before`, `after`, `line_spacing`

Direct package callees:
- `.assert_context`, `.spacing_spec`

Usage notes:
- Only valid inside `s_paragraph()`; `.assert_context` enforces usage.
