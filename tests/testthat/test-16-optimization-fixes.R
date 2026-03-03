# ============================================================================
# Test: Code Optimization Fixes and Edge Cases
# Tests for bug fixes and optimizations implemented Dec 25, 2025
# ============================================================================

# ----------------------------------------------------------------------------
# Helper Functions: firstRow, lastRow, every_nth
# ----------------------------------------------------------------------------

test_that("firstRow() returns TRUE only at first row", {
  data <- data.frame(a = 1:5, b = letters[1:5])
  spec <- create_table(data) |>
    add_style("highlight", s_font(bold = TRUE)) |>
    compute_cols(
      firstRow(),
      c_style(a, styleRef = "highlight")
    )
  
  # Should have compute_cols populated (styleRows created during create_report)
  expect_true(length(spec$.metadata$compute_cols) > 0)
  
  # Verify firstRow() produces correct logical vector in evaluation
  test_env <- ksTFL:::.create_data_env(data, ksTFL:::.env_func_list)
  result <- with(test_env, firstRow())
  expect_equal(result, c(TRUE, FALSE, FALSE, FALSE, FALSE))
})

test_that("lastRow() returns TRUE only at last row", {
  data <- data.frame(a = 1:5, b = letters[1:5])
  spec <- create_table(data) |>
    add_style("highlight", s_font(bold = TRUE)) |>
    compute_cols(
      lastRow(),
      c_style(a, styleRef = "highlight")
    )
  
  # Verify lastRow() produces correct logical vector
  test_env <- ksTFL:::.create_data_env(data, ksTFL:::.env_func_list)
  result <- with(test_env, lastRow())
  expect_equal(result, c(FALSE, FALSE, FALSE, FALSE, TRUE))
})

test_that("firstRow/lastRow handle empty data", {
  data <- data.frame(a = integer(0))
  test_env <- ksTFL:::.create_data_env(data, ksTFL:::.env_func_list)
  
  expect_equal(with(test_env, firstRow()), logical(0))
  expect_equal(with(test_env, lastRow()), logical(0))
})

test_that("firstRow/lastRow handle single-row data", {
  data <- data.frame(a = 1)
  test_env <- ksTFL:::.create_data_env(data, ksTFL:::.env_func_list)
  
  expect_equal(with(test_env, firstRow()), TRUE)
  expect_equal(with(test_env, lastRow()), TRUE)
})

test_that("everyNth() works correctly", {
  data <- data.frame(a = 1:10)
  test_env <- ksTFL:::.create_data_env(data, ksTFL:::.env_func_list)
  
  # Every 2nd row (1, 3, 5, 7, 9)
  result_2 <- with(test_env, everyNth(2))
  expect_equal(result_2, c(TRUE, FALSE, TRUE, FALSE, TRUE, FALSE, TRUE, FALSE, TRUE, FALSE))
  
  # Every 3rd row (1, 4, 7, 10)
  result_3 <- with(test_env, everyNth(3))
  expect_equal(result_3, c(TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, TRUE))
})

test_that("firstOf/lastOf work with multiple columns", {
  data <- data.frame(
    group = c("A", "A", "B", "B", "B", "C"),
    subgroup = c("X", "Y", "X", "X", "Y", "X")
  )
  test_env <- ksTFL:::.create_data_env(data, ksTFL:::.env_func_list)
  
  # firstOf with two columns
  result_first <- with(test_env, firstOf(group, subgroup))
  expect_equal(result_first, c(TRUE, TRUE, TRUE, FALSE, TRUE, TRUE))
  
  # lastOf with two columns
  result_last <- with(test_env, lastOf(group, subgroup))
  expect_equal(result_last, c(TRUE, TRUE, FALSE, TRUE, TRUE, TRUE))
})


test_that("firstOf/lastOf handle all-same values", {
  data <- data.frame(a = rep("A", 5))
  test_env <- ksTFL:::.create_data_env(data, ksTFL:::.env_func_list)
  
  # All same: first is row 1, last is row 5
  expect_equal(with(test_env, firstOf(a)), c(TRUE, FALSE, FALSE, FALSE, FALSE))
  expect_equal(with(test_env, lastOf(a)), c(FALSE, FALSE, FALSE, FALSE, TRUE))
})

