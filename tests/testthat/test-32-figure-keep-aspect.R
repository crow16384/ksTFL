# ============================================================================
# Test: figureScaleMode = "fitKeepAR" (step 9 / F01)
#
# The renderer reads the embedded file's intrinsic aspect (PNG IHDR, JPEG
# SOFn, SVG width/height -> viewBox) and fits it into the body area. These
# tests pin the EMITTED drawing extent (wp:extent cx/cy) — the only ground
# truth that matters for MS Word — using deterministic vector fixtures at
# known aspect ratios. Rcpp::Rcerr diagnostics are NOT asserted here (C-level
# stderr bypasses R sinks); the behavior contracts are.
# ============================================================================

# helper: write a pure-vector SVG with an exact pixel size (AR = w/h)
svg_file <- function(dir, w_px, h_px, name = "src.svg", attrs = c("width", "height")) {
  a <- if (length(attrs) == 2L) {
    sprintf('width="%d" height="%d"', w_px, h_px)
  } else if (identical(attrs, "viewBox")) {
    sprintf('viewBox="0 0 %d %d"', w_px, h_px)
  } else ""
  svg <- sprintf('<svg xmlns="http://www.w3.org/2000/svg" %s><rect width="%d" height="%d" fill="#36c"/></svg>',
                 a, w_px, h_px)
  f <- file.path(dir, name)
  writeLines(svg, f)
  f
}

# helper: extent cx/cy (EMU) of the first drawing in a DOCX
figure_extent <- function(docx) {
  x <- docx_part_text(docx)
  m <- regmatches(x, regexpr('<wp:extent cx="[0-9]+" cy="[0-9]+"', x))
  if (!length(m)) return(NULL)
  nums <- as.numeric(regmatches(m, gregexpr("[0-9]+", m))[[1]])
  c(cx = nums[1], cy = nums[2])
}

render_figure <- function(src, mode, tag = NULL, dirs, ...) {
  dots <- list(...)
  args <- c(list(spec = create_figure(src), hasData = FALSE, figureDevice = "svg",
                 figureScaleMode = mode), dots)
  spec <- suppressWarnings(do.call(set_document, args))
  name <- tag %||% paste0("fka_", gsub("[^a-zA-Z0-9]", "_", mode))
  suppressWarnings(write_doc(create_report(spec), name,
                             outDir = dirs$out, metaPath = dirs$meta, verbose = FALSE))
}

test_that("fitKeepAR preserves a wide source AR (4:1 SVG width/height)", {
  dirs <- local_docx_dirs()
  src <- svg_file(dirs$out, 800, 200)
  p <- render_figure(src, "fitKeepAR", dirs = dirs)
  e <- figure_extent(p)
  expect_false(is.null(e))
  expect_equal(e[["cx"]] / e[["cy"]], 4.0, tolerance = 0.01)
})

test_that("fitKeepAR preserves a tall source AR (1:3), height-constrained", {
  dirs <- local_docx_dirs()
  src <- svg_file(dirs$out, 200, 600)
  p <- render_figure(src, "fitKeepAR", dirs = dirs)
  e <- figure_extent(p)
  expect_equal(e[["cx"]] / e[["cy"]], 1 / 3, tolerance = 0.01)
  # and it must fit the usable area (not overflow the page)
  expect_lte(e[["cy"]], 914400 * 6.5)  # generous landscape-page bound
})

test_that("fitKeepAR reads viewBox when width/height are absent", {
  dirs <- local_docx_dirs()
  src <- svg_file(dirs$out, 600, 300, attrs = "viewBox")
  p <- render_figure(src, "fitKeepAR", dirs = dirs)
  e <- figure_extent(p)
  expect_equal(e[["cx"]] / e[["cy"]], 2.0, tolerance = 0.01)
})

test_that("fitKeepAR falls back to fitWidth box math for unreadable SVG", {
  dirs <- local_docx_dirs()
  src <- svg_file(dirs$out, 500, 500, attrs = "none")  # no size attributes
  p <- render_figure(src, "fitKeepAR", dirs = dirs)
  e <- figure_extent(p)
  # legacy fallback uses the 6x4 spec default AR = 1.5, width-constrained
  expect_equal(e[["cx"]] / e[["cy"]], 1.5, tolerance = 0.01)
})

test_that("fitWidth/fitPage/fixed behavior is UNCHANGED by the fix (golden pins)", {
  dirs <- local_docx_dirs()
  src <- svg_file(dirs$out, 800, 200)  # AR 4, but modes must ignore it
  ew <- figure_extent(render_figure(src, "fitWidth", dirs = dirs))
  ef <- figure_extent(render_figure(src, "fitPage", dirs = dirs))
  ex <- figure_extent(render_figure(src, "fixed", figureWidth = "6in", figureHeight = "4in", dirs = dirs))
  # all three: AR comes from the W/H arithmetic (default 6:4), NOT the source
  expect_equal(ew[["cx"]] / ew[["cy"]], 1.5, tolerance = 0.01)
  expect_equal(ef[["cx"]] / ef[["cy"]], 1.5, tolerance = 0.01)
  expect_equal(ex[["cx"]] / ex[["cy"]], 1.5, tolerance = 0.01)
})

test_that("fitKeepAR accepts explicit W/H but warns they are ignored", {
  dirs <- local_docx_dirs()
  src <- svg_file(dirs$out, 800, 200)
  spec <- create_figure(src)
  expect_warning(
    set_document(spec, hasData = FALSE, figureScaleMode = "fitKeepAR",
                 figureWidth = "5in", figureHeight = "2in"),
    "ignored", ignore.case = TRUE)
})

test_that("PNG intrinsic AR (IHDR) is used by fitKeepAR", {
  skip_if_not_installed("png")
  dirs <- local_docx_dirs()
  f <- file.path(dirs$out, "src.png")
  # 300x150 = AR 2 raster (big enough for base graphics margins)
  grDevices::png(f, width = 300L, height = 150L)
  graphics::par(mar = c(0, 0, 0, 0))
  graphics::plot.new()
  graphics::plot.window(xlim = c(0, 2), ylim = c(0, 1))
  graphics::rect(0, 0, 2, 1, col = "#36c", border = NA)
  dev.off()
  p <- render_figure(f, "fitKeepAR", tag = "fka_png", dirs = dirs)
  e <- figure_extent(p)
  expect_equal(e[["cx"]] / e[["cy"]], 2.0, tolerance = 0.01)
})
