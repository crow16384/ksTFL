# create_text(docPrefix = NULL)

Purpose: Create a `TFL_spec` for narrative (Text) documents.

Parameters:
- `docPrefix` (character, optional): optional prefix for document title.

Direct package callees:
- `.tfl_init`

Transitive/package-only chain (examples):
- `create_text` -> `.tfl_init` (initializes `TFL_spec`, sets `.metadata`, default `bodyText`, etc.)

Usage notes:
- Use when creating a text-only spec (no input data).
- Returned object: `TFL_spec` with `docType = "Text"`.
