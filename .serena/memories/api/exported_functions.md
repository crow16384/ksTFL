# Key Exported API Functions

## Spec Creation
- create_table(data, cols = everything(), docPrefix = NULL): Table spec from data.frame
- create_figure(plot_or_path, docPrefix = NULL, width = 6, height = 4, dpi = 300L, device = "png"): Figure spec from image file path OR ggplot2 object (auto-rendered to temp file)
- create_text(docPrefix = NULL): Text-only spec

## Content
- add_title(spec, text, id, styleRef, order)
- add_subtitle(spec, text, id, styleRef, order)
- add_footnote(spec, text, id, styleRef, order)
- add_body_text(spec, text, id, styleRef, order): S3 generic (TFL_spec, TFL_options, default)
- add_header(spec, ..., level): S3 generic, max 3 parts
- add_footer(spec, ..., level): S3 generic, max 3 parts
- add_span_header(spec, cols, label, labelStyleRef)

## Column Configuration
- define_cols(spec, cols, label, isVisible, isID, isGrouping, dedupe, colWidth, valueStyleRef, labelStyleRef, isPaging, isColBreak, blankAfter, type, format, missings): vectorized 1-or-n params, tidyselect

## Style System
- add_style(spec, id, ...): S3 generic, accepts modifier functions
- s_font(font_name, font_size, bold, italic, underline, color, highlight)
- s_paragraph(alignment, spacing, indents, word_style)
- s_spacing(before, after, line_spacing)
- s_indents(left, right, first_line)
- s_table_style(background_color, row_height, vertical_alignment, text_orientation, borders)
- s_borders(top, bottom, left, right)
- s_border(color, width, line_style)
- f_combine(...): combine style references

## Document Configuration
- set_document(spec, docPrefix, isContinues, gluePrefix, contentWidth)
- set_page_style(spec, page, margins): S3 generic (TFL_spec, TFL_options)
- p_page(size, orientation): page helper
- p_margins(top, bottom, left, right, header, footer): margins helper

## Conditional Row Styling
- compute_cols(spec, cond, ...): captures condition + actions as quosures
- c_style(cols, styleRef): apply style to columns
- c_merge(cols, styleRef): merge adjacent columns
- c_addrow(pos, value_from = NULL, styleRef = NULL): insert row above/below
- c_pageBreak(): insert page break

## Report Assembly & Rendering
- create_report(...): combine specs/reports, 6-phase pipeline
- save_report(report, docFileName, outDir = NULL, metaPath = NULL, prettify = FALSE): serialize to JSON + data files. Returns list(spec_file, datetime, metaPath)
- render_docx(spec_json, template_json = NULL, output_path, font_dirs = NULL, fallback_font = NULL, verbose = FALSE): C++ renderer → .docx

## Package Options
- tfl_get_options(): all options
- tfl_get_option(name): single option
- tfl_set_options(...): update options (REPLACES previous headers/footers, not accumulate)
- tfl_reset_options(): restore defaults

## Typical Full Pipeline
```r
spec <- create_table(mtcars) |> add_title("Title")
report <- create_report(spec)
saved <- save_report(report, "output.docx")
render_docx(
  spec_json = file.path(saved$metaPath, saved$spec_file),
  output_path = "output/result.docx"
)
```

## NAMESPACE Registrations
- useDynLib(ksTFL, .registration = TRUE) — loads compiled C++ code
- importFrom(Rcpp, sourceCpp)
- S3methods: add_style, add_body_text, add_header, add_footer (TFL_spec, TFL_options, default)
- S3methods: set_page_style (TFL_spec, TFL_options)
- S3method: c.tfl_style_combine, print.TFL_spec
