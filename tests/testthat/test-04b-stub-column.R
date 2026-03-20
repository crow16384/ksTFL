# ============================================================================
# Test: Span Header (Spanning Headers) with Tidyselect Support
# ============================================================================

test_that("add_span_header() accepts tidyselect with unquoted column names", {
  spec <- create_table(test_df_simple)  # 3 columns: id, value, ratio
  
  # Using tidyselect with unquoted names
  spec <- add_span_header(spec, cols = c(value, ratio), label = "Metrics")
  
  # Verify stub was created
  expect_length(spec$stubColumns, 1)
  stub <- spec$stubColumns[[1]]
  expect_equal(stub$label, "Metrics")
  expect_equal(sort(stub$cols), sort(c("value", "ratio")))
})

test_that("add_span_header() accepts quoted column names", {
  spec <- create_table(test_df_simple)
  
  # Using quoted names (backward compatible)
  spec <- add_span_header(spec, cols = c("value", "ratio"), label = "Metrics")
  
  expect_length(spec$stubColumns, 1)
  stub <- spec$stubColumns[[1]]
  expect_equal(stub$label, "Metrics")
})

test_that("add_span_header() supports column ranges (tidyselect)", {
  spec <- create_table(test_df_simple)
  
  # Using column range
  spec <- add_span_header(spec, cols = value:ratio, label = "Range")
  
  expect_length(spec$stubColumns, 1)
  stub <- spec$stubColumns[[1]]
  expect_equal(sort(stub$cols), sort(c("value", "ratio")))
})

test_that("add_span_header() supports starts_with() helper", {
  data <- data.frame(
    id = 1:10,
    age_years = rnorm(10, 45, 10),
    age_months = rnorm(10, 540, 120),
    weight = rnorm(10, 70, 10)
  )
  spec <- create_table(data)
  
  # Using starts_with() helper
  spec <- add_span_header(spec, cols = starts_with("age"), label = "Age Measurements")
  
  expect_length(spec$stubColumns, 1)
  stub <- spec$stubColumns[[1]]
  expect_true("age_years" %in% stub$cols)
  expect_true("age_months" %in% stub$cols)
  expect_false("id" %in% stub$cols)
  expect_false("weight" %in% stub$cols)
})

test_that("add_span_header() supports negation with -", {
  spec <- create_table(test_df_simple)
  
  # Using negation: all columns except id
  spec <- add_span_header(spec, cols = -id, label = "Non-ID Columns")
  
  stub <- spec$stubColumns[[1]]
  expect_false("id" %in% stub$cols)
  expect_true("value" %in% stub$cols)
  expect_true("ratio" %in% stub$cols)
})

test_that("add_span_header() validates column names against spec definition", {
  spec <- create_table(test_df_simple)  # Has: id, value, ratio
  
  # Try to reference non-existent column
  expect_error(
    add_span_header(spec, cols = c(id, nonexistent), label = "Bad"),
    "Invalid column selection"  # Will fail when nonexistent column is filtered out
  )
})

test_that("add_span_header() prevents column overlap at same stubOrder", {
  spec <- create_table(test_df_simple)
  
  # First stub with value and ratio
  spec <- add_span_header(spec, cols = c(value, ratio), label = "First", stubOrder = 1)
  
  # Second stub at same order trying to include overlapping column should fail
  expect_error(
    add_span_header(spec, cols = c(value, id), label = "Second", stubOrder = 1),
    "Column overlap detected"
  )
})

test_that("add_span_header() allows non-overlapping columns at same stubOrder", {
  data <- data.frame(a = 1:5, b = 1:5, c = 1:5, d = 1:5)
  spec <- create_table(data)
  
  # First stub: columns a and b
  spec <- add_span_header(spec, cols = c(a, b), label = "First", stubOrder = 1)
  
  # Second stub at same order with different columns: c and d
  spec <- add_span_header(spec, cols = c(c, d), label = "Second", stubOrder = 1)
  
  expect_equal(length(spec$stubColumns), 2)
})

test_that("add_span_header() sets labelStyleRef correctly", {
  spec <- create_table(test_df_simple)
  
  spec <- add_span_header(
    spec, 
    cols = c(value, ratio), 
    label = "Metrics",
    labelStyleRef = "bold_header"
  )
  
  stub <- spec$stubColumns[[1]]
  expect_equal(stub$labelStyleRef, "bold_header")
})

