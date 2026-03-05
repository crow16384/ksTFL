# styles_schema_v2 harmonization (Mar 2026)

- Created `inst/schemas/styles_schema_v2.json` and switched active style schema constant to v2.
- Added new template style sections:
  - `textStyles.tocTitle`
  - `textStyles.tocEntry` (single base style for TOC entries)
  - `textStyles.figureCaption`
  - `figureStyle.layout` (alignment, space_before, space_after)
  - `figureStyle.caption` (position, textStyleRef)
- Extended C++ template model/parser to load v2 style fields (`types.h`, `json_parser.cpp`).
- TOC styling now uses template-driven styles:
  - TOC title paragraph uses `tocTitle` style
  - generated `TOC1..TOC9` styles include `tocEntry` base formatting
- Figure rendering now applies template figure layout and caption behavior:
  - caption text comes from figure `subtitles`
  - caption position controlled by `figureStyle.caption.position`
  - caption style resolved via `figureStyle.caption.textStyleRef` with last-wins merge.
- Updated all bundled templates in `inst/templates/*.json` to include required v2 TOC/figure sections.
- Updated R/man/docs references from `styles_schema_v1.json` to `styles_schema_v2.json`.
- Confirmed regression passes for key suites (`test-17-ggplot-figure`, `test-09-integration`, `test-12-report-writer`).