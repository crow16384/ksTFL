# Tests for Context Manipulation Functions (add_title, add_subtitle, etc.)
# Tests require proper context setup via tfl_init()

test_that("add_title adds title to spec", {
  spec <- tfl_init() |>
    add_title("Main Title")
  
  expect_s3_class(spec, "TFL_spec")
  expect_true(length(spec$titles) > 0)
})

test_that("add_title accepts display level", {
  spec <- tfl_init() |>
    add_title("Title", displayLevel = "primary")
  
  expect_s3_class(spec, "TFL_spec")
})

test_that("add_title auto-generates ID when not provided", {
  spec <- tfl_init() |>
    add_title("Title 1") |>
    add_title("Title 2")
  
  expect_true(length(spec$titles) == 2)
})

test_that("add_subtitle adds subtitle to spec", {
  spec <- tfl_init() |>
    add_subtitle("Subtitle Text")
  
  expect_s3_class(spec, "TFL_spec")
  expect_true(length(spec$subtitles) > 0)
})

test_that("add_footnote adds footnote to spec", {
  spec <- tfl_init() |>
    add_footnote("Footnote Text")
  
  expect_s3_class(spec, "TFL_spec")
  expect_true(length(spec$footnotes) > 0)
})

test_that("add_footnote with placement option", {
  spec <- tfl_init() |>
    add_footnote("Note", placement = "bottom")
  
  expect_s3_class(spec, "TFL_spec")
})

test_that("add_body_text adds body text to spec", {
  spec <- tfl_init() |>
    add_body_text("Body text content")
  
  expect_s3_class(spec, "TFL_spec")
  expect_true(length(spec$bodyText) > 0)
})

test_that("add_header adds header to spec", {
  spec <- tfl_init() |>
    add_header("Header Content")
  
  expect_s3_class(spec, "TFL_spec")
  expect_true(length(spec$headers) > 0)
})

test_that("add_footer adds footer to spec", {
  spec <- tfl_init() |>
    add_footer("Footer Content")
  
  expect_s3_class(spec, "TFL_spec")
  expect_true(length(spec$footers) > 0)
})

test_that("add_stub_column adds stub column definition", {
  spec <- tfl_init(data = mtcars, docType = "Table") |>
    add_stub_column("cyl")
  
  expect_s3_class(spec, "TFL_spec")
  expect_true(length(spec$stubColumns) > 0)
})

test_that("add_stub_column requires context", {
  expect_error(
    add_stub_column(tfl_init(), "col"),
    class = "cli_error"
  )
})

test_that("set_document sets document properties", {
  spec <- tfl_init() |>
    set_document(
      bodyTitles = TRUE,
      contentWidth = "90%"
    )
  
  expect_s3_class(spec, "TFL_spec")
})

test_that("set_document_style sets document style reference", {
  spec <- tfl_init() |>
    set_document_style(
      docTemplate = "default_template",
      docStyleRef = "standard_style"
    )
  
  expect_s3_class(spec, "TFL_spec")
})

test_that("define_cols adds column definitions to spec", {
  spec <- tfl_init(data = mtcars, docType = "Table") |>
    define_cols(
      "mpg",
      label = "Miles per Gallon",
      c_format(type = "numeric", format = "%.1f")
    )
  
  expect_s3_class(spec, "TFL_spec")
})

test_that("define_cols requires proper context", {
  expect_error(
    define_cols(tfl_init(), "col"),
    class = "cli_error"
  )
})

test_that("c_format creates column format specification", {
  spec <- tfl_init(data = mtcars, docType = "Table") |>
    define_cols(
      "cyl",
      c_format(type = "numeric", format = "%d")
    )
  
  expect_s3_class(spec, "TFL_spec")
})

test_that("c_format rejects invalid type", {
  spec <- tfl_init(data = mtcars, docType = "Table")
  
  expect_error(
    spec |> define_cols(
      "cyl",
      c_format(type = "invalid")
    ),
    class = "cli_error"
  )
})

test_that("c_format with all parameters", {
  spec <- tfl_init(data = mtcars, docType = "Table") |>
    define_cols(
      "mpg",
      label = "MPG",
      c_format(
        type = "numeric",
        format = "%.2f",
        colWidth = "15%",
        valueStyleRef = "numeric_style"
      )
    )
  
  expect_s3_class(spec, "TFL_spec")
})

test_that("multiple title/subtitle/footnote calls accumulate", {
  spec <- tfl_init() |>
    add_title("Title 1") |>
    add_title("Title 2") |>
    add_subtitle("Subtitle 1") |>
    add_subtitle("Subtitle 2")
  
  expect_true(length(spec$titles) == 2)
  expect_true(length(spec$subtitles) == 2)
})

test_that("add_title with explicit ID", {
  spec <- tfl_init() |>
    add_title("Custom ID Title", id = "my_title")
  
  expect_true("my_title" %in% names(spec$titles))
})
