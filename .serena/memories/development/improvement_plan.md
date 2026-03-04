# Improvement Plan (Mar 2026)

## Priority 1: Quick Wins (< 30 min each)

### BUG-D: Remove unused `get_dbl()` [Trivial]
- File: src/kstfl/json_parser.cpp
- Action: Delete `get_dbl()` helper function definition and any forward declaration
- Impact: Suppress compiler warning, reduce dead code
- Risk: None — function is unreferenced

### OPT-5: Cache parse_inline_markup for titles [Low effort, Low impact]
- File: src/kstfl/docx_emitter.cpp
- Problem: `emit_title_paragraph()` calls `parse_inline_markup()` for the same title text once for the main paragraph and once for the TOC `TC` field. If TC field is emitted, the title is parsed twice.
- Fix: Store the parsed `InlineRun` vector and reuse it for both emissions.
- Risk: Low — localized change

## Priority 2: Medium Effort (1-2 hours each)

### OPT-3: string_view in split_words() [Medium effort, Medium impact]
- File: src/kstfl/text_measurer.cpp
- Problem: `split_words()` returns `vector<string>`, each element is a heap-allocated copy of a substring
- Fix: Return `vector<string_view>` pointing into the original string. Must ensure lifetime of source string outlives the views.
- Risk: Moderate — need to audit all callers to ensure source string lifetime is sufficient
- Prerequisite: Verify that the source string lives long enough in all call sites

### OPT-4: In-place merge_from() for StyleDef [Medium effort, Medium impact]
- File: src/kstfl/units.cpp (or new style_types.cpp)
- Problem: `merged_with()` creates a new StyleDef copy each time; chained calls (template → spec → row) create intermediates
- Fix: Add `void merge_from(const StyleDef& other)` that modifies `this` in-place. Keep `merged_with()` for API compatibility but implement via `merge_from()`.
- Risk: Low — additive change, existing API unchanged

### BUG-C: Verify find_style() scope [Investigation needed]
- File: src/kstfl/style_resolver.cpp
- Problem: `find_style()` only searches `spec_styles`, not template styles. If a row references a style name defined only in the template, it's silently skipped.
- Action: First determine if this is intentional design (spec overrides template entirely) or a bug
- If bug: Add template style fallback in `find_style()` after spec lookup fails
- Risk: Must understand intended style cascade before changing

## Priority 3: Larger Refactoring (0.5-1 day each)

### BUG-B: Nested inline tags state machine [Complex]
- File: src/kstfl/inline_parser.cpp
- Problem: `parse_inline_markup()` uses boolean flags (is_bold, is_italic, etc.) instead of a stack. Nested same-type tags (e.g., `**bold **nested** bold**`) don't restore state correctly — inner close clears the outer state.
- Fix: Replace boolean flags with a stack-based parser state. Each opening tag pushes state, each closing tag pops. The current state is the top of the stack merged downward.
- Impact: Correctness for edge-case nested formatting
- Risk: Moderate — core parser change, needs thorough testing
- Rarely triggered in clinical TFL practice

### SOLID: Split docx_emitter.cpp [Major refactoring]
- File: src/kstfl/docx_emitter.cpp (2294 lines)
- Problem: Single class handles content parts XML, metadata XML (core.xml, app.xml, content_types.xml), styles.xml, TOC emission, figure embedding, ZIP packaging
- Proposed split:
  - `docx_emitter.cpp` — orchestration + content emission (tables, text, figures)
  - `docx_metadata.cpp` — core.xml, app.xml, content_types.xml, rels
  - `docx_styles.cpp` — styles.xml generation from resolved styles
  - `docx_packager.cpp` — ZIP assembly and file writing
- Risk: High — many internal dependencies, needs careful interface design
- Testing: Existing 1027 tests provide good regression coverage

### SOLID: Relocate units.cpp methods [Medium refactoring]
- File: src/kstfl/units.cpp
- Problem: Contains `StyleDef::merged_with()`, alignment/border converters alongside unit conversion. Violates SRP.
- Fix: Move style-related methods to style_types.cpp (or similar), keep only unit conversion in units.cpp
- Risk: Low — file reorganization, no logic changes
- Prerequisite: OPT-4 (merge_from) ideally done first

## Recommended Execution Order
1. BUG-D (trivial, 5 min)
2. OPT-5 (low effort, 15 min)
3. OPT-4 (in-place merge, 1-2 hours)
4. OPT-3 (string_view, 1-2 hours)
5. BUG-C (investigation + possible fix, 1 hour)
6. BUG-B (parser rewrite, 2-4 hours)
7. SOLID refactoring (when time allows, multi-day)