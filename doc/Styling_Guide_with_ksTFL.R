## ----setup, include=FALSE-----------------------------------------------------
knitr::opts_chunk$set(comment = "", collapse = TRUE, eval = FALSE)

## ----s_font_example, eval = FALSE---------------------------------------------
# spec <- create_table(mtcars)
# 
# # Bold, 12pt Arial, red text (using hex code)
# spec <- add_style(spec, id = "header_bold_red",
#   s_font(font_name = "Arial", font_size = "12pt", bold = TRUE, color = "#CC0000"))
# 
# # Underlined, 10pt monospace, blue text (using color name)
# spec <- add_style(spec, id = "code_style",
#   s_font(font_name = "Courier New", font_size = "10pt", underline = TRUE, color = "blue"))
# 
# # Yellow highlight with black text
# spec <- add_style(spec, id = "highlighted",
#   s_font(color = "black", highlight = "yellow"))

## ----s_paragraph_example, eval = FALSE----------------------------------------
# spec <- create_table(mtcars)
# 
# # Centered text with 6pt spacing before/after
# spec <- add_style(spec, id = "centered_spaced",
#   s_paragraph(alignment = "center",
#               spacing = s_spacing(before = "6pt", after = "6pt")))
# 
# # Right-aligned with left indent
# spec <- add_style(spec, id = "right_indented",
#   s_paragraph(alignment = "right",
#               indents = s_indents(left = "10pt")))

## ----s_spacing_example, eval = FALSE------------------------------------------
# spec <- create_table(mtcars)
# 
# # Double-spaced with 12pt spacing after each paragraph
# spec <- add_style(spec, id = "double_spaced",
#   s_paragraph(spacing = s_spacing(after = "12pt", line_spacing = 2.0)))

## ----s_indents_example, eval = FALSE------------------------------------------
# spec <- create_table(mtcars)
# 
# # Hanging indent (first line outdented, rest indented)
# spec <- add_style(spec, id = "hanging_indent",
#   s_paragraph(indents = s_indents(left = "20pt", first_line = "-20pt")))
# 
# # Left and right margins with left indent
# spec <- add_style(spec, id = "block_indent",
#   s_paragraph(indents = s_indents(left = "30pt", right = "30pt")))

## ----s_table_style_example, eval = FALSE--------------------------------------
# spec <- create_table(mtcars)
# 
# # Light gray background, centered vertically, fixed row height
# spec <- add_style(spec, id = "header_cell",
#   s_table_style(background_color = "#F2F2F2",
#                 row_height = "30pt",
#                 vertical_alignment = "center"))
# 
# # Vertically rotated text (90 degrees)
# spec <- add_style(spec, id = "rotated_header",
#   s_table_style(text_orientation = "vertical_90"))

## ----s_borders_example, eval = FALSE------------------------------------------
# spec <- create_table(mtcars)
# 
# # All borders: thin single lines in dark gray
# spec <- add_style(spec, id = "all_borders",
#   s_table_style(
#     borders = s_borders(
#       top = s_border(color = "grey40", width = "1pt", line_style = "single"),
#       bottom = s_border(color = "grey40", width = "1pt", line_style = "single"),
#       left = s_border(color = "grey40", width = "1pt", line_style = "single"),
#       right = s_border(color = "grey40", width = "1pt", line_style = "single")
#     )
#   )
# )
# 
# # Heavy bottom border in dark color (using hex code)
# spec <- add_style(spec, id = "bottom_border_heavy",
#   s_table_style(
#     borders = s_borders(
#       bottom = s_border(color = "#333333", width = "2pt", line_style = "thick")
#     )
#   )
# )

## ----add_style_basic, eval = FALSE--------------------------------------------
# spec <- add_style(spec, id = "style_name",
#   s_font(...),
#   s_paragraph(...),
#   s_table_style(...)
# )

## ----add_style_complete, eval = FALSE-----------------------------------------
# spec <- create_table(mtcars)
# 
# # Comprehensive header style: bold white text on gray background, centered
# spec <- add_style(spec, id = "table_header",
#   s_font(font_name = "Arial", font_size = "12pt", bold = TRUE, color = "#FFFFFF"),
#   s_paragraph(alignment = "center", spacing = s_spacing(before = "6pt", after = "6pt")),
#   s_table_style(background_color = "#333333", row_height = "30pt", vertical_alignment = "center")
# )
# 
# # Simple numeric style: right-aligned
# spec <- add_style(spec, id = "numeric_right",
#   s_paragraph(alignment = "right")
# )
# 
# # ID/key style: bold
# spec <- add_style(spec, id = "id_bold",
#   s_font(bold = TRUE)
# )

## ----add_style_merge, eval = FALSE--------------------------------------------
# spec <- create_table(mtcars)
# 
# # First call: defines font
# spec <- add_style(spec, id = "emphasis", s_font(bold = TRUE))
# 
# # Second call: adds paragraph alignment; bold is preserved
# spec <- add_style(spec, id = "emphasis", s_paragraph(alignment = "center"))
# 
# # Result: "emphasis" has both bold font AND center alignment

## ----apply_label_style, eval = FALSE------------------------------------------
# spec <- create_table(mtcars)
# 
# spec <- add_style(spec, id = "header_bold", s_font(bold = TRUE, font_size = "12pt"))
# 
# # Apply to single column
# spec <- define_cols(spec, mpg, label = "MPG (miles/gallon)", labelStyleRef = "header_bold")
# 
# # Apply to multiple columns with recycling
# spec <- define_cols(spec, c(hp, cyl), label = c("HP", "Cylinders"), labelStyleRef = "header_bold")
# 
# # Different styles for different columns
# spec <- define_cols(spec, c(mpg, hp),
#   label = c("MPG", "HP"),
#   labelStyleRef = c("header_bold", "header_italic"))

