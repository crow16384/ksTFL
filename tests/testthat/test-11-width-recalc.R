# ============================================================================
# Test: Column Width Recalculation
# ============================================================================

test_that(".parse_colwidth() extracts unit and value from percentage", {
  result <- .parse_colwidth("25.3%")
  expect_equal(result$value, 25.3)
  expect_equal(result$unit, "%")
})

test_that(".parse_colwidth() extracts unit and value from cm", {
  result <- .parse_colwidth("3.5cm")
  expect_equal(result$value, 3.5)
  expect_equal(result$unit, "cm")
})

test_that(".parse_colwidth() extracts unit and value from in", {
  result <- .parse_colwidth("1.5in")
  expect_equal(result$value, 1.5)
  expect_equal(result$unit, "in")
})

test_that(".parse_colwidth() returns NULL for invalid input", {
  expect_null(.parse_colwidth("invalid"))
  expect_null(.parse_colwidth(""))
  expect_null(.parse_colwidth("25"))
})

test_that("metadata is created during table initialization", {
  spec <- create_table(test_df_simple)
  
  # Check metadata structure exists and is a list
  expect_is(spec$.metadata$colWidths, "list")
  expect_equal(length(spec$.metadata$colWidths), ncol(test_df_simple))
  
  # Check each column has metadata
  for (col_name in names(spec$columns)) {
    meta <- spec$.metadata$colWidths[[col_name]]
    
    # Check required fields exist with correct types
    expect_is(meta$unit, "character")
    expect_is(meta$value, "numeric")
    expect_is(meta$locked, "logical")
    expect_is(meta$auto_weight, "numeric")
    
    # Check initial state
    expect_equal(meta$locked, FALSE)
    expect_equal(meta$unit, "%")
    expect_true(meta$value > 0)
    expect_equal(meta$auto_weight, meta$value)
  }
})

test_that("metadata shows auto_weight preserved after initialization", {
  spec <- create_table(test_df_simple)
  
  # Collect all auto_weights
  auto_weights <- vapply(spec$.metadata$colWidths, function(m) m$auto_weight, numeric(1))
  
  # Should sum to 100% (allowing for rounding to 1 decimal place)
  total <- sum(auto_weights)
  expect_equal(total, 100, tolerance = 0.15)
})

test_that("define_cols with colWidth marks column as locked", {
  # Disable autoColWidth to prevent normalization during test
  tfl_set_options(autoColWidth = FALSE)
  
  spec <- create_table(test_df_simple)
  
  # Set width on first column
  spec <- define_cols(spec, id, colWidth = "15%")
  
  # Check metadata is updated
  expect_equal(spec$.metadata$colWidths$id$locked, TRUE)
  expect_equal(spec$.metadata$colWidths$id$value, 15)
  expect_equal(spec$.metadata$colWidths$id$unit, "%")
  
  # Remaining columns should still be unlocked
  expect_equal(spec$.metadata$colWidths$value$locked, FALSE)
  expect_equal(spec$.metadata$colWidths$ratio$locked, FALSE)
  
  tfl_set_options(autoColWidth = TRUE)
})

test_that("define_cols with fixed unit (cm) marks column as locked with unit", {
  tfl_set_options(autoColWidth = FALSE)
  
  spec <- create_table(test_df_simple)
  
  spec <- define_cols(spec, id, colWidth = "2.5cm")
  
  # Check that fixed unit is recorded
  expect_equal(spec$.metadata$colWidths$id$locked, TRUE)
  expect_equal(spec$.metadata$colWidths$id$unit, "cm")
  expect_equal(spec$.metadata$colWidths$id$value, 2.5)
  
  tfl_set_options(autoColWidth = TRUE)
})

test_that("define_cols triggers automatic recalculation when autoColWidth=TRUE", {
  # Ensure autoColWidth is TRUE
  tfl_set_options(autoColWidth = TRUE)
  
  spec <- create_table(test_df_simple)
  
  # Set width on first column and observe auto-recalculation
  spec <- define_cols(spec, id, colWidth = "25%")
  
  # Locked column (id) should be EXACTLY 25%
  id_width <- as.numeric(sub("%", "", spec$columns$id$format$colWidth))
  expect_equal(id_width, 25)
  
  # Other columns should be recalculated to fill remaining 75%
  value_width <- as.numeric(sub("%", "", spec$columns$value$format$colWidth))
  ratio_width <- as.numeric(sub("%", "", spec$columns$ratio$format$colWidth))
  
  expect_equal(value_width + ratio_width, 75)
  
  # Total should be 100%
  col_widths_str <- vapply(spec$columns, function(col) col$format$colWidth, character(1))
  widths_numeric <- as.numeric(sub("%", "", col_widths_str))
  expect_equal(sum(widths_numeric), 100)
})

