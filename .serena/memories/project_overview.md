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


## Recent Update (2026-06-04)
- Version bumped to `0.11.4` in `DESCRIPTION`.
- Inline parser now supports escaped literal tag markers via `\\<` (e.g. `\\<i>literal\\</i>` renders as literal `<i>literal</i>` text).
- Parser parity maintained across `has_inline_markup()`, `parse_inline_markup()`, and `get_plain_text()`.
- Escaped-tag coverage is in C++ unit tests (`cpp_test_inline_parser`) and R wrapper tests (`tests/testthat/test-18-cpp-units.R`).
- Changelog/docs updated in `NEWS.md`, `docs/news/index.md`, and version text in `docs/authors.md`.
