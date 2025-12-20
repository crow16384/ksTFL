# ============================================================================
# Test: Style Creation and Management
# ============================================================================

test_that("add_style() creates a new style", {
  spec <- create_text()
  spec <- add_style(spec, id = "my_bold", s_font(bold = TRUE))
  
  expect_true("my_bold" %in% names(spec$attribs$styles))
  expect_true(!is.null(spec$attribs$styles$my_bold))
})

test_that("add_style() with font properties", {
  spec <- create_text()
  spec <- add_style(spec, id = "styled_font", 
    s_font(font_name = "Arial", font_size = '12pt', bold = TRUE, color = "blue")
  )
  
  style <- spec$attribs$styles$styled_font
  expect_equal(style$font$font_name, "Arial")
  expect_equal(style$font$bold, TRUE)
  expect_equal(style$font$font_size, '12pt')
  expect_equal(style$font$color, '#0000FF')
})

test_that("add_style() with multiple font properties", {
  spec <- create_text()
  spec <- add_style(spec, id = "multi_font", 
    s_font(bold = TRUE, italic = TRUE, underline = TRUE)
  )
  
  style <- spec$attribs$styles$multi_font
  expect_equal(style$font$bold, TRUE)
  expect_equal(style$font$italic, TRUE)
  expect_equal(style$font$underline, TRUE)
})

test_that("add_style() with table style and borders", {
  spec <- create_text()
  spec <- add_style(spec, id = "bordered", 
    s_table_style(background_color = "#CCCCCC",
      borders = s_borders(
        bottom = s_border(width = "1pt", line_style = "single")
      )
    )
  )
  
  style <- spec$attribs$styles$bordered
  expect_equal(style$table_style$background_color, "#CCCCCC")
  expect_true(!is.null(style$table_style$borders$bottom))
})

test_that("add_style() with paragraph style", {
  spec <- create_text()
  spec <- add_style(spec, id = "indented_para",
    s_paragraph(spacing = s_spacing(line_spacing = 1.5, before = '1cm'))
  )
  
  style <- spec$attribs$styles$indented_para
  expect_true(!is.null(style$paragraph))
  expect_true(!is.null(style$paragraph$spacing))
  expect_equal(style$paragraph$spacing$line_spacing, 1.5)
})


test_that("add_style() rejects invalid nesting (s_borders outside s_table_style)", {
  spec <- create_text()
  
  expect_error(
    add_style(spec, id = "bad_style", s_borders()),
    "can only be used inside|wrong context"
  )
})

test_that("add_style() on TFL_spec returns modified spec", {
  spec <- create_text()
  result <- add_style(spec, id = "test_style", s_font(bold = TRUE))
  
  expect_s3_class(result, "TFL_spec")
  expect_true("test_style" %in% names(result$attribs$styles))
})

test_that("add_style() with color name", {
  spec <- create_text()
  spec <- add_style(spec, id = "colored", s_font(color = "red"))
  
  style <- spec$attribs$styles$colored
  expect_equal(style$font$color, "#FF0000")
})

test_that("add_style() with hex color", {
  spec <- create_text()
  spec <- add_style(spec, id = "hex_colored", s_font(color = "#FF0000"))
  
  style <- spec$attribs$styles$hex_colored
  expect_equal(style$font$color, "#FF0000")
})

test_that("add_style() with vertical alignment", {
  spec <- create_text()
  spec <- add_style(spec, id = "v_aligned",
    s_table_style(vertical_alignment = "center")
  )
  
  style <- spec$attribs$styles$v_aligned
  expect_equal(style$table_style$vertical_alignment, "center")
})

test_that("add_style() with multiple borders", {
  spec <- create_text()
  spec <- add_style(spec, id = "box_border",
    s_table_style(borders = s_borders(
      top = s_border(width = "1pt", color = "#000000"),
      bottom = s_border(width = "1pt", color = "#000000"),
      left = s_border(width = "1pt", color = "#000000"),
      right = s_border(width = "1pt", color = "#000000")
    ))
  )
  
  style <- spec$attribs$styles$box_border
  expect_true(!is.null(style$table_style$borders$top))
  expect_true(!is.null(style$table_style$borders$bottom))
  expect_true(!is.null(style$table_style$borders$left))
  expect_true(!is.null(style$table_style$borders$right))
})

test_that("add_style() with indentation", {
  spec <- create_text()
  spec <- add_style(spec, id = "indented",
    s_paragraph(indents = s_indents(left = "0.5in"))
  )
  
  style <- spec$attribs$styles$indented
  expect_true(!is.null(style$paragraph$indents))
})

test_that("add_style() last-win mege", {
  spec <- create_text()
  spec <- add_style(spec, id = "indented",
                    s_paragraph(indents = s_indents(left = "0.5in"))
  )
  
  style <- spec$attribs$styles$indented
  expect_equal(style$paragraph$indents$left, "0.5in")
  expect_true(is.null(style$paragraph$spacing$line_spacing))
  
  spec <- add_style(spec, id = "indented",
                   s_paragraph(indents = s_indents(left = "1in"),spacing = s_spacing(line_spacing = 1.5))
  )
  
  style <- spec$attribs$styles$indented
  expect_equal(style$paragraph$indents$left, "1in")
  expect_equal(style$paragraph$spacing$line_spacing, 1.5)
  
})

