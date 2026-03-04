# Add a footer row for TFL_spec

Add a footer row for TFL_spec

## Usage

``` r
# S3 method for class 'TFL_spec'
add_footer(spec, ..., level = NULL)
```

## Arguments

- spec:

  TFL_spec object

- ...:

  Up to 3 character strings (left, center, right)

  - Positional parts represent left, center and right header/footer
    cells respectively.

  - Supply fewer than 3 parts if some cells should be empty; use empty
    string "" for explicit empties.

  - Each call appends one header/footer row; use the `level` parameter
    to replace an existing row.

- level:

  Optional numeric index. If provided, replaces footer at that row. If
  NULL, appends next row.

## Value

Updated spec object
