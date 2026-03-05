# ============================================================================
# Test: Spec Serialization
# ============================================================================

test_that("serialize_spec() accepts TFL_report object", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  
  result <- serialize_spec(report)
  
  expect_is(result, "list")
  expect_true("fixed" %in% names(result))
})

test_that("serialize_spec() returns list with spec and fixed keys", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  
  result <- serialize_spec(report)
  
  expect_true("spec" %in% names(result))
  expect_true("fixed" %in% names(result))
})

test_that("serialize_spec() fixed element is JSON-serializable", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  
  result <- serialize_spec(report)
  
  # The fixed element should be serializable to JSON
  expect_is(result$fixed, "list")
})

test_that("serialize_spec() preserves spec structure in result", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  
  result <- serialize_spec(report)
  
  # result$spec should be the TFL_report
  expect_s3_class(result$spec, "TFL_report")
})

test_that("serialize_spec() with title and content", {
  spec <- create_text()
  spec <- add_title(spec, "Test Document")
  spec <- add_body_text(spec, "Document content")
  
  report <- create_report(spec)
  result <- serialize_spec(report)
  
  expect_true(!is.null(result$fixed))
})

test_that("serialize_spec() with styled spec", {
  spec <- create_table(test_df)
  spec <- add_style(spec, id = "my_style", s_font(bold = TRUE))
  spec <- define_cols(spec, id, labelStyleRef = "my_style")
  
  report <- create_report(spec)
  result <- serialize_spec(report)
  
  expect_is(result, "list")
  expect_true("fixed" %in% names(result))
})

test_that("serialize_spec() with empty text spec", {
  spec <- create_text()
  
  report <- create_report(spec)
  result <- serialize_spec(report)
  
  expect_is(result$fixed, "list")
})

test_that("serialize_spec() handles multiple specs in report", {
  spec1 <- create_table(test_df)
  spec2 <- create_text()
  spec3 <- create_figure(test_image_path)
  
  report <- create_report(spec1, spec2, spec3)
  result <- serialize_spec(report)
  
  expect_equal(length(result$spec), 3)
})

test_that("serialize_spec() with enforce_additional_properties parameter", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  
  # Test with FALSE (default)
  result1 <- serialize_spec(report, enforce_additional_properties = FALSE)
  expect_is(result1, "list")
  
  # Test with TRUE
  result2 <- serialize_spec(report, enforce_additional_properties = TRUE)
  expect_is(result2, "list")
})

test_that("serialize_spec() result is consistent across calls", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  
  result1 <- serialize_spec(report)
  result2 <- serialize_spec(report)
  
  # Both should have same structure
  expect_equal(names(result1), names(result2))
})

# ============================================================================
# Data-Specific Tests: Array Protection and PatternProperties
# ============================================================================

test_that("serialize_spec() preserves dataRef as array structure", {
  spec <- create_table(test_df)
  spec <- add_title(spec, "Test Table")
  report <- create_report(spec)
  
  result <- serialize_spec(report)
  spec_orig <- result$spec
  fixed <- result$fixed
  
  # Get the spec object key (should be in patternProperties)
  spec_keys <- names(fixed)[grep("^[A-Za-z0-9][A-Za-z0-9_-]*_[a-f0-9]{16}$", names(fixed))]
  expect_length(spec_keys, 1L)
  
  spec_obj <- fixed[[spec_keys[1]]]
  
  # Check dataRef is present and is a list (array)
  expect_true(!is.null(spec_obj$dataRef))
  expect_true(is.list(spec_obj$dataRef))
  
  # Verify data is preserved - dataRef should be in original too
  expect_true(!is.null(spec_orig[[1]]$dataRef))
})

test_that("serialize_spec() preserves titles text as array", {
  spec <- create_table(test_df)
  spec <- add_title(spec, "Title Line 1")
  
  report <- create_report(spec)
  result <- serialize_spec(report)
  spec_orig <- result$spec
  fixed <- result$fixed
  
  # Get the spec object
  spec_keys <- names(fixed)[grep("^[A-Za-z0-9][A-Za-z0-9_-]*_[a-f0-9]{16}$", names(fixed))]
  spec_obj <- fixed[[spec_keys[1]]]
  
  # Check titles structure
  expect_true(!is.null(spec_obj$titles))
  expect_true(is.list(spec_obj$titles))
  
  title_ids <- names(spec_obj$titles)
  expect_true(length(title_ids) > 0L)
  
  # Check text field is an array (list)
  title_obj <- spec_obj$titles[[title_ids[1]]]
  expect_true(!is.null(title_obj$text))
  expect_true(is.list(title_obj$text))
  expect_true(is.character(unlist(title_obj$text)))
  
  # Verify data matches original spec
  original_title_text <- spec_orig[[1]]$titles[[title_ids[1]]]$text
  expect_equal(title_obj$text[[1]], original_title_text)
})