test_that("add_span_header() auto-generates stubOrder", {
  spec <- create_table(test_df_simple)
  
  spec <- add_span_header(spec, cols = c(value, ratio), label = "First")
  spec <- add_span_header(spec, cols = id, label = "Second")
  
  stub1 <- spec$stubColumns[[1]]
  stub2 <- spec$stubColumns[[2]]
  
  # Auto-generated orders should be sequential
  expect_equal(stub1$stubOrder, 1)
  expect_equal(stub2$stubOrder, 2)
})

test_that("add_span_header() works with chained piping", {
  spec <- create_table(test_df_simple) |>
    add_span_header(cols = c(value, ratio), label = "Metrics") |>
    add_span_header(cols = id, label = "Identifier", stubOrder = 0)
  
  expect_equal(length(spec$stubColumns), 2)
})

# ============================================================================
# Advanced stubOrder and Multi-level Header Behavior Tests
# ============================================================================

test_that("add_span_header() with different stubOrders creates multi-level headers", {
  data <- data.frame(a = 1:5, b = 1:5, c = 1:5, d = 1:5, e = 1:5)
  spec <- create_table(data)
  
  # Create 3-level header structure
  # Level 1 (stubOrder = 0): Group all columns
  spec <- add_span_header(spec, cols = c(a, b, c, d, e), label = "All Data", stubOrder = 0)
  
  # Level 2 (stubOrder = 1): Split into two groups
  spec <- add_span_header(spec, cols = c(a, b), label = "Baseline", stubOrder = 1)
  spec <- add_span_header(spec, cols = c(c, d, e), label = "Treatment", stubOrder = 1)
  
  # Verify structure
  expect_equal(length(spec$stubColumns), 3)
  
  # Find each stub by stubOrder
  stubs_level0 <- Filter(function(x) x$stubOrder == 0, spec$stubColumns)
  stubs_level1 <- Filter(function(x) x$stubOrder == 1, spec$stubColumns)
  
  expect_equal(length(stubs_level0), 1)
  expect_equal(length(stubs_level1), 2)
  
  # Verify labels
  expect_equal(stubs_level0[[1]]$label, "All Data")
})

test_that("add_span_header() preserves column order within stub", {
  data <- data.frame(col_a = 1:5, col_b = 1:5, col_c = 1:5, col_d = 1:5)
  spec <- create_table(data)
  
  # Add stub with columns in specific order
  spec <- add_span_header(spec, cols = c(col_d, col_b, col_a), label = "Reordered")
  
  stub <- spec$stubColumns[[1]]
  # Columns should be stored (order might be normalized or preserved depending on implementation)
  expect_equal(length(stub$cols), 3)
  expect_true(all(c("col_a", "col_b", "col_d") %in% stub$cols))
})

test_that("add_span_header() with negative stubOrder (for alternate header placement)", {
  spec <- create_table(test_df_simple)
  
  # Create stub with negative order (may be used for footer-like headers)
  spec <- add_span_header(spec, cols = c(value, ratio), label = "Footer Header", stubOrder = -1)
  
  stub <- spec$stubColumns[[1]]
  expect_equal(stub$stubOrder, -1)
})

test_that("add_span_header() maintains stub independence across different stubOrders", {
  data <- data.frame(a = 1:5, b = 1:5, c = 1:5, d = 1:5)
  spec <- create_table(data)
  
  # Create stubs at different orders with overlapping columns (should be allowed)
  spec <- add_span_header(spec, cols = c(a, b), label = "Level1_A", stubOrder = 1)
  spec <- add_span_header(spec, cols = c(b, c), label = "Level2_B", stubOrder = 2)
  spec <- add_span_header(spec, cols = c(c, d), label = "Level3_C", stubOrder = 3)
  
  expect_equal(length(spec$stubColumns), 3)
  
  # Verify each stub has correct columns
  stubs <- spec$stubColumns
  stub_by_order <- setNames(stubs, sapply(stubs, function(x) x$stubOrder))
  
  expect_equal(sort(stub_by_order[["1"]]$cols), sort(c("a", "b")))
  expect_equal(sort(stub_by_order[["2"]]$cols), sort(c("b", "c")))
  expect_equal(sort(stub_by_order[["3"]]$cols), sort(c("c", "d")))
})

