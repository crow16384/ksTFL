# Add a footer row for TFL_options

Adds a footer row to the global TFL options, which can be used as
defaults for all spec objects.

## Usage

``` r
# S3 method for class 'TFL_options'
add_footer(spec, ..., level = NULL)
```

## Arguments

- spec:

  TFL_options object

- ...:

  Up to 3 character strings (left, center, right)

- level:

  Optional numeric index. If provided, replaces footer at that row. If
  NULL, appends next row.

## Value

Updated options object