test_that("define_cols does NOT trigger recalculation when autoColWidth=FALSE", {
  # Ensure autoColWidth is FALSE
  tfl_set_options(autoColWidth = FALSE)
  
  spec <- create_table(test_df_simple)
  
  # Store original widths for comparison
  old_widths <- vapply(spec$columns, function(col) col$format$colWidth, character(1))
  
  # Set width on first column
  spec <- define_cols(spec, id, colWidth = "20%")
  
  # Widths of OTHER columns should NOT have changed
  # (because autoColWidth=FALSE prevents recalculation)
  new_widths <- vapply(spec$columns, function(col) col$format$colWidth, character(1))
  
  expect_equal(unname(new_widths["value"]), unname(old_widths["value"]))
  expect_equal(unname(new_widths["ratio"]), unname(old_widths["ratio"]))
  
  # Only id should have been updated
  expect_equal(unname(new_widths["id"]), "20%")
  
  tfl_set_options(autoColWidth = TRUE)
})

test_that("multiple define_cols calls maintain correct state", {
  tfl_set_options(autoColWidth = TRUE)
  
  spec <- create_table(test_df_simple)
  
  # First call: set one column width
  spec <- define_cols(spec, id, colWidth = "20%")
  
  # Second call: set another column width
  spec <- define_cols(spec, value, colWidth = "15%")
  
  # Both should be locked
  expect_equal(spec$.metadata$colWidths$id$locked, TRUE)
  expect_equal(spec$.metadata$colWidths$value$locked, TRUE)
  
  # Remaining columns should be relative
  expect_equal(spec$.metadata$colWidths$ratio$locked, FALSE)
  
  # Locked columns should stay EXACTLY as specified
  id_width <- as.numeric(sub("%", "", spec$columns$id$format$colWidth))
  value_width <- as.numeric(sub("%", "", spec$columns$value$format$colWidth))
  
  expect_equal(id_width, 20)
  expect_equal(value_width, 15)
  
  # Unlocked columns (ratio) should fill the remaining 65%
  ratio_width <- as.numeric(sub("%", "", spec$columns$ratio$format$colWidth))
  expect_equal(ratio_width, 65)
  
  # Total should be exactly 100%
  col_widths_str <- vapply(spec$columns, function(col) col$format$colWidth, character(1))
  widths_numeric <- as.numeric(sub("%", "", col_widths_str))
  expect_equal(sum(widths_numeric), 100)
})

test_that("no recalculation occurs if no relative columns exist", {
  spec <- create_table(test_df_simple)
  
  # Set all columns to fixed units
  spec <- define_cols(spec, c(id, value, ratio), 
                      colWidth = c("2cm", "3cm", "4cm"))
  
  # Store widths
  old_widths <- vapply(spec$columns, function(col) col$format$colWidth, character(1))
  
  # Recalculate
  spec <- .recalculate_col_widths(spec)
  
  # Widths should not change
  new_widths <- vapply(spec$columns, function(col) col$format$colWidth, character(1))
  expect_equal(old_widths, new_widths)
})

test_that("Edge case: all columns locked at same percentage", {
  spec <- create_table(test_df_simple)
  
  # Lock all columns at equal percentage
  spec <- define_cols(spec, c(id, value, ratio), colWidth = "33.333%")
  spec <- .recalculate_col_widths(spec)
  
  # All should be locked
  for (col_name in c("id", "value", "ratio")) {
    expect_equal(spec$.metadata$colWidths[[col_name]]$locked, TRUE)
  }
  
  # Total must be 100% (exact)
  col_widths_str <- vapply(spec$columns, function(col) col$format$colWidth, character(1))
  widths_numeric <- as.numeric(sub("%", "", col_widths_str))
  expect_equal(sum(widths_numeric), 100, tolerance = 0.001)
})

test_that("Fixed column widths remain exactly unchanged after recalculation", {
  tfl_set_options(autoColWidth = TRUE)
  
  spec <- create_table(test_df_simple)
  
  # Set two different fixed unit widths
  spec <- define_cols(spec, id, colWidth = "2.5cm")
  initial_id <- spec$columns$id$format$colWidth
  
  spec <- define_cols(spec, value, colWidth = "1in")
  initial_value <- spec$columns$value$format$colWidth
  
  # Recalculate multiple times
  spec <- .recalculate_col_widths(spec)
  spec <- .recalculate_col_widths(spec)
  
  # Fixed columns should not change
  expect_equal(spec$columns$id$format$colWidth, initial_id)
  expect_equal(spec$columns$value$format$colWidth, initial_value)
  
  tfl_set_options(autoColWidth = TRUE)
})