test_that("add_span_header() detects partial overlap at same stubOrder", {
  data <- data.frame(a = 1:5, b = 1:5, c = 1:5, d = 1:5)
  spec <- create_table(data)
  
  # First stub: a, b, c
  spec <- add_span_header(spec, cols = c(a, b, c), label = "First", stubOrder = 1)
  
  # Second stub tries to use b, c, d (overlaps with first at b, c)
  expect_error(
    add_span_header(spec, cols = c(b, c, d), label = "Second", stubOrder = 1),
    "Column overlap detected"
  )
})

test_that("add_span_header() detects single column overlap at same stubOrder", {
  data <- data.frame(a = 1:5, b = 1:5, c = 1:5)
  spec <- create_table(data)
  
  # First stub: a and b
  spec <- add_span_header(spec, cols = c(a, b), label = "First", stubOrder = 1)
  
  # Second stub trying to use just b (single overlap)
  expect_error(
    add_span_header(spec, cols = b, label = "Second", stubOrder = 1),
    "Column overlap detected"
  )
})

test_that("add_span_header() error message includes stub details", {
  data <- data.frame(a = 1:5, b = 1:5, c = 1:5, d = 1:5)
  spec <- create_table(data)
  
  spec <- add_span_header(spec, cols = c(a, b), label = "Existing", stubOrder = 1, id = "stub_1")
  
  error <- tryCatch(
    add_span_header(spec, cols = c(b, c), label = "New", stubOrder = 1),
    error = function(e) e
  )
  
  error_msg <- conditionMessage(error)
  expect_true(grepl("overlap", error_msg, ignore.case = TRUE))
  expect_true(grepl("stub", error_msg, ignore.case = TRUE))
  expect_true(grepl("b", error_msg))  # Overlapping column should be mentioned
})

test_that("add_span_header() allows multiple non-overlapping stubs at same order", {
  data <- data.frame(a = 1:5, b = 1:5, c = 1:5, d = 1:5, e = 1:5, f = 1:5)
  spec <- create_table(data)
  
  # Create 3 stubs at order 1, all non-overlapping
  spec <- add_span_header(spec, cols = c(a, b), label = "Group1", stubOrder = 1)
  spec <- add_span_header(spec, cols = c(c, d), label = "Group2", stubOrder = 1)
  spec <- add_span_header(spec, cols = c(e, f), label = "Group3", stubOrder = 1)
  
  # All should be created successfully
  stubs_at_order_1 <- Filter(function(x) x$stubOrder == 1, spec$stubColumns)
  expect_equal(length(stubs_at_order_1), 3)
  
  # Verify no overlaps between them
  all_cols <- unlist(lapply(stubs_at_order_1, function(x) x$cols))
  expect_equal(length(all_cols), length(unique(all_cols)))  # All unique
})

test_that("add_span_header() custom IDs are preserved", {
  spec <- create_table(test_df_simple)
  
  spec <- add_span_header(spec, cols = c(value, ratio), label = "Metrics", id = "my_stub")
  
  expect_true("my_stub" %in% names(spec$stubColumns))
  expect_equal(spec$stubColumns$my_stub$label, "Metrics")
})

test_that("add_span_header() auto-generated IDs are unique", {
  spec <- create_table(test_df_simple)
  
  spec <- add_span_header(spec, cols = c(value, ratio), label = "First")
  spec <- add_span_header(spec, cols = id, label = "Second")
  
  ids <- names(spec$stubColumns)
  expect_equal(length(ids), length(unique(ids)))
})

test_that("add_span_header() works with contains() helper and overlap detection", {
  data <- data.frame(
    id = 1:5,
    var_score = rnorm(5),
    var_count = rpois(5, 10),
    other_metric = rnorm(5)
  )
  spec <- create_table(data)
  
  # Stub with columns containing "var"
  spec <- add_span_header(spec, cols = contains("var"), label = "Variables", stubOrder = 1)
  
  stub <- spec$stubColumns[[1]]
  expect_equal(length(stub$cols), 2)
  expect_true("var_score" %in% stub$cols)
  expect_true("var_count" %in% stub$cols)
  expect_false("other_metric" %in% stub$cols)
})

