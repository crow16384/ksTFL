# Update the session package settings

Update ksTFL session options. This function accepts:

- Named scalar options (e.g. `contentWidth = "95%"`, `missings = "."`).

- Settings objects produced by helper constructors such as
  [`add_header()`](https://example.com/reference/add_header.md),
  [`add_footer()`](https://example.com/reference/add_footer.md),
  [`add_body_text()`](https://example.com/reference/add_body_text.md),
  or page objects from
  [`p_page()`](https://example.com/reference/p_page.md).

- A mixture of both named values and settings objects.

## Usage

``` r
tfl_set_options(
  ...,
  docTemplate = NULL,
  footnotePlace = NULL,
  isContinues = NULL,
  contentWidth = NULL,
  missings = NULL,
  figureWidth = NULL,
  figureHeight = NULL,
  figureDevice = NULL,
  figureScaleMode = NULL,
  autoColWidth = NULL,
  minColWidth = NULL,
  insertTOC = NULL,
  tocTitle = NULL,
  output_directory = NULL,
  meta_directory = NULL
)
```

## Arguments

- ...:

  Named arguments OR settings objects returned from helper constructors.

  - Named scalar options (e.g. `contentWidth = "95%"`,
    `missings = "."`).

  - Settings objects produced by helper constructors such as
    [`add_header()`](https://example.com/reference/add_header.md),
    [`add_footer()`](https://example.com/reference/add_footer.md),
    [`add_style()`](https://example.com/reference/add_style.md),
    [`add_body_text()`](https://example.com/reference/add_body_text.md),
    and
    `set_page_style(`p_page([`p_margins()`](https://example.com/reference/p_margins.md))`)`.

  - A mixture of both named values and settings objects is accepted; the
    function routes each into the appropriate internal slot.

- docTemplate:

  Character; name of a predefined bundled template (e.g.
  `"CRO Example_default"`, `"Navy_Pro"`) or a file path to an external
  template JSON file. When `NULL` (default) the current session template
  is left unchanged. Use
  [`tfl_reset_options()`](https://example.com/reference/tfl_reset_options.md)
  to restore the built-in default (`"CRO Example_default"`).

- footnotePlace:

  Character; controls where footnotes are rendered. One of
  `"doc_footer"` (place inside the Word footer, below footer rows),
  `"repeated"` (place under the table on every page), or `"last_page"`
  (place under the table on the last page only). Default `"repeated"`.

- isContinues:

  Logical; override continuation behavior.

- contentWidth:

  Character; width for content area (e.g. "100%", "95%").

- missings:

  Character; default representation for missing values (e.g. "NA", ".",
  "—").

- figureWidth:

  Character; default width for figure output (e.g. `"6in"`, `"16cm"`).
  Applied when
  [`create_figure()`](https://example.com/reference/create_figure.md)
  specs do not specify their own width.

- figureHeight:

  Character; default height for figure output (e.g. `"4in"`, `"10cm"`).
  Applied when
  [`create_figure()`](https://example.com/reference/create_figure.md)
  specs do not specify their own height.

- figureDevice:

  Character; graphics device used for figure rendering (e.g. `"png"`,
  `"pdf"`, `"svg"`). Default depends on system capabilities.

- figureScaleMode:

  Character; how figures are scaled into the page content area.
  Typically `"fit"` (scale to fit) or `"exact"` (use exact dimensions).

- autoColWidth:

  Logical; enable automatic column width recalculation when user sets
  `colWidth` via
  [`define_cols()`](https://example.com/reference/define_cols.md).
  Default TRUE. When TRUE, locked columns maintain exact width while
  unlocked columns normalize to fill remaining space. Set FALSE to
  disable auto-recalculation and manage widths manually.

- minColWidth:

  Numeric; minimum relative column width (%) for unlocked columns during
  recalculation. Default 0.5. Used to validate that relative widths
  don't squeeze columns below acceptable minimum.

- insertTOC:

  Logical; when `TRUE` the renderer prepends a Table of Contents page
  (using a `{ TOC \f \h \z }` field) before the first spec. Requires at
  least one [`add_title()`](https://example.com/reference/add_title.md)
  or [`add_subtitle()`](https://example.com/reference/add_subtitle.md)
  call with `toclevel` set. Default `FALSE`. Can be overridden
  per-render via `save_report(insertTOC = )`.

- tocTitle:

  Character; heading text placed above the TOC field on the TOC page.
  Default `"Table of Contents"`. Set to `""` to omit the heading. Can be
  overridden per-render via `save_report(tocTitle = )`.

- output_directory:

  Character; path to default output directory of rendered document.

- meta_directory:

  Character; path to default directory for intermediate metadata (JSON
  specs, data, and asset files) created during rendering.

## Value

The updated settings list, returned invisibly. Use
[`tfl_get_options()`](https://example.com/reference/tfl_get_options.md)
to inspect.

## Details

The function tries to intelligently route each supplied object into the
appropriate internal settings slot (headers, footers, styles, bodyText,
page).

## Examples

``` r
if (FALSE) { # \dontrun{
# Set a named option
tfl_set_options(contentWidth = "95%", missings = ".")

# Set a predefined bundled template
tfl_set_options(docTemplate = "Navy_Pro")

# Set an external template file
tfl_set_options(docTemplate = "/path/to/my_template.json")

# Update page style via helper
 tfl_set_options(
   set_page_style(page= p_page(
   size = "Letter",
   orientation = "portrait",
   margins = p_margins(top = "1in", bottom = "1in", left = "0.75in", right = "0.75in")
 )))

# Add default header and footer via helpers
tfl_set_options(
  add_header(c("Left Header", "Center Header", "Right Header")),
  add_footer(c("Left Footer", "Center Footer", "Right Footer"))
)

# Add default body text via helper
tfl_set_options(
  add_body_text("This is the default body text for all text specs.")
)

# Control automatic column width recalculation
# Enable auto-recalculation (default):
tfl_set_options(autoColWidth = TRUE)
spec <- create_table(data) |>
  define_cols("id", colWidth = "20%")  # Locks id, others auto-adjust

# Disable auto-recalculation for manual width management:
tfl_set_options(autoColWidth = FALSE)
spec <- create_table(data) |>
  define_cols(c("id", "age"), colWidth = c("20%", "30%"))  # Exact widths, no auto-adjust

# Enable TOC page for all reports in the session
tfl_set_options(insertTOC = TRUE, tocTitle = "List of Tables")
# Then mark individual titles/subtitles with toclevel:
spec <- create_table(adsl) |>
  add_title("Table 1: Demographics", toclevel = 1)
# save_report() will now prepend a TOC page automatically.
# In Word: click the TOC placeholder and press F9 to populate it.
} # }
```
