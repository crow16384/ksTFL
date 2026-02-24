# Key Exported API Functions

## Spec Creation
- create_table(data, cols = everything(), docPrefix = NULL): Table spec from data.frame
- create_figure(filepath, docPrefix = NULL): Figure spec from image path
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
- c_addrow(pos, value_from, styleRef): insert row above/below
- c_pageBreak(): insert page break

## Report Assembly
- create_report(...): combine specs/reports, 6-phase pipeline
- save_report(report, docFileName, outDir, metaPath, prettify): serialize to JSON + data files

## Package Options
- tfl_get_options(): all options
- tfl_get_option(name): single option
- tfl_set_options(...): update options
- tfl_reset_options(): restore defaults
