## ----setup, include=FALSE-----------------------------------------------------
knitr::opts_chunk$set(comment = "", collapse = TRUE, eval = FALSE)

## ----quick_pipeline, eval = FALSE---------------------------------------------
# library(ksTFL)
# 
# # 1. Create a table spec from data
# spec <- create_table(mtcars, cols = c(mpg, cyl, hp))
# 
# # 2. Define a style and apply it
# spec <- add_style(spec, id = "header_bold",
#   s_font(bold = TRUE, font_size = "12pt"))
# 
# # 3. Customize columns
# spec <- define_cols(spec, c(mpg, cyl, hp),
#   label = c("MPG", "Cylinders", "HP"),
#   type = c("numeric", "numeric", "numeric"),
#   format = c("%.1f", "%.0f", "%.0f"),
#   labelStyleRef = "header_bold")
# 
# # 4. Add titles
# spec <- add_title(spec, "Motor Trends Dataset")
# spec <- add_footnote(spec, "Data from mtcars (1974).")
# 
# # 5. Inspect the spec
# print(spec)
# 
# # 6. Save for rendering
# report <- create_report(spec)
# save_report(report, docFileName = "my_table.docx", outDir = "./output", metaPath = tempdir())

## ----create_table_spec, eval = FALSE------------------------------------------
# # Simple: all columns
# spec_tbl <- create_table(mtcars)
# 
# # Select specific columns with tidyselect
# spec_tbl <- create_table(mtcars, cols = c(mpg, cyl, hp, wt))
# 
# # With prefix (used in file naming)
# spec_tbl <- create_table(mtcars, cols = c(mpg, cyl), docPrefix = "t01s01")

## ----create_figure_spec, eval = FALSE-----------------------------------------
# spec_fig <- create_figure(data = "path/to/plot.png")
# 
# # Optional: with prefix
# spec_fig <- create_figure(data = "plots/figure1.png", docPrefix = "fig01")

## ----create_text_spec, eval = FALSE-------------------------------------------
# spec_txt <- create_text()
# 
# # Add narrative content
# spec_txt <- add_body_text(spec_txt, "This analysis includes all subjects in the safety population.")

## ----define_single_column, eval = FALSE---------------------------------------
# spec <- define_cols(spec, mpg,
#   label = "Miles per Gallon",
#   type = "numeric",
#   format = "%.1f",
#   colWidth = "20%")

## ----define_batch_single, eval = FALSE----------------------------------------
# # Apply same label format to all columns
# spec <- define_cols(spec, c(mpg, cyl, hp),
#   label = c("MPG", "Cylinders", "HP"),
#   type = "numeric",        # Recycled to all 3
#   format = "%.0f")         # Recycled to all 3

## ----define_batch_mapped, eval = FALSE----------------------------------------
# # Different format for each column
# spec <- define_cols(spec, c(mpg, cyl, hp),
#   label = c("MPG", "Cylinders", "HP"),
#   type = c("numeric", "numeric", "numeric"),
#   format = c("%.1f", "%.0f", "%.0f"))

## ----define_styles, eval = FALSE----------------------------------------------
# spec <- create_table(mtcars)
# 
# # Header style: bold, 12pt, centered, gray background
# spec <- add_style(spec, id = "table_header",
#   s_font(font_name = "Arial", font_size = "12pt", bold = TRUE),
#   s_paragraph(alignment = "center"),
#   s_table_style(background_color = "#E0E0E0"))
# 
# # Numeric style: right-aligned
# spec <- add_style(spec, id = "numeric_right",
#   s_paragraph(alignment = "right"))
# 
# # Apply to columns
# spec <- define_cols(spec, c(mpg, hp),
#   labelStyleRef = "table_header",
#   valueStyleRef = "numeric_right")

## ----add_stubs, eval = FALSE--------------------------------------------------
# spec <- create_table(mtcars)
# spec <- define_cols(spec, c(mpg, cyl, hp, wt),
#   label = c("MPG", "Cyl", "HP", "Weight"))
# 
# # Top-level span header spanning all columns
# spec <- add_span_header(spec, cols = c(mpg, cyl, hp, wt),
#   label = "Motor Vehicle Specs",
#   stubOrder = 0) |>
# # Second-level headers: finer grouping
# add_span_header(cols = c(mpg, cyl, hp),
#   label = "Engine",
#   stubOrder = 1) |>
# add_span_header(cols = wt,
#   label = "Weight",
#   stubOrder = 1)

## ----add_stubs_tidyselect, eval = FALSE---------------------------------------
# # Using column ranges and helpers
# spec <- add_span_header(spec, cols = mpg:hp, label = "First", stubOrder = 0) |>
#   add_span_header(cols = starts_with("c"), label = "C-columns", stubOrder = 1) |>
#   add_span_header(cols = -mpg, label = "Non-MPG", stubOrder = 2)

