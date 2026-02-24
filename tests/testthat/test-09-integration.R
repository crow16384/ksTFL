# ============================================================================
# Test: Full Integration Workflows
# ============================================================================

test_that("Full table workflow with styling", {
  spec <- create_table(test_df)
  spec <- add_title(spec, "Sample Data Table")
  spec <- add_subtitle(spec, "Analysis Results")
  
  spec <- add_style(spec, id = "header_bold", s_font(bold = TRUE))
  spec <- add_style(spec, id = "numeric_right", s_table_style(vertical_alignment = "top"))
  
  spec <- define_cols(spec, id, label = "ID", isID = TRUE, labelStyleRef = "header_bold")
  spec <- define_cols(spec, value, label = "Value", type = "numeric", format = "0.00", valueStyleRef = "numeric_right")
  
  spec <- add_footnote(spec, "Source: internal database")
  
  expect_equal(spec$document$docType, "Table")
  expect_true(length(spec$titles) > 0)
  expect_true(length(spec$attribs$styles) >= 2)
})

test_that("Full text document workflow", {
  spec <- create_text()
  spec <- add_header(spec, "Report Header")
  spec <- add_title(spec, "Analysis Report")
  
  spec <- add_body_text(spec, "Introduction and context...")
  spec <- add_body_text(spec, "Main findings and analysis...")
  spec <- add_body_text(spec, "Conclusions and recommendations...")
  
  spec <- add_footer(spec, "End of Report")
  
  expect_equal(spec$document$docType, "Text")
  expect_equal(length(spec$bodyText), 3)
})

test_that("Multi-spec report with different document types", {
  table_spec <- create_table(test_df)
  table_spec <- add_title(table_spec, "Data Summary")
  
  text_spec <- create_text()
  text_spec <- add_title(text_spec, "Analysis Notes")
  text_spec <- add_body_text(text_spec, "Additional context and notes...")
  
  figure_spec <- create_figure(filepath = test_image_path)
  
  report <- create_report(table_spec, text_spec, figure_spec)
  
  expect_equal(length(report), 3)
  expect_equal(report[[1]]$document$docType, "Table")
  expect_equal(report[[2]]$document$docType, "Text")
  expect_equal(report[[3]]$document$docType, "Figure")
})

test_that("Complex table with multiple styles and definitions", {
  spec <- create_table(test_df)
  
  # Add multiple styles
  spec <- add_style(spec, id = "bold", s_font(bold = TRUE))
  spec <- add_style(spec, id = "italic", s_font(italic = TRUE))
  spec <- add_style(spec, id = "centered", s_table_style(vertical_alignment = "center"))
  
  # Apply to multiple columns
  spec <- define_cols(spec, id, label = "ID", labelStyleRef = "bold")
  spec <- define_cols(spec, value, label = "Value", labelStyleRef = "italic")
  spec <- define_cols(spec, ratio, label = "Ratio", labelStyleRef = "centered")
  
  spec <- add_title(spec, "Complex Table")
  spec <- add_header(spec, "Header")
  spec <- add_footer(spec, "Footer")
  
  expect_true(length(spec$attribs$styles) >= 3)
  expect_true(length(spec$titles) > 0)
  expect_true(length(spec$headers) > 0)
})

test_that("Options applied to all created specs", {
  # Set global options
  original_missings <- tfl_get_option("missings")
  tfl_set_options(missings = "N/A")
  
  spec <- create_table(test_df)
  
  # Check that option is accessible (through define_cols)
  expect_true(!is.null(spec$.metadata))
  
  # Cleanup
  tfl_set_options(missings = original_missings)
})

test_that("Chaining function calls with pipe operator", {
  spec <- create_table(test_df) |>
    add_title("Piped Table") |>
    add_style(id = "bold_style", s_font(bold = TRUE)) |>
    define_cols(id, label = "ID", labelStyleRef = "bold_style")
  
  expect_equal(spec$document$docType, "Table")
  expect_true(length(spec$titles) > 0)
  expect_true("bold_style" %in% names(spec$attribs$styles))
})

