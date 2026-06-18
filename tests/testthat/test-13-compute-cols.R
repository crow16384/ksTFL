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
  expect_equal(sort(names(action)), sort(c("cols", "styleRef", "seq")))
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
  expect_equal(sort(names(merge_action)), sort(c("cols", "styleRef", "seq")))
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
  expected_fields <- c("pos", "value_from", "styleRef", "seq")
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

# ============================================================================
# Tests for stackable actions: c_glue() + c_addrow() interaction
# ============================================================================

test_that("c_glue then c_addrow uses glued values (same column)", {
  skip_on_cran()
  
  df <- data.frame(
    PARAM = c("ALT", "AST", "ALT"),
    VISIT = c("Week 2", "Week 2", "Week 4"),
    VALUE = c(25, 30, 28),
    stringsAsFactors = FALSE
  )
  
  spec <- create_table(df) %>%
    define_cols(c(PARAM, VISIT, VALUE)) %>%
    compute_cols(
      PARAM == "ALT",
      c_glue(PARAM, "after", glue_col = VISIT, separator = ": "),
      c_addrow("above", value_from = PARAM)
    )
  
  # Create report to finalize actions
  report <- create_report(spec)
  spec_result <- report[[1]]
  
  # Verify styleRows exists and has entries for all rows
  expect_true(!is.null(spec_result$styleRows))
  expect_length(spec_result$styleRows, 3)  # 3 data rows
  
  # Check first ALT row (row 1: PARAM="ALT", VISIT="Week 2")
  row1_json <- spec_result$styleRows[[1]]
  expect_type(row1_json, "character")
  
  row1_actions <- jsonlite::fromJSON(row1_json, simplifyVector = FALSE)
  
  # Verify both glue and add_row actions exist
  expect_true("glue" %in% names(row1_actions))
  expect_true("add_row" %in% names(row1_actions))
  
  # Verify glue action details
  glue_action <- row1_actions$glue[[1]]
  expect_equal(glue_action$seq, 0)  # First action
  expect_equal(glue_action$cols, list("PARAM"))
  expect_equal(glue_action$position, "after")
  expect_equal(glue_action$glue_col, "VISIT")
  expect_equal(glue_action$separator, ": ")
  
  # Verify add_row action details
  addrow_action <- row1_actions$add_row[[1]]
  expect_equal(addrow_action$seq, 1)  # Second action
  expect_equal(addrow_action$pos, "above")
  expect_equal(addrow_action$value_from, "PARAM")
  
  # Verify sequence: glue (seq=0) comes before add_row (seq=1)
  expect_true(glue_action$seq < addrow_action$seq)
})

test_that("multiple c_glue accumulate before c_addrow", {
  skip_on_cran()
  
  df <- data.frame(
    LABEL = c("A", "B", "C"),
    UNIT = c("mg", "kg", "L"),
    NOTE = c("*", "†", "‡"),
    stringsAsFactors = FALSE
  )
  
  spec <- create_table(df) %>%
    define_cols(c(LABEL, UNIT, NOTE)) %>%
    compute_cols(
      LABEL == "B",
      c_glue(LABEL, "after", glue_col = UNIT, separator = " "),
      c_glue(LABEL, "before", glue_col = NOTE, separator = ""),
      c_addrow("above", value_from = LABEL)
    )
  
  report <- create_report(spec)
  spec_result <- report[[1]]
  
  # Check row 2 (LABEL == "B")
  row2_json <- spec_result$styleRows[[2]]
  row2_actions <- jsonlite::fromJSON(row2_json, simplifyVector = FALSE)
  
  # Verify two glue actions and one add_row action
  expect_true("glue" %in% names(row2_actions))
  expect_true("add_row" %in% names(row2_actions))
  expect_length(row2_actions$glue, 2)  # Two glue operations
  
  # First glue: LABEL + UNIT (after)
  glue1 <- row2_actions$glue[[1]]
  expect_equal(glue1$seq, 0)
  expect_equal(glue1$cols, list("LABEL"))
  expect_equal(glue1$position, "after")
  expect_equal(glue1$glue_col, "UNIT")
  
  # Second glue: NOTE + LABEL (before)
  glue2 <- row2_actions$glue[[2]]
  expect_equal(glue2$seq, 1)
  expect_equal(glue2$cols, list("LABEL"))
  expect_equal(glue2$position, "before")
  expect_equal(glue2$glue_col, "NOTE")
  
  # Add_row comes after both glues
  addrow <- row2_actions$add_row[[1]]
  expect_equal(addrow$seq, 2)
  expect_true(addrow$seq > glue1$seq && addrow$seq > glue2$seq)
})

