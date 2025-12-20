# tfl_set_options(..., bodyTitles = NULL, bodySubtitles = NULL, ...)

Purpose: Update ksTFL session options. Accepts named scalars and helper constructor calls.

Key behavior and transitive chains:
- Validates scalar options and updates `.options_env$settings`.
- Accepts helper calls in `...` and evaluates them with an `opts` object as first argument. Supported helpers include:
  - `add_style()` -> may call `s_*` nested modifiers
  - `add_header()` / `add_footer()` -> appends header/footer rows
  - `set_page_style(page = p_page(...))` -> `p_page` -> `p_margins`
  - `add_body_text()` -> modifies default body text

Direct package callees:
- `.options_env` (read/write), and may invoke any of: `add_style`, `add_header`, `add_footer`, `set_page_style`, `add_body_text` via `eval_bare` of reconstructed calls.

Usage notes:
- When passing helper calls, nested helper constructors are executed (so `p_page(p_margins(...))` is valid and will run during `tfl_set_options`).
