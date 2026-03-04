# Retrieve a single package option

Fetch a single named option from the active ksTFL settings. This is a
convenience wrapper around
[`tfl_get_options()`](https://example.com/reference/tfl_get_options.md)
that returns one element or throws a friendly error if the option does
not exist.

## Usage

``` r
tfl_get_option(name)
```

## Arguments

- name:

  Character(1). Name of the option to fetch. Common options: `"page"`,
  `"styles"`, `"footnotePlace"`, `"isContinues"`, `"contentWidth"`,
  `"missings"`, `"autoColWidth"`, `"minColWidth"`, `"insertTOC"`,
  `"tocTitle"`, `"output_directory"`, `"meta_directory"`.

## Value

The value associated with `name` (type depends on the option).

## Examples

``` r
if (FALSE) { # \dontrun{
# Get the current page settings
tfl_get_option("page")

# Check whether TOC generation is enabled
tfl_get_option("insertTOC")
tfl_get_option("tocTitle")
} # }
```
