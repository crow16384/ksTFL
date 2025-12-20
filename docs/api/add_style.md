# add_style(spec, id, ...)

Purpose: Add or update named style definitions. S3-dispatched.

Methods:
- `add_style.TFL_spec` — apply style to a `TFL_spec` object
- `add_style.TFL_options` — apply to options defaults
- `add_style.default` — errors

Parameters:
- `spec` — `TFL_spec` or `TFL_options`
- `id` — style identifier (auto-generated if NULL)
- `...` — modifiers produced by `s_*()` helpers

Direct package callees (TFL_spec method):
- `.set_context`, `.process_style_modifier`, `.validate_style_payload`, `.merge_recursive`, `.clear_context`, `.validate_params`

Allowed modifiers (per context):
- `s_font()`, `s_paragraph()`, `s_table_style()`
  - `s_paragraph()` may contain `s_spacing()` and `s_indents()`
  - `s_table_style()` may contain `s_borders()` -> `s_border()`

Usage notes:
- Modifiers are merged into the named style using last-win semantics.
- `add_style()` used both for spec-local styles and global option styles.
