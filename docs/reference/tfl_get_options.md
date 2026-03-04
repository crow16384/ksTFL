# Return the active package options

Returns the current session settings for ksTFL as a named list. These
are the effective values used when building specs and rendering
documents.

## Usage

``` r
tfl_get_options()
```

## Value

A named list representing the current ksTFL options.

## Details

The returned object is the internal settings list stored in the package
environment. Modifying the returned object will not change package
state; use
[`tfl_set_options()`](https://example.com/reference/tfl_set_options.md)
to update settings for the current session.

## Examples

``` r
if (FALSE) { # \dontrun{
# Inspect all current settings
tfl_get_options()
} # }
```
