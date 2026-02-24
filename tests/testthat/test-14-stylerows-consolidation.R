# Test styleRows consolidation during create_report phase

test_that("combined styles are consolidated into single hash", {
  df <- data.frame(
    visit = c("Visit 1", "Visit 2", "Visit 3"),
    Parameter = c("Pulse", "Temp", "Pulse"),
    value = c(72, 98.6, 75)
  )
  
  spec <- create_table(df) %>%
    add_style("bold_font", s_font(bold = TRUE)) %>%
    add_style("blue_color", s_font(color = "#0000FF")) %>%
    compute_cols(
      Parameter == "Pulse",
      c_style(1:2, f_combine("bold_font", "blue_color"))
    )
  
  # Create report with consolidation
  report <- create_report(spec)
  spec_result <- report[[1]]
  
  # Consolidated hash should be created in attribs$styles
  all_style_names <- names(spec_result$attribs$styles)
  hash_styles <- all_style_names[grepl("^style_", all_style_names)]
  
  expect_true(length(hash_styles) >= 1)
  
  # The hash should follow pattern
  consolidated_hash <- hash_styles[1]
  expect_match(consolidated_hash, "^style_[a-f0-9]{16}$")
  
  # The consolidated style should be a list
  consolidated_style <- spec_result$attribs$styles[[consolidated_hash]]
  expect_true(is.list(consolidated_style))
})

test_that("style references replaced with consolidated hash in JSON", {
  df <- data.frame(
    Parameter = c("Pulse", "Temp", "Pulse"),
    value = c(72, 98.6, 75)
  )
  
  spec <- create_table(df) %>%
    add_style("bold", s_font(bold = TRUE)) %>%
    add_style("italic", s_font(italic = TRUE)) %>%
    compute_cols(
      Parameter == "Pulse",
      c_style(1, f_combine("bold", "italic"))
    )
  
  # Create report to consolidate
  report <- create_report(spec)
  spec_result <- report[[1]]
  
  # styleRows should be character vector of JSON strings
  expect_true(is.character(spec_result$styleRows))
  
  # Find the row with the combined style (row 1 or row 3)
  row1_json <- spec_result$styleRows[1]
  row3_json <- spec_result$styleRows[3]
  
  # Parse the JSON to verify structure
  parsed_row1 <- jsonlite::fromJSON(row1_json, simplifyDataFrame = FALSE)
  parsed_row3 <- jsonlite::fromJSON(row3_json, simplifyDataFrame = FALSE)
  
  # One of these should have the consolidated hash
  style_ref_1 <- if (!is.null(parsed_row1$style)) parsed_row1$style[[1]]$styleRef else NULL
  style_ref_3 <- if (!is.null(parsed_row3$style)) parsed_row3$style[[1]]$styleRef else NULL
  
  # At least one should have a hash reference
  hash_found <- FALSE
  hash_value <- NULL
  
  if (!is.null(style_ref_1) && is.character(style_ref_1) && length(style_ref_1) == 1) {
    if (grepl("^style_", style_ref_1)) {
      hash_found <- TRUE
      hash_value <- style_ref_1
    }
  }
  
  if (!hash_found && !is.null(style_ref_3) && is.character(style_ref_3) && length(style_ref_3) == 1) {
    if (grepl("^style_", style_ref_3)) {
      hash_found <- TRUE
      hash_value <- style_ref_3
    }
  }
  
  expect_true(hash_found)
  expect_match(hash_value, "^style_[a-f0-9]{16}$")
})

test_that("different style combinations get different hashes", {
  df <- data.frame(
    ParamA = c("X", "Y", "X"),
    ParamB = c("A", "A", "B"),
    value = c(1, 2, 3)
  )
  
  spec <- create_table(df) %>%
    add_style("bold", s_font(bold = TRUE)) %>%
    add_style("italic", s_font(italic = TRUE)) %>%
    add_style("red", s_font(color = "red")) %>%
    compute_cols(
      ParamA == "X",
      c_style(1, f_combine("bold", "italic"))
    ) %>%
    compute_cols(
      ParamB == "B",
      c_style(2, f_combine("bold", "red"))
    )
  
  # Create report - should create 2 different consolidated hashes
  report <- create_report(spec)
  spec_result <- report[[1]]
  
  hash_styles <- names(spec_result$attribs$styles)[grepl("^style_", names(spec_result$attribs$styles))]
  
  expect_true(length(hash_styles) >= 2)
  
  # All hashes should be unique
  expect_equal(length(hash_styles), length(unique(hash_styles)))
})
