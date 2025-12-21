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

Key Parameters:
- `autoColWidth` (logical, default TRUE): Controls whether `define_cols()` triggers automatic recalculation of unlocked column widths when user sets `colWidth` on any column.
  - When TRUE: Locked columns remain immutable, unlocked columns normalize to fill available space
  - When FALSE: No automatic recalculation; user manages all column widths manually

Usage notes:
- When passing helper calls, nested helper constructors are executed (so `p_page(p_margins(...))` is valid and will run during `tfl_set_options`).
- Column width auto-recalculation uses LOCKED/UNLOCKED partitioning: locked columns (any unit) stay fixed, unlocked % columns normalize to fill remaining space.
