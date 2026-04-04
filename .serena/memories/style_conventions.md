# ksTFL Code Style & Conventions

## R Style
- Double quotes for strings
- Integer literals: use `1L` suffix where appropriate
- Internal (non-exported) functions prefixed with `.` (e.g. `.tfl_init()`)
- Exported functions must have complete roxygen2 docs + NAMESPACE entries
- Constants in `R/constants.R`, named `.const_*`

## Validation & Errors
- Argument validation: `checkmate::` assertions
- User-facing errors: `cli::cli_abort()`
- User-facing warnings: `cli::cli_warn()`
- Do NOT use base `stop()` / `warning()` for user messages

## Style/Context API
- `add_style(...)` can contain `s_font()`, `s_paragraph()`, `s_table_style()`
- `s_borders()` must be nested inside `s_table_style(...)`
- `s_border()` used only as side values inside `s_borders(...)`

## Serialization
- Schema-driven; never bypass with hardcoded JSON keys
- `spec$.metadata` is internal — never serialize it

## Merging
- Use `.merge_recursive()` for recursive merges — don't create duplicates

## Inline markup (cell values)
- Supported tags: `<b>`, `<i>`, `<u>`, `<s>`, `<sup>`, `<sub>`, `<br>`, `<p>`
- `<s>` maps to OOXML `<w:strike/>`
