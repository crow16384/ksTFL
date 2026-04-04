# ksTFL Project Overview

## Purpose
R package for generating clinical Tables, Figures, and Listings (TFL) metadata and rendering submission-quality DOCX output via a C++20 engine.

## Tech Stack
- **Primary**: R (S3 OOP, Rcpp, roxygen2)
- **Secondary**: C++20 (Rcpp bindings, HarfBuzz text measurement)
- **Key R deps**: cli, checkmate, jsonlite, purrr, rlang, tidyselect

## Core Architecture
- Main object: `TFL_spec`
- Initializers: `create_table()`, `create_text()`, `create_figure()` → call `.tfl_init()` internally
- Rendering: `render_docx()` → calls C++ engine
- Schema-driven serialization — constants live in `R/constants.R`
- Internal metadata in `spec$.metadata` — never serialize this

## Code Structure
- `R/spec_init.R` — spec initialization, column specs
- `R/render_docx.R` — DOCX rendering entrypoint
- `R/constants.R` — all schema/config constants (`.const_*` naming)
- `R/schema_serialize.R` — JSON serialization pipeline
- `R/meta_management.R` — metadata helpers
- `R/pkg_settings.R` — package-level options
- `src/rcpp_bindings.cpp` — Rcpp glue
- `src/kstfl/` — C++20 renderer core
- `tests/testthat/` — testthat tests
