# set_document(spec, ...)

Purpose: Set document-level metadata and flags (docPrefix, hasData, contentWidth, etc.).

Direct package callees:
- `assert_class`, `.validate_params`, `.validate_pattern`, `.merge_recursive`, `cli_warn`

Usage notes:
- Use to annotate document-level properties; merges with last-win.
- `contentWidth` validated against `.const_pattern_content_width`.