test_that("c_glue on column A, c_addrow from column B (independent)", {
  skip_on_cran()
  
  df <- data.frame(
    COL_A = c("X", "Y", "Z"),
    COL_B = c("Alpha", "Beta", "Gamma"),
    SUFFIX = c("_1", "_2", "_3"),
    stringsAsFactors = FALSE
  )
  
  spec <- create_table(df) %>%
    define_cols(c(COL_A, COL_B, SUFFIX)) %>%
    compute_cols(
      COL_A == "Y",
      c_glue(COL_A, "after", glue_col = SUFFIX, separator = ""),
      c_addrow("above", value_from = COL_B)  # Different column
    )
  
  report <- create_report(spec)
  spec_result <- report[[1]]
  
  # Check row 2 (COL_A == "Y")
  row2_json <- spec_result$styleRows[[2]]
  row2_actions <- jsonlite::fromJSON(row2_json, simplifyVector = FALSE)
  
  # Verify glue on COL_A and add_row from COL_B
  expect_true("glue" %in% names(row2_actions))
  expect_true("add_row" %in% names(row2_actions))
  
  # Glue operates on COL_A
  glue_action <- row2_actions$glue[[1]]
  expect_equal(glue_action$seq, 0)
  expect_equal(glue_action$cols, list("COL_A"))
  expect_equal(glue_action$glue_col, "SUFFIX")  # Gluing from SUFFIX column
  expect_equal(glue_action$separator, "")
  expect_equal(glue_action$position, "after")
  
  # Add_row uses COL_B (independent column)
  addrow_action <- row2_actions$add_row[[1]]
  expect_equal(addrow_action$seq, 1)
  expect_equal(addrow_action$value_from, "COL_B")
  expect_equal(addrow_action$pos, "above")
})

test_that("c_glue with hidden column source works with c_addrow", {
  skip_on_cran()
  
  df <- data.frame(
    PARAM = c("ALT", "AST", "ALT"),
    VISIT = c("Week 2", "Week 2", "Week 4"),
    HIDDEN_UNIT = c("U/L", "U/L", "U/L"),
    VALUE = c(25, 30, 28),
    stringsAsFactors = FALSE
  )
  
  spec <- create_table(df) %>%
    define_cols(c(PARAM, VISIT, VALUE)) %>%
    define_cols(HIDDEN_UNIT, isVisible = FALSE) %>%
    compute_cols(
      PARAM == "ALT",
      c_glue(PARAM, "after", glue_col = HIDDEN_UNIT, separator = " "),
      c_addrow("above", value_from = PARAM)
    )
  
  report <- create_report(spec)
  spec_result <- report[[1]]
  
  # Check first ALT row
  row1_json <- spec_result$styleRows[[1]]
  row1_actions <- jsonlite::fromJSON(row1_json, simplifyVector = FALSE)
  
  # Verify glue uses hidden UNIT column
  expect_true("glue" %in% names(row1_actions))
  expect_true("add_row" %in% names(row1_actions))
  
  glue_action <- row1_actions$glue[[1]]
  expect_equal(glue_action$seq, 0)
  expect_equal(glue_action$cols, list("PARAM"))
  expect_equal(glue_action$glue_col, "HIDDEN_UNIT")  # Hidden column
  expect_equal(glue_action$position, "after")
  expect_equal(glue_action$separator, " ")
  
  addrow_action <- row1_actions$add_row[[1]]
  expect_equal(addrow_action$seq, 1)
  expect_equal(addrow_action$value_from, "PARAM")
})

