## ----create_sample_data, eval = FALSE-----------------------------------------
# # Sample datasets used by multiple sections (run locally before executing examples)
# set.seed(2025)
# 
# demog_tbl <- data.frame(
#   subject_id = sprintf("S%03d", 1:24),
#   age = sample(25:80, 24, TRUE),
#   sex = sample(c("M","F"), 24, TRUE),
#   trt = sample(c("Placebo","DrugA"), 24, TRUE),
#   stringsAsFactors = FALSE
# )
# 
# vitals_tbl <- data.frame(
#   subject_id = rep(demog_tbl$subject_id, each = 2),
#   visit = rep(c("Baseline","Week 12"), times = 24),
#   sbp = round(rnorm(48, 120, 12)),
#   dbp = round(rnorm(48, 75, 8)),
#   stringsAsFactors = FALSE
# )
# 
# labs_tbl <- data.frame(
#   subject_id = demog_tbl$subject_id,
#   ALT = round(rnorm(24, 28, 9)),
#   AST = round(rnorm(24, 26, 8)),
#   stringsAsFactors = FALSE
# )
# 
# # Example plot file (created locally when running the vignette)
# plot_file <- file.path(tempdir(), "example_plot.png")
# png(plot_file, width = 600, height = 400)
# plot(demog_tbl$age, vitals_tbl$sbp[1:24], xlab = "Age", ylab = "SBP", main = "Age vs SBP")
# dev.off()

## ----example_minimal_table, eval = FALSE--------------------------------------
# spec_min_table <- create_table(data = demog_tbl, cols = c(subject_id, age, sex, trt), docPrefix = "demog_min")
# spec_min_table <- add_title(spec_min_table, "Demographics (minimal)")
# 
# # Print shows a compact overview (useful in interactive sessions)
# print(spec_min_table)
# # close the example chunk

## ----save_min_table, eval = FALSE---------------------------------------------
# # End-to-end: wrap single spec into a report and save
# rpt_min_table <- create_report(spec_min_table)
# res_min_table <- save_report(rpt_min_table, docFileName = "tbl_min.docx", outDir = "./out", metaPath = tempdir(), prettify = TRUE)
# res_min_table

## ----example_minimal_figure, eval = FALSE-------------------------------------
# spec_min_fig <- create_figure(data = plot_file)
# spec_min_fig <- add_title(spec_min_fig, "Example: Age vs SBP")
# print(spec_min_fig)
# # close example chunk

## ----save_min_fig, eval = FALSE-----------------------------------------------
# # End-to-end: save the single-figure report
# rpt_min_fig <- create_report(spec_min_fig)
# res_min_fig <- save_report(rpt_min_fig, docFileName = "fig_min.docx", outDir = "./out", metaPath = tempdir(), prettify = TRUE)
# res_min_fig

## ----example_minimal_text, eval = FALSE---------------------------------------
# spec_min_text <- create_text()
# spec_min_text <- add_body_text(spec_min_text, "This narrative describes the study population and analysis approach.")
# print(spec_min_text)
# # close example chunk

## ----save_min_text, eval = FALSE----------------------------------------------
# # End-to-end: save the narrative as a report
# rpt_min_text <- create_report(spec_min_text)
# res_min_text <- save_report(rpt_min_text, docFileName = "txt_min.docx", outDir = "./out", metaPath = tempdir(), prettify = TRUE)
# res_min_text

## ----example_define_single, eval = FALSE--------------------------------------
# # Define one column
# spec_single <- create_table(data = demog_tbl, cols = c(subject_id, age, sex, trt))
# spec_single <- define_cols(spec_single, subject_id, label = "Subject ID", isID = TRUE)
# 
# # Another single column call (chaining is encouraged)
# spec_single <- define_cols(spec_single, age,
#                            label = "Age (years)",
#                            type = "numeric",
#                            format = "%.0f")
# 
# print(spec_single)
# # close example chunk

## ----example_define_batch_single, eval = FALSE--------------------------------
# # Apply single format to multiple columns
# spec_batch <- create_table(data = demog_tbl, cols = c(age, height, weight))
# spec_batch <- define_cols(spec_batch, c(age, height, weight),
#                           type = "numeric",      # Applied to all 3
#                           format = "%.1f",       # Applied to all 3
#                           valueStyleRef = "numeric_right")  # Applied to all 3
# 
# print(spec_batch)
# # close example chunk

