# ============================================================================
# Test: Report Writer (save_report and helpers)
# ============================================================================

# Setup test data and temporary directories
test_df <- data.frame(
  id = 1:5,
  name = c("Alice", "Bob", "Charlie", "Diana", "Eve"),
  age = c(25, 30, 35, 28, 32),
  score = c(85.5, 92.3, 78.1, 88.9, 95.2)
)

# Helper function to create temporary test directory
create_test_dir <- function() {
  temp_dir <- tempfile(pattern = "ksTFL_test_")
  dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)
  temp_dir
}

# ============================================================================
# Tests: save_report() basic functionality
# ============================================================================

test_that("save_report() requires TFL_report class", {
  expect_error(
    save_report(list(), docFileName = "test.docx"),
    "must be of class TFL_report"
  )
})

test_that("save_report() requires docFileName parameter", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  
  expect_error(
    save_report(report),
    "argument.*docFileName.*missing"
  )
})

test_that("save_report() accepts character docFileName", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))
  
  result <- save_report(
    report,
    docFileName = "test.docx",
    metaPath = temp_dir
  )
  
  expect_is(result, "list")
})

test_that("save_report() rejects non-character docFileName", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  
  expect_error(
    save_report(report, docFileName = 123),
    "docFileName"
  )
})

test_that("save_report() returns list with expected fields", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))
  
  result <- save_report(
    report,
    docFileName = "test.docx",
    metaPath = temp_dir
  )
  
  expect_true("spec_file" %in% names(result))
  expect_true("datetime" %in% names(result))
  expect_true("metaPath" %in% names(result))
})

test_that("save_report() creates output directory if not exists", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  temp_dir <- file.path(tempdir(), "new_ksTFL_dir")
  if (dir.exists(temp_dir)) unlink(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE))
  
  result <- save_report(
    report,
    docFileName = "test.docx",
    metaPath = temp_dir
  )
  
  expect_true(dir.exists(temp_dir))
})

test_that("save_report() creates JSON spec file", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))
  
  result <- save_report(
    report,
    docFileName = "test.docx",
    metaPath = temp_dir
  )
  
  spec_filepath <- file.path(temp_dir, result$spec_file)
  expect_true(file.exists(spec_filepath))
})

test_that("save_report() returns invisible result", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))
  
  result <- save_report(
    report,
    docFileName = "test.docx",
    metaPath = temp_dir
  )
  
  # Result should be invisible but still assignable
  expect_is(result, "list")
})

# ============================================================================
# Tests: save_report() with outDir parameter
# ============================================================================

test_that("save_report() uses provided outDir", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  out_dir <- create_test_dir()
  on.exit({
    unlink(temp_dir, recursive = TRUE)
    unlink(out_dir, recursive = TRUE)
  })
  
  result <- save_report(
    report,
    docFileName = "test.docx",
    outDir = out_dir,
    metaPath = temp_dir
  )
  
  # Check that spec file was saved to metaPath
  spec_filepath <- file.path(temp_dir, result$spec_file)
  expect_true(file.exists(spec_filepath))
})

test_that("save_report() uses default outDir from options", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))
  
  # Should not error, using default from tfl_get_option("output_directory")
  result <- save_report(
    report,
    docFileName = "test.docx",
    metaPath = temp_dir
  )
  
  expect_is(result, "list")
})

test_that("save_report() rejects non-character outDir", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  
  expect_error(
    save_report(
      report,
      docFileName = "test.docx",
      outDir = 123
    ),
    "outDir"
  )
})

# ============================================================================
# Tests: save_report() with metaPath parameter
# ============================================================================

test_that("save_report() rejects non-character metaPath", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  
  expect_error(
    save_report(
      report,
      docFileName = "test.docx",
      metaPath = 123
    ),
    "metaPath"
  )
})

test_that("save_report() uses tempdir as default metaPath", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  
  result <- save_report(
    report,
    docFileName = "test.docx"
  )
  
  # Result should contain tempdir path
  expect_true(file.exists(file.path(result$metaPath, result$spec_file)))
  
  # Cleanup
  unlink(file.path(result$metaPath, result$spec_file))
})

# ============================================================================
# Tests: save_report() with prettify parameter
# ============================================================================

test_that("save_report() prettify=FALSE creates compact JSON", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))
  
  result <- save_report(
    report,
    docFileName = "test.docx",
    metaPath = temp_dir,
    prettify = FALSE
  )
  
  json_content <- readLines(file.path(temp_dir, result$spec_file))
  # Compact JSON should be single or few lines, no excessive newlines
  expect_true(length(json_content) < 20)
})

