# Reset all session options to package defaults

Restores all ksTFL session options (headers, footers, body text, styles,
page settings, column width behavior, etc.) to their original package
defaults. Useful at the start of a new reporting session or after
experimenting with
[`tfl_set_options()`](https://example.com/reference/tfl_set_options.md).

## Usage

``` r
tfl_reset_options()
```

## Value

The default options list, returned invisibly.

## See also

[`tfl_set_options()`](https://example.com/reference/tfl_set_options.md),
[`tfl_get_options()`](https://example.com/reference/tfl_get_options.md),
[`tfl_get_option()`](https://example.com/reference/tfl_get_option.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Set some session defaults
tfl_set_options(
  add_header("Study ABC", "Phase II", "CONFIDENTIAL"),
  add_footer("Company", "Page {page}", "2025")
)

# ... build tables ...

# Reset everything back to package defaults
tfl_reset_options()
tfl_get_options()  # Confirm reset
} # }
```