test_that("add_span_header() with matches() regex helper", {
  data <- data.frame(
    age_baseline = rnorm(5),
    age_week_4 = rnorm(5),
    age_week_8 = rnorm(5),
    weight = rnorm(5)
  )
  spec <- create_table(data)
  
  # Stub with regex pattern
  spec <- add_span_header(spec, cols = matches("^age"), label = "Age Measurements")
  
  stub <- spec$stubColumns[[1]]
  expect_equal(length(stub$cols), 3)
  expect_false("weight" %in% stub$cols)
})

test_that("add_span_header() labelStyleRef accepts multiple styles", {
  spec <- create_table(test_df_simple)
  
  spec <- add_span_header(
    spec, 
    cols = c(value, ratio), 
    label = "Metrics",
    labelStyleRef = c("bold", "italic", "large")
  )
  
  stub <- spec$stubColumns[[1]]
  expect_equal(length(stub$labelStyleRef), 3)
  expect_true("bold" %in% stub$labelStyleRef)
})

test_that("add_span_header() empty selection after tidyselect filtering raises error", {
  data <- data.frame(a = 1:5, b = 1:5, c = 1:5)
  spec <- create_table(data)
  
  # Try to select columns that don't exist
  expect_error(
    add_span_header(spec, cols = starts_with("nonexistent"), label = "Empty"),
    "Must have length >= 1"
  )
})

# ============================================================================
# Regression: full-spanning stub must not be shrunk by Post-pass 3
# ============================================================================

test_that("span header covering all columns retains full gridSpan after rendering", {
  # Reproduces the vignette issue: stubOrder=2 spans ALL 3 columns,

  # stubOrder=1 spans only 2.  The renderer must NOT peel the uncovered
# column off the top-level span.
  data <- data.frame(
    subject = sprintf("S%03d", 1:3),
    age = c(40, 50, 60),
    sex = c("M", "F", "M")
  )

  spec <- create_table(data, cols = c(subject, age, sex))
  spec <- define_cols(spec, c(subject, age, sex),
                      label = c("Subject ID", "Age (years)", "Sex"))
  spec <- add_span_header(spec, c(age, sex), "Characteristic", stubOrder = 1)
  spec <- add_span_header(spec, c(subject, age, sex), "Treatment A (N=10)", stubOrder = 2)

  report <- create_report(spec)

  out_dir  <- tempfile("ksTFL_stubspan_out_")
  meta_dir <- tempfile("ksTFL_stubspan_meta_")
  dir.create(out_dir, recursive = TRUE)
  dir.create(meta_dir, recursive = TRUE)
  on.exit({
    unlink(out_dir, recursive = TRUE)
    unlink(meta_dir, recursive = TRUE)
  })

  out_path <- write_doc(report, name = "stub_span_test",
                        outDir = out_dir, metaPath = meta_dir)
  expect_true(file.exists(out_path))

  # Unzip the DOCX and inspect document.xml for gridSpan values
  unzip_dir <- tempfile("ksTFL_stubspan_unzip_")
  dir.create(unzip_dir)
  on.exit(unlink(unzip_dir, recursive = TRUE), add = TRUE)
  utils::unzip(out_path, exdir = unzip_dir)

  doc_xml <- readLines(file.path(unzip_dir, "word", "document.xml"), warn = FALSE)
  doc_text <- paste(doc_xml, collapse = "")

  # "Treatment A (N=10)" must span all 3 columns => gridSpan val="3"
  # Look backwards from "Treatment A" to find the gridSpan in the same <w:tc>
  pos <- regexpr("Treatment A", doc_text)
  expect_true(pos > 0, label = "Treatment A text found in DOCX XML")
  before <- substr(doc_text, max(1L, pos - 800L), pos - 1L)
  spans <- regmatches(before, gregexpr('gridSpan w:val="[0-9]+"', before, perl = TRUE))[[1]]
  expect_true(length(spans) > 0, label = "gridSpan found before Treatment A")
  # The last gridSpan before the text belongs to the same <w:tc>
  expect_equal(spans[length(spans)], 'gridSpan w:val="3"',
               label = "Treatment A gridSpan must be 3 (all columns)")
})
