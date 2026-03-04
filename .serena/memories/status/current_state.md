# Current Project State (Updated Mar 2026)

## Version & Build
- Package: ksTFL v0.2.3
- C++ Standard: C++20 (g++ 14.2.0)
- 1027 R tests passing, 135 C++ assertions (3 suites)
- 26 bugs fixed and documented in development/bugs_lessons
- Only compiler warning: unused `get_dbl()` in json_parser.cpp (BUG-D, trivial)

## Recent Changes (Mar 2026)
- **BUG-A FIXED**: Zero page margin override — added `PageMarginsOverride` with `optional<Length>` (types.h, json_parser.cpp, style_resolver.cpp)
- **OPT-1 IMPLEMENTED**: Hoisted `seg_cols` set to per-segment in `emit_table()` (docx_emitter.h/.cpp)
- **OPT-2 IMPLEMENTED**: In-place XML escaping — `escape_text_into`/`escape_attr_into` write directly to buffer (xml_writer.h/.cpp)
- Build passes cleanly, all 1027 tests pass (0 failures, 0 warnings, 0 skips)

## Previous Changes (Jul 2025)
- VS Code C++ config repaired (includePath, clangd, c_cpp_properties.json)
- compile_commands.json workflow added (tools/gen_compile_commands.sh with bear/intercept-build/compiledb fallback)
- Git commit 34dd12a: "Improve VS Code C++ configuration and compile_commands workflow"

## Remaining Work

### Bugs (from Deep C++ Code Review)
- **BUG-B** (Low): inline_parser.cpp — nested same-type inline tags don't restore state correctly (boolean machine, not stack-based). Rarely triggered in practice.
- **BUG-C** (Low): find_style() only searches spec_styles, not template; unknown refs silently skipped. Need to verify intended behavior.
- **BUG-D** (Trivial): json_parser.cpp `get_dbl()` unused — remove dead code to suppress compiler warning.

### Optimizations
- **OPT-3** (Low): split_words() in text_measurer.cpp allocates vector of `string` — could use `string_view` to avoid copies.
- **OPT-4** (Low): merged_with() chains create intermediate StyleDef copies — add in-place `merge_from()`.
- **OPT-5** (Low): Double parse_inline_markup for titles with TC fields — cache result.

### SOLID / Refactoring (Future)
- docx_emitter.cpp (2294 lines) violates SRP: metadata, emission, TOC, figures, ZIP orchestration. Split into focused classes.
- units.cpp contains style merge methods + alignment/border converters — relocate to style_types.cpp.
- RAII guard for `measurer_` pointer in DocxEmitter::emit() (minor safety improvement).

## Architecture
6-phase pipeline: Parse → Resolve → Model → Measure → Paginate → Emit
12 modules in src/kstfl/, vendor deps: nlohmann/json, minizip
External deps: HarfBuzz, FreeType, Rcpp

## Environment
- R IS installed on dev machine — run R/Rscript directly, do NOT use Docker
- Linux (Debian), g++ 14.2.0