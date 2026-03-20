# Show current font status

Prints the font resolution report from the most recent scan without
re-scanning. Use
[`tfl_rescan_fonts()`](https://example.com/reference/tfl_rescan_fonts.md)
to perform a fresh scan.

## Usage

``` r
tfl_font_status()
```

## Value

Invisibly returns the cached font scan report.

## See also

[`tfl_rescan_fonts()`](https://example.com/reference/tfl_rescan_fonts.md)
to re-run the scan.

## Examples

``` r
if (FALSE) { # \dontrun{
# Check which fonts are resolved and which use fallbacks
tfl_font_status()
} # }
```
