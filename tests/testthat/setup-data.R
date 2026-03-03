# ============================================================================
# Test data and setup for ksTFL tests
# ============================================================================

# Simple 3-column test data frame for width recalculation tests
test_df_simple <- tibble::tibble(
  id    = 1:10,
  value = c(100, 105, 110, NA, 115, 120, 125, 130, NA, 140),
  ratio = c(0.1, 0.2, NA, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0)
)

attr(test_df_simple$id, "label") <- "Identifier"
attr(test_df_simple$value, "label") <- "Value (numeric)"
attr(test_df_simple$ratio, "label") <- "Ratio (0-1)"

# Simple test data frame with various types and missing values
test_df <- tibble::tibble(
  id        = 1:10,
  group     = rep(c("A", "B"), 5),
  value     = c(100, 105, 110, NA, 115, 120, 125, 130, NA, 140),
  ratio     = c(0.1, 0.2, NA, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0),
  flag      = rep(c(TRUE, FALSE), 5),
  category  = factor(c("cat1", "cat2", "cat1", NA, "cat2", "cat1", "cat2", "cat1", "cat2", "cat1")),
  name      = c("Alice", "Bob", NA, "Diana", "Eve", "Frank", "Grace", "Henry", "Ivy", "Jack")
)

# Add labels to columns
attr(test_df$id, "label") <- "Identifier"
attr(test_df$group, "label") <- "Group"
attr(test_df$value, "label") <- "Value (numeric)"
attr(test_df$ratio, "label") <- "Ratio (0-1)"
attr(test_df$flag, "label") <- "Flag"
attr(test_df$category, "label") <- "Category"
attr(test_df$name, "label") <- "Person Name"

# Large test data with 1000 rows and various types
large_df <- tibble::tibble(
  idx       = 1:1000,
  val_int   = sample(c(NA, 1:100), 1000, replace = TRUE),
  val_num   = rnorm(1000, mean = 50, sd = 15),
  val_chr   = sample(c("A", "B", "C", NA), 1000, replace = TRUE),
  val_date  = as.Date("2020-01-01") + sample(0:365, 1000, replace = TRUE),
  val_pct   = round(runif(1000, 0, 100), 1)
)

# Test image path (will create a dummy file for testing)
test_image_path <- tempfile(fileext = ".png")
file.create(test_image_path)

# Cleanup function for image
cleanup_test_image <- function() {
  if (file.exists(test_image_path)) {
    file.remove(test_image_path)
  }
}
