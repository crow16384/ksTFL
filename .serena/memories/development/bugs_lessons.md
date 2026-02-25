# Bugs & Lessons Learned

## Bug 1: Percent Column Width Parsing (Feb 2026)
**Symptom**: Length::parse("5.0%") called without reference width → crash or 0 result
**Root Cause**: json_parser.cpp parsed col_width_raw directly as Length, but % widths need table_width (available only after page geometry computation)
**Fix**: Changed ColumnFormat from `optional<Length> col_width` to `optional<string> col_width_raw`. Deferred parsing to style_resolver.cpp::resolve_column_widths() where table_width is known.
**Files**: types.h, json_parser.cpp, style_resolver.cpp
**Lesson**: Defer unit parsing that depends on context (page size, parent dimensions) until resolution phase.

## Bug 2: Data File .json Extension Mismatch (Feb 2026)
**Symptom**: Renderer says "Data file not found" despite save_report() writing it
**Root Cause**: save_report writes `0001_abc123.json` but spec stores dataRef as `0001_abc123` (no extension). Renderer tried exact path match only.
**Fix**: Added .json extension fallback in renderer.cpp: try exact path, then path + ".json"
**Files**: renderer.cpp
**Lesson**: When two components (writer and reader) communicate via file paths, ensure extension conventions match or add fallback.

## Bug 3: XmlWriter attribute() Outside Start Tag (Feb 2026)
**Symptom**: `"XmlWriter::attribute() called outside of start tag"` crash during OOXML emission
**Root Cause**: `self_closing_element("X")` writes `<X/>` immediately and does NOT set `start_tag_open_ = true`. But 14 places in docx_emitter.cpp called `self_closing_element()` followed by `attribute()`, which requires `start_tag_open_`.
**Fix**: Changed all 14 occurrences to `start_element()` + `attribute()` + `end_element()` pattern. The end_element() auto-emits `/>` when no content was added (effectively same XML output).
**Files**: docx_emitter.cpp (emit_content_types, emit_rels, emit_document_rels)
**Lesson**: CRITICAL XML WRITER RULE — `self_closing_element()` is ONLY for elements with zero attributes. For elements with attributes, ALWAYS use start_element/attribute/end_element.

## Bug 4: Empty String text_width Crash (Feb 2026)
**Symptom**: `vapply(..., integer(1))` error — expected integer, got double (-Inf)
**Root Cause**: `text_width("")` returns zero-length vector. `max()` of empty vector returns `-Inf` (double), which doesn't match `vapply`'s expected `integer(1)`.
**Fix**: Added guard: `if (length(w) == 0L) 0L else max(w)` in max_line_width() helper
**Files**: utility_functions.R
**Lesson**: Always handle empty/zero-length results from text measurement. `max()` with empty input is a silent trap.

## Bug 5: c_addrow Positional Argument Misidentification (Feb 2026)
**Symptom**: c_addrow(pos = "above", styleRef = "cat_header") incorrectly interpreted styleRef as value_from
**Root Cause**: .parse_action_addrow() used `rlang::call_args()` with positional index access (`args[[2]]`, `args[[3]]`). When `value_from` was omitted and only `pos` + `styleRef` were named, `args[[2]]` picked up `styleRef` value as `value_from`.
**Fix**: Replaced positional access with `match.call(definition = c_addrow, call = action_call)` which properly resolves named + positional arguments according to the function signature.
**Files**: rowstyle_actions.R
**Lesson**: NEVER use positional index access on call_args() when function has optional arguments. Use match.call() for robust argument resolution.

## Bug 6: gluePrefix Type Mismatch (Feb 2026)
**Symptom**: tfl_set_options() rejected gluePrefix = ": " (character) 
**Root Cause**: Package options expects gluePrefix as logical (TRUE/FALSE), not character string
**Fix**: Changed `gluePrefix = ": "` to `gluePrefix = TRUE` in test examples
**Files**: inst/examples/full_cycle_render.R
**Lesson**: Always check the actual function signature/docs before passing values. tfl_set_options validates types strictly.

## General Lessons

### XmlWriter API Contract
- start_element() → start_tag_open_ = true → attribute() works → end_element() closes
- self_closing_element() → writes <X/> immediately → start_tag_open_ stays false → attribute() THROWS
- end_element() when start_tag_open_: emits `/>` (auto self-close, no content was written)
- end_element() when !start_tag_open_: emits `</X>` (normal close)

### R Call Object Patterns
- rlang::call_args(): returns args in order they appear in the CALL (not the definition)
- match.call(definition, call): properly maps positional args to named params per function signature
- For functions with optional middle params, match.call() is essential

### Text Specs and Data
- Text specs (docType="Text") don't have data files, but create_report still assigns dataRef
- Renderer logs "WARNING: Data file not found" for text specs — this is benign, not an error
- Don't special-case text specs in the renderer; the warning is acceptable

### Debug Trace Strategy
- Use verbose guards (`if (config_.verbose)`) for production traces in renderer.cpp
- Remove raw `std::cerr` debug traces after fixing bugs
- Keep `#include <iostream>` only in files that actually use std::cerr for verbose output