test_that("Percentage values are rounded to exactly 1 decimal place", {
  tfl_set_options(autoColWidth = TRUE)
  
  spec <- create_table(test_df_simple)
  spec <- define_cols(spec, id, colWidth = "33.333%")
  spec <- .recalculate_col_widths(spec)
  
  # Check only AUTO-CALCULATED (unlocked) columns have 1 decimal place
  # (user-set widths like "33.333%" are preserved as-is)
  for (col_name in names(spec$columns)) {
    meta <- spec$.metadata$colWidths[[col_name]]
    if (!meta$locked && meta$unit == "%") {  # Only check unlocked % columns
      width_str <- spec$columns[[col_name]]$format$colWidth
      # Extract the numeric part
      num_part <- sub("%", "", width_str)
      # Should have at most 1 decimal place
      if (grepl("\\.", num_part)) {
        decimal_part <- sub(".*\\.", "", num_part)
        # Should have 1 digit after decimal
        expect_equal(nchar(decimal_part), 1, 
                    label = paste("Column", col_name, "width", width_str, "should have 1 decimal place"))
      }
    }
  }
  
  tfl_set_options(autoColWidth = TRUE)
})

test_that("Metadata value updates match colWidth format strings", {
  tfl_set_options(autoColWidth = TRUE)
  
  spec <- create_table(test_df_simple)
  spec <- define_cols(spec, id, colWidth = "30%")
  spec <- .recalculate_col_widths(spec)
  
  # Check that metadata values match the format strings for % columns
  for (col_name in names(spec$columns)) {
    format_str <- spec$columns[[col_name]]$format$colWidth
    meta <- spec$.metadata$colWidths[[col_name]]
    
    if (meta$unit == "%") {
      # Extract numeric value from format string
      format_numeric <- as.numeric(sub("%", "", format_str))
      # Should match metadata value (within rounding tolerance)
      expect_equal(unname(format_numeric), unname(meta$value), tolerance = 0.01,
                   label = paste("Column", col_name))
    }
  }
})

test_that("auto_weights remain constant during recalculation", {
  spec <- create_table(test_df_simple)
  
  # Capture initial auto_weights
  initial_auto_weights <- vapply(spec$.metadata$colWidths, function(m) m$auto_weight, numeric(1))
  
  # Lock several columns at different widths
  spec <- define_cols(spec, id, colWidth = "20%")
  spec <- define_cols(spec, value, colWidth = "30%")
  
  # Recalculate multiple times
  spec <- .recalculate_col_widths(spec)
  spec <- .recalculate_col_widths(spec)
  
  # auto_weights should never change
  final_auto_weights <- vapply(spec$.metadata$colWidths, function(m) m$auto_weight, numeric(1))
  
  expect_equal(final_auto_weights, initial_auto_weights)
  
  tfl_set_options(autoColWidth = TRUE)
})

test_that("Reported Issue: locked% columns stay locked, not recalculated", {
  # This test reproduces the exact issue from the bug report:
  # When user set id=20%, it was being recalculated to 19.1%
  # When second define_cols() set value=15%, id changed to 19.8% (should stay 20%)
  
  tfl_set_options(autoColWidth = TRUE)
  
  spec <- create_table(test_df_simple)
  
  # STEP 1: User locks id at 20%
  spec <- define_cols(spec, id, colWidth = "20%")
  
  id_width_after_first <- as.numeric(sub("%", "", spec$columns$id$format$colWidth))
  
  # FIXED BEHAVIOR: id_width_after_first == 20.0 (not 19.1)
  expect_equal(id_width_after_first, 20)
  
  # STEP 2: User locks value at 15%
  spec <- define_cols(spec, value, colWidth = "15%")
  
  id_width_after_second <- as.numeric(sub("%", "", spec$columns$id$format$colWidth))
  value_width_after_second <- as.numeric(sub("%", "", spec$columns$value$format$colWidth))
  
  # FIXED BEHAVIOR: id stays 20% (not 19.8%), value is 15%
  expect_equal(id_width_after_second, 20)
  expect_equal(value_width_after_second, 15)
  
  # Verify: locked columns don't change between steps
  expect_equal(id_width_after_first, id_width_after_second)
  
  # Verify: unlocked column (ratio) fills the remaining space
  ratio_width <- as.numeric(sub("%", "", spec$columns$ratio$format$colWidth))
  expect_equal(ratio_width, 65)
  
  # Verify: total is exactly 100%
  col_widths_str <- vapply(spec$columns, function(col) col$format$colWidth, character(1))
  widths_numeric <- as.numeric(sub("%", "", col_widths_str))
  expect_equal(sum(widths_numeric), 100)
})
