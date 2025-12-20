# ============================================================================
# Test: Report Creation and Style Consolidation
# ============================================================================

# ---- Basic single/multiple spec handling ----

test_that("create_report() combines single spec", {
  spec <- create_table(test_df)
  
  report <- create_report(spec)
  
  expect_s3_class(report, "TFL_report")
  expect_is(report, "list")
  expect_equal(length(report), 1L)
})

test_that("create_report() combines multiple specs", {
  table1 <- create_table(test_df)
  table2 <- create_text()
  
  report <- create_report(table1, table2)
  
  expect_equal(length(report), 2L)
  expect_true(all(vapply(report, function(x) inherits(x, "TFL_spec"), logical(1))))
})

test_that("create_report() keys specs by variable name and hash", {
  spec1 <- create_table(test_df)
  spec2 <- create_text()
  
  report <- create_report(spec1, spec2)
  
  keys <- names(report)
  expect_equal(length(keys), 2L)
  expect_true(any(grepl("spec1", keys)))
  expect_true(any(grepl("spec2", keys)))
  # Keys should have format: <varname>_<hash>
  expect_true(all(grepl("^[a-z0-9_]+_[a-f0-9]{16}$", keys)))
})

# ---- docOrder and docType validation ----

test_that("create_report() sets correct docOrder for mixed types", {
  table_spec <- create_table(test_df)
  text_spec <- create_text()
  fig_spec <- create_figure(filepath = test_image_path)
  
  report <- create_report(table_spec, text_spec, fig_spec)
  
  expect_equal(report[[1]]$document$docOrder, 1L)
  expect_equal(report[[2]]$document$docOrder, 2L)
  expect_equal(report[[3]]$document$docOrder, 3L)
  
  # Verify docTypes are preserved
  expect_equal(report[[1]]$document$docType, "Table")
  expect_equal(report[[2]]$document$docType, "Text")
  expect_equal(report[[3]]$document$docType, "Figure")
})

# ---- dataRef creation and validation ----

test_that("create_report() creates dataRef for new specs with correct format", {
  spec1 <- create_table(test_df)
  spec2 <- create_text()
  
  report <- create_report(spec1, spec2)
  
  # dataRef should be padded order (4 digits) with underscore and hash
  ref1 <- report[[1]]$dataRef
  ref2 <- report[[2]]$dataRef
  
  expect_equal(length(ref1), 1L)
  expect_equal(length(ref2), 1L)
  expect_true(grepl("^0001_[a-f0-9]{16}$", ref1))
  expect_true(grepl("^0002_[a-f0-9]{16}$", ref2))
  expect_false(isTRUE(all.equal(ref1, ref2)))
})

test_that("create_report() preserves dataRef from input reports", {
  spec1 <- create_table(test_df)
  spec2 <- create_text()
  report1 <- create_report(spec1, spec2)
  
  # Store original dataRef values
  original_ref1 <- report1[[1]]$dataRef
  original_ref2 <- report1[[2]]$dataRef
  
  # Add new spec and combine with report
  spec3 <- create_figure(filepath = test_image_path)
  report2 <- create_report(report1, spec3)
  
  # Original dataRef should be preserved (not renamed)
  expect_equal(report2[[1]]$dataRef, original_ref1)
  expect_equal(report2[[2]]$dataRef, original_ref2)
  # New spec should have new dataRef with doc order 3
  expect_true(grepl("^0003_", report2[[3]]$dataRef))
})

# ---- Input validation ----

test_that("create_report() rejects non-TFL_spec/TFL_report inputs", {
  spec <- create_table(test_df)
  
  expect_error(
    create_report(spec, "not_a_spec"),
    "must be of class TFL_spec or TFL_report"
  )
  
  expect_error(
    create_report(spec, 123),
    "must be of class TFL_spec or TFL_report"
  )
  
  expect_error(
    create_report(spec, list(a = 1)),
    "must be of class TFL_spec or TFL_report"
  )
})

test_that("create_report() requires at least one argument", {
  expect_error(
    create_report(),
    "at least one"
  )
})

test_that("create_report() detects duplicate spec keys", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  
  # Try to combine report with itself (same specs)
  # This should error because keys are identical
  expect_error(
    create_report(report, report),
    "Duplicate spec keys|identical content"
  )
})

# ---- Style consolidation logic ----

test_that("create_report() consolidates style combinations for new specs", {
  spec <- create_table(test_df)
  spec <- add_style(spec, id = "style_bold", s_font(bold = TRUE))
  spec <- add_style(spec, id = "style_italic", s_font(italic = TRUE))
  # Apply combination of styles
  spec <- define_cols(spec, id, labelStyleRef = c("style_bold", "style_italic"))
  
  report <- create_report(spec)
  result <- report[[1]]
  
  # After consolidation, combination should be merged
  label_ref <- result$columns$id$labelStyleRef
  expect_true(is.character(label_ref))
  expect_equal(length(label_ref), 1L)
  # Should be hashed style reference (format: style_<16-char-hex>)
  expect_true(grepl("^style_[a-f0-9]{16}$", label_ref))
  
  # Merged style should exist in spec
  expect_true(label_ref %in% names(result$attribs$styles))
  
  # Original component styles should be removed
  expect_false("style_bold" %in% names(result$attribs$styles))
  expect_false("style_italic" %in% names(result$attribs$styles))
})