## ----example_define_batch_mapped, eval = FALSE--------------------------------
# # Different label and format for each column
# spec_mapped <- create_table(data = demog_tbl, cols = c(age, sex, trt))
# spec_mapped <- define_cols(spec_mapped, c(age, sex, trt),
#                            label = c("Age (years)", "Biological Sex", "Treatment Group"),
#                            type = c("numeric", "string", "string"),
#                            format = c("%.0f", "", "")
# )
# 
# print(spec_mapped)
# # close example chunk

## ----example_define_chain, eval = FALSE---------------------------------------
# # Start with basic table
# spec_chain <- create_table(data = demog_tbl, cols = c(subject_id, age, sex, trt))
# 
# # First pass: set all labels
# spec_chain <- define_cols(spec_chain, c(subject_id, age, sex, trt),
#                           label = c("Subject ID", "Age", "Sex", "Treatment"))
# 
# # Second pass: set numeric formatting for age and trt
# spec_chain <- define_cols(spec_chain, age, type = "numeric", format = "%.0f")
# 
# # Third pass: mark subject_id as ID column (repeats on page breaks)
# spec_chain <- define_cols(spec_chain, subject_id, isID = TRUE)
# 
# print(spec_chain)
# # close example chunk

## ----example_set_document_prefix, eval = FALSE--------------------------------
# spec <- create_table(demog_tbl)
# 
# # Add document prefix
# spec <- set_document(spec,
#   docPrefix = "Table 14.1",
#   hasData = TRUE)
# 
# print(spec)

## ----example_set_document_width, eval = FALSE---------------------------------
# spec <- create_table(demog_tbl)
# 
# spec <- set_document(spec,
#   docPrefix = "Table 14.2",
#   contentWidth = "95%",        # Narrower content (default 100%)
#   bodyTitles = FALSE,          # Titles in header, not body
#   bodyFootnotes = TRUE,        # Footnotes in body
#   glueNumType = FALSE)         # Prefix separate from title

## ----example_combine_report, eval = FALSE-------------------------------------
# report_simple <- create_report(spec_min_table, spec_min_fig, spec_min_text)
# print(report_simple)
# # close example chunk

## ----save_report_simple, eval = FALSE-----------------------------------------
# # Save combined simple report
# res_report_simple <- save_report(report_simple, docFileName = "report_simple.docx", outDir = "./out", metaPath = tempdir(), prettify = TRUE)
# res_report_simple

## ----example_colwidth_auto, eval = FALSE--------------------------------------
# # Create table; widths are auto-calculated from data characteristics
# spec_auto <- create_table(data = labs_tbl, cols = c(subject_id, ALT, AST))
# spec_auto <- define_cols(spec_auto, c(subject_id, ALT, AST),
#                          label = c("Subject ID", "ALT (U/L)", "AST (U/L)"))
# 
# # Print to see auto-calculated widths
# print(spec_auto)
# # close example chunk

## ----example_colwidth_lock_one, eval = FALSE----------------------------------
# # Lock subject_id at 15%, let ALT and AST split the remaining 85%
# spec_lock1 <- create_table(data = labs_tbl, cols = c(subject_id, ALT, AST))
# spec_lock1 <- define_cols(spec_lock1, subject_id,
#                           label = "Subject ID",
#                           colWidth = "15%")  # Lock at 15%
# 
# # When auto-recalculation runs (automatic), ALT and AST widths are recalculated
# # to maintain their initial proportion while filling the remaining 85%
# 
# print(spec_lock1)
# # close example chunk

## ----example_colwidth_lock_multiple, eval = FALSE-----------------------------
# # Lock two columns, let the third auto-adjust
# spec_lock_multi <- create_table(data = labs_tbl, cols = c(subject_id, ALT, AST))
# spec_lock_multi <- define_cols(spec_lock_multi, subject_id,
#                                label = "Subject ID",
#                                colWidth = "12%")
# spec_lock_multi <- define_cols(spec_lock_multi, ALT,
#                                label = "ALT (U/L)",
#                                colWidth = "40%")
# 
# # AST automatically fills remaining 48% (100% - 12% - 40%)
# 
# print(spec_lock_multi)
# # close example chunk

