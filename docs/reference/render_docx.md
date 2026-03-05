# Render a DOCX Document from TFL Report

Renders a TFL report (previously saved via
[`save_report`](https://example.com/reference/save_report.md)) into a
styled DOCX document using the C++ rendering engine. The renderer
performs deterministic pagination with HarfBuzz-based text measurement,
producing submission-quality clinical tables, figures, and listings.

## Usage

``` r
render_docx(
  spec_json,
  template_json = NULL,
  output_path,
  font_dirs = NULL,
  fallback_font = NULL,
  verbose = FALSE
)
```

## Arguments

- spec_json:

  Character string. Path to the spec JSON file produced by
  [`save_report`](https://example.com/reference/save_report.md).

- template_json:

  Character string. Path to the styles template JSON file. If provided,
  this template is used for all specs (global override). If `NULL`
  (default), each spec resolves its own template from `docTemplate` (set
  via
  [`set_page_style`](https://example.com/reference/set_page_style.md)`(docTemplate = "Navy_Pro")`).
  For multi-spec reports, different specs may therefore use different
  templates. Template names are looked up in the package's bundled
  `inst/templates/` directory. Missing values or unknown names fall back
  to `CRO Example_default` with a warning.

- output_path:

  Character string. Path for the output .docx file. If the directory
  does not exist, it will be created.

- font_dirs:

  Character vector (optional). Additional directories to search for
  fonts. The package's bundled fonts (inst/fonts/) are always included
  automatically. Only fonts from these directories are used — no system
  fonts are searched.

- fallback_font:

  Character string (optional). Path to a fallback font file (e.g.,
  Liberation Sans). If not specified, the embedded fallback font is
  used.

- verbose:

  Logical. If `TRUE`, print progress messages to stderr. Default:
  `FALSE`.

## Value

Invisibly returns the `output_path` (the path to the generated .docx
file).

## Details

The rendering pipeline operates in the following phases:

1.  **Parse**: Read spec JSON, template JSON, and data JSON files

2.  **Resolve**: Merge template and spec styles; compute page geometry

3.  **Model**: Build logical table (header grid, row stream, styleRows
    expansion)

4.  **Measure**: HarfBuzz-based text shaping and cell height measurement

5.  **Paginate**: Deterministic vertical and horizontal pagination

6.  **Emit**: Stream OOXML into a valid .docx (ZIP) package

**Font handling**: The renderer uses only fonts bundled in the package's
`inst/fonts/` directory, plus any additional directories specified in
`font_dirs`. No system fonts are searched. If a requested font is not
found, LiberationSans (bundled) is used as fallback. Font metrics are
computed from the OS/2 table (usWinAscent/usWinDescent) to match
Microsoft Word's line height calculation.

**Template**: The template controls default styles (fonts, spacing,
borders), page layout, and table formatting. By default
(`template_json = NULL`), template selection is per-spec using each
spec's `docTemplate`. Set `template_json` to force one template for the
full document. Custom templates must conform to `styles_schema_v2.json`.

## Examples

``` r
if (FALSE) { # \dontrun{
# Create and save a report
spec <- create_table(mtcars)
spec <- add_title(spec, "Motor Trend Car Road Tests")
report <- create_report(spec)
saved <- save_report(report, docFileName = "demo.docx")

# Render to DOCX
render_docx(
  spec_json = file.path(saved$metaPath, saved$spec_file),
  output_path = "output/demo.docx"
)

# With custom template and fonts
render_docx(
  spec_json = file.path(saved$metaPath, saved$spec_file),
  template_json = "my_template.json",
  output_path = "output/demo.docx",
  font_dirs = c("/usr/local/share/fonts/custom"),
  verbose = TRUE
)
} # }
```
