# Rescan system fonts

Re-runs the font discovery process using the current value of
`getOption("ksTFL.font_dirs")`. This is useful after installing new
fonts or after changing the `ksTFL.font_dirs` option.

## Usage

``` r
tfl_rescan_fonts()
```

## Value

Invisibly returns the font scan report (a list with `resolutions` and
`dirs_scanned`).

## See also

[`tfl_font_status()`](https://example.com/reference/tfl_font_status.md)
to print the cached report without rescanning.

## Examples

``` r
if (FALSE) { # \dontrun{
# Rescan after installing new fonts
tfl_rescan_fonts()

# Point to a custom font directory, then rescan
options(ksTFL.font_dirs = c("/usr/share/fonts/custom"))
tfl_rescan_fonts()
} # }
```
