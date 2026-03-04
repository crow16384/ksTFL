# Improvement Plan (Updated Mar 2026)

## Completed

| Task | Commit | Summary |
|------|--------|---------|
| BUG-A | 760a052 | Zero margin override — `optional<Length>` in PageMarginsOverride |
| OPT-1 | 760a052 | Hoisted seg_cols set to per-segment |
| OPT-2 | 760a052 | In-place XML escaping (escape_text_into/escape_attr_into) |
| BUG-D | 25a4df7 | Removed unused get_dbl() — zero warnings |
| OPT-5 | 25a4df7 | Cached parse_inline_markup for titles across pages |
| OPT-3 | 22252c7 | string_view in split_words + measure_run_width |
| OPT-4 | 85ff257 | In-place merge_from() for all 8 style structs, 22 call sites |
| BUG-C | 016ad0d | Resolved as correct by design — documentation fix only |
| BUG-B | 40d4bbb | Stack-based state rebuild for nested same-type inline tags |

## All Bugs and Optimizations Complete

All 4 identified bugs (A-D) and 5 optimizations (1-5) from the code review are now resolved.
Test count increased from 1027 to 1030.

## Remaining Work

### SOLID: Split docx_emitter.cpp [Major refactoring, 1+ day]
- File: src/kstfl/docx_emitter.cpp (~2300 lines)
- Problem: Single class handles content emission, metadata XML, styles.xml, TOC, figures, ZIP packaging
- Proposed split:
  - docx_emitter.cpp — orchestration + content emission
  - docx_metadata.cpp — core.xml, app.xml, content_types.xml, rels
  - docx_styles.cpp — styles.xml generation
  - docx_packager.cpp — ZIP assembly
- Risk: High — many internal dependencies

### SOLID: Relocate units.cpp methods [Medium refactoring, 2-4 hours]
- File: src/kstfl/units.cpp
- Problem: Contains style merge methods + alignment/border converters alongside unit conversion
- Fix: Move style-related methods to style_types.cpp, keep only unit conversion in units.cpp
- Risk: Low — file reorganization only

## Recommended Execution Order
1. SOLID: units.cpp split (2-4 hours)
2. SOLID: docx_emitter.cpp split (1+ day)