test_that("serialize_spec() preserves subtitles with correct values", {
  spec <- create_table(test_df)
  spec <- add_subtitle(spec, "Subtitle A")
  spec <- add_subtitle(spec, "Subtitle B")
  
  report <- create_report(spec)
  result <- serialize_spec(report)
  spec_orig <- result$spec
  fixed <- result$fixed
  
  spec_keys <- names(fixed)[grep("^[A-Za-z0-9][A-Za-z0-9_-]*_[a-f0-9]{16}$", names(fixed))]
  spec_obj <- fixed[[spec_keys[1]]]
  
  # Check subtitles exist and are lists
  expect_true(!is.null(spec_obj$subtitles))
  expect_true(is.list(spec_obj$subtitles))
  
  subtitle_ids <- names(spec_obj$subtitles)
  expect_true(length(subtitle_ids) >= 2L)
  
  # Verify each subtitle text is an array
  for (sub_id in subtitle_ids) {
    sub_obj <- spec_obj$subtitles[[sub_id]]
    expect_true(is.list(sub_obj$text))
    expect_true(is.character(unlist(sub_obj$text)))
    
    # Verify data matches original
    original_sub_text <- spec_orig[[1]]$subtitles[[sub_id]]$text
    expect_equal(sub_obj$text[[1]], original_sub_text)
  }
})

test_that("serialize_spec() preserves footnotes text as arrays with values", {
  spec <- create_table(test_df)
  spec <- add_footnote(spec, "Note about data")
  spec <- add_footnote(spec, "Second note")
  
  report <- create_report(spec)
  result <- serialize_spec(report)
  spec_orig <- result$spec
  fixed <- result$fixed
  
  spec_keys <- names(fixed)[grep("^[A-Za-z0-9][A-Za-z0-9_-]*_[a-f0-9]{16}$", names(fixed))]
  spec_obj <- fixed[[spec_keys[1]]]
  
  # Check footnotes structure
  expect_true(!is.null(spec_obj$footnotes))
  expect_true(is.list(spec_obj$footnotes))
  
  footnote_ids <- names(spec_obj$footnotes)
  expect_equal(length(footnote_ids), 2L)
  
  # Verify each footnote text is a list (array)
  for (fn_id in footnote_ids) {
    fn_obj <- spec_obj$footnotes[[fn_id]]
    expect_true(is.list(fn_obj$text))
    expect_true(is.character(unlist(fn_obj$text)))
    
    # Verify specific content matches
    original_fn_text <- spec_orig[[1]]$footnotes[[fn_id]]$text
    expect_equal(fn_obj$text[[1]], original_fn_text)
    
    # Verify order field exists
    expect_true(!is.null(fn_obj$order))
    expect_true(is.numeric(fn_obj$order))
  }
})

test_that("serialize_spec() preserves columns with correct types", {
  spec <- create_table(test_df)
  spec <- add_style(spec, id = "col_style", s_font(bold = TRUE))
  spec <- define_cols(spec, c(id, value), labelStyleRef = "col_style")
  
  report <- create_report(spec)
  result <- serialize_spec(report)
  spec_orig <- result$spec
  fixed <- result$fixed
  
  spec_keys <- names(fixed)[grep("^[A-Za-z0-9][A-Za-z0-9_-]*_[a-f0-9]{16}$", names(fixed))]
  spec_obj <- fixed[[spec_keys[1]]]
  
  # Check columns structure
  expect_true(!is.null(spec_obj$columns))
  expect_true(is.list(spec_obj$columns))
  
  col_ids <- names(spec_obj$columns)
  expect_true(length(col_ids) >= 2L)
  
  # Verify each column has correct structure
  for (col_id in col_ids) {
    col_obj <- spec_obj$columns[[col_id]]
    
    # Check format exists and is a list
    expect_true(!is.null(col_obj$format))
    expect_true(is.list(col_obj$format))
    expect_true(!is.null(col_obj$format$type))
    
    # Check label if present
    if (!is.null(col_obj$label)) {
      expect_true(is.character(col_obj$label))
    }
    
    # Check colOrder is numeric
    expect_true(!is.null(col_obj$colOrder))
    expect_true(is.numeric(col_obj$colOrder))
    
    # Verify labelStyleRef is array if present
    if (!is.null(col_obj$labelStyleRef)) {
      expect_true(is.list(col_obj$labelStyleRef))
      expect_true(is.character(unlist(col_obj$labelStyleRef)))
      
      # Compare with original
      original_ref <- spec_orig[[1]]$columns[[col_id]]$labelStyleRef
      expect_equal(col_obj$labelStyleRef[[1]], original_ref)
    }
  }
})


