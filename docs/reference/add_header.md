# Add a header row

Generic function to add header rows. Dispatches to class-specific
methods, allowing headers to be added to both spec objects and global
options.

## Usage

``` r
add_header(spec = NULL, ..., level = NULL)
```

## Arguments

- spec:

  Spec object (dispatches on class)

- ...:

  Up to 3 character strings (left, center, right)

  - Positional parts represent left, center and right header/footer
    cells respectively.

  - Supply fewer than 3 parts if some cells should be empty; use empty
    string "" for explicit empties.

  - Each call appends one header/footer row; use the `level` parameter
    to replace an existing row.

- level:

  Optional numeric index. If provided, replaces header at that row. If
  NULL, appends next row.

## Value

Updated spec object

## Details

Each call adds a new header row. Per schema, headers are arrays of
arrays (each call = one row).

## Examples

``` r
if (FALSE) { # \dontrun{
# Add to a spec object
spec <- create_text() |>
  add_header("Study ABC-123", "CONFIDENTIAL", "Page {PAGE}") |>
  add_header("Protocol v2.0", "", "Date: {DATE}")

# Add to global options
options <- tfl_get_options()
options <- add_header(options, "Study ABC-123", "CONFIDENTIAL", "Page {PAGE}")
} # }
```
