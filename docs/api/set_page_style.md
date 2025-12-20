# set_page_style(spec, docTemplate = NULL, page = NULL)

Purpose: Set document-style configuration. S3-dispatched.

Direct package callees (TFL_spec method):
- `.set_context`, `.validate_params`, `.get_allowed_properties`, `.merge_recursive`, `.clear_context`

Transitive chain (user-driven):
- `set_page_style` may accept `page = p_page(...)` -> `p_page` -> `p_margins`

Usage notes:
- `page` can be `p_page()` result or a validated list with keys `size`, `orientation`, `margins`.