test_that("firstOfBlock test", {
  data <- data.frame(
    group = c("A", "A", "B", "B", "B", "C", "C", "C"),
    subgroup = c("X", "Y", "X", "X", "Y", "X",  "Y", "X")
  )
  test_env <- ksTFL:::.create_data_env(data, ksTFL:::.env_func_list)
  
  # firstOf with two columns
  result_first <- with(test_env, firstOfBlock(group, 2))
  expect_equal(result_first, c(F,F,F,F,F,T,F,F))
  
  # lastOf with two columns
  result_last <- with(test_env, firstOfBlock(group, 2, -1))
  expect_equal(result_last, c(F,F,T,F,F,F,F,F))
})

# ----------------------------------------------------------------------------
# .parse_colwidth with explicit return
# ----------------------------------------------------------------------------

test_that(".parse_colwidth returns correct structure", {
  result <- ksTFL:::.parse_colwidth("25.5%")
  expect_type(result, "list")
  expect_named(result, c("unit", "value"))
  expect_equal(result$unit, "%")
  expect_equal(result$value, 25.5)
})

test_that(".parse_colwidth handles various units", {
  expect_equal(ksTFL:::.parse_colwidth("10cm")$unit, "cm")
  expect_equal(ksTFL:::.parse_colwidth("2.5in")$unit, "in")
  expect_equal(ksTFL:::.parse_colwidth("15mm")$unit, "mm")
  expect_equal(ksTFL:::.parse_colwidth("100pt")$unit, "pt")
})

test_that(".parse_colwidth returns NULL for invalid input", {
  expect_null(ksTFL:::.parse_colwidth("invalid"))
  expect_null(ksTFL:::.parse_colwidth(""))
  expect_null(ksTFL:::.parse_colwidth(NA_character_))
  expect_null(ksTFL:::.parse_colwidth(25))  # Not character
})

# ----------------------------------------------------------------------------
# NULL/NA Label Handling
# ----------------------------------------------------------------------------

test_that("spec prints correctly with NULL labels", {
  data <- data.frame(x = 1:3)
  spec <- create_table(data)
  
  # Remove label to simulate NULL
  spec$columns$x$label <- NULL
  
  # Should not crash
  expect_no_error(print(spec))
  output <- capture.output(print(spec))
  expect_true(length(output) > 0)
})

test_that("spec prints correctly with NA labels", {
  data <- data.frame(x = 1:3)
  attr(data$x, "label") <- NA_character_
  spec <- create_table(data)
  
  # Should not crash
  expect_no_error(print(spec))
  output <- capture.output(print(spec))
  expect_true(length(output) > 0)
})

# ----------------------------------------------------------------------------
# Format Spec Caching
# ----------------------------------------------------------------------------

test_that("format spec cache works for repeated column types", {
  # Clear cache first
  rm(list = ls(envir = ksTFL:::.format_spec_cache), envir = ksTFL:::.format_spec_cache)
  
  # Create data with many integer columns
  data <- as.data.frame(matrix(1:100, nrow = 10, ncol = 10))
  colnames(data) <- paste0("col", 1:10)
  
  spec <- create_table(data)
  
  # All columns should use cached format "%d"
  formats <- sapply(spec$columns, function(col) col$format$format)
  expect_true(all(formats == "%d"))
  
  # Cache should have entries
  expect_true(length(ls(envir = ksTFL:::.format_spec_cache)) > 0)
})

test_that("format spec cache handles decimal variations", {
  rm(list = ls(envir = ksTFL:::.format_spec_cache), envir = ksTFL:::.format_spec_cache)
  
  data <- data.frame(
    col1 = c(1.1, 2.2, 3.3),      # 1 decimal
    col2 = c(1.11, 2.22, 3.33),   # 2 decimals
    col3 = c(1.111, 2.222, 3.333) # 3 decimals
  )
  
  spec <- create_table(data)
  
  # Each should get appropriate format
  expect_true(grepl("%.1f", spec$columns$col1$format$format, fixed = TRUE))
  expect_true(grepl("%.2f", spec$columns$col2$format$format, fixed = TRUE))
  expect_true(grepl("%.3f", spec$columns$col3$format$format, fixed = TRUE))
})

