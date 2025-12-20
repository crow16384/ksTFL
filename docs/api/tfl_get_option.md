# tfl_get_option(name)

Purpose: Retrieve a single named package option.

Parameters:
- `name` (character(1))

Direct package callees:
- reads `.options_env$settings`
- uses `cli_abort` when unknown

Usage notes:
- Use `tfl_get_options()` to list available option names.
