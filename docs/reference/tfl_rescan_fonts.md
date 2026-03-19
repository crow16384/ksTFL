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
