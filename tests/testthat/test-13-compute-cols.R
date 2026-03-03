# Test compute_cols with styleRows
# ACTUAL BEHAVIOR:
# - After create_table(): spec$styleRows is empty list()
# - After compute_cols(): spec$styleRows is still empty list() (just stores instructions)
# - After create_report(): spec$styleRows becomes character vector of JSON strings

test_that("compute_cols stores compute instructions, styleRows populated at create_report", {
  df <- data.frame(
    visit = c("Visit 1", "Visit 2", "Visit 3"),
    Parameter = c("Pulse", "Temp", "Pulse"),
    value = c(72, 98.6, 75)
  )
  
  spec <- create_table(df) %>%
    add_style("bold_style", s_font(bold = TRUE)) %>%
    compute_cols(
      Parameter == "Pulse",
      c_style(1:2, "bold_style")
    )
  
  # After compute_cols: spec$.metadata$compute_cols contains instructions
  expect_false(is.null(spec$.metadata$compute_cols))
  expect_length(spec$.metadata$compute_cols, 1L)
  
  # spec$styleRows is still empty list (not yet processed)
  expect_true(is.list(spec$styleRows))
  expect_length(spec$styleRows, 0L)
  
  # Now create the report - this evaluates conditions and creates styleRows JSON
  report <- create_report(spec)
  spec_result <- report[[1]]
  
  # After create_report: styleRows is character vector of JSON strings
  expect_true(is.character(spec_result$styleRows))
  expect_length(spec_result$styleRows, 3L)
  
  # Verify structure: matching rows have JSON, non-matching rows are '{}'
  row1_json <- spec_result$styleRows[1]  # Matches (Parameter == "Pulse")
  row2_json <- spec_result$styleRows[2]  # Doesn't match (Parameter == "Temp")
  row3_json <- spec_result$styleRows[3]  # Matches (Parameter == "Pulse")
  
  # Non-matching row should be empty JSON
  expect_equal(row2_json, "{}")
  
  # Matching rows should have content
  expect_true(nzchar(row1_json))
  expect_true(nzchar(row3_json))
  
  # Parse first row to verify structure
  parsed_row1 <- jsonlite::fromJSON(row1_json, simplifyDataFrame = FALSE)
  expect_true(is.list(parsed_row1))
  expect_true("style" %in% names(parsed_row1))
  
  # Verify action object structure
  action <- parsed_row1$style[[1]]
  expect_equal(names(action), c("cols", "styleRef"))
  expect_equal(action$cols, c("visit", "Parameter"))
  expect_equal(action$styleRef, "bold_style")
})

test_that("compute_cols with f_combine creates combined style references", {
  df <- data.frame(
    visit = c("Visit 1", "Visit 2", "Visit 3"),
    Parameter = c("Pulse", "Temp", "Pulse"),
    value = c(72, 98.6, 75)
  )
  
  spec <- create_table(df) %>%
    add_style("bold", s_font(bold = TRUE)) %>%
    add_style("blue", s_font(color = "#0000FF")) %>%
    compute_cols(
      Parameter == "Pulse",
      c_style(1:2, f_combine("bold", "blue"))
    )
  
  # Create report to evaluate conditions
  report <- create_report(spec)
  spec_result <- report[[1]]
  
  # Parse first row which should have combined style
  row1_json <- spec_result$styleRows[1]
  parsed_row1 <- jsonlite::fromJSON(row1_json, simplifyDataFrame = FALSE)
  
  expect_true(is.list(parsed_row1))
  action <- parsed_row1$style[[1]]
  style_ref <- action$styleRef
  
  # Combined style becomes hash after consolidation
  expect_true(is.character(style_ref))
  expect_true(grepl("^style_", style_ref) || length(style_ref) == 2L)
})