test_that("c_clear + c_glue + c_addrow works as replacement", {
  skip_on_cran()
  
  df <- data.frame(
    DISPLAY = c("Old A", "Old B", "Old C"),
    REPLACEMENT = c("New A", "New B", "New C"),
    stringsAsFactors = FALSE
  )
  
  spec <- create_table(df) %>%
    define_cols(c(DISPLAY, REPLACEMENT)) %>%
    compute_cols(
      DISPLAY == "Old B",
      c_clear(DISPLAY),
      c_glue(DISPLAY, "after", glue_col = REPLACEMENT),
      c_addrow("above", value_from = DISPLAY)
    )
  
  report <- create_report(spec)
  spec_result <- report[[1]]
  
  # Check row 2 (DISPLAY == "Old B")
  row2_json <- spec_result$styleRows[[2]]
  row2_actions <- jsonlite::fromJSON(row2_json, simplifyVector = FALSE)
  
  # Verify clear, glue, and add_row actions in sequence
  expect_true("clear" %in% names(row2_actions))
  expect_true("glue" %in% names(row2_actions))
  expect_true("add_row" %in% names(row2_actions))
  
  # Clear DISPLAY (seq=0)
  clear_action <- row2_actions$clear[[1]]
  expect_equal(clear_action$seq, 0)
  expect_equal(clear_action$cols, list("DISPLAY"))
  
  # Glue REPLACEMENT column value to cleared DISPLAY (seq=1)
  glue_action <- row2_actions$glue[[1]]
  expect_equal(glue_action$seq, 1)
  expect_equal(glue_action$cols, list("DISPLAY"))
  expect_equal(glue_action$glue_col, "REPLACEMENT")
  expect_equal(glue_action$position, "after")
  
  # Add_row from modified DISPLAY (seq=2)
  addrow_action <- row2_actions$add_row[[1]]
  expect_equal(addrow_action$seq, 2)
  expect_equal(addrow_action$value_from, "DISPLAY")
})

test_that("c_addrow below position also uses glued values", {
  skip_on_cran()
  
  df <- data.frame(
    PARAM = c("Total", "Subtotal"),
    SUFFIX = c(" (Summary)", " (Interim)"),
    VALUE = c(100, 50),
    stringsAsFactors = FALSE
  )
  
  spec <- create_table(df) %>%
    define_cols(c(PARAM, VALUE)) %>%
    define_cols(SUFFIX, isVisible = FALSE) %>%
    compute_cols(
      PARAM == "Total",
      c_glue(PARAM, "after", glue_col = SUFFIX),
      c_addrow("below", value_from = PARAM)
    )
  
  report <- create_report(spec)
  spec_result <- report[[1]]
  
  # Check first row (PARAM == "Total")
  row1_json <- spec_result$styleRows[[1]]
  row1_actions <- jsonlite::fromJSON(row1_json, simplifyVector = FALSE)
  
  # Verify glue and add_row "below" actions
  expect_true("glue" %in% names(row1_actions))
  expect_true("add_row" %in% names(row1_actions))
  
  # Glue (seq=0)
  glue_action <- row1_actions$glue[[1]]
  expect_equal(glue_action$seq, 0)
  expect_equal(glue_action$cols, list("PARAM"))
  expect_equal(glue_action$glue_col, "SUFFIX")  # Gluing from SUFFIX column
  expect_equal(glue_action$position, "after")
  
  # Add_row below (seq=1)
  addrow_action <- row1_actions$add_row[[1]]
  expect_equal(addrow_action$seq, 1)
  expect_equal(addrow_action$pos, "below")  # Below instead of above
  expect_equal(addrow_action$value_from, "PARAM")
})