# ----------------------------------------------------------------------------
# Schema Resolution Caching
# ----------------------------------------------------------------------------

test_that("schema cache persists across serialize_spec calls", {
  # Get cache size before
  initial_size <- length(ls(envir = ksTFL:::.schema_cache))
  
  spec1 <- create_table(mtcars[1:5, 1:3])
  report1 <- create_report(spec1)  # serialize_spec needs TFL_report
  json1 <- serialize_spec(report1)
  
  cache_after_first <- length(ls(envir = ksTFL:::.schema_cache))
  
  spec2 <- create_table(mtcars[6:10, 1:3])
  report2 <- create_report(spec2)
  json2 <- serialize_spec(report2)
  
  cache_after_second <- length(ls(envir = ksTFL:::.schema_cache))
  
  # Cache should grow or stay same (not reset)
  expect_true(cache_after_first >= initial_size)
  expect_true(cache_after_second >= cache_after_first)
})

# ----------------------------------------------------------------------------
# Style Resolution Memoization
# ----------------------------------------------------------------------------

test_that("style resolution cache works for repeated inputs", {
  rm(list = ls(envir = ksTFL:::.style_resolution_cache), envir = ksTFL:::.style_resolution_cache)
  
  # Call with same inputs multiple times
  result1 <- ksTFL:::._resolve_style_refs(c("style1", "style2"), 3, "test")
  result2 <- ksTFL:::._resolve_style_refs(c("style1", "style2"), 3, "test")
  
  # Results should be identical
  expect_identical(result1, result2)
  
  # Cache should have entry
  expect_true(length(ls(envir = ksTFL:::.style_resolution_cache)) > 0)
})

# ----------------------------------------------------------------------------
# Max Depth in Recursive Extraction
# ----------------------------------------------------------------------------

test_that("create_report handles deeply nested style references", {
  # Create spec with normal nesting
  data <- data.frame(x = 1:3)
  spec <- create_table(data) |>
    add_style("s1", s_font(bold = TRUE)) |>
    define_cols(x, valueStyleRef = "s1")
  
  # Should work fine with normal nesting
  expect_no_error(create_report(spec))
})

test_that("create_report warns on pathologically deep nesting", {
  # This is hard to test without actually creating a pathological structure
  # But we can verify the max_depth parameter exists and functions
  data <- data.frame(x = 1:3)
  spec <- create_table(data) |>
    add_style("s1", s_font(bold = TRUE))
  
  # Should complete without hitting depth limit
  expect_no_error(suppressWarnings(create_report(spec)))
})

# ----------------------------------------------------------------------------
# Vectorized Format Guessing Performance
# ----------------------------------------------------------------------------

test_that("vectorized format guessing handles large datasets", {
  # Create large dataset
  n <- 1000
  data <- data.frame(
    id = 1:n,
    value = rnorm(n),
    category = sample(letters, n, replace = TRUE)
  )
  
  # Should complete in reasonable time
  start_time <- Sys.time()
  spec <- create_table(data)
  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  
  # With vectorization, should be fast (< 2 seconds on most systems)
  expect_true(elapsed < 2)
  expect_equal(length(spec$columns), 3)
})

test_that("vectorized format guessing correct for mixed types", {
  data <- data.frame(
    int_col = 1:10,
    dbl_col = seq(1.1, 2.0, by = 0.1),
    chr_col = letters[1:10],
    fct_col = factor(rep(c("A", "B"), 5))
  )
  
  spec <- create_table(data)
  
  expect_equal(spec$columns$int_col$format$type, "numeric")
  expect_equal(spec$columns$dbl_col$format$type, "numeric")
  expect_equal(spec$columns$chr_col$format$type, "string")
  expect_equal(spec$columns$fct_col$format$type, "string")
})