## ----example_colwidth_mixed_units, eval = FALSE-------------------------------
# # Lock subject_id at 2 cm, others in percentages
# spec_mixed <- create_table(data = labs_tbl, cols = c(subject_id, ALT, AST))
# spec_mixed <- define_cols(spec_mixed, subject_id,
#                           label = "Subject ID",
#                           colWidth = "2cm")  # Absolute width
# spec_mixed <- define_cols(spec_mixed, ALT,
#                           label = "ALT (U/L)",
#                           colWidth = "35%")   # Percentage of remaining
# 
# print(spec_mixed)
# # close example chunk

## ----example_colwidth_validation, eval = FALSE--------------------------------
# spec_valid <- create_table(data = labs_tbl, cols = c(subject_id, ALT, AST))
# 
# # VALID: Set a reasonable relative width
# spec_valid <- define_cols(spec_valid, ALT,
#                           colWidth = "30%")  # OK: 30% is valid
# 
# # INVALID: Cannot set 100% relative width (leaves no space for other columns)
# # This will raise an error:
# # spec_valid <- define_cols(spec_valid, ALT, colWidth = "100%")
# # Error: relative width 100.0% exceeds maximum allowed 75.0%
# #        (accounting for locked columns and minimum 0.5% for other columns)
# 
# # INVALID: Cannot set width below minimum threshold
# # spec_valid <- define_cols(spec_valid, AST, colWidth = "0.2%")
# # Error: relative width 0.2% is below minimum 0.5%
# 
# # Minimum width constraints (can be customized via package options):
# # - Relative widths (%): minimum 0.5%
# # - Fixed widths (cm, in, pt): minimum 0.2cm (~2mm, ~0.08in)
# 
# # Configure minimum width via package options:
# tfl_set_options(minColWidth = 1.0)  # Set minimum relative width to 1.0%
# 
# # Now 0.5% will fail, but 1.0% will succeed
# spec_valid <- define_cols(spec_valid, AST,
#                           colWidth = "1.0%")  # OK with new minimum
# 
# print(spec_valid)

## ----example_multilevel_table, eval = FALSE-----------------------------------
# spec_multi <- create_table(data = labs_tbl, cols = c(subject_id, ALT, AST))
# spec_multi <- add_title(spec_multi, "Laboratory Results")
# spec_multi <- add_subtitle(spec_multi, "Selected hepatic enzymes by subject")
# spec_multi <- add_footnote(spec_multi, "Values are shown as observed.")
# 
# spec_multi <- define_cols(
#   spec_multi,
#   c(subject_id, ALT, AST),
#   label = c("Subject ID", "ALT (U/L)", "AST (U/L)")
# )
# 
# print(spec_multi)
# # close example chunk

## ----save_multilevel, eval = FALSE--------------------------------------------
# # Save the multilevel table as a report
# rpt_multi <- create_report(spec_multi)
# res_multi <- save_report(rpt_multi, docFileName = "tbl_multi.docx", outDir = "./out", metaPath = tempdir(), prettify = TRUE)
# res_multi

## ----example_stubs_single, eval = FALSE---------------------------------------
# # Start with demographics table
# spec_stub_simple <- create_table(data = demog_tbl, cols = c(subject_id, age, sex, trt))
# spec_stub_simple <- define_cols(spec_stub_simple,
#                                 c(subject_id, age, sex, trt),
#                                 label = c("Subject","Age","Sex","Treatment"))
# 
# # Add a spanning header for "Demographics" above age and sex
# spec_stub_simple <- add_span_header(spec_stub_simple,
#                                     cols = c("age", "sex"),
#                                     label = "Demographics")
# 
# print(spec_stub_simple)
# # close example chunk

