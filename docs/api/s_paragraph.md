# s_paragraph(alignment = NULL, spacing = NULL, indents = NULL, word_style = NULL)

Purpose: Paragraph modifier for `add_style()`; accepts nested modifiers.

Parameters:
- `alignment`, `spacing`, `indents`, `word_style`

Direct package callees:
- `.assert_context`, `.set_context`, `.paragraph_spec`, `.validate_params`, `.clear_context`

Nested allowed modifiers:
- `s_spacing()`, `s_indents()` (only inside `s_paragraph` context)

Transitive example:
- `s_paragraph` -> `.paragraph_spec` (collects nested payload) -> `.validate_params`

Usage notes:
- Must be called only within `add_style()`; `.set_context` ensures nested `s_spacing`/`s_indents` use is validated.
