# Create a Figure Specification

Create and initialize a TFL specification for embedding a figure.
Accepts either a **file path** to an existing image or a **ggplot2
object** that is rendered automatically to a temporary SVG file.

## Usage

``` r
create_figure(plot_or_path, dpi = 300L)
```

## Arguments

- plot_or_path:

  One of:

  - A **character string** — path to an existing, readable image file
    (`.png`, `.jpeg`/`.jpg`, or `.svg`).

  - A **ggplot2 object** (class `"gg"` or `"ggplot"`) — the plot is
    rendered to a temporary file via
    [`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html).
    Use `width`, `height`, `dpi`, and `device` to control output
    dimensions.

- dpi:

  Integer. Resolution (dots per inch) when `plot_or_path` is a ggplot2
  object. Ignored for file paths. Default: `300`.

- width:

  Numeric. Plot width in inches when `plot_or_path` is a ggplot2 object.
  Ignored for file paths. Default: `6`.

- height:

  Numeric. Plot height in inches when `plot_or_path` is a ggplot2
  object. Ignored for file paths. Default: `4`.

- device:

  Character. Output format when `plot_or_path` is a ggplot2 object. One
  of `"svg"` (default), `"png"`, `"jpeg"`, `"jpg"`. Ignored for file
  paths.

## Value

A `TFL_spec` object with `docType = "Figure"`.

## Details

When a ggplot2 object is passed:

1.  The plot is rendered via
    [`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html)
    to a temporary file in
    [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

2.  The temporary file path is stored in `spec$.metadata$filePath`.

3.  [`save_report()`](https://example.com/reference/save_report.md)
    copies the file (prefixed with `dataRef`) into `metaPath`, where the
    C++ renderer reads it.

4.  The temporary file persists for the duration of the R session.

The C++ renderer natively supports `.png`, `.jpeg`/`.jpg`, and `.svg`
formats.

## Examples

``` r
if (FALSE) { # \dontrun{
## From file path (existing behaviour)
spec <- create_figure("inst/images/example.png")

## From a ggplot2 object
library(ggplot2)
p <- ggplot(mtcars, aes(x = wt, y = mpg)) + geom_point()
spec <- create_figure(p)

## Control figure defaults via options
tfl_set_options(figureWidth = "8in", figureHeight = "5in", figureDevice = "svg")
spec <- create_figure(p, dpi = 150)

## Override per figure
spec <- create_figure(p) |>
  set_document(figureDevice = "jpeg", figureScaleMode = "fitWidth")

## Full pipeline
spec <- create_figure(p) |>
  add_title("Weight vs MPG") |>
  add_footnote("Source: Motor Trend, 1974.")
report <- create_report(spec)
saved  <- save_report(report, docFileName = "fig01.docx")
render_docx(
  spec_json   = file.path(saved$metaPath, saved$spec_file),
  output_path = "output/fig01.docx"
)
} # }
```
