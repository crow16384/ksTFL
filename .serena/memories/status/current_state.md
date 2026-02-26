# Current Status (Feb 27, 2026)

## Fully Implemented
- Spec initialization for all 3 docTypes (Table, Text, Figure)
- **ggplot2 integration in create_figure()**: accepts ggplot2 objects directly (auto-rendered to temp file via ggsave()); explicit 3-branch type validation (gg/ggplot → temp file, character path → pass-through, anything else → cli_abort())
- .save_ggplot_to_temp() internal helper (width/height/dpi/device params)
- ggplot2 in DESCRIPTION Suggests; requires `requireNamespace()` check at runtime only
- Column auto-detection and format assignment with .guess_table_layout()
- Auto column width calculation and redistribution
- Style consolidation with hash-based merging in create_report()
- Context-based function nesting validation (spec_context.R)
- 30+ predefined clinical styles
- Comprehensive error messages with cli_abort()
- Full test coverage (20 test files: 19 R testthat + 1 C++ harness, 806+ passing tests)
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
  - 13 full-cycle rendering examples passing (inst/examples/full_cycle_render.R)
  - test-17-ggplot-figure.R: 27 tests covering ggplot2 path, file path, and type safety
- **C++ Unit Tests** (Feb 27, 2026):
  - src/cpp_tests.cpp: lightweight TestResult harness, 3 Rcpp-exported suites (~135 assertions total)
  - cpp_test_units(): 60+ assertions — parse_length (all units + error cases), Color::parse, emu_to_twips, emu_to_half_points, pt_to_half_points, pt_to_eighth_points, page_size_dimensions (5 sizes), Length arithmetic/comparisons, border_line_style_to_ooxml, alignment_to_ooxml
  - cpp_test_inline_parser(): 35+ assertions — has_inline_markup, plain text, b/i/u/sup/sub, nesting, br/p, case-insensitivity, unknown tag passthrough
  - cpp_test_xml_writer(): 40+ assertions — declaration, self-close, text content, string/int/multiple attributes, 3-level nesting, text escaping (&<>"), attr escaping ("), element_with_text, element_with_attr, raw(), comment(), clear()/take()/depth(), namespace_decl(), error conditions
  - tests/testthat/test-18-cpp-units.R: 24 test_that blocks; each C++ assertion → individual expect_true/expect_false

## Still TODO
- row_style_schema validation rules (schema exists but validation rules pending)
- styles_schema validation rules (schema exists but validation rules pending)
- Performance optimization: memoization for schema lookups if needed
- Regression test suite for rendered DOCX output (visual/structural validation)
- Windows build testing (Makevars.win exists but untested)
- Structural header_top_border / header_bottom_border application in emitter (parsed+stored, not yet applied)

## Schema Files
- spec_schema_v1.json: current main schema
- row_style_actions_schema_v0.json: styleRows schema
- styles_schema_v0.json / v1.json: style definitions
- spec_schema_v0.json: legacy (presumed deprecated)

## Full Cycle Test Examples (inst/examples/full_cycle_render.R)
13 examples:
1. Minimal table (mtcars, styled titles, subtitle, centered)
2. Styled demographics with spanning headers + vertical merge
3. Multi-spec report (table + text + table)
4. Landscape A4 with global options
5. Column breaks with horizontal pagination
6. Row actions (c_style, c_addrow, c_pageBreak)
7. Text-only document
8. Full clinical package (3 specs: demog + AE listing + summary)
9. Long table with isPaging (300+ rows, 30 pages)
10. Rich inline markup (**bold**, *italic*, __underline__)
11. Minimal ggplot2 scatter plot (PNG, 6x4in, 300dpi)
12. ggplot2 PK concentration-time figure + companion summary table
13. Three ggplot2 figures: PNG (box plot), JPEG (KM survival), SVG (forest plot)

## Bug Fixes History (Feb 2026)
- Bug 7: isGrouping incorrectly forcing page breaks (only isPaging should)
- Bug 8: Header vertical merge — stub columns not merged with label row
- Bug 9: Integer format UB — %d with double arg → garbage (static_cast<int> fix)
- Bug 10: Table bottom border lost — structural borders parsed but never stored/applied
- Bug 11: Titles as separate paragraphs — now combined with <w:br/>
- Bug 3: XmlWriter self_closing_element + attribute crash (14 fixes in docx_emitter.cpp)
- Bug 4: text_width("") empty vector crash
- Bug 5: c_addrow positional arg misidentification (fixed with match.call)
- Bug 6: gluePrefix type mismatch
- Bug 1-2: percent column width parsing, data file .json extension