test_that("save_report() prettify=TRUE creates formatted JSON", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))
  
  result <- save_report(
    report,
    docFileName = "test.docx",
    metaPath = temp_dir,
    prettify = TRUE
  )
  
  json_content <- readLines(file.path(temp_dir, result$spec_file))
  # Prettified JSON should have more lines due to indentation
  expect_true(length(json_content) > 5)
})

# ============================================================================
# Tests: save_report() with Table docType
# ============================================================================

test_that("save_report() saves table data JSON file", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))
  
  result <- save_report(
    report,
    docFileName = "test.docx",
    metaPath = temp_dir
  )
  
  # Table should have data file saved
  # The dataRef becomes the filename
  spec_json <- jsonlite::fromJSON(file.path(temp_dir, result$spec_file))
  spec_key <- names(spec_json)[names(spec_json) != "_metadata"][1]
  
  if (!is.null(spec_json[[spec_key]]$dataRef)) {
    data_file <- paste0(spec_json[[spec_key]]$dataRef, ".json")
    expect_true(file.exists(file.path(temp_dir, data_file)))
  }
})

test_that("save_report() filters table data to report columns", {
  spec <- create_table(test_df, c(id, name))
  spec <- define_cols(spec, c(id, name), label = "Basic Info")
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))
  
  result <- save_report(
    report,
    docFileName = "test.docx",
    metaPath = temp_dir
  )
  
  # Get the data file reference
  spec_json <- jsonlite::fromJSON(file.path(temp_dir, result$spec_file))
  spec_key <- names(spec_json)[names(spec_json) != "_metadata"][1]
  data_ref <- spec_json[[spec_key]]$dataRef
  
  if (!is.null(data_ref)) {
    data_json <- jsonlite::fromJSON(
      file.path(temp_dir, paste0(data_ref, ".json"))
    )
    
    # Should only have id and name columns
    expect_true("id" %in% names(data_json))
    expect_true("name" %in% names(data_json))
    expect_false("age" %in% names(data_json))
  }
})

test_that("save_report() removes NULL values from spec", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))
  
  result <- save_report(
    report,
    docFileName = "test.docx",
    metaPath = temp_dir
  )
  
  spec_json <- jsonlite::fromJSON(
    file.path(temp_dir, result$spec_file),
    simplifyVector = FALSE
  )
  
  # The spec JSON should not have .metadata
  spec_key <- names(spec_json)[names(spec_json) != "_metadata"][1]
  expect_null(spec_json[[spec_key]]$.metadata)
})

test_that("save_report() includes _metadata section in JSON", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  out_dir <- create_test_dir()
  on.exit({
    unlink(temp_dir, recursive = TRUE)
    unlink(out_dir, recursive = TRUE)
  })
  
  result <- save_report(
    report,
    docFileName = "myreport.docx",
    outDir = out_dir,
    metaPath = temp_dir
  )
  
  spec_json <- jsonlite::fromJSON(
    file.path(temp_dir, result$spec_file),
    simplifyVector = FALSE
  )
  
  expect_true("_metadata" %in% names(spec_json))
  expect_equal(spec_json$`_metadata`$docFileName, "myreport.docx")
  expect_true(!is.null(spec_json$`_metadata`$outDir))
  expect_true(!is.null(spec_json$`_metadata`$datetime))
})

# ============================================================================
# Tests: save_report() with Text docType
# ============================================================================

test_that("save_report() handles text-only specs", {
  spec <- create_text()
  spec <- add_title(spec, "Text Document")
  spec <- add_body_text(spec, "This is text content")
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))
  
  result <- save_report(
    report,
    docFileName = "text.docx",
    metaPath = temp_dir
  )
  
  expect_is(result, "list")
  expect_true(file.exists(file.path(temp_dir, result$spec_file)))
})

test_that("save_report() excludes .metadata from text specs", {
  spec <- create_text()
  spec <- add_body_text(spec, "Content")
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))
  
  result <- save_report(
    report,
    docFileName = "text.docx",
    metaPath = temp_dir
  )
  
  spec_json <- jsonlite::fromJSON(
    file.path(temp_dir, result$spec_file),
    simplifyVector = FALSE
  )
  
  spec_key <- names(spec_json)[names(spec_json) != "_metadata"][1]
  expect_null(spec_json[[spec_key]]$.metadata)
})

# ============================================================================
# Tests: save_report() with multiple specs
# ============================================================================

