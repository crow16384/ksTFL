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
