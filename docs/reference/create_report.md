# Combine Multiple TFL Specifications and/or Reports into a Single Report

This function takes multiple TFL specification objects and/or previously
created TFL report objects and combines them into a single report object
matching the spec_schema_v2 structure. Each spec is keyed by a
combination of its variable name and metadata hash (for direct specs) or
preserves original keys (for specs from reports).

## Usage

``` r
create_report(...)
```

## Arguments

- ...:

  One or more objects of class `TFL_spec` or `TFL_report`, or plain
  `list`s whose elements are `TFL_spec` / `TFL_report` objects.

  - `TFL_spec` objects produced by
    [`create_table()`](https://crow16384.github.io/ksTFL-release/reference/create_table.md),
    [`create_text()`](https://crow16384.github.io/ksTFL-release/reference/create_text.md)
    or
    [`create_figure()`](https://crow16384.github.io/ksTFL-release/reference/create_figure.md).

  - `TFL_report` objects produced by previous calls to
    `create_report()`.

  - `list` arguments are expanded in place; for each `TFL_spec` element
    the list slot name (if any) is used as the key basis. Unnamed slots
    fall back to `<outer_arg_name>_<i>` (or `spec_<i>` when the outer
    argument is itself a literal `list(...)` call). Nested lists are not
    supported.

  - Arguments are processed in order; each new `TFL_spec` is keyed by
    the argument name combined with the spec metadata hash.

  - `TFL_report` objects are flattened and their spec keys are
    preserved.

## Value

A named list where each element is a TFL_spec object, keyed by the
pattern `<variable_name>_<hash>` for direct specs, or original keys for
specs extracted from input reports. Result has class `TFL_report`.

## Details

The function performs the following operations:

1.  Flattens all inputs (expands `list` arguments and extracts specs
    from `TFL_report` objects).

2.  Auto-disambiguates duplicate keys among newly-added specs by
    appending a numeric suffix (`_2`, `_3`, ...) to the name basis;
    duplicate keys originating from `TFL_report` arguments still trigger
    a hard error.

3.  Consolidates styles within newly-added `TFL_spec` objects only
    (specs from `TFL_report` are already consolidated).

4.  Assigns a global `docOrder` integer (1, 2, 3, ...) based on final
    position.

5.  Preserves existing `dataRef` values and warns if duplicates
    detected.

6.  Returns a named list keyed by `<variable_name>_<hash>` or original
    report keys.

## Examples

``` r
if (FALSE) { # \dontrun{
spec1 <- create_table(mtcars)
spec2 <- create_text()
final_report <- create_report(spec1, spec2)

# Combining with a previous report
spec3 <- create_figure("path/to/image.png")
combined <- create_report(final_report, spec3)

# Passing a named list of specs
out <- list(t1 = spec1, t2 = spec2)
report_from_list <- create_report(out)
} # }
```
