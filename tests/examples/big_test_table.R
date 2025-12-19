set.seed(123)

n <- 100000

big_tbl <- tibble(
  id_int           = seq_len(n),
  group_int        = sample(1:10, n, TRUE),
  count_int        = sample(c(NA_integer_, 1:1000), n, TRUE),
  
  value_num        = rnorm(n, mean = 100, sd = 15),
  ratio_num        = runif(n),
  money_num        = round(rlnorm(n, 3, 0.5), 2),
  
  flag_logical     = sample(c(TRUE, FALSE, NA), n, TRUE),
  
  name_chr         = sample(c("Alice", "Bob", "Carlos", "Дмитрий", "测试"), n, TRUE),
  comment_chr      = sample(
    c(
      "short text",
      "longer descriptive text",
      "multi\nline\ntext",
      NA_character_
    ),
    n, TRUE
  ),
  
  code_chr         = sprintf("C%05d", sample(1:99999, n, TRUE)),
  
  category_fct     = factor(sample(LETTERS[1:5], n, TRUE)),
  
  date_date        = as.Date("2020-01-01") + sample(0:2000, n, TRUE),
  time_posix       = as.POSIXct("2020-01-01", tz = "UTC") +
    sample(0:(3600 * 24 * 365), n, TRUE),
  
  percent_num      = round(runif(n, 0, 100), 1),
  score_num        = sample(c(NA_real_, seq(0, 1, by = 0.01)), n, TRUE),
  
  text_utf8        = sample(
    c("café", "naïve", "über", "中文", "日本語", "한국어"),
    n, TRUE
  ),
  
  yesno_chr        = sample(c("yes", "no", NA_character_), n, TRUE),
  
  amount_big       = rnorm(n, 1e6, 5e4),
  
  id_chr           = paste0("ID-", sample(100000:999999, n, TRUE))
)

# add labels (optional but useful for testing)
attr(big_tbl$id_int, "label") <- "Record identifier"
attr(big_tbl$value_num, "label") <- "Measured value"
attr(big_tbl$comment_chr, "label") <- "User comment (may span\nmultiple lines)"
attr(big_tbl$text_utf8, "label") <- "International text"