test_that("serialize_spec() single-element arrays remain as arrays", {
  spec <- create_table(test_df)
  spec <- add_title(spec, "Single Title")
  
  report <- create_report(spec)
  result <- serialize_spec(report)
  fixed <- result$fixed
  
  spec_keys <- names(fixed)[grep("^[A-Za-z0-9][A-Za-z0-9_-]*_[a-f0-9]{16}$", names(fixed))]
  spec_obj <- fixed[[spec_keys[1]]]
  
  # Check that single-element title text is still a list (array), not unboxed to string
  title_ids <- names(spec_obj$titles)
  title_obj <- spec_obj$titles[[title_ids[1]]]
  
  expect_true(is.list(title_obj$text))
  expect_true(length(title_obj$text) == 1L)
  expect_true(is.character(unlist(title_obj$text)))
  expect_equal(unlist(title_obj$text), "Single Title")
})

test_that("serialize_spec() multiple specs maintain independent data", {
  spec1 <- create_table(test_df[1:5, ])
  spec1 <- add_title(spec1, "Table 1")
  spec1 <- add_footnote(spec1, "Note for table 1")
  
  spec2 <- create_text()
  spec2 <- add_title(spec2, "Text Block")
  spec2 <- add_body_text(spec2, "Some content")
  spec2 <- add_footnote(spec2, "Note for text")
  
  report <- create_report(spec1, spec2)
  result <- serialize_spec(report)
  spec_orig <- result$spec
  fixed <- result$fixed
  
  # Should have 2 spec keys plus _metadata
  spec_keys <- names(fixed)[grep("^[A-Za-z0-9][A-Za-z0-9_-]*_[a-f0-9]{16}$", names(fixed))]
  expect_equal(length(spec_keys), 2L)
  
  # Verify each spec maintains independent titles
  for (i in seq_along(spec_keys)) {
    spec_obj <- fixed[[spec_keys[i]]]
    
    expect_true(!is.null(spec_obj$titles))
    expect_true(is.list(spec_obj$titles))
    
    title_ids <- names(spec_obj$titles)
    expect_true(length(title_ids) > 0L)
    
    for (title_id in title_ids) {
      title_text <- spec_obj$titles[[title_id]]$text
      expect_true(is.list(title_text))
      
      # Compare with original
      original_text <- spec_orig[[i]]$titles[[title_id]]$text
      expect_equal(title_text[[1]], original_text)
    }
  }
})

test_that("serialize_spec() JSON serialization with actual values", {
  spec <- create_table(test_df)
  spec <- add_title(spec, "Test Title")
  spec <- add_footnote(spec, "Test Note")
  report <- create_report(spec)
  
  result <- serialize_spec(report)
  fixed <- result$fixed
  
  # Remove class names (unclass recursively) and .metadata from each spec before JSON serialization
  fixed_clean <- .unclass_recursive(fixed)
  
  # Remove .metadata from each spec object (contains environments that can't be serialized)
  spec_keys <- names(fixed_clean)[grep("^[A-Za-z0-9][A-Za-z0-9_-]*_[a-f0-9]{16}$", names(fixed_clean))]
  for (spec_key in spec_keys) {
    fixed_clean[[spec_key]]$.metadata <- NULL
  }
  
  # Should be able to serialize to JSON
  json_str <- tryCatch({
    jsonlite::toJSON(fixed_clean, auto_unbox = TRUE)
  }, error = function(e) NULL)
  
  expect_false(is.null(json_str))
  expect_true(is.character(json_str))
  expect_true(nchar(json_str) > 0L)
  
  # Deserialize and verify structure is preserved
  deserialized <- jsonlite::fromJSON(json_str,simplifyVector = F, simplifyDataFrame = F, flatten = F)
  
  expect_true(!is.null(deserialized))
  expect_true(is.list(deserialized))
  
  # Verify title is still array in deserialized version
  spec_keys <- names(deserialized)[grep("^[A-Za-z0-9][A-Za-z0-9_-]*_[a-f0-9]{16}$", names(deserialized))]
  if (length(spec_keys) > 0L) {
    spec_obj <- deserialized[[spec_keys[1]]]
    if (!is.null(spec_obj$titles)) {
      title_ids <- names(spec_obj$titles)
      if (length(title_ids) > 0L) {
        title_text <- spec_obj$titles[[title_ids[1]]]$text
        expect_true(is.list(title_text))
      }
    }
  }
})

