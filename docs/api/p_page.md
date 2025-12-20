# p_page(size = .const_default_page_size, orientation = NULL, margins = NULL, pageTemplate = NULL)

Purpose: Page settings constructor; returns an object usable by `set_page_style()`.

Parameters:
- `size`, `orientation`, `margins` (accepts `p_margins()`), `pageTemplate`

Direct package callees:
- `.assert_context`, `.page_spec`, `.validate_params`

Nested allowed modifiers:
- `p_margins()` (only inside `p_page`)

Transitive chain (common):
- `p_page` -> `p_margins`

Usage notes:
- Use `p_page()` when calling `set_page_style()` or supplying page defaults via `tfl_set_options()`.
