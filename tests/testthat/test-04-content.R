# ============================================================================
# Test: Content Functions (titles, subtitles, footnotes, body text)
# ============================================================================

test_that("add_title() adds title to table spec", {
  spec <- create_table(test_df)
  spec <- add_title(spec, "My Table Title")
  
  expect_true(length(spec$titles) > 0)
  expect_equal(spec$titles[[1]]$text, "My Table Title")
})

test_that("add_title() with multiple lines", {
  spec <- create_text()
  spec <- add_title(spec, c("Line 1", "Line 2"))
  
  expect_equal(length(spec$titles), 1)
  expect_equal(length(spec$titles[[1]]$text), 2)
  expect_equal(spec$titles[[1]]$text[1], "Line 1")
  expect_equal(spec$titles[[1]]$text[2], "Line 2")
  
  spec <- add_title(spec, c("Line 3", "Line 4"))
  expect_equal(length(spec$titles), 2)
  expect_equal(length(spec$titles[[1]]$text), 2)
  expect_equal(spec$titles[[2]]$text[1], "Line 3")
  expect_equal(spec$titles[[2]]$text[2], "Line 4")
  
})

test_that("add_subtitle() adds subtitle to spec", {
  spec <- create_text()
  spec <- add_subtitle(spec, "Analysis Results")
  
  expect_true(length(spec$subtitles) == 1)
  expect_equal(spec$subtitles[[1]]$text, "Analysis Results")
  
  spec <- add_subtitle(spec, "Analysis Results 1")
  
  expect_true(length(spec$subtitles) == 2)
  expect_equal(spec$subtitles[[2]]$text, "Analysis Results 1")
})

test_that("add_footnote() adds footnote to spec", {
  spec <- create_table(test_df)
  spec <- add_footnote(spec, "Source: internal data")
  
  expect_true(length(spec$footnotes) > 0)
  expect_equal(spec$footnotes[[1]]$text, "Source: internal data")
})

test_that("add_body_text() on Table spec", {
  spec <- create_table(test_df)
  spec <- add_body_text(spec, "Additional context for table")
  
  expect_equal(length(spec$bodyText), 1)
  expect_equal(spec$bodyText[[1]]$text[[1]], "Additional context for table")
})

test_that("add_body_text() on Text spec", {
  spec <- create_text()
  spec <- add_body_text(spec, "This is narrative text")
  spec <- add_body_text(spec, "about some drug")
  
  expect_equal(spec$bodyText[[1]]$text, "This is narrative text")
  expect_equal(spec$bodyText[[2]]$text, "about some drug")
})

test_that("add_title() with styleRef", {
  spec <- create_text()
  spec <- add_style(spec, id = "title_style", s_font(bold = TRUE, color = "blue"))
  spec <- add_title(spec, "Styled Title", styleRef = "title_style")
  
  expect_equal(spec$titles[[1]]$styleRef, "title_style")
})

test_that("add_footnote() with styleRef", {
  spec <- create_text()
  spec <- add_style(spec, id = "note_style", s_font(italic = TRUE))
  spec <- add_footnote(spec, "Footnote text", styleRef = "note_style")
  
  expect_true(!is.null(spec$footnotes[[1]]$styleRef))
})

test_that("add_title() multiple calls append titles", {
  spec <- create_text()
  spec <- add_title(spec, "Title 1")
  spec <- add_title(spec, "Title 2")
  
  expect_equal(length(spec$titles), 2)
})

test_that("add_body_text() multiple calls append text", {
  spec <- create_text()
  spec <- add_body_text(spec, "First paragraph")
  spec <- add_body_text(spec, "Second paragraph")
  
  expect_equal(length(spec$bodyText), 2)
})

test_that("add_title() with empty string", {
  spec <- create_text()
  spec <- add_title(spec, "")
  
  expect_equal(spec$titles[[1]]$text, "")
})

test_that("add_footnote() with special characters", {
  spec <- create_text()
  spec <- add_footnote(spec, "Source: © 2024, confidential")
  
  expect_true(grepl("©", spec$footnotes[[1]]$text))
})

