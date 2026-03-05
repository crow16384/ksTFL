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

test_that("add_style() accepts table empty-line settings", {
  spec <- create_text()
  spec <- add_style(
    spec,
    id = "empty_line_style",
    s_table_style(topEmptyLine = "6pt", bottomEmptyLine = "4pt")
  )

  style <- spec$attribs$styles$empty_line_style
  expect_equal(style$table_style$topEmptyLine, "6pt")
  expect_equal(style$table_style$bottomEmptyLine, "4pt")
})

test_that("set_document() accepts table empty-line settings", {
  spec <- create_table(iris)
  spec <- set_document(spec, topEmptyLine = "6pt", bottomEmptyLine = "8pt")

  expect_equal(spec$document$topEmptyLine, "6pt")
  expect_equal(spec$document$bottomEmptyLine, "8pt")
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

test_that("add_style() accepts multiple nested modifiers on TFL_spec (strict checks)", {
  spec <- create_text()
  res <- add_style(spec, id = "combo_style",
                   s_font(font_name = "Arial", font_size = "12pt", bold = TRUE),
                   s_paragraph(alignment = "center", spacing = s_spacing(before = "4pt")),
                   s_table_style(background_color = "#EFEFEF")
  )

  expect_true("combo_style" %in% names(res$attribs$styles))
  st <- res$attribs$styles$combo_style
  expect_equal(st$font$font_name, "Arial")
  expect_equal(st$font$font_size, "12pt")
  expect_equal(st$font$bold, TRUE)
  expect_equal(st$paragraph$alignment, "center")
  expect_equal(st$paragraph$spacing$before, "4pt")
  expect_equal(st$table_style$background_color, "#EFEFEF")
})

test_that("add_style() accepts multiple nested modifiers on TFL_options (strict checks)", {
  opts <- tfl_get_options()

  res_opts <- add_style(opts, id = "opt_combo",
                        s_font(font_name = "Arial", font_size = "11pt"),
                        s_paragraph(alignment = "left"),
                        s_table_style(background_color = "#FFFFFF")
  )

  expect_true("opt_combo" %in% names(res_opts$styles))
  st2 <- res_opts$styles$opt_combo
  expect_equal(st2$font$font_name, "Arial")
  expect_equal(st2$font$font_size, "11pt")
  expect_equal(st2$paragraph$alignment, "left")
  expect_equal(st2$table_style$background_color, "#FFFFFF")
})

test_that("set_page_style() accepts nested p_page on TFL_spec and TFL_options", {
  # TFL_spec
  spec <- create_text()
  spec2 <- set_page_style(spec,
                          page = p_page(size = "A4", orientation = "landscape",
                                        margins = p_margins(top = "25mm", bottom = "25mm")))
  expect_equal(spec2$attribs$documentStyle$page$size, "A4")
  expect_equal(spec2$attribs$documentStyle$page$orientation, "landscape")
  expect_equal(spec2$attribs$documentStyle$page$margins$top, "25mm")

  # TFL_options: modify global session settings via tfl_set_options()
  old_opts <- tfl_get_options()
  # Use tfl_set_options() with a helper call; tfl_set_options parses the call
  tfl_set_options(set_page_style(page = p_page(size = "Letter", orientation = "portrait",
                                               margins = p_margins(top = "1in", bottom = "1in"))))
  opts_now <- tfl_get_options()
  expect_equal(opts_now$page$size, "Letter")
  expect_equal(opts_now$page$orientation, "portrait")
  expect_equal(opts_now$page$margins$top, "1in")
  # restore previous session options
  tfl_set_options(old_opts)
})

test_that("add_style() on TFL_options accepts nested s_borders/s_border", {
  opts <- tfl_get_options()
  opts2 <- add_style(opts, id = "opt_border",
                     s_table_style(background_color = "#DDDDDD",
                                   borders = s_borders(bottom = s_border(width = "2pt", color = "#000000"))))
  expect_true("opt_border" %in% names(opts2$styles))
  st <- opts2$styles$opt_border
  expect_equal(st$table_style$background_color, "#DDDDDD")
  expect_equal(st$table_style$borders$bottom$width, "2pt")
  expect_equal(st$table_style$borders$bottom$color, "#000000")
})