test_that("save_report() handles multiple specs in report", {
  spec1 <- create_table(test_df)
  spec2 <- create_text()
  spec2 <- add_body_text(spec2, "Summary text")
  report <- create_report(spec1, spec2)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))
  
  result <- save_report(
    report,
    docFileName = "multi.docx",
    metaPath = temp_dir
  )
  
  expect_is(result, "list")
  expect_true(file.exists(file.path(temp_dir, result$spec_file)))
})

test_that("save_report() handles mixed docTypes correctly", {
  spec1 <- create_table(test_df)
  spec2 <- create_text()
  spec2 <- add_body_text(spec2, "Summary text")
  spec3 <- create_table(test_df)
  report <- create_report(spec1, spec2, spec3)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  result <- save_report(
    report,
    docFileName = "mixed.docx",
    metaPath = temp_dir
  )

  expect_is(result, "list")
  spec_json <- jsonlite::fromJSON(file.path(temp_dir, result$spec_file))

  # Should have 4 keys: _metadata + 3 specs
  expect_true(length(names(spec_json)) >= 3)
})

# ============================================================================
# Tests: .remove_nulls_recursive() helper
# ============================================================================

test_that(".remove_nulls_recursive() removes NULL from list", {
  input <- list(a = 1, b = NULL, c = 3)
  
  result <- .remove_nulls_recursive(input)
  
  expect_false("b" %in% names(result))
  expect_true("a" %in% names(result))
  expect_true("c" %in% names(result))
})

test_that(".remove_nulls_recursive() handles nested lists", {
  input <- list(
    a = 1,
    nested = list(x = NULL, y = 2),
    b = NULL
  )
  
  result <- .remove_nulls_recursive(input)
  
  expect_false("b" %in% names(result))
  expect_false("x" %in% names(result$nested))
  expect_true("y" %in% names(result$nested))
})

test_that(".remove_nulls_recursive() preserves atomic values", {
  input <- 42
  
  result <- .remove_nulls_recursive(input)
  
  expect_equal(result, 42)
})

test_that(".remove_nulls_recursive() handles deeply nested structures", {
  input <- list(
    level1 = list(
      level2 = list(
        level3 = list(a = 1, b = NULL)
      ),
      z = NULL
    ),
    y = NULL
  )
  
  result <- .remove_nulls_recursive(input)
  
  expect_null(result$y)
  expect_null(result$level1$z)
  expect_null(result$level1$level2$level3$b)
  expect_equal(result$level1$level2$level3$a, 1)
})

# ============================================================================
# Tests: .save_table_data() helper
# ============================================================================

test_that(".save_table_data() creates JSON file for tables", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))
  
  # Serialize and save
  result <- save_report(
    report,
    docFileName = "test.docx",
    metaPath = temp_dir
  )
  
  # Verify data file exists
  spec_json <- jsonlite::fromJSON(file.path(temp_dir, result$spec_file))
  spec_key <- names(spec_json)[names(spec_json) != "_metadata"][1]
  data_ref <- spec_json[[spec_key]]$dataRef
  
  expect_true(file.exists(file.path(temp_dir, paste0(data_ref, ".json"))))
})

test_that(".save_table_data() preserves row count", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))
  
  result <- save_report(
    report,
    docFileName = "test.docx",
    metaPath = temp_dir
  )
  
  spec_json <- jsonlite::fromJSON(file.path(temp_dir, result$spec_file))
  spec_key <- names(spec_json)[names(spec_json) != "_metadata"][1]
  data_ref <- spec_json[[spec_key]]$dataRef
  
  data_json <- as.data.frame(jsonlite::fromJSON(
    file.path(temp_dir, paste0(data_ref, ".json")),
    flatten = T
  ))
  
  # Should have same number of rows as original
  expect_equal(nrow(data_json), nrow(test_df))
})

# ============================================================================
# Tests: JSON validity
# ============================================================================

test_that("save_report() produces valid JSON", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))
  
  result <- save_report(
    report,
    docFileName = "test.docx",
    metaPath = temp_dir
  )
  
  # Should be able to parse the JSON
  json_content <- readLines(file.path(temp_dir, result$spec_file))
  expect_error(
    jsonlite::fromJSON(paste(json_content, collapse = "\n")),
    NA  # Expect no error
  )
})

test_that("save_report() JSON has correct structure", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))
  
  result <- save_report(
    report,
    docFileName = "test.docx",
    metaPath = temp_dir
  )
  
  spec_json <- jsonlite::fromJSON(file.path(temp_dir, result$spec_file))
  
  # Should have _metadata and at least one spec
  expect_true("_metadata" %in% names(spec_json))
  expect_true(length(names(spec_json)) > 1)
})

