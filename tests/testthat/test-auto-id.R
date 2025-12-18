test_that(".auto_id returns 1 for empty or unnamed lists (zero-padded)", {
  expect_equal(.auto_id("style_", list()), "style_0001")
  expect_equal(.auto_id("style_", list(a = 1))[1], "style_0001")
})

test_that(".auto_id appends after contiguous sequence (zero-padded)", {
  lst <- list(style_1 = 1, style_2 = 2)
  expect_equal(.auto_id("style_", lst), "style_0003")
})

test_that(".auto_id fills gaps in numeric suffixes (zero-padded)", {
  lst <- list(style_0001 = 1, style_0003 = 3)
  expect_equal(.auto_id("style_", lst), "style_0002")
})

test_that(".auto_id handles mixed padding and gaps", {
  lst <- list(style_1 = 1, style_0003 = 3)
  expect_equal(.auto_id("style_", lst), "style_0002")
})

test_that(".auto_id ignores non-matching names (zero-padded)", {
  lst <- list(foo = 1, bar = 2, style_a = 3)
  expect_equal(.auto_id("style_", lst), "style_0001")
})
