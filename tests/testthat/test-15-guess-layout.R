test_that(".guess_table_layout handles small dataframes", {
  df <- data.frame(
    id = 1:3,
    name = c("A", "BB", "CCC"),
    stringsAsFactors = FALSE
  )
  res <- .guess_table_layout(df)
  expect_true(is.list(res))
  expect_true(!is.null(res$formats))
  expect_equal(length(res$formats), ncol(df))
  expect_equal(names(res$formats), names(df))
  expect_equal(length(res$metadata), ncol(df))
})

test_that(".guess_table_layout handles zero-row dataframes", {
  df0 <- data.frame(
    id = integer(0),
    note = character(0),
    stringsAsFactors = FALSE
  )
  res0 <- .guess_table_layout(df0)
  expect_true(is.list(res0))
  expect_equal(length(res0$formats), ncol(df0))
  expect_equal(names(res0$formats), names(df0))
  expect_equal(length(res0$metadata), ncol(df0))
})

test_that(".guess_table_layout handles large dataframes without error", {
  set.seed(1)
  n <- 1000L
  df_large <- data.frame(
    x = rnorm(n),
    y = sample(letters, n, replace = TRUE),
    stringsAsFactors = FALSE
  )
  res_l <- .guess_table_layout(df_large)
  expect_true(is.list(res_l))
  expect_equal(length(res_l$formats), ncol(df_large))
  expect_equal(names(res_l$formats), names(df_large))
})

test_that(".guess_table_layout handles integer-like doubles safely", {
  df <- data.frame(
    int_like = c(1, 2 + 1e-9, NA_real_, 4),
    stringsAsFactors = FALSE
  )

  res <- NULL
  expect_no_error({
    res <- .guess_table_layout(df)
  })

  expect_equal(res$formats$int_like$type, "numeric")
  expect_equal(res$formats$int_like$format, "%d")
})

test_that(".guess_table_layout keeps decimal formats for non-integer doubles", {
  df <- data.frame(
    decimal_vals = c(12.5, 31.2, 50, 43.8),
    stringsAsFactors = FALSE
  )

  res <- .guess_table_layout(df)
  expect_equal(res$formats$decimal_vals$type, "numeric")
  expect_equal(res$formats$decimal_vals$format, "%.1f")
})