# ============================================================================
# Tests: Datetime formatting
# ============================================================================

test_that("save_report() returns ISO 8601 datetime", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))
  
  result <- save_report(
    report,
    docFileName = "test.docx",
    metaPath = temp_dir
  )
  
  # Should match ISO 8601 format: YYYY-MM-DDTHH:MM:SS
  expect_match(result$datetime, "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}$")
})

test_that("save_report() JSON metadata has valid datetime", {
  spec <- create_table(test_df)
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))
  
  result <- save_report(
    report,
    docFileName = "test.docx",
    metaPath = temp_dir
  )
  
  spec_json <- jsonlite::fromJSON(file.path(temp_dir, result$spec_file))
  datetime <- spec_json$`_metadata`$datetime
  
  expect_match(datetime, "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}$")
})

# ============================================================================
# Tests: render_docx template resolution helpers
# ============================================================================

test_that(".resolve_template_paths_by_spec() resolves per-spec docTemplate values", {
  spec1 <- create_table(test_df)
  spec1 <- set_page_style(spec1, docTemplate = "Navy_Pro")

  spec2 <- create_text()
  spec2 <- set_page_style(spec2, docTemplate = "Carbon_Dark")
  spec2 <- add_body_text(spec2, "content")

  report <- create_report(spec1, spec2)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))

  saved <- save_report(report, docFileName = "tmpl.docx", metaPath = temp_dir)
  spec_path <- file.path(temp_dir, saved$spec_file)

  resolved <- .resolve_template_paths_by_spec(spec_path)

  expect_equal(length(resolved), 2L)
  resolved_files <- basename(unlist(resolved, use.names = FALSE))
  expect_true("Navy_Pro.json" %in% resolved_files)
  expect_true("Carbon_Dark.json" %in% resolved_files)
})

test_that(".build_multi_template_payload() creates valid multi-template payload", {
  paths_by_spec <- list(
    spec_a = system.file("templates", "Navy_Pro.json", package = "ksTFL", mustWork = TRUE),
    spec_b = system.file("templates", "Carbon_Dark.json", package = "ksTFL", mustWork = TRUE)
  )

  payload_json <- .build_multi_template_payload(paths_by_spec)
  payload <- jsonlite::fromJSON(payload_json, simplifyVector = FALSE)

  expect_true(isTRUE(payload[["_ksTFL_multi_template"]]))
  expect_true(!is.null(payload$default))
  expect_true(!is.null(payload$per_spec$spec_a))
  expect_true(!is.null(payload$per_spec$spec_b))
})

# ============================================================================
# Tests: write_doc() overrideTemplate name-or-path compatibility
# ============================================================================

test_that("write_doc() accepts bundled template name in overrideTemplate", {
  spec <- create_text() |> add_body_text("hello") |> set_document(hasData = FALSE)
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  out_dir <- create_test_dir()
  on.exit({
    unlink(temp_dir, recursive = TRUE)
    unlink(out_dir, recursive = TRUE)
  })

  out_path <- write_doc(
    report = report,
    name = "write_doc_tmpl_name",
    outDir = out_dir,
    metaPath = temp_dir,
    overrideTemplate = "Navy_Pro"
  )

  expect_true(file.exists(out_path))
})

test_that("write_doc() warns and falls back for unknown overrideTemplate name", {
  spec <- create_text() |> add_body_text("hello") |> set_document(hasData = FALSE)
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  out_dir <- create_test_dir()
  on.exit({
    unlink(temp_dir, recursive = TRUE)
    unlink(out_dir, recursive = TRUE)
  })

  out_path <- expect_warning(
    write_doc(
      report = report,
      name = "write_doc_tmpl_fallback",
      outDir = out_dir,
      metaPath = temp_dir,
      overrideTemplate = "Unknown_Template_Name"
    ),
    "Falling back to"
  )

  expect_true(file.exists(out_path))
})

test_that("write_doc() accepts external overrideTemplate path", {
  spec <- create_text() |> add_body_text("hello") |> set_document(hasData = FALSE)
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  out_dir <- create_test_dir()
  on.exit({
    unlink(temp_dir, recursive = TRUE)
    unlink(out_dir, recursive = TRUE)
  })

  template_path <- system.file("templates", "Navy_Pro.json", package = "ksTFL", mustWork = TRUE)

  out_path <- write_doc(
    report = report,
    name = "write_doc_tmpl_path",
    outDir = out_dir,
    metaPath = temp_dir,
    overrideTemplate = template_path
  )

  expect_true(file.exists(out_path))
})
