# add_title(spec, text, id = NULL, styleRef = NULL, order = NULL)

Purpose: Add a title group to a spec.

Parameters:
- `text` (character vector)
- `id` (optional identifier)
- `styleRef` (list of style names)
- `order` (optional integer)

Direct package callees:
- `assert_class`, `.auto_id`, `.validate_params`, `.merge_recursive`

Usage notes:
- Auto-generates ID if `NULL`.
- Merges with existing entry using `.merge_recursive`.
