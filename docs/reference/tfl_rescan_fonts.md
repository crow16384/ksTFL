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

## Details

To point ksTFL at a custom TTF folder, set the `ksTFL.font_dirs` option
before or during your session, then call `tfl_rescan_fonts()`:

    options(ksTFL.font_dirs = "/path/to/your/fonts")
    tfl_rescan_fonts()

Multiple directories are supported:

    options(ksTFL.font_dirs = c("/path/to/fonts1", "/path/to/fonts2"))
    tfl_rescan_fonts()

The package's own bundled fonts directory is always scanned
automatically; `ksTFL.font_dirs` only adds extra directories on top of
that. To make the setting persistent across sessions, add the
[`options()`](https://rdrr.io/r/base/options.html) call to your
`~/.Rprofile`.

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
