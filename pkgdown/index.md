<div class="kshero">

<img src="man/figures/ksTFL-logo-hero.gif" alt="ksTFL animated logo" class="kshero-logo" width="560" />

<p class="kshero-tag">Clinical Tables, Figures, and Listings —<br />from R code to validated DOCX, in one pipeline.</p>

<div class="kshero-cta">
<a class="btn btn-kstfl" href="articles/Getting_Started_with_ksTFL.html">Start here</a>
<a class="btn btn-kstfl-ghost" href="https://github.com/al-garik/ksTFL-examples">Full example gallery</a>
</div>

</div>

## Why ksTFL

**ksTFL** is a professional R package designed to fill a long-standing gap in the R ecosystem: the lack of a dedicated, end-to-end solution for producing well-formatted, regulatory-compliant clinical Tables, Figures, and Listings (TFLs). While R excels at statistical analysis, generating submission-quality DOCX outputs that meet pharmaceutical industry standards has traditionally required fragile workarounds or external tooling. ksTFL solves this by distilling the best ideas from existing reporting solutions into a simple, minimalistic, yet highly flexible declarative language — a compact set of composable functions whose combinations can produce virtually any clinical output format.

The core philosophy is **data–presentation separation**: input data stays clean and planar, free of reporting artefacts such as merged cells, indentation columns, or display-only rows. Formatting, pagination, grouping, and styling are declared independently and applied at render time. This keeps datasets maintainable, traceable, and validation-ready — exactly what regulated environments demand.

Under the hood, a built-in **rendering engine** with text shaping converts declarative specs into styled DOCX documents with deterministic, pixel-perfect pagination. Rendering is extremely fast even on large datasets, making ksTFL practical for batch production of hundreds of outputs in a single pipeline run.

### Key design principles

- **Separation of concerns** — metadata generation (R) is decoupled from document rendering; input data remain clean and analysis-ready
- **Declarative syntax** — describe *what* to render, not *how* to render it; a small function vocabulary covers the full range of clinical outputs
- **Deterministic pagination** — font shaping guarantees pixel-perfect, reproducible layouts and page breaks
- **High performance** — the C++ engine renders large multi-spec reports in seconds
- **Type safety** — comprehensive input validation with informative error messages
- **Reproducibility** — specifications are serializable, so stored metadata can be replayed years later without re-running the analysis pipeline

## What the output looks like

Every page below was rendered by ksTFL itself from short, commented example
programs. Click any page to open it full size.

<div class="ksgallery">

<a class="ksdemo" href="home/demo-span-headers.png" target="_blank" rel="noopener">
  <img src="home/demo-span-headers.png" alt="Demography table with grouped treatment-arm headers" />
  <figcaption>Demography table with grouped column headers for each treatment arm</figcaption>
</a>

<a class="ksdemo" href="home/demo-ae-summary.png" target="_blank" rel="noopener">
  <img src="home/demo-ae-summary.png" alt="Adverse event summary table" />
  <figcaption>Adverse-event summary across dose groups, with counts and percentages</figcaption>
</a>

<a class="ksdemo" href="home/demo-figure.png" target="_blank" rel="noopener">
  <img src="home/demo-figure.png" alt="Scatter plot embedded in a report page" />
  <figcaption>A ggplot2 scatter plot embedded in the report, fitted to the page exactly</figcaption>
</a>

<a class="ksdemo" href="home/demo-report-sections.png" target="_blank" rel="noopener">
  <img src="home/demo-report-sections.png" alt="Multi-section report page" />
  <figcaption>Sections of a larger report flowing page to page, titles and footnotes placed exactly where you ask</figcaption>
</a>

<a class="ksdemo" href="home/demo-styled-status.png" target="_blank" rel="noopener">
  <img src="home/demo-styled-status.png" alt="Table with conditionally colored values" />
  <figcaption>Values highlighted automatically — the colors follow the data, not manual editing</figcaption>
</a>

<a class="ksdemo" href="home/demo-disposition.png" target="_blank" rel="noopener">
  <img src="home/demo-disposition.png" alt="Subject disposition table" />
  <figcaption>Subject disposition inside a combined report of tables, text, and figures</figcaption>
