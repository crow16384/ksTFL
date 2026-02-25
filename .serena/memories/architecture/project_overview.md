# ksTFL Project Overview

## Purpose
ksTFL is an R package for generating structured JSON metadata specifications for clinical Tables, Figures, and Listings (TFLs) in pharmaceutical/clinical research. It follows a spec-first architecture: R generates metadata, and a built-in C++20 rendering engine produces DOCX documents with deterministic pagination.

## Version and Author
- Version: 0.1.0
- Author: Igor Aleschenkov (KeyStat Solutions)
- License: MIT

## Key Design Principles
- Separation of concerns: metadata generation (R) decoupled from rendering (C++)
- Schema-driven validation (JSON Schema v1)
- Declarative syntax: users describe what to render
- Tidyselect integration for column selection
- Comprehensive validation with checkmate + cli error messages
- Deterministic pagination: HarfBuzz-based text measurement ensures pixel-perfect layout

## R Dependencies
- cli: formatted error messages
- checkmate: type-safe argument validation
- jsonlite: JSON serialization
- tidyselect: column selection
- rlang: quasiquotation, data masks, environments
- digest: hash generation for style dedup
- htmltools + rstudioapi: interactive preview
- Rcpp (>= 1.0.0): C++ interface

## C++ System Dependencies
- C++20 compiler (g++ 13+)
- HarfBuzz (>= 2.0): Unicode text shaping
- FreeType (>= 2.0): Font loading and glyph metrics
- minizip (zlib): ZIP archive creation for .docx
- nlohmann/json v3.11.3: JSON parsing (vendored in src/vendor/)

## Three Document Types
1. Table: requires data.frame, auto-detects column formats
2. Figure: requires file path to image
3. Text: narrative-only (data=NULL)

## Workflow Pipeline
1. create_table()/create_figure()/create_text() → TFL_spec
2. Customize: add_title(), add_style(), define_cols(), compute_cols()
3. create_report() → TFL_report (style consolidation, validation, styleRows finalization)
4. save_report() → JSON spec + data files on disk
5. render_docx() → C++ renderer → styled .docx document

## Full Pipeline Example
```r
spec <- create_table(mtcars) |> add_title("Motor Trend Cars")
report <- create_report(spec)
saved <- save_report(report, "demo.docx")
render_docx(
  spec_json = file.path(saved$metaPath, saved$spec_file),
  output_path = "output/demo.docx"
)
```

## Docker Environment
- Image: rocker/verse:latest
- Container: kstfl-r
- Project mount: /home/rstudio/ksTFL
- R is NOT installed on the host dev machine — all R execution is via docker exec