## ----example_stubs_tidyselect, eval = FALSE-----------------------------------
# # Table with mixed column types
# mixed_data <- data.frame(
#   id = 1:10,
#   age_baseline = rnorm(10, 45, 10),
#   age_follow = rnorm(10, 46, 10),
#   weight_baseline = rnorm(10, 70, 10),
#   weight_follow = rnorm(10, 71, 10)
# )
# 
# spec_tidysel <- create_table(mixed_data)
# 
# # Using starts_with() helper
# spec_tidysel <- add_span_header(spec_tidysel,
#                                 cols = starts_with("age"),
#                                 label = "Age Measurements",
#                                 stubOrder = 0)
# 
# # Using negation (-) to exclude columns
# spec_tidysel <- add_span_header(spec_tidysel,
#                                 cols = -id,
#                                 label = "Baseline and Follow",
#                                 stubOrder = 1)
# 
# # Using matches() regex pattern
# spec_tidysel <- add_span_header(spec_tidysel,
#                                 cols = matches("_baseline$"),
#                                 label = "Baseline Visits",
#                                 stubOrder = 2)
# 
# print(spec_tidysel)

## ----example_stubs_multi, eval = FALSE----------------------------------------
# # Create table with visit measurements at two time points
# vitals_data <- data.frame(
#   subject = sprintf("S%03d", 1:10),
#   baseline_sbp = round(rnorm(10, 120, 10)),
#   baseline_dbp = round(rnorm(10, 75, 8)),
#   week12_sbp = round(rnorm(10, 118, 10)),
#   week12_dbp = round(rnorm(10, 74, 8))
# )
# 
# # Create spec and define columns
# spec_stubs_multi <- create_table(data = vitals_data,
#                                  cols = c(subject, baseline_sbp, baseline_dbp, week12_sbp, week12_dbp))
# spec_stubs_multi <- define_cols(spec_stubs_multi,
#                                 c(subject, baseline_sbp, baseline_dbp, week12_sbp, week12_dbp),
#                                 label = c("Subject ID", "SBP", "DBP", "SBP", "DBP"))
# 
# # Add first stub spanning baseline measurements
# spec_stubs_multi <- add_span_header(spec_stubs_multi,
#                                     cols = c("baseline_sbp", "baseline_dbp"),
#                                     label = "Baseline",
#                                     stubOrder = 1)
# 
# # Add second stub spanning week 12 measurements
# spec_stubs_multi <- add_span_header(spec_stubs_multi,
#                                     cols = c("week12_sbp", "week12_dbp"),
#                                     label = "Week 12",
#                                     stubOrder = 2)
# 
# print(spec_stubs_multi)
# # close example chunk

## ----example_stubs_styled, eval = FALSE---------------------------------------
# # First, create a style for stub labels
# spec_stubs_style <- create_table(data = demog_tbl, cols = c(subject_id, age, sex, trt))
# 
# spec_stubs_style <- add_style(spec_stubs_style,
#                               id = "stub_header",
#                               s_font(bold = TRUE, font_size = "12pt"),
#                               s_paragraph(alignment = "center"),
#                               s_table_style(background_color = "#E8E8E8"))
# 
# # Define columns
# spec_stubs_style <- define_cols(spec_stubs_style,
#                                 c(subject_id, age, sex, trt),
#                                 label = c("Subject ID", "Age", "Sex", "Treatment"))
# 
# # Add stub with style reference
# spec_stubs_style <- add_span_header(spec_stubs_style,
#                                     cols = c("age", "sex"),
#                                     label = "Demographics",
#                                     labelStyleRef = "stub_header")
# 
# print(spec_stubs_style)
# # close example chunk

## ----save_stub, eval = FALSE--------------------------------------------------
# # Save stubbed table report
# rpt_stub <- create_report(spec_stubs_style)
# res_stub <- save_report(rpt_stub, docFileName = "tbl_stub.docx", outDir = "./out", metaPath = tempdir(), prettify = TRUE)
# res_stub

## ----example_styles_base, eval = FALSE----------------------------------------
# # Create a table spec
# spec_base_styles <- create_table(data = demog_tbl, cols = c(subject_id, age, sex, trt))
# 
# # Define reusable base styles
# spec_base_styles <- add_style(spec_base_styles, id = "bold_header",
#                               s_font(bold = TRUE, font_size = "12pt"))
# 
# spec_base_styles <- add_style(spec_base_styles, id = "right_align",
#                               s_paragraph(alignment = "right"))
# 
# spec_base_styles <- add_style(spec_base_styles, id = "light_gray_bg",
#                               s_table_style(background_color = "#F5F5F5"))
# 
# # Apply to columns
# spec_base_styles <- define_cols(spec_base_styles,
#                                 c(subject_id, age, sex, trt),
#                                 label = c("Subject ID", "Age", "Sex", "Treatment"),
#                                 labelStyleRef = c("bold_header", "", "", ""))
# 
# print(spec_base_styles)
# # close example chunk

