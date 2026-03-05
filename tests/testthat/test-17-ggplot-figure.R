# ============================================================================
# Test: ggplot2 integration via create_figure()
# ============================================================================

# Helper: build a minimal ggplot2 object
make_plot <- function() {
  skip_if_not_installed("ggplot2")
  ggplot2::ggplot(mtcars, ggplot2::aes(x = wt, y = mpg)) +
    ggplot2::geom_point()
}

# Helper: temporary output directory
create_test_dir <- function() {
  d <- tempfile(pattern = "ksTFL_ggtest_")
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

# ============================================================================
# .save_ggplot_to_temp() — unit tests
# ============================================================================

test_that(".save_ggplot_to_temp() creates an SVG file by default", {
  skip_if_not_installed("ggplot2")
  p <- make_plot()
  path <- ksTFL:::.save_ggplot_to_temp(p)
  expect_true(file.exists(path))
  expect_match(path, "\\.svg$", ignore.case = TRUE)
  unlink(path)
})

test_that(".save_ggplot_to_temp() respects device = 'jpeg'", {
  skip_if_not_installed("ggplot2")
  p <- make_plot()
  path <- ksTFL:::.save_ggplot_to_temp(p, device = "jpeg")
  expect_true(file.exists(path))
  expect_match(path, "\\.jpeg$", ignore.case = TRUE)
  unlink(path)
})

test_that(".save_ggplot_to_temp() respects device = 'jpg' alias", {
  skip_if_not_installed("ggplot2")
  p <- make_plot()
  path <- ksTFL:::.save_ggplot_to_temp(p, device = "jpg")
  expect_true(file.exists(path))
  expect_match(path, "\\.jpeg$", ignore.case = TRUE)
  unlink(path)
})

test_that(".save_ggplot_to_temp() respects device = 'svg'", {
  skip_if_not_installed("ggplot2")
  p <- make_plot()
  path <- ksTFL:::.save_ggplot_to_temp(p, device = "svg")
  expect_true(file.exists(path))
  expect_match(path, "\\.svg$", ignore.case = TRUE)
  unlink(path)
})

test_that(".save_ggplot_to_temp() rejects invalid device", {
  skip_if_not_installed("ggplot2")
  p <- make_plot()
  expect_error(
    ksTFL:::.save_ggplot_to_temp(p, device = "pdf"),
    "device"
  )
})

test_that(".save_ggplot_to_temp() rejects non-positive width", {
  skip_if_not_installed("ggplot2")
  p <- make_plot()
  expect_error(
    ksTFL:::.save_ggplot_to_temp(p, width = 0),
    "width"
  )
})

test_that(".save_ggplot_to_temp() rejects non-positive height", {
  skip_if_not_installed("ggplot2")
  p <- make_plot()
  expect_error(
    ksTFL:::.save_ggplot_to_temp(p, height = -1),
    "height"
  )
})

test_that(".save_ggplot_to_temp() rejects non-positive dpi", {
  skip_if_not_installed("ggplot2")
  p <- make_plot()
  expect_error(
    ksTFL:::.save_ggplot_to_temp(p, dpi = 0),
    "dpi"
  )
})

# ============================================================================
# create_figure() — accepts ggplot2 objects
# ============================================================================

test_that("create_figure() accepts a ggplot2 object and returns TFL_spec", {
  skip_if_not_installed("ggplot2")
  p <- make_plot()
  spec <- create_figure(p)
  expect_s3_class(spec, "TFL_spec")
  expect_equal(spec$document$docType, "Figure")
  expect_true(is.list(spec$figure))
  expect_true(!is.null(spec$figure$figureScaleMode))
})

test_that("create_figure() uses figure defaults from options", {
  skip_if_not_installed("ggplot2")
  old <- tfl_get_options()
  on.exit(.options_env$settings <- old, add = TRUE)
  expect_warning(
    tfl_set_options(
      figureWidth = "70%",
      figureHeight = "50%",
      figureDevice = "png",
      figureScaleMode = "fitWidth"
    ),
    "Figure dimensions are ignored"
  )
  p <- make_plot()
  spec <- create_figure(p)
  expect_equal(spec$figure$width, old$figureWidth)
  expect_equal(spec$figure$height, old$figureHeight)
  expect_equal(spec$figure$device, "png")
  expect_equal(spec$figure$figureScaleMode, "fitWidth")
})

test_that("set_document() overrides figure settings", {
  skip_if_not_installed("ggplot2")
  p <- make_plot()
  spec <- expect_warning(
    create_figure(p) |>
      set_document(
        figureWidth = "8cm",
        figureHeight = "10cm",
        figureDevice = "svg",
        figureScaleMode = "fitPage"
      ),
    "Figure dimensions are ignored"
  )

  expect_equal(spec$figure$width, "6in")
  expect_equal(spec$figure$height, "4in")
  expect_equal(spec$figure$device, "svg")
  expect_equal(spec$figure$figureScaleMode, "fitPage")
})

test_that("set_document() warns and ignores explicit sizes in fit modes", {
  skip_if_not_installed("ggplot2")
  p <- make_plot()

  expect_warning(
    create_figure(p) |>
      set_document(
        figureWidth = "80%",
        figureHeight = "10cm",
        figureScaleMode = "fitWidth"
      ),
    "Figure dimensions are ignored"
  )
})

test_that("set_document() fills missing fixed dimension from defaults", {
  skip_if_not_installed("ggplot2")
  p <- make_plot()
  spec0 <- create_figure(p)
  spec0$figure$height <- NULL

  spec <- expect_warning(
    set_document(spec0, figureWidth = "7in", figureScaleMode = "fixed"),
    "Missing .*figureHeight"
  )

  expect_equal(spec$figure$width, "7in")
  expect_equal(spec$figure$height, "4in")
})

test_that("set_document() errors for mixed percent and absolute units", {
  skip_if_not_installed("ggplot2")
  p <- make_plot()

  expect_error(
    create_figure(p) |>
      set_document(figureWidth = "70%", figureHeight = "4in"),
    "Cannot mix percentage and absolute units"
  )
})

test_that("create_figure() stores a valid readable file path for ggplot2 input", {
  skip_if_not_installed("ggplot2")
  p <- make_plot()
  spec <- create_figure(p)
  stored_path <- spec$.metadata$filePath
  expect_true(is.character(stored_path))
  expect_true(file.exists(stored_path))
})

test_that("create_figure() stores SVG path by default for ggplot2 input", {
  skip_if_not_installed("ggplot2")
  p <- make_plot()
  spec <- create_figure(p)
  expect_match(spec$.metadata$filePath, "\\.svg$", ignore.case = TRUE)
})

test_that("create_figure() respects device = 'jpeg' for ggplot2 input", {
  skip_if_not_installed("ggplot2")
  old <- tfl_get_options()
  on.exit(.options_env$settings <- old, add = TRUE)
  tfl_set_options(figureDevice = "jpeg")
  p <- make_plot()
  spec <- create_figure(p)
  expect_match(spec$.metadata$filePath, "\\.jpeg$", ignore.case = TRUE)
  expect_true(file.exists(spec$.metadata$filePath))
})

test_that("create_figure() respects device = 'svg' for ggplot2 input", {
  skip_if_not_installed("ggplot2")
  old <- tfl_get_options()
  on.exit(.options_env$settings <- old, add = TRUE)
  tfl_set_options(figureDevice = "svg")
  p <- make_plot()
  spec <- create_figure(p)
  expect_match(spec$.metadata$filePath, "\\.svg$", ignore.case = TRUE)
  expect_true(file.exists(spec$.metadata$filePath))
})

test_that("create_figure() forwards width/height/dpi without error", {
  skip_if_not_installed("ggplot2")
  old <- tfl_get_options()
  on.exit(.options_env$settings <- old, add = TRUE)
  tfl_set_options(figureWidth = "8in", figureHeight = "5in")
  p <- make_plot()
  # Should not throw
  spec <- create_figure(p, dpi = 150L)
  expect_s3_class(spec, "TFL_spec")
  expect_true(file.exists(spec$.metadata$filePath))
})

test_that("create_figure() with ggplot2 object ignores filepath param name (positional)", {
  skip_if_not_installed("ggplot2")
  p <- make_plot()
  # Positional call — same as create_figure(plot_or_path = p)
  spec <- create_figure(p)
  expect_equal(spec$document$docType, "Figure")
})

test_that("create_figure() still accepts character file path (backward compat)", {
  spec <- create_figure(test_image_path)
  expect_s3_class(spec, "TFL_spec")
  expect_equal(spec$document$docType, "Figure")
})

test_that("create_figure() still rejects missing / invalid file path (backward compat)", {
  expect_error(
    create_figure("/nonexistent/path/to/image.png"),
    "readable"
  )
})

# ============================================================================
# Integration: ggplot2 figure through create_report() + save_report()
# ============================================================================

test_that("ggplot2 figure goes through create_report() without error", {
  skip_if_not_installed("ggplot2")
  p <- make_plot()
  spec   <- create_figure(p)
  report <- create_report(spec)
  expect_s3_class(report, "TFL_report")
  expect_equal(length(report), 1)
})

test_that("save_report() copies ggplot2 figure file to metaPath", {
  skip_if_not_installed("ggplot2")
  p      <- make_plot()
  spec   <- create_figure(p) |> add_title("ggplot Test Figure")
  report <- create_report(spec)
  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  result <- save_report(report, docFileName = "gg_fig.docx", metaPath = temp_dir)

  # Spec JSON should exist
  expect_true(file.exists(file.path(temp_dir, result$spec_file)))

  # Image file should be copied to metaPath
  spec_key  <- names(report)[1]
  data_ref  <- report[[spec_key]]$dataRef
  img_file  <- file.path(temp_dir, paste0(data_ref, ".svg"))
  expect_true(file.exists(img_file))
})

test_that("save_report() handles mixed Table + ggplot2 Figure report", {
  skip_if_not_installed("ggplot2")
  p         <- make_plot()
  spec_tbl  <- create_table(mtcars[1:5, ], cols = c(mpg, cyl, wt)) |>
    add_title("Cars Table")
  spec_fig  <- create_figure(p) |> add_title("Cars Figure")
  report    <- create_report(spec_tbl, spec_fig)

  temp_dir <- create_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  result <- save_report(report, docFileName = "mixed.docx", metaPath = temp_dir)
  expect_true(file.exists(file.path(temp_dir, result$spec_file)))

  # Table data JSON should exist
  tbl_key  <- names(report)[1]
  tbl_ref  <- report[[tbl_key]]$dataRef
  expect_true(file.exists(file.path(temp_dir, paste0(tbl_ref, ".json"))))

  # Figure SVG should exist
  fig_key  <- names(report)[2]
  fig_ref  <- report[[fig_key]]$dataRef
  expect_true(file.exists(file.path(temp_dir, paste0(fig_ref, ".svg"))))
})

test_that("dataRef for ggplot2 figure matches expected format", {
  skip_if_not_installed("ggplot2")
  p      <- make_plot()
  spec   <- create_figure(p)
  report <- create_report(spec)
  key    <- names(report)[1]
  data_ref <- report[[key]]$dataRef
  # Expected format: 4-digit padded docOrder + "_" + 16-char hex hash
  expect_match(data_ref, "^\\d{4}_[a-f0-9]{16}$")
})

# ============================================================================
# File path input — explicit coverage (non-ggplot2 tools, external images)
# ============================================================================

test_that("create_figure() accepts PNG file produced outside R (by path)", {
  spec <- create_figure(test_image_path)
  expect_s3_class(spec, "TFL_spec")
  expect_equal(spec$document$docType, "Figure")
  expect_equal(spec$.metadata$filePath, normalizePath(test_image_path, winslash = "/", mustWork = FALSE))
})

test_that("create_figure() accepts JPEG file path (non-ggplot2)", {
  tmp <- tempfile(fileext = ".jpeg")
  file.create(tmp)
  on.exit(unlink(tmp), add = TRUE)
  spec <- create_figure(tmp)
  expect_s3_class(spec, "TFL_spec")
  expect_match(spec$.metadata$filePath, "\\.jpeg$", ignore.case = TRUE)
})

test_that("create_figure() accepts SVG file path (non-ggplot2)", {
  tmp <- tempfile(fileext = ".svg")
  file.create(tmp)
  on.exit(unlink(tmp), add = TRUE)
  spec <- create_figure(tmp)
  expect_s3_class(spec, "TFL_spec")
  expect_match(spec$.metadata$filePath, "\\.svg$", ignore.case = TRUE)
})

test_that("create_figure() rejects unreadable file path with clear error", {
  expect_error(
    create_figure("/no/such/file.png"),
    "readable"
  )
})

# ============================================================================
# Type safety — unsupported input types
# ============================================================================

test_that("create_figure() rejects NULL with clear error", {
  expect_error(
    create_figure(NULL),
    "file path string or a ggplot2 object"
  )
})

test_that("create_figure() rejects numeric input with clear error", {
  expect_error(
    create_figure(42),
    "file path string or a ggplot2 object"
  )
})

test_that("create_figure() rejects list input with clear error", {
  expect_error(
    create_figure(list(a = 1)),
    "file path string or a ggplot2 object"
  )
})

test_that("create_figure() rejects character vector of length > 1", {
  expect_error(
    create_figure(c("a.png", "b.png")),
    "file path string or a ggplot2 object"
  )
})

test_that("create_figure() rejects recordedplot / grob objects with clear error", {
  # Simulate a non-ggplot2 graphics object
  grob_like <- structure(list(), class = "grob")
  expect_error(
    create_figure(grob_like),
    "file path string or a ggplot2 object"
  )
})
