# Key Exported API Functions

## Spec Creation
- create_table(data, cols = everything(), docPrefix = NULL)
- create_figure(plot_or_path, docPrefix = NULL, width = 6, height = 4, dpi = 300L, device = "png"): accepts ggplot2 object or file path
- create_text(docPrefix = NULL)

## Content
- add_title(spec, text, id, styleRef, order)
- add_subtitle(spec, text, id, styleRef, order)
- add_footnote(spec, text, id, styleRef, order)
- add_body_text(spec, text, id, styleRef, order): S3 generic
- add_header(spec, ..., level): S3 generic, max 3 parts
- add_footer(spec, ..., level): S3 generic, max 3 parts
- add_span_header(spec, cols, label, labelStyleRef)

## Column Configuration
- define_cols(spec, cols, label, isVisible, isID, isGrouping, dedupe, colWidth, valueStyleRef, labelStyleRef, isPaging, isColBreak, blankAfter, type, format, missings): vectorized, tidyselect

## Style System
- add_style(spec, id, ...): S3 generic
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
- set_page_style(spec, page, margins): S3 generic
- p_page(size, orientation)
- p_margins(top, bottom, left, right, header, footer)

## Conditional Row Styling
- compute_cols(spec, cond, ...): captures condition + actions as quosures
- c_style(cols, styleRef)
- c_merge(cols, styleRef)
- c_addrow(pos, value_from = NULL, styleRef = NULL)
- c_pageBreak()

## Report Assembly & Rendering
- create_report(...): combine specs/reports, 6-phase pipeline
- save_report(report, docFileName, outDir = NULL, metaPath = NULL, prettify = FALSE)
  Returns list(spec_file, datetime, metaPath). Also updates _index.json in metaPath.
- render_docx(spec_json, template_json = NULL, output_path, font_dirs = NULL, fallback_font = NULL, verbose = FALSE)
  Returns integer page count (invisibly). Logs page count via cli_alert_success.

## Meta Folder Management (R/meta_management.R, added Mar 1 2026)
- list_reports(meta_dir, sort_by = c("datetime", "doc_file", "spec_file"))
  Scans meta folder, returns data frame: doc_file, datetime, is_latest, n_specs, spec_file, data_refs.
  Uses _index.json when present (fast); falls back to scanning all JSONs.
  is_latest = TRUE for most-recent spec per doc_file; FALSE = obsolete candidate.

- replay_report(spec_json, meta_dir = NULL, output_path = NULL, template_json = NULL, verbose = FALSE)
  Re-renders DOCX from stored JSON without any R objects.
  spec_json: full path OR doc_file name (resolves latest) OR hash filename.
  output_path: defaults to outDir/docFileName from _metadata.

- clean_reports(meta_dir, keep_versions = 1L, dry_run = TRUE)
  Removes: (1) obsolete spec JSONs (older versions per doc_file), (2) orphaned data/image files.
  keep_versions: how many recent versions to keep per document (default 1, set 2 for rollback).
  dry_run = TRUE: only reports what would be deleted. dry_run = FALSE: deletes and rebuilds _index.json.
  Returns invisible list(obsolete_specs, orphaned_data, orphaned_imgs, deleted).

## Package Options
- tfl_get_options(), tfl_get_option(name)
- tfl_set_options(...): REPLACES previous headers/footers, does not accumulate
- tfl_reset_options()

## C++ Test Hooks (Internal)
- cpp_test_units(): 60+ assertions for units.cpp
- cpp_test_inline_parser(): 35+ assertions for inline_parser.cpp
- cpp_test_xml_writer(): 40+ assertions for xml_writer.cpp

## Typical Full Pipeline
```r
spec <- create_table(mtcars) |> add_title("Title")
report <- create_report(spec)
saved <- save_report(report, "output.docx")
render_docx(
  spec_json = file.path(saved$metaPath, saved$spec_file),
  output_path = "output/result.docx"
)

# Replay from stored JSON
replay_report("output.docx", meta_dir = saved$metaPath)

# Clean old versions
clean_reports(saved$metaPath, dry_run = FALSE)
```

## NAMESPACE Registrations
- useDynLib(ksTFL, .registration = TRUE)
- importFrom(Rcpp, sourceCpp)
- S3methods: add_style, add_body_text, add_header, add_footer (TFL_spec, TFL_options, default)
- S3methods: set_page_style (TFL_spec, TFL_options)
- S3method: c.tfl_style_combine, print.TFL_spec
- Exports: list_reports, replay_report, clean_reports (added Mar 1 2026)
