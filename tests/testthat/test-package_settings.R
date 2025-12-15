# Tests for Package Settings Functions
# Tests tfl_get_settings, tfl_get_setting, tfl_set_settings, tfl_reset_settings

test_that("tfl_get_settings returns settings list", {
  settings <- tfl_get_settings()
  
  expect_type(settings, "list")
  expect_true(length(settings) > 0)
})

test_that("tfl_get_settings returns required fields", {
  settings <- tfl_get_settings()
  
  required_fields <- c(
    "body_titles", "body_subtitles", "body_footnotes",
    "is_continues", "content_width", "doc_style_template"
  )
  
  for (field in required_fields) {
    expect_true(field %in% names(settings), info = paste("Missing field:", field))
  }
})

test_that("tfl_get_setting retrieves individual setting", {
  value <- tfl_get_setting("body_titles")
  
  expect_true(!is.null(value))
})

test_that("tfl_get_setting with valid key", {
  body_titles <- tfl_get_setting("body_titles")
  is_continues <- tfl_get_setting("is_continues")
  
  expect_true(!is.null(body_titles))
  expect_true(!is.null(is_continues))
})

test_that("tfl_get_setting with invalid key returns NULL", {
  result <- tfl_get_setting("nonexistent_setting")
  
  expect_null(result)
})

test_that("tfl_set_settings updates multiple settings", {
  original <- tfl_get_settings()
  
  tfl_set_settings(
    body_titles = FALSE,
    content_width = "80%"
  )
  
  updated <- tfl_get_settings()
  
  expect_false(updated$body_titles)
  expect_equal(updated$content_width, "80%")
  
  # Restore original
  tfl_reset_settings()
})

test_that("tfl_set_settings merges with existing settings", {
  original <- tfl_get_settings()
  
  tfl_set_settings(body_titles = FALSE)
  updated <- tfl_get_settings()
  
  # Other settings should remain unchanged
  expect_equal(updated$body_subtitles, original$body_subtitles)
  
  tfl_reset_settings()
})

test_that("tfl_reset_settings restores defaults", {
  original <- tfl_get_settings()
  
  # Modify settings
  tfl_set_settings(body_titles = FALSE)
  
  # Reset to defaults
  tfl_reset_settings()
  reset_settings <- tfl_get_settings()
  
  expect_equal(reset_settings, original)
})

test_that("tfl_reset_settings with no prior changes maintains defaults", {
  settings1 <- tfl_get_settings()
  tfl_reset_settings()
  settings2 <- tfl_get_settings()
  
  expect_equal(settings1, settings2)
})

test_that("settings persist across multiple get calls", {
  tfl_set_settings(body_titles = FALSE)
  
  value1 <- tfl_get_setting("body_titles")
  value2 <- tfl_get_setting("body_titles")
  
  expect_equal(value1, value2)
  expect_false(value1)
  
  tfl_reset_settings()
})

test_that("tfl_set_settings accepts logical values", {
  tfl_set_settings(body_titles = TRUE)
  expect_true(tfl_get_setting("body_titles"))
  
  tfl_set_settings(body_titles = FALSE)
  expect_false(tfl_get_setting("body_titles"))
  
  tfl_reset_settings()
})

test_that("tfl_set_settings accepts character values", {
  tfl_set_settings(content_width = "75%")
  expect_equal(tfl_get_setting("content_width"), "75%")
  
  tfl_reset_settings()
})

test_that("tfl_set_settings with empty list", {
  original <- tfl_get_settings()
  
  tfl_set_settings()
  updated <- tfl_get_settings()
  
  expect_equal(updated, original)
})

test_that("tfl_get_settings is independent of tfl_init", {
  settings <- tfl_get_settings()
  spec <- tfl_init()
  settings2 <- tfl_get_settings()
  
  expect_equal(settings, settings2)
})

test_that("settings influence spec initialization", {
  tfl_set_settings(body_titles = FALSE)
  
  spec <- tfl_init()
  settings <- tfl_get_settings()
  
  # Document should reflect settings
  expect_equal(spec$document$bodyTitles, settings$body_titles)
  
  tfl_reset_settings()
})
