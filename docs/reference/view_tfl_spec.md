# Open the HTML TFL Specification Preview in the RStudio Viewer

Renders a comprehensive HTML overview of a TFL specification and
displays it in the RStudio Viewer pane. Requires RStudio and the
htmltools package.

## Usage

``` r
view_tfl_spec(spec)
```

## Arguments

- spec:

  A `TFL_spec` object.

## Value

`TRUE` invisibly on success, `FALSE` invisibly if the viewer could not
be opened (e.g. not running inside RStudio or htmltools is missing).
