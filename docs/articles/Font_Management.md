# Font Management in ksTFL

## Overview

ksTFL renders DOCX documents using a C++ engine that requires
TrueType/OpenType font files for text measurement and pagination.
Starting with version 0.7.0, the package **automatically discovers fonts
installed on the operating system** at load time. If a required font is
not available on the system, a metrically compatible open-source
fallback is used.

This article explains how font discovery works, which fallback fonts are
bundled, and how to configure custom font directories.

## How Font Discovery Works

When ksTFL is loaded (via [`library(ksTFL)`](https://example.com) or
[`devtools::load_all()`](https://devtools.r-lib.org/reference/load_all.html)),
the following happens:

1.  **System directories are scanned.** The C++ font scanner inspects
    platform-specific directories using FreeType to read font family
    names and style flags from each `.ttf`, `.otf`, and `.ttc` file.

2.  **User directories are scanned.** If the R option `ksTFL.font_dirs`
    is set, those directories are scanned as well.

3.  **Bundled fallback fonts are scanned.** The package’s own
    `inst/fonts/` directory (containing license-free alternatives) is
    scanned last.

4.  **Target fonts are resolved.** For each target font family (Arial,
    Times New Roman, Courier New, Georgia, Verdana, Trebuchet MS), the
    scanner checks whether the font was found in any scanned directory.
    If not, a designated fallback is assigned.

**Key rule:** system-installed fonts always take priority. The bundled
fallbacks are only used when a target font is not found anywhere on the
system.

### Platform-Specific Directories

The scanner inspects the following directories by default:

| Platform    | Directories                                                                                              |
|-------------|----------------------------------------------------------------------------------------------------------|
| **Linux**   | `/usr/share/fonts`, `/usr/local/share/fonts`, `~/.local/share/fonts`, `~/.fonts`, plus any XDG data dirs |
| **macOS**   | `/System/Library/Fonts`, `/Library/Fonts`, `~/Library/Fonts`                                             |
| **Windows** | System fonts directory (from registry), plus user fonts in `%LOCALAPPDATA%\Microsoft\Windows\Fonts`      |

## Target Fonts and Fallbacks

The rendering engine targets six font families commonly used in clinical
documents. Each has a metrically compatible open-source fallback bundled
with the package:

| Target Font         | Fallback Font    | Notes                                   |
|---------------------|------------------|-----------------------------------------|
| **Arial**           | Liberation Sans  | Metrically identical to Arial           |
| **Times New Roman** | Liberation Serif | Metrically identical to Times New Roman |
| **Courier New**     | Liberation Mono  | Metrically identical to Courier New     |
| **Georgia**         | Liberation Serif | Serif fallback for Georgia              |
| **Verdana**         | Liberation Sans  | Sans-serif fallback for Verdana         |
| **Trebuchet MS**    | Liberation Sans  | Sans-serif fallback for Trebuchet MS    |

All bundled fonts are licensed under the SIL Open Font License 1.1.

If a font family requested in a spec (via `s_font(font_name = "...")`)
is not a target font and is not found on the system, the engine falls
back to Liberation Sans as the last resort.

For convenience, ksTFL also ships built-in style atoms for the target
font families: `font_arial`, `font_courier_new`, `font_times_new_roman`,
`font_georgia`, `font_verdana`, and `font_trebuchet_ms`. These atoms set
only `font_name`, so they can be safely combined with size, colour,
alignment, and other style atoms via
[`f_combine()`](https://example.com/reference/f_combine.md).

## Checking Font Status

After loading the package, call
[`tfl_font_status()`](https://example.com/reference/tfl_font_status.md)
to see the current font resolution:

``` r
library(ksTFL)
tfl_font_status()
#> ksTFL font scan: 3 target(s) resolved, 3 using fallback
#>   [ok]       Arial                -> Arial
#>   [ok]       Times New Roman      -> Times New Roman
#>   [ok]       Courier New          -> Courier New
#>   [fallback] Georgia              -> Liberation Serif
#>   [fallback] Verdana              -> Liberation Sans
#>   [fallback] Trebuchet MS         -> Liberation Sans
#>   Scanned 5 directories
```

**Reading the output:**

- **`[ok]`** — The target font was found on the system and will be used
  directly.
- **`[fallback]`** — The target font was not found; the bundled fallback
  is used instead.

## Adding Custom Font Directories

If proprietary fonts are installed in a non-standard location (e.g., a
network share or a project-local folder), point the `ksTFL.font_dirs`
option to those directories **before** loading the package, or rescan
afterwards:

### Option A: Set before loading

``` r
options(ksTFL.font_dirs = c("/opt/company-fonts", "/mnt/shared/fonts"))
library(ksTFL)
```

### Option B: Set and rescan after loading

``` r
library(ksTFL)
options(ksTFL.font_dirs = "/opt/company-fonts")
tfl_rescan_fonts()
```

Both approaches produce the same result. The `ksTFL.font_dirs` option
accepts a character vector of directory paths.

## Rescanning Fonts

Call
[`tfl_rescan_fonts()`](https://example.com/reference/tfl_rescan_fonts.md)
after:

- Installing new system fonts
- Changing the `ksTFL.font_dirs` option
- Mounting a new network font directory

``` r
# Install Georgia to /usr/local/share/fonts/georgia/ ... then:
tfl_rescan_fonts()
#> ksTFL font scan: 6 target(s) resolved, 0 using fallback
#>   [ok]       Arial                -> Arial
#>   [ok]       Times New Roman      -> Times New Roman
#>   [ok]       Courier New          -> Courier New
#>   [ok]       Georgia              -> Georgia
#>   [ok]       Verdana              -> Verdana
#>   [ok]       Trebuchet MS         -> Trebuchet MS
#>   Scanned 5 directories
```

## Startup Messages

When the package is attached, it prints a concise summary if any target
fonts are using fallbacks:

    ksTFL v0.7.0 - Clinical TFL Framework
    For help, type: ??ksTFL
    Note: 3 font(s) using fallback: Georgia, Verdana, Trebuchet MS
    Run tfl_font_status() for details.

If all target fonts are found on the system, no font-related message is
shown.

## Interaction with `write_doc()`

The [`write_doc()`](https://example.com/reference/write_doc.md) function
(and
[`replay_report()`](https://example.com/reference/replay_report.md))
automatically uses the font directories from the scanner cache. You can
still pass additional per-call directories via the `font_dirs` argument:

``` r
write_doc(report, name = "output",
          outDir = "results",
          metaPath = tempdir(),
          font_dirs = "/path/to/extra-fonts")
```

Per-call directories are appended to the scanner’s cached list for that
render only — they do not modify the global font registry.

## FAQ

### Q: I see `[fallback]` for a font I know is installed. What’s wrong?

The font may be installed in a directory not scanned by default. Add its
directory to `ksTFL.font_dirs` and rescan:

``` r
options(ksTFL.font_dirs = "/path/to/font/directory")
tfl_rescan_fonts()
```

### Q: Can I use custom fonts not in the target list?

Yes. Any font found during scanning is available to the renderer. Use
the family name as it appears in the font’s metadata (e.g.,
`s_font(font_name = "Fira Sans")`). If the font is in a non-standard
directory, add that directory to `ksTFL.font_dirs`.

### Q: Will documents look different on systems without the proprietary fonts?

The fallback fonts (Liberation family) are designed to be metrically
compatible with their proprietary counterparts. Line breaks, page
breaks, and column widths should be identical or very close. Minor
glyph-level differences may exist, but document layout is preserved.

### Q: How do I suppress the startup font warning?

You can suppress all startup messages with:

``` r
suppressPackageStartupMessages(library(ksTFL))
```

Or install the missing fonts and the message will not appear.