## ----add_content, eval = FALSE------------------------------------------------
# spec <- create_table(mtcars)
# 
# # Titles and subtitles
# spec <- add_title(spec, "Demographics")
# spec <- add_subtitle(spec, "Motor Vehicle Analysis")
# 
# # Footnotes (document-level notes)
# spec <- add_footnote(spec, "Values are from 1974 Motor Trend magazine.")
# 
# # Page headers (left/center/right)
# spec <- add_header(c("Study ABC", "CONFIDENTIAL", "Page {page}"))
# 
# # Page footers (left/center/right)
# spec <- add_footer(c("Company", "Locked DB", "2025"))
# 
# # Body text (narrative)
# spec <- add_body_text(spec, "This analysis includes all subjects in the safety population.")

## ----create_report, eval = FALSE----------------------------------------------
# # Create multiple specs
# spec_table <- create_table(mtcars)
# spec_table <- add_title(spec_table, "Table 1: Demographics")
# 
# spec_text <- create_text()
# spec_text <- add_body_text(spec_text, "Analysis performed in R.")
# 
# spec_fig <- create_figure("plots/histogram.png")
# 
# # Combine into single report
# report <- create_report(spec_table, spec_text, spec_fig)
# 
# # Inspect combined report
# print(report)

## ----compute_cols_basic, eval = FALSE-----------------------------------------
# spec <- create_table(mtcars)
# 
# # Define a style for first group occurrences
# spec <- add_style(spec, id = "group_header", s_font(bold = TRUE, color = "#0000FF"))
# 
# # Apply style conditionally: highlight first occurrence of each cyl group
# spec <- compute_cols(spec, firstOf(cyl),
#   c_style(c(mpg, hp), styleRef = "group_header"))
# 
# # Add a separator row above first group
# spec <- compute_cols(spec, firstOf(cyl),
#   c_addrow(pos = "above"))

## ----compute_cols_conditions, eval = FALSE------------------------------------
# # Direct column comparison
# compute_cols(spec, cyl > 6, c_style(mpg, styleRef = "emphasize"))
# 
# # String matching
# compute_cols(spec, Parameter == "Pulse", c_style(value, styleRef = "numeric"))
# 
# # Helper functions (firstOf, lastOf, every_nth)
# compute_cols(spec, firstOf(group), c_style(c(col1, col2), styleRef = "group_header"))
# 
# # Combine conditions
# compute_cols(spec, cyl == 8 & hp > 100, c_style(mpg, styleRef = "high_power"))

## ----save_report, eval = FALSE------------------------------------------------
# report <- create_report(spec_table, spec_text)
# 
# # Save with validation and serialization
# result <- save_report(report,
#   docFileName = "my_report.docx",
#   outDir = "./output",
#   metaPath = tempdir(),
#   prettify = TRUE)
# 
# # Inspect output
# str(result)

## ----session_options, eval = FALSE--------------------------------------------
# # Set session defaults
# tfl_set_options(
#   add_header(c("Study ABC", "Locked Database", "CONFIDENTIAL")),
#   add_footer(c("Company Name", "Page {page}", "2025")),
#   add_body_text("Analysis performed in R with ksTFL."))
# 
# # All new specs created afterward inherit these settings
# spec1 <- create_table(data1)  # Automatically gets headers/footers/body text
# spec2 <- create_table(data2)  # Also inherits defaults
# 
# # Check current options
# tfl_get_options()
# 
# # Reset to package defaults
# tfl_reset_options()

## ----complete_example, eval = FALSE-------------------------------------------
# library(ksTFL)
# 
# # --- Setup ---
# data <- data.frame(
#   subject = sprintf("S%03d", 1:10),
#   age = round(rnorm(10, 45, 10)),
#   sex = sample(c("M", "F"), 10, TRUE)
# )
# 
# # --- Create & customize ---
# spec <- create_table(data, cols = c(subject, age, sex))
# 
# spec <- add_style(spec, id = "header",
#   s_font(bold = TRUE, font_size = "11pt"),
#   s_paragraph(alignment = "center"),
#   s_table_style(background_color = "#DDDDDD"))
# 
# spec <- define_cols(spec, c(subject, age, sex),
#   label = c("Subject ID", "Age (years)", "Sex"),
#   labelStyleRef = "header")
# 
# spec <- define_cols(spec, age, type = "numeric", format = "%.0f")
# 
# spec <- add_title(spec, "Demographics Table")
# spec <- add_subtitle(spec, "All subjects in safety population")
# spec <- add_footnote(spec, "Data are shown as observed.")
# 
# # --- Export ---
# report <- create_report(spec)
# save_report(report,
#   docFileName = "demographics.docx",
#   outDir = "./output",
#   metaPath = tempdir())
# 
# # Done!

