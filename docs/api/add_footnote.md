# add_footnote(spec, text, id = NULL, styleRef = NULL, order = NULL)

Purpose: Add footnote groups to a spec.

Direct package callees:
- `assert_class`, `.auto_id`, `.validate_params`, `.merge_recursive`

Usage notes: Similar pattern to `add_title`/`add_subtitle` but writes into `spec$footnotes`.
