# add_body_text(spec = NULL, text = NULL, id = NULL, styleRef = NULL, order = NULL)

Purpose: Add body text to a spec or options (S3 dispatch).

Direct package callees:
- `UseMethod` (dispatch), `.auto_id`, `.generate_default_bodytext_id`, `.validate_params`, `.merge_recursive`

Behavior notes:
- `add_body_text.TFL_spec` removes default placeholder bodyText entries when user adds custom text.
- `add_body_text.TFL_options` uses `__default_NNN` pattern for default entries.
