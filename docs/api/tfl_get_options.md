# tfl_get_options()

Purpose: Return active package options (session settings).

Direct package callees:
- reads `.options_env$settings`

Usage notes:
- Returns the settings list; do not mutate returned object to change settings (use `tfl_set_options`).
