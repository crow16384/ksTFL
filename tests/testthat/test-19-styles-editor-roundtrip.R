# test-19-styles-editor-roundtrip.R
# Regression tests for no-op save behavior in styles editor.

load_styles_editor_env <- function() {
  app_path <- normalizePath(testthat::test_path("../../inst/shiny/styles_editor/app.R"), mustWork = TRUE)
  app_dir <- dirname(app_path)

  env <- new.env(parent = baseenv())
  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(app_dir)
  source(app_path, local = env)
  env$bundled_templates_dir <- function() {
    normalizePath(file.path(app_dir, "..", "..", "templates"), mustWork = TRUE)
  }
  env
}

test_that("styles editor no-op preserves loaded template exactly", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("colourpicker")

  editor_env <- load_styles_editor_env()

  shiny::testServer(editor_env$server, {
    session$setInputs(bundled_template = "Carbon_Dark")
    session$setInputs(load_bundled = 1)
    session$flushReact()

    expect_false(has_user_edits())
    expect_true(identical(assembled_template(), current_template()))
  })
})

test_that("styles editor marks and applies real edits", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("colourpicker")

  editor_env <- load_styles_editor_env()

  shiny::testServer(editor_env$server, {
    session$setInputs(bundled_template = "Carbon_Dark")
    session$setInputs(load_bundled = 1)
    session$flushReact()

    before <- current_template()

    session$setInputs(doc_margin_top = "9in")
    session$flushReact()

    expect_true(has_user_edits())
    expect_false(identical(assembled_template(), before))
    expect_equal(assembled_template()$document$page$margins$top, "9in")
  })
})

test_that("styles editor persists table empty-line layout edits", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("colourpicker")

  editor_env <- load_styles_editor_env()

  shiny::testServer(editor_env$server, {
    session$setInputs(bundled_template = "Carbon_Dark")
    session$setInputs(load_bundled = 1)
    session$flushReact()

    session$setInputs(tbl_top_empty_line = "6pt")
    session$setInputs(tbl_bottom_empty_line = "8pt")
    session$flushReact()

    expect_true(has_user_edits())
    expect_equal(assembled_template()$tableStyle$layout$topEmptyLine, "6pt")
    expect_equal(assembled_template()$tableStyle$layout$bottomEmptyLine, "8pt")
  })
})

test_that("no-op CRO_Example_default download preserves null and absent fields in JSON", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("colourpicker")

  editor_env <- load_styles_editor_env()

  shiny::testServer(editor_env$server, {
    session$setInputs(bundled_template = "CRO_Example_default")
    session$setInputs(load_bundled = 1)
    session$flushReact()

    expect_false(has_user_edits())

    # No-op download should use the original JSON text
    raw_json <- original_json_text()
    expect_true(nzchar(raw_json))

    # Verify the original JSON text preserves null values
    expect_true(grepl('"background_color":\\s*null', raw_json))
    expect_true(grepl('"width":\\s*null', raw_json))
    expect_true(grepl('"color":\\s*null', raw_json))

    # Verify text_orientation is NOT present (missing optional field)
    expect_false(grepl('"text_orientation"', raw_json))

    # Verify docHeader does NOT have indents block
    original <- jsonlite::fromJSON(raw_json, simplifyDataFrame = FALSE)
    expect_null(original$textStyles$docHeader$paragraph$indents)
  })
})

test_that("edited CRO_Example_default does not inject defaults for unedited protected fields", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("colourpicker")

  editor_env <- load_styles_editor_env()

  shiny::testServer(editor_env$server, {
    session$setInputs(bundled_template = "CRO_Example_default")
    session$setInputs(load_bundled = 1)
    session$flushReact()

    # Make a single unrelated edit
    session$setInputs(doc_margin_top = "2in")
    session$flushReact()

    expect_true(has_user_edits())

    tmpl <- assembled_template()

    # Verify the edit was applied
    expect_equal(tmpl$document$page$margins$top, "2in")

    # Protected: background_color should remain NULL (serializes as null), not a hex default
    expect_null(tmpl$tableStyle$header$row$background_color)
    expect_null(tmpl$tableStyle$body$row$background_color)

    # Protected: text_orientation must NOT be injected
    expect_false("text_orientation" %in% names(tmpl$tableStyle$header$row))
    expect_false("text_orientation" %in% names(tmpl$tableStyle$body$row))

    # Protected: docHeader must NOT have indents (absent in original)
    expect_null(tmpl$textStyles$docHeader$paragraph$indents)
    expect_null(tmpl$textStyles$docFooter$paragraph$indents)

    # Protected: body row border null colors/widths should be NULL
    body_borders <- tmpl$tableStyle$body$row$borders
    expect_null(body_borders$top$color)
    expect_null(body_borders$top$width)
    expect_null(body_borders$bottom$color)
    expect_null(body_borders$bottom$width)

    # Verify serialized JSON also reflects these semantics
    json <- jsonlite::toJSON(tmpl, auto_unbox = TRUE, pretty = TRUE, null = "null")

    # No hex color defaults for background_color
    expect_false(grepl('"background_color":\\s*"[0-9A-Fa-f]', json))
    # background_color serialized as null
    expect_true(grepl('"background_color":\\s*null', json))
    # No text_orientation injected
    expect_false(grepl('"text_orientation"', json))
  })
})
