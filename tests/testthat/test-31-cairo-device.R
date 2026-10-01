# ============================================================================
# Test: cairo figure device (default since 2026-10-01) — Finding-Office-SVG-
# text-crop integration.
#
# Contract pinned here:
#   * figureDevice default is "cairo" and produces a paths-only SVG
#     (zero <text elements) — the MS Word safety gate (skill fact #42).
#   * "svg" (svglite) still works but warns once per session (Word-unsafe).
#   * fallback chain cairo -> svg -> png with warn-once; figure production
#     never dies on a missing suggested package.
#   * the spec records the device that ACTUALLY produced the file and the
#     spec schema enum now accepts "cairo".
# ============================================================================

# Self-contained helpers (testthat does not share file scopes)
cairo_plot <- function() {
  skip_if_not_installed("ggplot2")
  ggplot2::ggplot(mtcars, ggplot2::aes(x = wt, y = mpg)) +
    ggplot2::geom_point()
}
cairo_skip_no_svg <- function() skip_if_not_installed("svglite")

reset_svg_warn <- function() ksTFL:::.reset_warn_once()

opts_restore <- function(.env = parent.frame()) {
  old <- ksTFL:::.options_env$settings
  defer_baked(bquote(assign("settings", .(old), envir = ksTFL:::.options_env)),
              env = .env)
}

test_that("default device produces a paths-only SVG (Word-safety gate)", {
  skip_if_not_installed("Cairo")
  p <- cairo_plot()
  path <- ksTFL:::.save_ggplot_to_temp(p)  # function default = cairo
  on.exit(unlink(path))
  expect_match(path, "\\.svg$", ignore.case = TRUE)
  txt <- paste(readLines(path, warn = FALSE), collapse = "")
  n_text <- length(regmatches(txt, gregexpr("<text", txt))[[1]])
  expect_identical(n_text, 0L)                # no <text elements at all
  expect_match(txt, "<path", fixed = TRUE)    # glyphs as vector paths
})

test_that("session default option is cairo", {
  skip_if_not_installed("Cairo")
  opts_restore()
  tfl_reset_options()
  expect_identical(tfl_get_option("figureDevice"), "cairo")
})

test_that("create_figure() default device stores svg path, records cairo", {
  skip_if_not_installed("Cairo")
  p <- cairo_plot()
  spec <- create_figure(p)
  expect_match(spec$.metadata$filePath, "\\.svg$", ignore.case = TRUE)
  expect_identical(spec$figure$device, "cairo")
  unlink(spec$.metadata$filePath)
})

test_that("figureDevice 'svg' warns once per session about Word", {
  cairo_skip_no_svg()
  reset_svg_warn()
  p <- cairo_plot()
  path1 <- expect_warning(
    ksTFL:::.save_ggplot_to_temp(p, device = "svg"), "Word")
  unlink(path1)
  # second call in the same session: silent (warn-once contract)
  p2 <- cairo_plot()
  path2 <- expect_warning(
    ksTFL:::.save_ggplot_to_temp(p2, device = "svg"), regexp = NA)
  unlink(path2)
  reset_svg_warn()
})

test_that("png device stays warning-free", {
  reset_svg_warn()
  p <- cairo_plot()
  path <- expect_warning(ksTFL:::.save_ggplot_to_temp(p, device = "png"),
                         regexp = NA)
  expect_match(path, "\\.png$", ignore.case = TRUE)
  unlink(path)
})

test_that("cairo fallback chain: no Cairo -> svg (warn once per session)", {
  cairo_skip_no_svg()
  reset_svg_warn()
  local_mocked_bindings(
    .fig_ns_available = function(pkg) pkg != "Cairo",
    .package = "ksTFL"
  )
  d <- expect_warning(ksTFL:::.resolve_figure_device("cairo"), "Cairo")
  expect_identical(d, "svg")
  d2 <- expect_warning(ksTFL:::.resolve_figure_device("cairo"), regexp = NA)
  expect_identical(d2, "svg")
  reset_svg_warn()
})

test_that("cairo fallback chain: no Cairo no svglite -> png", {
  reset_svg_warn()
  local_mocked_bindings(
    .fig_ns_available = function(pkg) FALSE,
    .package = "ksTFL"
  )
  d <- expect_warning(ksTFL:::.resolve_figure_device("cairo"), "png")
  expect_identical(d, "png")
  reset_svg_warn()
})

test_that("svg with missing svglite is served via cairo (Word-safe upgrade)", {
  skip_if_not_installed("Cairo")
  reset_svg_warn()
  local_mocked_bindings(
    .fig_ns_available = function(pkg) pkg == "Cairo",
    .package = "ksTFL"
  )
  d <- expect_warning(ksTFL:::.resolve_figure_device("svg"), "svglite")
  expect_identical(d, "cairo")
  reset_svg_warn()
})

test_that("create_figure records the actual device after a fallback", {
  cairo_skip_no_svg()
  opts_restore()
  reset_svg_warn()
  local_mocked_bindings(
    .fig_ns_available = function(pkg) pkg != "Cairo",
    .package = "ksTFL"
  )
  tfl_set_options(figureDevice = "cairo")
  p <- cairo_plot()
  suppressWarnings(spec <- create_figure(p))  # fallback warns once
  # spec must record the device that ACTUALLY produced the file
  expect_identical(spec$figure$device, "svg")
  unlink(spec$.metadata$filePath)
  reset_svg_warn()
})

test_that("cairo figures pass spec schema validation (enum updated)", {
  skip_if_not_installed("Cairo")
  p <- cairo_plot()
  spec <- create_figure(p)
  report <- create_report(spec)
  res <- tryCatch(ksTFL:::serialize_spec(report), error = function(e) e)
  expect_false(inherits(res, "error"),
               info = if (inherits(res, "error")) conditionMessage(res) else "")
  expect_true("fixed" %in% names(res))
  unlink(spec$.metadata$filePath)
})

test_that("invalid device choices are still rejected", {
  p <- cairo_plot()
  expect_error(ksTFL:::.save_ggplot_to_temp(p, device = "pdf"), "device")
  expect_error(tfl_set_options(figureDevice = "pdf"), "figureDevice")
})