</a>

</div>

## Quick start

```r
library(ksTFL)

# 1. Initialize a table specification
spec <- create_table(mtcars, cols = c(cyl, mpg, hp, wt))

# 2. Add document content
spec <- spec |>
  add_title("Motor Trend Car Road Tests", styleRef = "i") |>
  add_subtitle("Number of Cylinders: #ByGroup1", styleRef = f_combine("fc_blue", "tw_50")) |>
  add_footnote("Source: 1974 Motor Trend US magazine")

# 3. Define column properties
spec <- spec |>
  define_cols(c(mpg, hp, wt),
              label = c("Miles/(US) gallon", "Horsepower", "Weight (1000 lbs)"),
              valueStyleRef = "ac") |>
  define_cols(cyl, isGrouping = TRUE, isVisible = FALSE)

# 4. Conditional row styling: red-highlight powerful engines
spec <- spec |>
  compute_cols(hp > 200, c_style(hp, styleRef = "fc_red"))

# 5. Assemble and render to DOCX
report <- create_report(spec)
write_doc(report, name = "demo", outDir = tempdir())
```

The result is a print-ready Word document: grouped by cylinder count, right-aligned
numbers, an italic title, and red horsepowers — no post-editing in Word.

## Installation

ksTFL ships **pre-compiled binaries** for R 4.5 and R 4.6 on Windows, Ubuntu/Debian,
Fedora/RHEL, and macOS (ARM) — no compilers or system libraries needed for most users.

The simplest method, works on every platform:

```r
install.packages("ksTFL",
  repos = c("https://crow16384.r-universe.dev", "https://cloud.r-project.org"))
```

Windows binaries are also available directly:

```r
install.packages("ksTFL",
  repos = "https://crow16384.github.io/ksTFL-release",
  type  = "binary")
```

Or download finished packages (`.zip`, `.tar.gz`, `.tgz`) from the
[release repository](https://github.com/crow16384/ksTFL-release/releases) and
install with `install.packages(file, repos = NULL)`.

Building from source requires a C++20 compiler and R development tools
(Rtools on Windows, Xcode Command Line Tools on macOS, `build-essential` on Linux):

```r
remotes::install_github("crow16384/ksTFL")
```

## What else it can do

- **Templates** — bundled corporate layouts (`Navy_Pro`, `Carbon_Dark`, `Listings`, …);
  switch one option and the whole document family changes its look. Your own JSON
  template can live next to the report and travel with it.
- **Font management** — the package finds fonts installed on your system and falls
  back to metric-compatible open-source alternatives (Liberation family) when a
  proprietary one is missing, so a report paginates the same on any machine.
- **Replay** — `save_report()` keeps a specification bundle; `replay_report()`
  rebuilds the exact DOCX on another machine, later, without the original analysis
  session. Ideal for validation and QA.
- **Table of contents** — one option prepends a clickable ToC page to a report.
- **RStudio add-ins** — a template editor and a style picker, so layout work does
  not require memorizing option names.
- **Multilingual** — any Unicode text: Cyrillic, CJK, and Greek letters share the
  same page with ordinary cell values.

## Documentation & resources

| I want to… | Go to |
|------------|-------|
| Learn the workflow in one sitting | [Getting Started](articles/Getting_Started_with_ksTFL.html) |
| Solve a specific problem | [FAQ & Troubleshooting](articles/FAQ_with_ksTFL.html) |
| See real examples, table by table | [Real Examples](articles/Real_Examples_with_ksTFL.html) and the [examples repository](https://github.com/al-garik/ksTFL-examples) |
| Fine-tune colors, fonts, borders | [Styling Guide](articles/Styling_Guide_with_ksTFL.html) |
| Look up any function | [Reference](reference/index.html) |
| Print a cheat sheet | [Cheatsheet (PDF)](ksTFL_cheatsheet.pdf) |
| Give a talk | [Slides (PDF)](ksTFL_slides.pdf) |

--------------------------------------------------------------------------------

**License.** GPL-3. **Authors.** Igor Aleschenkov, Vladimir Larchenko — ksTFL Team ©
