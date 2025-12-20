# add_subtitle(spec, text, id = NULL, styleRef = NULL, order = NULL)

Purpose: Add a subtitle group to a spec.

Direct package callees:
- `assert_class`, `.auto_id`, `.validate_params`, `.merge_recursive`

Usage notes: Similar to `add_title()` but writes into `spec$subtitles`.
