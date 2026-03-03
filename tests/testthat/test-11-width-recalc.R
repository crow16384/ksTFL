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
test_that("define_cols() rejects 100% width when unlocked columns need space", {
  spec <- create_table(test_df_simple)  # 3 columns: id, value, ratio
  
  # Try to set one column to 100%
  # With 3 columns and minColWidth=0.5%, 2 unlocked columns need 1% total
  # So 100% is invalid
  expect_error(
    define_cols(spec, id, colWidth = "100%"),
    "Cannot set column"
  )
})

test_that("define_cols() rejects colWidth that exceeds maximum allowed", {
  spec <- create_table(test_df_simple)  # 3 columns: id, value, ratio
  print(spec)
  # Lock first column at 99% (leaves 1% for 2 unlocked @ 0.5% each)
  # This should fail because we can't fit 2 columns @ minimum 0.5%
  expect_error(
    define_cols(spec, id, colWidth = "99.5%"),
    "Cannot set column"
  )
})

test_that("define_cols() allows valid relative widths", {
  spec <- create_table(test_df_simple)  # 3 columns: id, value, ratio
  
  # Set id to 49% leaves 51% for 2 unlocked columns at 25.5% each
  # This should succeed
  expect_no_error(
    spec <- define_cols(spec, id, colWidth = "49%")
  )
  
  id_width <- as.numeric(sub("%", "", spec$columns$id$format$colWidth))
  expect_equal(id_width, 49)
})

test_that("define_cols() error message includes helpful details", {
  spec <- create_table(test_df_simple)  # 3 columns
  
  # Try to set to invalid width and capture error
  error <- tryCatch(
    define_cols(spec, id, colWidth = "100%"),
    error = function(e) e
  )
  
  # Check error message contains key information
  error_msg <- conditionMessage(error)
  expect_true(grepl("Cannot set column", error_msg))
  expect_true(grepl("insufficient space", error_msg))
})

test_that("minColWidth option can be customized", {
  # Set higher minimum
  old_min <- tfl_get_option("minColWidth")
  tfl_set_options(minColWidth = 2.0)
  
  on.exit(tfl_set_options(minColWidth = old_min))
  tfl_get_option('minColWidth')
  spec <- create_table(test_df_simple)  # 3 columns: id, value, ratio
  
  # With minColWidth = 2.0%, 2 unlocked need 4% total
  # So max for first column is 96%
  expect_error(
    define_cols(spec, id, colWidth = "98%"),
    "Cannot set column"
  )
  
  # But 96% should work
  expect_no_error(
    spec <- define_cols(spec, id, colWidth = "96%")
  )
})

test_that("define_cols() with fixed-unit width (cm) doesn't validate relative constraints", {
  # Fixed-unit columns (cm, in, mm) are not affected by relative percentage constraints
  spec <- create_table(test_df_simple)  # 3 columns
  
  # Set a column to a fixed width - should not trigger percentage validation
  expect_no_error(
    spec <- define_cols(spec, id, colWidth = "5cm")
  )
  
  # Verify metadata shows it's fixed unit
  expect_equal(spec$.metadata$colWidths$id$unit, "cm")
})

test_that("define_cols() rejects relative width below 0.5%", {
  spec <- create_table(test_df_simple)
  
  # Try to set relative width below minimum (0.5%)
  expect_error(
    define_cols(spec, id, colWidth = "0.3%"),
    "below minimum allowed"
  )
  
  expect_error(
    define_cols(spec, id, colWidth = "0%"),
    "below minimum allowed"
  )
  
  # 0.5% should work (is the minimum)
  expect_no_error(
    spec <- define_cols(spec, id, colWidth = "0.5%")
  )
})

test_that("define_cols() rejects fixed width below 0.2cm", {
  spec <- create_table(test_df_simple)
  
  # Try to set fixed width below minimum (0.2cm)
  expect_error(
    define_cols(spec, id, colWidth = "0.1cm"),
    "below minimum allowed"
  )
  
  expect_error(
    define_cols(spec, id, colWidth = "0cm"),
    "below minimum allowed"
  )
  
  # 0.2cm should work (is the minimum)
  expect_no_error(
    spec <- define_cols(spec, id, colWidth = "0.2cm")
  )
})

test_that("define_cols() accepts equivalent fixed widths (cm, in, mm conversions)", {
  spec <- create_table(test_df_simple)
  
  # These should all be approximately equivalent to 0.2cm and should pass
  # 0.2cm = 0.0787in ≈ 0.079in
  # 0.2cm = 2mm
  
  expect_no_error(spec <- define_cols(spec, id, colWidth = "0.2cm"))
  

  spec <- create_table(test_df_simple)
  expect_no_error(spec <- define_cols(spec, id, colWidth = "0.08in"))
  
  # Below minimum in equivalent units should fail
  expect_error(
    define_cols(spec, id, colWidth = "0.15cm"),  # 0.15cm < 0.2cm
    "below minimum allowed"
  )
})

test_that("minimum width error messages show helpful conversion info", {
  spec <- create_table(test_df_simple)
  
  # Capture error for fixed width
  error <- tryCatch(
    define_cols(spec, id, colWidth = "0.1cm"),
    error = function(e) e
  )
  
  error_msg <- conditionMessage(error)
  expect_true(grepl("below minimum allowed", error_msg))
  expect_true(grepl("0.2cm", error_msg))
})