test_that("create_report() does not re-consolidate styles from input reports", {
  spec <- create_table(test_df)
  spec <- add_style(spec, id = "style1", s_font(bold = TRUE))
  spec <- add_style(spec, id = "style2", s_font(italic = TRUE))
  spec <- define_cols(spec, id, labelStyleRef = c("style1", "style2"))
  
  report1 <- create_report(spec)
  
  # Get the consolidated style reference from first report
  consolidated_ref <- report1[[1]]$columns$id$labelStyleRef
  style_names_after_first <- names(report1[[1]]$attribs$styles)
  
  # Add a new spec
  spec2 <- create_text()
  report2 <- create_report(report1, spec2)
  
  # Original spec from report should maintain same consolidated reference
  expect_equal(
    report2[[1]]$columns$id$labelStyleRef,
    consolidated_ref
  )
  
  # Original spec should not have styles re-consolidated
  # (should still have same styles as before)
  expect_equal(
    sort(names(report2[[1]]$attribs$styles)),
    sort(style_names_after_first)
  )
})

# ---- Mixing reports and specs ----

test_that("create_report() flattens and combines mixed reports and specs", {
  spec1 <- create_table(test_df)
  spec2 <- create_text()
  report1 <- create_report(spec1, spec2)
  
  spec3 <- create_figure(filepath = test_image_path)
  spec4 <- create_text()
  
  # Mix: report1 (2 specs) + individual spec3 + individual spec4
  final_report <- create_report(report1, spec3, spec4)
  
  expect_equal(length(final_report), 4L)
  expect_true(all(vapply(final_report, function(x) inherits(x, "TFL_spec"), logical(1))))
  
  # Verify docOrder is sequential
  doc_orders <- unname(vapply(final_report, function(x) x$document$docOrder, integer(1)))
  expect_equal(doc_orders, c(1L, 2L, 3L, 4L))
})

test_that("create_report() preserves spec order across mixed inputs", {
  spec_a <- create_table(test_df)
  spec_a <- add_title(spec_a, "Spec A")
  
  spec_b <- create_text()
  spec_b <- add_title(spec_b, "Spec B")
  
  report_ab <- create_report(spec_a, spec_b)
  
  spec_c <- create_figure(filepath = test_image_path)
  spec_c <- add_title(spec_c, "Spec C")
  
  # Combine: report(A, B) + C
  final <- create_report(report_ab, spec_c)
  
  # Order should be preserved: A, B, C
  expect_equal(final[[1]]$document$docOrder, 1L)
  expect_equal(final[[2]]$document$docOrder, 2L)
  expect_equal(final[[3]]$document$docOrder, 3L)
  
  # Verify titles match original order
  expect_equal(final[[1]]$titles[[1]]$text, c("Spec A"))
  expect_equal(final[[2]]$titles[[1]]$text, c("Spec B"))
  expect_equal(final[[3]]$titles[[1]]$text, c("Spec C"))
})

# ---- dataRef duplication warnings ----

test_that("create_report() warns about duplicate dataRef values", {
  spec1 <- create_table(test_df)
  spec2 <- create_table(test_df)
  
  report1 <- create_report(spec1)
  report2 <- create_report(spec2)
  
  # Manually set same dataRef on both reports to simulate shared data
  report1[[1]]$dataRef <- "shared_data_0001"
  report2[[1]]$dataRef <- "shared_data_0001"
  
  # Combining should warn about duplicate dataRef
  expect_warning(
    final <- create_report(report1, report2),
    "dataRef.*multiple|referenced by multiple"
  )
})

# ---- Edge cases ----

test_that("create_report() handles nested report combinations", {
  spec1 <- create_table(test_df)
  spec2 <- create_text()
  report1 <- create_report(spec1, spec2)
  
  spec3 <- create_figure(filepath = test_image_path)
  report2 <- create_report(report1, spec3)
  
  spec4 <- create_text()
  final <- create_report(report2, spec4)
  
  expect_equal(length(final), 4L)
  doc_orders <- unname(vapply(final, function(x) x$document$docOrder, integer(1)))
  expect_equal(doc_orders, c(1L, 2L, 3L, 4L))
})

test_that("create_report() with multiple style consolidations", {
  spec1 <- create_table(test_df)
  spec1 <- add_style(spec1, id = "s1", s_font(bold = TRUE))
  spec1 <- add_style(spec1, id = "s2", s_font(italic = TRUE))
  spec1 <- add_style(spec1, id = "s3", s_font(underline = TRUE))
  spec1 <- define_cols(spec1, id, labelStyleRef = c("s1", "s2"))
  spec1 <- define_cols(spec1, group, labelStyleRef = c("s1", "s3"))
  
  report <- create_report(spec1)
  result <- report[[1]]
  
  # Two combinations should be consolidated
  id_ref <- result$columns$id$labelStyleRef
  group_ref <- result$columns$group$labelStyleRef
  
  expect_equal(length(id_ref), 1L)
  expect_equal(length(group_ref), 1L)
  
  # Should be different hashes (different combinations)
  expect_false(isTRUE(all.equal(id_ref, group_ref)))
  
  # Both should exist in styles
  expect_true(id_ref %in% names(result$attribs$styles))
  expect_true(group_ref %in% names(result$attribs$styles))
  
  # Original component styles should be removed
  expect_false("s1" %in% names(result$attribs$styles))
  expect_false("s2" %in% names(result$attribs$styles))
  expect_false("s3" %in% names(result$attribs$styles))
})

test_that("create_report() returns TFL_report class", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  
  expect_is(report, "TFL_report")
})

