# p_margins(top=NULL, bottom=NULL, left=NULL, right=NULL, header=NULL, footer=NULL)

Purpose: Page margins helper (used inside `p_page()`).

Parameters:
- `top`, `bottom`, `left`, `right`, `header`, `footer`

Direct package callees:
- `.assert_context`, `.margins_spec`, `.validate_params`

Usage notes:
- Only valid inside `p_page()`; returns `tfl_margins` payload consumed by `p_page`.