## ----example_styles_fcombine, eval = FALSE------------------------------------
# # Create spec and define base styles
# spec_combined <- create_table(data = demog_tbl, cols = c(subject_id, age, sex, trt))
# 
# # Define atomic styles
# spec_combined <- add_style(spec_combined, id = "bold_text", s_font(bold = TRUE))
# spec_combined <- add_style(spec_combined, id = "red_color", s_font(color = "#CC0000"))
# spec_combined <- add_style(spec_combined, id = "centered", s_paragraph(alignment = "center"))
# 
# # Combine styles: bold + red text + centered
# spec_combined <- define_cols(spec_combined,
#                              subject_id,
#                              label = "Subject ID",
#                              labelStyleRef = f_combine("bold_text", "red_color", "centered"))
# 
# # Different columns can use different combinations
# spec_combined <- define_cols(spec_combined, age, label = "Age",
#                              labelStyleRef = f_combine("bold_text", "centered"))
# 
# print(spec_combined)
# # close example chunk

## ----example_styles_batch_combine, eval = FALSE-------------------------------
# # Create spec and styles
# spec_batch_combined <- create_table(data = demog_tbl, cols = c(subject_id, age, sex, trt))
# 
# spec_batch_combined <- add_style(spec_batch_combined, id = "header_emphasis",
#                                  s_font(bold = TRUE, font_size = "13pt"),
#                                  s_table_style(background_color = "#E0E0E0"))
# 
# # Apply combined styles: emphasis for subject_id + age, different for sex + trt
# spec_batch_combined <- define_cols(spec_batch_combined,
#                                    c(subject_id, age, sex, trt),
#                                    label = c("Subject ID", "Age", "Sex", "Treatment"),
#                                    labelStyleRef = c(f_combine("header_emphasis", "centered"),
#                                                      f_combine("header_emphasis", "centered"),
#                                                      "centered",
#                                                      "centered"))
# 
# print(spec_batch_combined)
# # close example chunk

## ----save_styles, eval = FALSE------------------------------------------------
# # Save the styled table report
# rpt_styles <- create_report(spec_batch_combined)
# res_styles <- save_report(rpt_styles, docFileName = "tbl_styles.docx", outDir = "./out", metaPath = tempdir(), prettify = TRUE)
# res_styles

## ----compute_basic_style, eval = FALSE----------------------------------------
# # Sample data with groups
# data <- data.frame(
#   group = c("A", "A", "B", "B", "C"),
#   metric = c("Value 1", "Value 2", "Value 3", "Value 4", "Value 5"),
#   count = c(10, 20, 15, 25, 30)
# )
# 
# # Create spec and define styles
# spec <- create_table(data) |>
#   add_style("group_header", s_font(bold = TRUE, color = "#0000FF")) |>
#   add_style("emphasize", s_table_style(background_color = "#FFFFCC"))
# 
# # Apply conditional styling: bold+blue for first occurrence of each group
# spec <- spec |>
#   compute_cols(firstOf(group), c_style(c(metric, count), styleRef = "group_header"))
# 
# # Apply conditional styling: highlight rows with high count
# spec <- spec |>
#   compute_cols(count > 20, c_style(count, styleRef = "emphasize"))
# 
# print(spec)

## ----compute_combined_style, eval = FALSE-------------------------------------
# spec <- create_table(data) |>
#   add_style("bold", s_font(bold = TRUE)) |>
#   add_style("large", s_font(font_size = "14pt")) |>
#   add_style("highlight", s_table_style(background_color = "#FFFF00"))
# 
# # Apply combined styles to first group occurrence
# spec <- spec |>
#   compute_cols(firstOf(group),
#     c_style(metric, styleRef = f_combine("bold", "large", "highlight"))
#   )

