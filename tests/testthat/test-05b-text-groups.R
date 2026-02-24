test_that("add_title adds a title group", {
  spec <- create_text()
  spec2 <- add_title(spec, "My Title")
  expect_s3_class(spec2, "TFL_spec")
  expect_true(length(spec2$titles) == 1)
  expect_equal(spec2$titles[[1]]$text, "My Title")
})

test_that("add_subtitle adds a subtitle group", {
  spec <- create_text()
  spec2 <- add_subtitle(spec, "My Subtitle")
  expect_s3_class(spec2, "TFL_spec")
  expect_true(length(spec2$subtitles) == 1)
  expect_equal(spec2$subtitles[[1]]$text, "My Subtitle")
})

test_that("add_footnote adds a footnote group", {
  spec <- create_text()
  spec2 <- add_footnote(spec, "My Footnote")
  expect_s3_class(spec2, "TFL_spec")
  expect_true(length(spec2$footnotes) == 1)
  expect_equal(spec2$footnotes[[1]]$text, "My Footnote")
})

test_that("add_body_text.TFL_spec removes default entries and adds new body text", {
  spec <- create_text()
  # initial defaults (if any)
  initial_defaults <- grep(paste0("^", .const_bodytext_default_id_prefix, "_"), names(spec$bodyText), value = TRUE)
  spec2 <- add_body_text(spec, "No data available")
  expect_s3_class(spec2, "TFL_spec")
  # No defaults should remain after adding custom text
  remaining_defaults <- grep(paste0("^", .const_bodytext_default_id_prefix, "_"), names(spec2$bodyText), value = TRUE)
  expect_length(remaining_defaults, 0)
  expect_true(length(spec2$bodyText) >= 1)
  expect_equal(spec2$bodyText[[1]]$text, "No data available")
})
