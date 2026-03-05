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

  One or more objects of class `TFL_spec` or `TFL_report` to be
  combined.

  - `TFL_spec` objects produced by
    [`create_table()`](https://example.com/reference/create_table.md),
    [`create_text()`](https://example.com/reference/create_text.md) or
    [`create_figure()`](https://example.com/reference/create_figure.md).

  - `TFL_report` objects produced by previous calls to
    `create_report()`.

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

1.  Flattens all inputs (extracts specs from `TFL_report` objects)

2.  Validates that no duplicate spec keys exist across all inputs

3.  Consolidates styles within newly-added `TFL_spec` objects only
    (specs from `TFL_report` are already consolidated)

4.  Assigns a global `docOrder` integer (1, 2, 3, ...) based on final
    position

5.  Preserves existing `dataRef` values and warns if duplicates detected

6.  Returns a named list keyed by `<variable_name>_<hash>` or original
    report keys

## Examples

``` r
if (FALSE) { # \dontrun{
spec1 <- create_table(mtcars)
spec2 <- create_text()
final_report <- create_report(spec1, spec2)

# Combining with a previous report
spec3 <- create_figure("path/to/image.png")
combined <- create_report(final_report, spec3)
} # }
```
