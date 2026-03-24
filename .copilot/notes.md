## Building the pkgdown site

From the package root in R:

```r
# Optional: longer timeout if CRAN is slow (downlit fetches packages.rds when building articles)
options(timeout = 120)
pkgdown::build_site(pkg = ".", install = FALSE, preview = FALSE)
```

- **X11 / headless**: Vignettes set `dev = "cairo_png"` so the site builds without an X11 display. Example plots use `png(..., type = "cairo")` where needed.
- **CRAN timeout**: Building articles uses **downlit**, which fetches `https://cran.rstudio.com/web/packages/packages.rds`. If that times out, run with network access and/or increase `options(timeout = 120)` (or higher). For fully offline builds, use the **pkgdown.offline** package and call `pkgdown.offline::build_site()` instead.

---