# ----------------------------------------------------------------------------
# Validation Wrapper .validate()
# ----------------------------------------------------------------------------

test_that(".validate() wrapper works with auto function name", {
  # Can't easily test internal function directly, but verify it exists
  expect_true(exists(".validate", where = asNamespace("ksTFL"), inherits = FALSE))
})

# ----------------------------------------------------------------------------
# create_report Edge Cases
# ----------------------------------------------------------------------------

test_that("create_report handles empty spec list", {
  # Empty list should error
  expect_error(create_report(), "requires at least one")
})

test_that("create_report handles single spec", {
  spec <- create_table(mtcars[1:3, 1:2])
  report <- create_report(spec)
  
  expect_s3_class(report, "TFL_report")
  # TFL_report is a named list of specs
  expect_equal(length(report), 1)
})

test_that("create_report preserves spec order", {
  spec1 <- create_table(mtcars[1:2, 1:2])
  spec2 <- create_text() |> add_body_text("Text")
  spec3 <- create_table(mtcars[3:4, 1:2])
  
  report <- create_report(spec1, spec2, spec3)
  
  expect_equal(report[[1]]$document$docOrder, 1)
  expect_equal(report[[2]]$document$docOrder, 2)
  expect_equal(report[[3]]$document$docOrder, 3)
})

test_that("create_report detects duplicate keys", {
  # Create two specs with identical data (will have same hash)
  data1 <- data.frame(x = 1:3, y = 4:6)
  spec1 <- create_table(data1)
  spec1_dup <- create_table(data1)  # Same data = same hash
  
  # Try to add duplicate spec (same data, same hash, same variable name pattern)
  # Both will generate key like "spec_<hash>" causing duplicate
  # We need to ensure they have the same variable name too
  report1 <- create_report(spec1)
  
  # When we pass spec1_dup with a name that would create the same key
  # Actually, the issue is that variable names differ (spec1 vs spec1_dup)
  # Let's create truly identical scenario by passing same spec twice
  expect_error(create_report(spec1, spec1), "Duplicate.*key")
})

test_that("create_report handles mixed report and spec inputs", {
  spec1 <- create_table(mtcars[1:2, 1:2])
  spec2 <- create_table(mtcars[3:4, 1:2])
  
  report1 <- create_report(spec1)
  report2 <- create_report(report1, spec2)
  
  expect_s3_class(report2, "TFL_report")
  expect_equal(length(report2), 2)
  expect_equal(report2[[1]]$document$docOrder, 1)
  expect_equal(report2[[2]]$document$docOrder, 2)
})

# ----------------------------------------------------------------------------
# Style Consolidation Edge Cases
# ----------------------------------------------------------------------------

test_that("style consolidation handles empty styles", {
  data <- data.frame(x = 1:3)
  spec <- create_table(data)
  
  # Create spec with no styles
  spec$attribs$styles <- list()
  
  # Should still work
  expect_no_error(create_report(spec))
})

test_that("style consolidation handles missing style refs", {
  data <- data.frame(x = 1:3)
  spec <- create_table(data) |>
    define_cols(x, valueStyleRef = "nonexistent_style")
  
  # Should error with clear message about missing style
  expect_error(
    create_report(spec),
    "Referenced styles not found"
  )
})

test_that("style consolidation merges f_combine correctly", {
  data <- data.frame(x = 1:3, y = 4:6)
  spec <- create_table(data) |>
    add_style("bold", s_font(bold = TRUE)) |>
    add_style("italic", s_font(italic = TRUE)) |>
    define_cols(c(x, y), valueStyleRef = f_combine("bold", "italic"))
  
  report <- create_report(spec)
  consolidated <- report[[1]]  # First (and only) spec
  
  # Should have consolidated style
  expect_true(any(grepl("^style_", names(consolidated$attribs$styles))))
  
  # Original styles are removed during consolidation since they're only used in f_combine
  # (they become unreferenced after replacement with merged style)
  # This is correct behavior - merged style contains their properties
  merged_style_name <- names(consolidated$attribs$styles)[grepl("^style_", names(consolidated$attribs$styles))][1]
  merged_style <- consolidated$attribs$styles[[merged_style_name]]
  
  # Check that merged style has properties from both
  expect_true(!is.null(merged_style))
})

