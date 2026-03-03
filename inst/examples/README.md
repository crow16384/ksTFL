# ksTFL Examples

This folder contains runnable example scripts demonstrating the full ksTFL pipeline.

## `full_cycle_render.R` — 13 full-cycle examples (recommended)

The main example script covering all document types and features:

| Example | Description |
|---------|-------------|
| ex01 | Minimal table |
| ex02 | Styled table with column definitions, spanning headers |
| ex03 | Multi-spec report: Table + Text + Table |
| ex04 | Wide table with horizontal pagination |
| ex05 | Conditional row styling (`compute_cols`) |
| ex06 | Mixed Figure + Table report (file path input) |
| ex07 | Multi-page table with stub columns |
| ex08 | Full clinical demographics table |
| ex09 | Text-only narrative document |
| ex10 | Inline markup (`<b>`, `<i>`, `<sup>`, `<sub>`, etc.) |
| **ex11** | **ggplot2 figure — minimal scatter plot** |
| **ex12** | **ggplot2 figure (PNG) + companion summary table** |
| **ex13** | **Multiple ggplot2 figures: PNG, JPEG, and SVG** |

### Prerequisites

- ksTFL installed with C++ renderer compiled (HarfBuzz / FreeType / minizip)
- Examples 11–13 require `ggplot2` (`install.packages("ggplot2")`)
- Docker image `rocker/verse` has all dependencies pre-installed

### How to run

```r
# From package root (development)
devtools::load_all()
source("inst/examples/full_cycle_render.R")

# Or installed package
source(system.file("examples", "full_cycle_render.R", package = "ksTFL"))
```

Output goes to `tmp/output/*.docx`. Metadata JSON files land in `tmp/output/meta/`.

---

## `ksTFL_example.R` / `ksTFL_example_extended.R` — legacy examples

Earlier spec-only examples (no rendering). Kept for reference. Use `full_cycle_render.R` for new work.