test_that("c_merge action stored correctly with styleRef field", {
  df <- data.frame(
    col1 = c("A", "B", "C"),
    col2 = c("X", "Y", "Z"),
    col3 = c(1, 2, 3)
  )
  
  spec <- create_table(df) %>%
    add_style("merge_style", s_font(bold = TRUE)) %>%
    compute_cols(
      col1 == "A",
      c_merge(c(col1, col2), "merge_style")
    )
  
  # Create report to build styleRows
  report <- create_report(spec)
  spec_result <- report[[1]]
  
  # First row should have merge action (col1 == "A")
  row1_json <- spec_result$styleRows[1]
  parsed_row1 <- jsonlite::fromJSON(row1_json, simplifyDataFrame = FALSE)
  
  expect_true(is.list(parsed_row1))
  expect_true("merge" %in% names(parsed_row1))
  
  merge_action <- parsed_row1$merge[[1]]
  expect_equal(names(merge_action), c("cols", "styleRef"))
  expect_equal(merge_action$cols, c("col1", "col2"))
  expect_equal(merge_action$styleRef, "merge_style")
})

test_that("c_addrow action stored correctly with styleRef field", {
  df <- data.frame(
    col1 = c("A", "B"),
    col2 = c(1, 2)
  )
  
  spec <- create_table(df) %>%
    add_style("add_style", s_font(bold = TRUE)) %>%
    compute_cols(
      col1 == "A",
      c_addrow(pos = "above", value_from = col1, "add_style")
    )
  
  # Create report to build styleRows
  report <- create_report(spec)
  spec_result <- report[[1]]
  
  # First row should have add_row action (col1 == "A")
  row1_json <- spec_result$styleRows[1]
  parsed_row1 <- jsonlite::fromJSON(row1_json, simplifyDataFrame = FALSE)
  
  expect_true(is.list(parsed_row1))
  expect_true("add_row" %in% names(parsed_row1))
  
  addrow_action <- parsed_row1$add_row[[1]]
  expected_fields <- c("pos", "value_from", "styleRef")
  expect_equal(sort(names(addrow_action)), sort(expected_fields))
  expect_equal(addrow_action$pos, "above")
  expect_equal(addrow_action$value_from, "col1")
  expect_equal(addrow_action$styleRef, "add_style")
})

test_that("multiple actions in same row are aggregated", {
  df <- data.frame(
    col1 = c("A", "B", "C"),
    col2 = c("X", "Y", "Z"),
    col3 = c(1, 2, 3)
  )
  
  spec <- create_table(df) %>%
    add_style("style1", s_font(bold = TRUE)) %>%
    add_style("style2", s_font(italic = TRUE)) %>%
    compute_cols(
      col1 == "A",
      c_style(col1, "style1"),
      c_merge(c(col2, col3), "style2")
    )
  
  # Create report to build styleRows
  report <- create_report(spec)
  spec_result <- report[[1]]
  
  # First row should have both style and merge actions
  row1_json <- spec_result$styleRows[1]
  parsed_row1 <- jsonlite::fromJSON(row1_json, simplifyDataFrame = FALSE)
  
  # Both style and merge actions should be present
  expect_true("style" %in% names(parsed_row1))
  expect_true("merge" %in% names(parsed_row1))
  
  expect_length(parsed_row1$style, 1L)
  expect_length(parsed_row1$merge, 1L)
  
  # Verify each action structure
  style_action <- parsed_row1$style[[1]]
  expect_equal(style_action$cols, "col1")
  expect_equal(style_action$styleRef, "style1")
  
  merge_action <- parsed_row1$merge[[1]]
  expect_equal(merge_action$cols, c("col2", "col3"))
  expect_equal(merge_action$styleRef, "style2")
})