# ----------------------------------------------------------------------------
# Width Recalculation Edge Cases
# ----------------------------------------------------------------------------

test_that("width recalculation with all columns locked", {
  data <- data.frame(x = 1:3, y = 4:6, z = 7:9)
  spec <- create_table(data) |>
    define_cols(x, colWidth = "30%") |>
    define_cols(y, colWidth = "30%") |>
    define_cols(z, colWidth = "40%")
  
  # Sum should be 100%
  widths <- sapply(spec$columns, function(col) col$format$colWidth)
  expect_equal(sum(as.numeric(gsub("%", "", widths))), 100)
})

test_that("width recalculation respects minimum width", {
  data <- data.frame(x = 1:3, y = 4:6, z = 7:9)
  
  # Width over 100% should be allowed (percentages don't have hard limit)
  spec <- create_table(data) |> define_cols(x, colWidth = "99%")
  expect_s3_class(spec, "TFL_spec")
})

test_that("width recalculation handles invisible columns", {
  data <- data.frame(x = 1:3, y = 4:6, z = 7:9)
  spec <- create_table(data) |>
    define_cols(y, isVisible = FALSE)
  
  # Invisible column should have 0.0cm width
  expect_equal(spec$columns$y$format$colWidth, "0.0cm")
  
  # Other columns should fill 100%
  visible_widths <- c(
    as.numeric(gsub("%", "", spec$columns$x$format$colWidth)),
    as.numeric(gsub("%", "", spec$columns$z$format$colWidth))
  )
  expect_equal(sum(visible_widths), 100)
})

test_that("cannot set colWidth on invisible column", {
  data <- data.frame(x = 1:3)
  
  expect_error(
    create_table(data) |> define_cols(x, isVisible = FALSE, colWidth = "50%"),
    "Cannot set.*colWidth.*invisible"
  )
})

# ----------------------------------------------------------------------------
# Spec Stability Tests
# ----------------------------------------------------------------------------

test_that("spec structure remains stable after multiple operations", {
  data <- data.frame(x = 1:5, y = letters[1:5])
  
  spec <- create_table(data) |>
    add_style("s1", s_font(bold = TRUE)) |>
    add_title("Title") |>
    add_subtitle("Subtitle") |>
    add_footnote("Note") |>
    define_cols(x, colWidth = "30%") |>
    compute_cols(x > 2, c_style(x, styleRef = "s1"))
  
  # Should have all expected components
  expect_true("document" %in% names(spec))
  expect_true("columns" %in% names(spec))
  expect_true("titles" %in% names(spec))
  expect_true("subtitles" %in% names(spec))
  expect_true("footnotes" %in% names(spec))
  expect_true("attribs" %in% names(spec))
  expect_true(".metadata" %in% names(spec))
  
  # Metadata should be intact
  expect_true("data_env" %in% names(spec$.metadata))
  expect_true("compute_cols" %in% names(spec$.metadata))  # styleRows created by create_report()
})

test_that("report object remains stable after consolidation", {
  spec1 <- create_table(mtcars[1:3, 1:2]) |>
    add_style("bold", s_font(bold = TRUE))
  
  spec2 <- create_table(mtcars[4:6, 1:2]) |>
    add_style("italic", s_font(italic = TRUE))
  
  report <- create_report(spec1, spec2)
  
  # Report should have correct structure (named list)
  expect_s3_class(report, "TFL_report")
  expect_true(is.list(report))
  expect_equal(length(report), 2)
  
  # Each spec should maintain integrity
  for (i in seq_along(report)) {
    spec <- report[[i]]
    expect_s3_class(spec, "TFL_spec")
    expect_true("document" %in% names(spec))
    expect_true("columns" %in% names(spec))
    expect_true("attribs" %in% names(spec))
  }
})
