# ============================================================================
# Test data and setup for ksTFL tests
# ============================================================================

# Deterministic fixtures: seed for the whole suite; any test that needs its
# own randomness re-seeds locally. (Regression 2026-09-29: large_df used
# unseeded sample()/rnorm(), so fixtures changed between runs.)
set.seed(42)

# Base-R ONLY here on purpose: setup files are evaluated before any test runs,
# so an undeclared hard dependency would abort the ENTIRE suite (tibble was a
# Suggests package: devtools::check() on a machine without tibble failed on
# line loadNamespace() - fixed 2026-09-29). Individual tests that specifically
# exercise tibble/vctrs input shapes declare their own
# skip_if_not_installed("tibble") guards (see test-12).

# Simple 3-column test data frame for width recalculation tests
test_df_simple <- data.frame(
  id    = 1:10,
  value = c(100, 105, 110, NA, 115, 120, 125, 130, NA, 140),
  ratio = c(0.1, 0.2, NA, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0)
)

attr(test_df_simple$id, "label") <- "Identifier"
attr(test_df_simple$value, "label") <- "Value (numeric)"
attr(test_df_simple$ratio, "label") <- "Ratio (0-1)"

# Simple test data frame with various types and missing values
test_df <- data.frame(
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

# Large test data with 1000 rows and various types (seeded via set.seed above)
large_df <- data.frame(
  idx       = 1:1000,
  val_int   = sample(c(NA, 1:100), 1000, replace = TRUE),
  val_num   = rnorm(1000, mean = 50, sd = 15),
  val_chr   = sample(c("A", "B", "C", NA), 1000, replace = TRUE),
  val_date  = as.Date("2020-01-01") + sample(0:365, 1000, replace = TRUE),
  val_pct   = round(runif(1000, 0, 100), 1)
)

# Valid PNG for figure tests: canonical 1x1 transparent PNG as raw bytes —
# fully deterministic, platform-independent, and a REAL image (the previous
# fixture was an empty file, which let tests assert against a non-decodable
# image; the renderer only checks readability, so semantic figure tests
# silently targeted invalid input).
.png_1x1 <- as.raw(c(
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x87, 0x00, 0x00, 0x00,
  0x0d, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82
))

# Test image path (real minimal PNG)
test_image_path <- tempfile(fileext = ".png")
writeBin(.png_1x1, test_image_path)

# Cleanup function for image
cleanup_test_image <- function() {
  if (file.exists(test_image_path)) {
    file.remove(test_image_path)
  }
}
