# create_figure(filepath, docPrefix = NULL)

Purpose: Create a `TFL_spec` for embedding a figure file.

Parameters:
- `filepath` (character): path to the image file
- `docPrefix` (character, optional)

Direct package callees:
- `.tfl_init`

Transitive/package-only chain:
- `create_figure` -> `.tfl_init` -> `.is_readable_file`, `.create_data_env`, `.auto_id`

Usage notes:
- `.tfl_init` validates the file is readable using internal helper `.is_readable_file`.
