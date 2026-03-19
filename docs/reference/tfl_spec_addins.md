# RStudio Addins for TFL Specification Preview

Two addins that open the HTML TFL Specification Preview in the RStudio
Viewer pane.

## Usage

``` r
tfl_spec_preview_selection()

tfl_spec_preview_prompt()
```

## Details

- `tfl_spec_preview_selection()`:

  Evaluates the currently selected text in the source editor and, if the
  result is a `TFL_spec` object, opens the HTML preview.

- `tfl_spec_preview_prompt()`:

  Prompts for the name of an object in `.GlobalEnv` and, if it is a
  `TFL_spec`, opens the HTML preview.

Both functions require RStudio
([`rstudioapi::isAvailable()`](https://rstudio.github.io/rstudioapi/reference/isAvailable.html)).

## See also

[`view_tfl_spec()`](https://example.com/reference/view_tfl_spec.md)
