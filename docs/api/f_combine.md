# f_combine(...)

Purpose: Group multiple style names into a combined object usable in mappings.

Parameters:
- `...` (one-or-more single character style names)

Direct package callees:
- none (validates args)

Transitive/package-only chain:
- `f_combine` is used by `define_cols`, `add_stub_column`, and other callers that accept style refs.

Usage notes:
- Returns a character vector with class `tfl_style_combine` to signal grouped styles.
- Use to create one-to-one mappings: `labelStyleRef = c(f_combine("a","b"), f_combine("c"))`.
