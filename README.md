# ksTFL: Clinical TFL Framework

An R package for generating metadata for clinical Tables, Figures, and Listings (TFLs). ksTFL creates a specification object (`TFL_spec`) that describes document structure, data, styles, and content—this metadata is then passed to Python code for rendering into styled DOCX documents.

## Installation

```r
# Install from source
devtools::install_github("your-repo/ksTFL")
```

## Quick Start

```r
library(ksTFL)

# Create a table spec from a data frame
spec_table <- create_table(mtcars, cols = c(mpg, cyl, hp))

# Add titles and styling
spec_table <- add_title(spec_table, "Motor Cars Analysis")
spec_table <- add_subtitle(spec_table, "Summary Statistics")

# Define column properties
spec_table <- define_cols(
  spec_table,
  c(mpg, cyl, hp),
  label = c("MPG", "Cylinders", "HP"),
  colWidth = c("30%", "30%", "40%")
)

# Create a styled report
report <- create_report(spec_table)

# Save for rendering (requires downstream Python processing)
save_report(report, docFileName = "clinical_report.json", outDir = "./output")
```

## Documentation

- **[Complete Vignette](vignettes/ksTFL-vignette.Rmd)** - Comprehensive guide covering workflow, styling, options, and examples
- **[API Reference](man/)** - Detailed roxygen documentation for all exported functions
- **Quick Reference**:
  - `create_table()`, `create_figure()`, `create_text()` — Initialize specs
  - `add_title()`, `add_subtitle()`, `add_body_text()`, `add_footnote()` — Add content
  - `define_cols()` — Configure table columns
  - `add_style()`, `s_font()`, `s_paragraph()`, `s_table_style()` — Style specs
  - `create_report()` — Combine specs into a report
  - `save_report()` — Export to JSON

## Key Features

- **Declarative metadata**: Describe what to render (columns, titles, styles) without low-level layout operations
- **Schema validation**: Specs are validated against a JSON schema for consistency
- **Style consolidation**: `create_report()` deduplicates and merges style fragments
- **Tidyselect support**: Column selection via tidyselect expressions
- **Data environment**: Original data is accessible for conditional styling and expressions

## Architecture

ksTFL follows a **specification-first** design:

1. Initialize a spec with `create_table()`, `create_figure()`, or `create_text()`
2. Add content (titles, headers, footers, footnotes, body text)
3. Define column properties and styles
4. Combine specs into a report with `create_report()`
5. Serialize to JSON and save with `save_report()` for downstream rendering

The spec object stores:
- **document**: Document metadata (type, titles, subtitles, headers, footers)
- **columns**: Column definitions with formats, labels, and style references
- **styles**: Named style definitions (fonts, paragraphs, table styles, borders)
- **.metadata**: Internal state (data environment, report columns, hash)
- **Internal metadata**: The spec contains internal bookkeeping (a data environment copy, report column list, and internal hash). These internal fields are not part of the user-facing API and are removed from the JSON export produced by `save_report()`.

## Package Options

Control package behavior with `tfl_set_options()`:

```r
tfl_set_options(
  autoColWidth = TRUE,
  add_style(id = "bold_font", s_font(bold = TRUE)),
  add_header("Company", "Report", "Date")
)

# Retrieve options
current_options <- tfl_get_options()
single_option <- tfl_get_option("autoColWidth")

# Reset to defaults
tfl_reset_options()
```

## Dependencies

- **cli**: Formatted error messages and logging
- **checkmate**: Argument validation
- **jsonlite**: JSON serialization
- **tidyselect**: Column selection semantics
- **rlang**: Quoting and evaluation utilities
- **purrr**: Functional programming helpers
- **digest**: Hash generation for style consolidation


## License

MIT + file LICENSE

## Author

Igor Aleschenkov

---

**Note**: ksTFL is designed to work with a Python backend renderer that consumes the JSON spec and produces styled DOCX documents. The R package focuses on metadata generation and validation.

