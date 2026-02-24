# ksTFL Project Overview

## Purpose
ksTFL is an R package for generating structured JSON metadata specifications for clinical Tables, Figures, and Listings (TFLs) in pharmaceutical/clinical research. It follows a spec-first architecture: R generates metadata, a separate Python backend renders DOCX.

## Version and Author
- Version: 0.1.0
- Author: Igor Aleschenkov (KeyStat Solutions)
- License: MIT

## Key Design Principles
- Separation of concerns: metadata (R) decoupled from rendering (Python)
- Schema-driven validation (JSON Schema v1)
- Declarative syntax: users describe what to render
- Tidyselect integration for column selection
- Comprehensive validation with checkmate + cli error messages

## Dependencies
- cli: formatted error messages
- checkmate: type-safe argument validation
- jsonlite: JSON serialization
- tidyselect: column selection
- rlang: quasiquotation, data masks, environments
- digest: hash generation for style dedup
- htmltools + rstudioapi: interactive preview

## Three Document Types
1. Table: requires data.frame, auto-detects column formats
2. Figure: requires file path to image
3. Text: narrative-only (data=NULL)

## Workflow Pipeline
1. create_table()/create_figure()/create_text() -> TFL_spec
2. Customize: add_title(), add_style(), define_cols(), compute_cols()
3. create_report() -> TFL_report (style consolidation, validation)
4. save_report() -> JSON + data files -> Python renderer -> DOCX