## ----apply_value_style, eval = FALSE------------------------------------------
# spec <- create_table(mtcars)
# 
# spec <- add_style(spec, id = "numeric_right", s_paragraph(alignment = "right"))
# 
# # Right-align all numeric values in the mpg column
# spec <- define_cols(spec, mpg, type = "numeric", valueStyleRef = "numeric_right")

## ----apply_stub_style, eval = FALSE-------------------------------------------
# spec <- create_table(mtcars)
# 
# spec <- add_style(spec, id = "stub_label",
#   s_font(bold = TRUE, font_size = "11pt"),
#   s_table_style(background_color = "#EFEFEF"))
# 
# spec <- add_span_header(spec, cols = c("mpg", "cyl"), label = "Engine",
#   labelStyleRef = "stub_label")

## ----apply_content_style, eval = FALSE----------------------------------------
# spec <- create_table(mtcars)
# 
# spec <- add_style(spec, id = "title_style",
#   s_font(bold = TRUE, font_size = "14pt"),
#   s_paragraph(alignment = "center"))
# 
# spec <- add_title(spec, "Motor Trends Analysis", styleRef = "title_style")

## ----f_combine_basic, eval = FALSE--------------------------------------------
# spec <- create_table(mtcars)
# 
# spec <- add_style(spec, id = "bold", s_font(bold = TRUE))
# spec <- add_style(spec, id = "red", s_font(color = "red"))  # Using color name
# spec <- add_style(spec, id = "centered", s_paragraph(alignment = "center"))
# 
# # Apply bold + red + centered to a column header
# spec <- define_cols(spec, mpg, label = "MPG",
#   labelStyleRef = f_combine("bold", "red", "centered"))

## ----f_combine_per_column, eval = FALSE---------------------------------------
# spec <- create_table(mtcars)
# 
# # Define base styles
# spec <- add_style(spec, id = "bold", s_font(bold = TRUE))
# spec <- add_style(spec, id = "italic", s_font(italic = TRUE))
# spec <- add_style(spec, id = "centered", s_paragraph(alignment = "center"))
# spec <- add_style(spec, id = "right", s_paragraph(alignment = "right"))
# 
# # Apply different combinations per column
# spec <- define_cols(spec, c(mpg, cyl, hp),
#   label = c("MPG", "Cylinders", "HP"),
#   labelStyleRef = c(
#     f_combine("bold", "centered"),      # mpg: bold + centered
#     f_combine("italic", "right"),       # cyl: italic + right
#     f_combine("bold", "italic", "centered")  # hp: bold + italic + centered
#   )
# )

## ----pattern_clinical_header, eval = FALSE------------------------------------
# spec <- create_table(my_data)
# 
# spec <- add_style(spec, id = "clinical_header",
#   s_font(font_name = "Arial", font_size = "11pt", bold = TRUE, color = "#FFFFFF"),
#   s_paragraph(alignment = "center"),
#   s_table_style(background_color = "#003366", row_height = "28pt", vertical_alignment = "center")
# )
# 
# spec <- define_cols(spec, c(all columns), labelStyleRef = "clinical_header")

## ----pattern_numeric, eval = FALSE--------------------------------------------
# spec <- add_style(spec, id = "numeric_format",
#   s_font(font_name = "Courier New", font_size = "10pt"),
#   s_paragraph(alignment = "right")
# )
# 
# spec <- define_cols(spec, c(age, weight, dose), type = "numeric", valueStyleRef = "numeric_format")

## ----pattern_id_column, eval = FALSE------------------------------------------
# spec <- add_style(spec, id = "id_column",
#   s_font(bold = TRUE, font_size = "11pt"),
#   s_paragraph(alignment = "left")
# )
# 
# spec <- define_cols(spec, subject_id,
#   label = "Subject ID",
#   labelStyleRef = "id_column",
#   colWidth = "15%",
#   isID = TRUE)

## ----pattern_multi_stub, eval = FALSE-----------------------------------------
# spec <- add_style(spec, id = "level1_stub",
#   s_font(bold = TRUE, font_size = "12pt", color = "#FFFFFF"),
#   s_table_style(background_color = "#666666", vertical_alignment = "center"))
# 
# spec <- add_style(spec, id = "level2_stub",
#   s_font(bold = TRUE, font_size = "11pt"),
#   s_table_style(background_color = "#CCCCCC", vertical_alignment = "center"))
# 
# spec <- add_span_header(spec, cols = c("var1", "var2", "var3"), label = "Baseline",
#   stubOrder = 1, labelStyleRef = "level1_stub")
# 
# spec <- add_span_header(spec, cols = c("var1", "var2"), label = "Safety",
#   stubOrder = 2, labelStyleRef = "level2_stub")

## ----error_context, eval = FALSE----------------------------------------------
# # WRONG
# my_style <- s_font(bold = TRUE)  # ERROR
# 
# # CORRECT
# spec <- add_style(spec, id = "my_style", s_font(bold = TRUE))

## ----error_invalid, eval = FALSE----------------------------------------------
# # WRONG
# s_font(bold = "bolded")  # ERROR: must be TRUE/FALSE
# 
# # CORRECT
# s_font(bold = TRUE)

## ----error_consolidate, eval = FALSE------------------------------------------
# spec <- create_table(mtcars)
# spec <- define_cols(spec, mpg, labelStyleRef = f_combine("bold", "red"))
# 
# # WRONG: save directly without consolidation
# save_report(spec, ...)  # Combined styles may not be consolidated
# 
# # CORRECT: consolidate first
# report <- create_report(spec)  # Merges "bold" + "red"
# save_report(report, ...)

