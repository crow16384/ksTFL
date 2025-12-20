# s_font(font_name = NULL, font_size = NULL, bold = NULL, ...)

Purpose: Create a font modifier for `add_style()`.

Parameters:
- `font_name`, `font_size`, `bold`, `italic`, `underline`, `color`, `highlight`

Direct package callees:
- `.assert_context`, `.font_spec`

Transitive chain:
- `s_font` -> `.font_spec` (constructs font payload). Used by `add_style()` when composing a style.

Usage notes
- Must be used inside `add_style()`; `.assert_context` enforces this.
