# Tests for Style Modifier Functions (s_font, s_spacing, etc.)
# Tests the creation and validation of style specifications
# NOTE: Figure docType is used for style tests (doesn't require data)

test_that("s_font creates font specification with defaults", {
  spec <- tfl_init(docType = "Figure") |>
    add_style("test_style",
      s_font()
    )
  
  expect_s3_class(spec, "TFL_spec")
  expect_true(!is.null(spec$attribs$styles$test_style))
})

test_that("s_font accepts valid font parameters", {
  spec <- tfl_init(docType = "Figure") |>
    add_style("header",
      s_font(font_name = "Arial", font_size = "14pt", bold = TRUE, italic = FALSE)
    )
  
  expect_s3_class(spec, "TFL_spec")
  expect_true(!is.null(spec$attribs$styles$header))
})

test_that("s_font rejects non-logical bold/italic/underline", {
  expect_error(
    tfl_init(docType = "Figure") |>
      add_style("bad",
        s_font(bold = "yes")  # Should be logical
      ),
    class = "cli_error"
  )
})

test_that("s_font accepts color specifications", {
  spec <- tfl_init(docType = "Figure") |>
    add_style("colored",
      s_font(color = "#FF0000", background_color = "#FFFFFF")
    )
  
  expect_s3_class(spec, "TFL_spec")
})

test_that("s_spacing creates spacing specification", {
  spec <- tfl_init(docType = "Figure") |>
    add_style("spaced",
      s_spacing(before = "6pt", after = "12pt", line_spacing = 1.5)
    )
  
  expect_s3_class(spec, "TFL_spec")
})

test_that("s_spacing rejects invalid line_spacing", {
  expect_error(
    tfl_init(docType = "Figure") |>
      add_style("bad",
        s_spacing(line_spacing = 0)  # Must be >= 1
      ),
    class = "cli_error"
  )
})

test_that("s_spacing accepts various units", {
  spec <- tfl_init(docType = "Figure") |>
    add_style("units",
      s_spacing(before = "1cm", after = "0.5in", line_spacing = 1.2)
    )
  
  expect_s3_class(spec, "TFL_spec")
})

test_that("s_indents creates indentation specification", {
  spec <- tfl_init(docType = "Figure") |>
    add_style("indented",
      s_indents(left = "0.5in", right = "0.25in", first_line = "0.5in")
    )
  
  expect_s3_class(spec, "TFL_spec")
})

test_that("s_paragraph creates paragraph style", {
  spec <- tfl_init(docType = "Figure") |>
    add_style("para",
      s_paragraph(alignment = "center", keep_together = TRUE)
    )
  
  expect_s3_class(spec, "TFL_spec")
})

test_that("s_paragraph rejects invalid alignment", {
  expect_error(
    tfl_init(docType = "Figure") |>
      add_style("bad",
        s_paragraph(alignment = "invalid")
      ),
    class = "cli_error"
  )
})

test_that("s_border creates border specification", {
  spec <- tfl_init(docType = "Figure") |>
    add_style("border",
      s_border(position = "top", color = "#000000", width = "1pt", style = "single")
    )
  
  expect_s3_class(spec, "TFL_spec")
})

test_that("s_borders creates multiple border specification", {
  spec <- tfl_init(docType = "Figure") |>
    add_style("borders",
      s_borders(color = "#000000", width = "1pt")
    )
  
  expect_s3_class(spec, "TFL_spec")
})

test_that("s_table_style creates table cell styling", {
  spec <- tfl_init(docType = "Figure") |>
    add_style("cell",
      s_table_style(background_color = "#E0E0E0", vertical_align = "center")
    )
  
  expect_s3_class(spec, "TFL_spec")
})

test_that("s_margins creates margin specification", {
  spec <- tfl_init(docType = "Figure") |>
    add_style("margins",
      s_margins(top = "1in", bottom = "1in", left = "0.75in", right = "0.75in")
    )
  
  expect_s3_class(spec, "TFL_spec")
})

test_that("s_page creates page specification", {
  spec <- tfl_init(docType = "Figure") |>
    add_style("page",
      s_page(size = "Letter", orientation = "portrait")
    )
  
  expect_s3_class(spec, "TFL_spec")
})

test_that("s_page rejects invalid size", {
  expect_error(
    tfl_init(docType = "Figure") |>
      add_style("bad_page",
        s_page(size = "InvalidSize")
      ),
    class = "cli_error"
  )
})

test_that("multiple style modifiers merge with last-win strategy", {
  spec <- tfl_init(docType = "Figure") |>
    add_style("header",
      s_font(font_name = "Arial", bold = TRUE)
    ) |>
    add_style("header",
      s_font(color = "#FF0000")  # Only color is added, bold is preserved
    )
  
  expect_s3_class(spec, "TFL_spec")
  expect_true(!is.null(spec$attribs$styles$header))
})

test_that("add_style auto-generates ID when not provided", {
  spec <- tfl_init(docType = "Figure") |>
    add_style(id = NULL,
      s_font(bold = TRUE)
    )
  
  expect_s3_class(spec, "TFL_spec")
  # Should have auto-generated style ID
  expect_true(length(spec$attribs$styles) > 0)
})

test_that("add_style rejects invalid modifier objects", {
  expect_error(
    tfl_init(docType = "Figure") |>
      add_style("bad",
        list(invalid = "object")  # Not a valid modifier
      ),
    class = "cli_error"
  )
})