test_that("multiple compute_cols blocks accumulate actions", {
  df <- data.frame(
    col1 = c("A", "B", "C"),
    col2 = c("X", "Y", "Z"),
    col3 = c(1, 2, 3)
  )
  
  spec <- create_table(df) %>%
    add_style("s1", s_font(bold = TRUE)) %>%
    add_style("s2", s_font(italic = TRUE)) %>%
    add_style("s3", s_font(color = "red")) %>%
    compute_cols(col1 == "A", c_style(col1, "s1")) %>%
    compute_cols(col1 == "A", c_style(col2, "s2")) %>%
    compute_cols(col3 > 1, c_merge(c(col2, col3), "s3"))
  
  # Create report to build styleRows
  report <- create_report(spec)
  spec_result <- report[[1]]
  
  # First row matches both col1=="A" conditions and col3>1
  row1_json <- spec_result$styleRows[1]
  parsed_row1 <- jsonlite::fromJSON(row1_json, simplifyDataFrame = FALSE)
  
  # Should have both style actions from the two col1=="A" compute_cols
  expect_length(parsed_row1$style, 2L)
  expect_true("style" %in% names(parsed_row1))
  
  
  # Second row only matches col3>1
  row2_json <- spec_result$styleRows[3]
  parsed_row2 <- jsonlite::fromJSON(row2_json, simplifyDataFrame = FALSE)
  expect_false("style" %in% names(parsed_row2))
  expect_true("merge" %in% names(parsed_row2))
})

test_that("create_report consolidates combined styles in attribs", {
  df <- data.frame(
    Parameter = c("Pulse", "Temp", "Pulse"),
    value = c(72, 98.6, 75)
  )
  
  spec <- create_table(df) %>%
    add_style("bold_style", s_font(bold = TRUE)) %>%
    add_style("blue_style", s_font(color = "#0000FF")) %>%
    compute_cols(
      Parameter == "Pulse",
      c_style(1:2, f_combine("bold_style", "blue_style"))
    )
  
  # Create report with consolidation
  report <- create_report(spec)
  spec_result <- report[[1]]
  
  # After consolidation: consolidated hash should be created in attribs$styles
  hash_styles <- names(spec_result$attribs$styles)[grepl("^style_", names(spec_result$attribs$styles))]
  expect_true(length(hash_styles) > 0L)
  
  # The consolidated hash should follow pattern
  consolidated_hash <- hash_styles[1]
  expect_match(consolidated_hash, "^style_[a-f0-9]{16}$")
  
  # The consolidated style should be a list
  consolidated_style <- spec_result$attribs$styles[[consolidated_hash]]
  expect_true(is.list(consolidated_style))
})

test_that("non-matching rows result in empty JSON in styleRows", {
  df <- data.frame(
    Parameter = c("Pulse", "Temp", "BP"),
    value = c(72, 98.6, 140)
  )
  
  spec <- create_table(df) %>%
    add_style("bold", s_font(bold = TRUE)) %>%
    compute_cols(
      Parameter == "Pulse",
      c_style(1, "bold")
    )
  
  report <- create_report(spec)
  spec_result <- report[[1]]
  
  # styleRows should be character vector of JSON strings
  expect_true(is.character(spec_result$styleRows))
  expect_length(spec_result$styleRows, 3L)
  
  # Row 1 (Pulse) should match and have content
  row1_json <- spec_result$styleRows[1]
  expect_true(nzchar(row1_json))
  expect_false(row1_json=="{}")
  expect_false(is.null(row1_json))
  
  # Row 2 (Temp) should not match and be empty JSON
  row2_json <- spec_result$styleRows[2]
  expect_equal(row2_json, "{}")
  
  # Row 3 (Pulse) should match and have content
  row3_json <- spec_result$styleRows[3]
  expect_true(nzchar(row3_json))
  expect_true(row3_json=="{}")
})

test_that("serialize_spec validates and returns fixed spec structure", {
  df <- data.frame(
    Parameter = c("Pulse", "Temp"),
    value = c(72, 98.6)
  )
  
  spec <- create_table(df) %>%
    add_style("bold_style", s_font(bold = TRUE)) %>%
    compute_cols(
      Parameter == "Pulse",
      c_style(1, "bold_style")
    )
  
  report <- create_report(spec)
  
  # Serialize the report
  json_result <- serialize_spec(report)
  
  # serialize_spec returns list(spec=..., fixed=...)
  expect_true(is.list(json_result))
  expect_true("fixed" %in% names(json_result))
  expect_true("spec" %in% names(json_result))
  
  fixed <- json_result$fixed
  
  # Fixed should be a list
  expect_true(is.list(fixed))
  expect_false(fixed[[1]]$styleRows[[1]]=='{}')
})
