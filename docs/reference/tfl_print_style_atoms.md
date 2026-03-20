# Print all built-in style atoms to the console

Iterates over every atom in the internal `.const_options_styles`
registry and prints a coloured, grouped summary using cli.
`tfl_style_atoms_catalog()` is a convenience alias for
`tfl_print_style_atoms()`.

## Usage

``` r
tfl_print_style_atoms()

tfl_style_atoms_catalog()
```

## Value

Invisible `NULL`.

## Examples

``` r
if (FALSE) { # \dontrun{
# Print the full catalog of built-in style atoms
tfl_print_style_atoms()

# Same output via the alias
tfl_style_atoms_catalog()
} # }
```
