# CLARIFICATION QUESTIONS FOR TFL SETTINGS REFACTORING

## High-Level Design Questions

### 1. Body Text Default Behavior
**Current Understanding**: Default "No data to report" message always available, with special `__default_NNN` ID pattern.

**Questions**:
- Should the default bodyText **always** be present in every new spec, or only if user hasn't set one?
- When user calls `add_body_text()` on an existing spec that has `__default_*` entries, should we:
  - **A)** Automatically remove all `__default_*` entries (my current recommendation)
  - **B)** Keep defaults and append user's text (might create duplicate/confusing messages)
  - **C)** Provide explicit function like `add_body_text(..., replace_defaults = TRUE)`?

- What order value should default bodyText use? (Suggestion: `order = 999` to appear last)
- Should the default bodyText be editable after `tfl_init()`, or read-only?

### 2. Header/Footer Merging Strategy
**Current Understanding**: Users can set default headers/footers in settings, which apply automatically to new specs.

**Questions**:
- When user has both default headers AND adds headers via `add_header()` on same spec:
  - **A)** Merge them together (defaults + user additions)
  - **B)** Replace (user additions override defaults completely)
  - **C)** Provide explicit parameter to control behavior?

- Example scenario:
  ```r
  # Settings have default header: ["Company Name", "", ""]
  spec <- tfl_init(data) %>%
    add_header(c("Protocol ABC", "", "Page {PAGE}"))
  # Result should be: 2 header rows or 1 merged header?
  ```

### 3. Page Settings Integration
**Current Understanding**: Users set page via `s_page()`, which returns a tfl_page object stored in settings.

**Questions**:
- Currently `s_page()` returns structure with nested `margins` (from `s_margins()`). Should users:
  - **A)** Use full chain: `tfl_set_options(page = s_page(margins = s_margins(...)))`
  - **B)** Support convenience: `tfl_set_options(page = s_page(...), margins = s_margins(...))`?

- Should page settings be fully applied via `set_document_style()` in `tfl_init()`, or just provide initial values?

### 4. Settings API Design
**Current Understanding**: Switch from `tfl_set_settings(...)` to `tfl_set_options(page = NULL, headers = NULL, ...)`

**Questions**:
- Do you prefer named parameters (my current recommendation) or keep dots with helper validation?
- For complex objects (page, headers, styles), should we:
  - **A)** Accept the actual objects (e.g., `page = s_page(...)`)
  - **B)** Accept nested lists (e.g., `page = list(size = "A4", orientation = "landscape")`)
  - **C)** Support both with automatic conversion?

- Should settings be immutable/read-only after set, or freely modifiable?

### 5. Backwards Compatibility
**Current Understanding**: Keep old `tfl_set_settings()` working OR deprecate cleanly.

**Questions**:
- Should we:
  - **A)** Maintain both APIs indefinitely (old and new)
  - **B)** Deprecate old API with warning and target removal date
  - **C)** Immediately replace (breaking change)?

- If maintaining both, how should conflicts be handled?

---

## Implementation Scope Questions

### 6. Styles in Settings
**Current Understanding**: `styles` is in settings but not fully integrated.

**Questions**:
- Should users be able to set default styles via settings? (e.g., company brand colors)
- How should defaults interact with `add_style()` function?

### 7. Other Document Properties
**Current Understanding**: Properties like `bodyTitles`, `bodySubtitles`, `contentWidth` etc. are in settings.

**Questions**:
- Should these be included in the new `tfl_set_options()` API?
- Or kept simple for now (just focus on page, headers, footers, bodyText)?

### 8. Constants & Configuration Files
**Current Understanding**: Defaults hardcoded in code via constants.

**Questions**:
- Should we add ability to load settings from external file (JSON/YAML)?
- Or keep everything code-driven for this phase?

---

## Practical Usage Pattern Questions

### 9. Desired User Workflow
**Current Understanding**: User sets options once, reused across session.

**Example Workflow**:
```r
# At session start:
tfl_set_options(
  page = s_page(size = "Letter", orientation = "portrait", 
                margins = s_margins(top = "1in")),
  headers = add_header(NULL, c("Company ABC", "Confidential", "")),
  bodyText = add_body_text(NULL, "No data available for this analysis")
)

# Later, create specs that inherit these:
spec1 <- tfl_init(data1) # Gets page, headers, bodyText defaults
spec2 <- tfl_init(data2) # Same defaults

# Can override per-spec:
spec3 <- tfl_init(data3) %>%
  add_header(c("Different Header", "", ""))  # Replaces or merges default?
  
# Get current settings back:
current <- tfl_get_settings()
```

**Question**: Does this workflow match your vision?

### 10. Use Case: Multiple Projects
**Workflow**:
```r
# Project A settings
tfl_set_options(headers = add_header(NULL, c("PROJECT A", "", "")), ...)

# Create specs for Project A
specs_a <- lapply(data_list_a, function(d) tfl_init(d))

# Switch to Project B settings
tfl_set_options(headers = add_header(NULL, c("PROJECT B", "", "")), ...)

# Create specs for Project B
specs_b <- lapply(data_list_b, function(d) tfl_init(d))
```

**Question**: Should settings allow quick save/restore for this pattern?

---

## Data Structure Questions

### 11. Settings Storage Format
**Current**: `.options_env$settings` is a named list

**Question**: Should we keep this approach or refactor to S3 object?
```r
# Current:
.options_env$settings <- list(page = ..., headers = ..., ...)

# Alternative:
.options_env$settings <- structure(
  list(page = ..., headers = ..., ...),
  class = "TFL_settings"
)
# With print method, validation method, etc.
```

---

## Testing & Documentation Questions

### 12. Testing Strategy
**Questions**:
- Should settings be reset before/after each test?
- Should we test that defaults are applied correctly to `tfl_init()` output?
- Should we test interaction between settings defaults and per-spec overrides?

### 13. Documentation Examples
**Questions**:
- Should we provide example workflow files (e.g., `demo_settings.R`)?
- Should we add vignette covering settings management?

---

## Summary: Priority Ranking

**Please prioritize by importance (1 = most important):**

- [ ] Page settings with `s_page()` integration
- [ ] Header/footer defaults
- [ ] Body text defaults with `__default_*` pattern
- [ ] Redesign `tfl_set_options()` API
- [ ] Constant consolidation
- [ ] Settings save/restore for multi-project workflows
- [ ] External config file support
- [ ] S3 TFL_settings object with methods

---

## Next Steps

Once you clarify these questions, I can:

1. Create detailed code implementation
2. Generate modified files for pkg_settings.R, spec_init.R, spec_context.R, constants.R
3. Add comprehensive examples and tests
4. Update Roxygen documentation

Would you like me to proceed with assumptions on any of these, or would you prefer to answer the key questions first?
