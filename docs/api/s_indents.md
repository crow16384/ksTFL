# s_indents(left = NULL, right = NULL, first_line = NULL)

Purpose: Paragraph indents nested modifier (use only inside `s_paragraph`).

Parameters:
- `left`, `right`, `first_line`

Direct package callees:
- `.assert_context`, `.indents_spec`

Usage notes:
- Only valid inside `s_paragraph()`; creates `tfl_indents` nested payload.
