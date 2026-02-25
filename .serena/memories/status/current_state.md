# Current Status (Feb 25, 2026)

## Fully Implemented
- Spec initialization for all 3 docTypes (Table, Text, Figure)
- Column auto-detection and format assignment with .guess_table_layout()
- Auto column width calculation and redistribution
- Style consolidation with hash-based merging in create_report()
- Context-based function nesting validation (spec_context.R)
- 30+ predefined clinical styles
- Comprehensive error messages with cli_abort()
- Full test coverage (19 test files, 806 passing tests)
- Extended create_report() with mixed report/spec support
- Conditional row styling (compute_cols with c_style, c_merge, c_addrow, c_pageBreak)
- Schema-driven serialization and validation
- save_report() for JSON + data file export
- Package options management
- Print method for TFL_spec (console + HTML viewer)
- Spanning column headers (add_span_header)
- **C++20 DOCX Renderer** — complete end-to-end rendering pipeline:
  - HarfBuzz text shaping for deterministic measurement
  - FreeType font loading with fallback chain
  - Vertical + horizontal pagination (isPaging-only page breaks, isGrouping for boundaries only)
  - OOXML emission into valid .docx ZIP packages
  - Support for all 3 doc types, styleRows actions, inline markup
  - Column format application (numeric %.Nf, integer %d with proper int cast)
  - Vertical merge in header grid (VMergeState: Restart/Continue for stub columns)
  - Structural borders: header_top, header_bottom, table_bottom parsed from template
  - Table bottom border applied to last data row per page
  - Title soft break: all title groups combined in single paragraph with <w:br/>, per-group font styling preserved
  - Header/footer as separate OOXML parts (word/headerN.xml, word/footerN.xml)
  - xml:space="preserve" auto-added on <w:t> elements
  - 10 comprehensive full-cycle rendering examples passing (inst/examples/full_cycle_render.R)

## Still TODO
- row_style_schema validation rules (schema exists but validation rules pending)
- styles_schema validation rules (schema exists but validation rules pending)
- Performance optimization: memoization for schema lookups if needed
- Regression test suite for rendered DOCX output (visual/structural validation)
- Windows build testing (Makevars.win exists but untested)
- Structural header_top_border / header_bottom_border application in emitter (parsed+stored, not yet applied)

## Schema Files
- spec_schema_v1.json: current main schema (941 lines)
- row_style_actions_schema_v0.json: styleRows schema
- styles_schema_v0.json / v1.json: style definitions
- spec_schema_v0.json: legacy (presumed deprecated)

## Full Cycle Test Examples (inst/examples/full_cycle_render.R)
10 examples covering progressively complex scenarios:
1. Minimal table (mtcars, styled titles with soft breaks, subtitle, centered table+titles)
2. Styled demographics with spanning headers + vertical merge
3. Multi-spec report (table + text + table)
4. Landscape A4 with global options
5. Column breaks with horizontal pagination
6. Row actions (c_style, c_addrow, c_pageBreak)
7. Text-only document
8. Full clinical package (3 specs: demog + AE listing + summary)
9. Long table with isPaging (300+ rows, 30 pages, isPaging-driven breaks)
10. Rich inline markup (**bold**, *italic*, __underline__)

All 10 produce valid .docx files (3KB-36KB).

## Recent Bug Fixes (Feb 2026)
- Bug 7: Pagination — isGrouping was incorrectly forcing page breaks (only isPaging should)
- Bug 8: Header vertical merge — stub columns not merged with label row
- Bug 9: Integer format UB — %d with double arg → garbage (static_cast<int> fix)
- Bug 10: Table bottom border lost — structural borders parsed but never stored/applied
- Bug 11: Titles as separate paragraphs — each add_title() was a separate <w:p>, now combined with <w:br/>
- Bug 3: XmlWriter self_closing_element + attribute crash (14 fixes in docx_emitter.cpp)
- Bug 4: text_width("") empty vector crash in utility_functions.R
- Bug 5: c_addrow positional arg misidentification in rowstyle_actions.R (fixed with match.call)
- Bug 6: gluePrefix type mismatch in test examples
- Bug 1-2 (earlier): percent column width parsing, data file .json extension