## ----compute_merge, eval = FALSE----------------------------------------------
# spec <- create_table(data) |>
#   add_style("group_label", s_table_style(background_color = "#D9D9D9"))
# 
# # Merge metric and count columns for first occurrence (group header style)
# spec <- spec |>
#   compute_cols(firstOf(group),
#     c_merge(c(metric, count), styleRef = "group_label")
#   )

## ----compute_addrow, eval = FALSE---------------------------------------------
# spec <- create_table(data) |>
#   add_style("separator", s_table_style(background_color = "#E8E8E8"))
# 
# # Insert empty separator above first group occurrence
# spec <- spec |>
#   compute_cols(firstOf(group),
#     c_addrow(pos = "above")  # Empty row, no value_from
#   )
# 
# # Insert summary row below last group occurrence (using a specific column as content)
# spec <- spec |>
#   compute_cols(lastOf(group),
#     c_addrow(pos = "below", value_from = "group", styleRef = "separator")
#   )

## ----compute_multi_action, eval = FALSE---------------------------------------
# spec <- create_table(data) |>
#   add_style("header", s_font(bold = TRUE)) |>
#   add_style("separator", s_table_style(background_color = "#E8E8E8"))
# 
# # For first group occurrence: add separator, style, and merge
# spec <- spec |>
#   compute_cols(firstOf(group),
#     c_addrow(pos = "above"),  # Add empty separator
#     c_style(metric, styleRef = "header"),  # Style metric column
#     c_merge(c(metric, count))  # Merge adjacent columns
#   )

## ----example_save_report, eval = FALSE----------------------------------------
# # Create multiple specs
# table_spec <- create_table(data = labs_tbl, cols = c(subject_id, ALT, AST))
# table_spec <- add_title(table_spec, "Laboratory Results")
# 
# text_spec <- create_text()
# text_spec <- add_body_text("All values are from the locked database.")
# 
# # Assemble into report
# report_full <- create_report(table_spec, text_spec)
# 
# # Save — internally validates and writes JSON + data files to metaPath
# res <- save_report(report_full,
#                    docFileName = "example_report.docx",
#                    outDir = "./out",
#                    metaPath = tempdir(),
#                    prettify = TRUE)
# 
# # Inspect metadata
# str(res)

## ----example_session_options_basic, eval = FALSE------------------------------
# # Set session defaults (applies to all NEW specs created after this call)
# tfl_set_options(
#   add_header(c("Study ABC", "Phase II Safety Study", "CONFIDENTIAL")),
#   add_footer(c("Company Confidential", "Page {page} of {numpages}"))
# )
# 
# # Create spec — automatically inherits headers/footers from options
# spec_with_opts <- create_table(data = demog_tbl, cols = c(subject_id, age, sex, trt))
# spec_with_opts <- add_title(spec_with_opts, "Demographics Table")
# 
# print(spec_with_opts)
# # close example chunk

## ----example_session_options_override, eval = FALSE---------------------------
# # Session options are still in effect from previous example
# 
# # Create a spec with session defaults
# spec_default <- create_table(data = labs_tbl, cols = c(subject_id, ALT, AST))
# spec_default <- add_title(spec_default, "Lab Results (using session defaults)")
# 
# # Create another spec but override the header
# spec_override <- create_table(data = demog_tbl, cols = c(subject_id, age))
# spec_override <- add_header(c("Study XYZ", "Different Study", "CONFIDENTIAL"))  # Overrides session default
# spec_override <- add_title(spec_override, "Demographics (custom header)")
# 
# print(spec_default)   # Uses session header from tfl_set_options
# print(spec_override)  # Uses custom header from add_header call
# # close example chunk

## ----example_session_options_inspect, eval = FALSE----------------------------
# # Check current options
# current_options <- tfl_get_options()
# str(current_options)
# 
# # Get a single option
# current_missings <- tfl_get_option("missings")
# cat("Current missings representation:", current_missings, "\n")
# 
# # Reset to package defaults
# tfl_reset_options()
# 
# # Now new specs will use package defaults instead of your custom session options
# spec_reset <- create_table(data = demog_tbl, cols = c(subject_id, age))
# print(spec_reset)
# # close example chunk