test_that("serialize_spec() column data types match original", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  
  result <- serialize_spec(report)
  spec_orig <- result$spec
  fixed <- result$fixed
  
  spec_keys <- names(fixed)[grep("^[A-Za-z0-9][A-Za-z0-9_-]*_[a-f0-9]{16}$", names(fixed))]
  spec_obj <- fixed[[spec_keys[1]]]
  
  # Verify column types are preserved
  if (!is.null(spec_obj$columns)) {
    col_ids <- names(spec_obj$columns)
    
    for (col_id in col_ids) {
      col_fixed <- spec_obj$columns[[col_id]]
      col_orig <- spec_orig[[1]]$columns[[col_id]]
      
      # Type should match
      expect_equal(col_fixed$format$type, col_orig$format$type)
      
      # Format should match
      if (!is.null(col_orig$format$format)) {
        expect_equal(col_fixed$format$format, col_orig$format$format)
      }
    }
  }
})

test_that("serialize_spec() with styled content preserves styleRef values", {
  spec <- create_table(test_df)
  spec <- add_style(spec, id = "title_style", s_font(bold = TRUE))
  spec <- add_style(spec, id = "footnote_style", s_font(italic = TRUE))
  spec <- add_title(spec, "Styled Title", styleRef = "title_style")
  spec <- add_footnote(spec, "Styled Note", styleRef = "footnote_style")
  
  report <- create_report(spec)
  result <- serialize_spec(report)
  spec_orig <- result$spec
  fixed <- result$fixed
  
  spec_keys <- names(fixed)[grep("^[A-Za-z0-9][A-Za-z0-9_-]*_[a-f0-9]{16}$", names(fixed))]
  spec_obj <- fixed[[spec_keys[1]]]
  
  # Check title styleRef
  if (!is.null(spec_obj$titles)) {
    title_ids <- names(spec_obj$titles)
    if (length(title_ids) > 0L) {
      title_obj <- spec_obj$titles[[title_ids[1]]]
      
      if (!is.null(title_obj$styleRef)) {
        expect_true(is.list(title_obj$styleRef))
        
        # Compare with original
        original_styleRef <- spec_orig[[1]]$titles[[title_ids[1]]]$styleRef
        expect_equal(title_obj$styleRef[[1]], original_styleRef)
        expect_equal(unlist(title_obj$styleRef), "title_style")
      }
    }
  }
})

test_that("serialize_spec() order field preserved in content elements", {
  spec <- create_table(test_df)
  spec <- add_title(spec, "Title 1")
  spec <- add_title(spec, "Title 2")
  spec <- add_footnote(spec, "Note 1")
  spec <- add_footnote(spec, "Note 2")
  
  report <- create_report(spec)
  result <- serialize_spec(report)
  spec_orig <- result$spec
  fixed <- result$fixed
  
  spec_keys <- names(fixed)[grep("^[A-Za-z0-9][A-Za-z0-9_-]*_[a-f0-9]{16}$", names(fixed))]
  spec_obj <- fixed[[spec_keys[1]]]
  
  # Check title orders are sequential
  if (!is.null(spec_obj$titles)) {
    title_ids <- names(spec_obj$titles)
    
    for (idx in seq_along(title_ids)) {
      title_obj <- spec_obj$titles[[title_ids[idx]]]
      
      # Order should be numeric and match original
      expect_true(!is.null(title_obj$order))
      expect_true(is.numeric(title_obj$order))
      
      original_order <- spec_orig[[1]]$titles[[title_ids[idx]]]$order
      expect_equal(title_obj$order, original_order)
    }
  }
})

test_that("serialize_spec() handles dotted spec keys with array-protected fields", {
  skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = wt, y = mpg)) +
    ggplot2::geom_point()

  t.fig.spec <- create_figure(p) |>
    add_title("Figure Title") |>
    add_subtitle("Figure Subtitle") |>
    add_footnote("Figure Footnote")

  report <- create_report(t.fig.spec)
  result <- serialize_spec(report)
  fixed <- result$fixed

  spec_keys <- names(fixed)[grep("^[A-Za-z0-9][A-Za-z0-9_.-]*_[a-f0-9]{16}$", names(fixed))]
  expect_length(spec_keys, 1L)
  expect_match(spec_keys[[1]], "^t\\.fig\\.spec_[a-f0-9]{16}$")

  spec_obj <- fixed[[spec_keys[[1]]]]
  expect_true(is.list(spec_obj$dataRef))

  title_id <- names(spec_obj$titles)[[1]]
  subtitle_id <- names(spec_obj$subtitles)[[1]]
  footnote_id <- names(spec_obj$footnotes)[[1]]

  expect_true(is.list(spec_obj$titles[[title_id]]$text))
  expect_true(is.list(spec_obj$subtitles[[subtitle_id]]$text))
  expect_true(is.list(spec_obj$footnotes[[footnote_id]]$text))
})
