# TFL Settings System - Quick Visual Summary

## Current vs Proposed Architecture

### CURRENT STATE
```
User Session
    ↓
[tfl_set_settings(...)]  ← Uses dots, limited type validation
    ↓
.options_env$settings = {
  page: {size, orientation},
  headers: list(),
  footers: list(),
  bodyText: list(),
  styles: list(),
  ...
}
    ↓
tfl_init(data)
    ↓
.fill_spec_defaults(spec)  ← Reads settings
    ↓
TFL_spec created
```

### PROPOSED STATE
```
User Session
    ↓
[tfl_set_options(page=s_page(...), headers=add_header(...), bodyText=add_body_text(...), ...)]
    ↓
Validation Layer:
  - page must be tfl_page object
  - headers must be list or from add_header()
  - bodyText must have __default_* IDs
  - etc.
    ↓
.options_env$settings = {
  page: tfl_page object,
  headers: []{text, order},
  footers: []{text, order},
  bodyText: []{
    __default_001: {text, order, styleRef},  ← Special default pattern
    __default_002: {...}
  },
  styles: {...},
  ...
}
    ↓
tfl_init(data)
    ↓
.fill_spec_defaults(spec)  ← Reads settings, applies page/headers/footers
    ↓
TFL_spec created with:
  - Default page settings
  - Default headers/footers
  - Default "No data" bodyText (__default_001)
    ↓
User calls: add_body_text(spec, "custom message")
    ↓
[add_body_text.TFL_spec()] DETECTS __default_* entries
    ↓
Removes all __default_* entries BEFORE adding user's text
    ↓
Clean spec with only user-defined bodyText
```

---

## The 5 Main Components

### 1. PAGE SETTINGS
```r
# Set defaults
tfl_set_options(
  page = s_page(
    size = "A4",
    orientation = "landscape",
    margins = s_margins(top = "1in", bottom = "1in", left = "0.75in", right = "0.75in")
  )
)

# Used automatically in tfl_init()
spec <- tfl_init(data)  # Gets page defaults from settings

# Can override per-spec if needed
spec <- tfl_init(data) %>%
  set_document_style(page = s_page(size = "Letter"))
```

### 2. HEADERS & FOOTERS
```r
# Set defaults
tfl_set_options(
  headers = add_header(NULL, c("Company ABC", "Confidential", "")),
  footers = add_footer(NULL, c("Page {PAGE} of {NUMPAGES}", "", ""))
)

# Automatically applied to new specs
spec <- tfl_init(data)  # Gets default header/footer

# Add additional headers per-spec
spec <- tfl_init(data) %>%
  add_header(c("Protocol XYZ-123", "", ""))  # Merges with defaults?
```

### 3. BODY TEXT WITH DEFAULTS
```r
# Global setting - always available
tfl_set_options(
  bodyText = add_body_text(NULL, 
    text = "No data to report",
    id = NULL  # Auto-becomes __default_001
  )
)

# Automatic in all new specs
spec <- tfl_init(data)
# spec$bodyText = {__default_001: {text: "No data to report", order: 999}}

# User adds custom bodyText
spec <- spec %>%
  add_body_text("Analysis not performed")
# AUTOMATICALLY REMOVES __default_001 and replaces with user's version
# Result: spec$bodyText = {bodyText_1: {text: "Analysis not performed", order: 1}}

# If user wants to keep default AND add custom:
spec <- spec %>%
  add_body_text("Also include this")
# Result has ONLY user entries, __default_* gone
```

### 4. IMPROVED OPTIONS API
```r
# OLD (dots, limited validation)
tfl_set_settings(
  doc_style_template = "template",
  page = s_page(...),  # Problem: objects don't work well with dots
  headers = add_header(...)  # Problem: complex structures
)

# NEW (named parameters, full validation)
tfl_set_options(
  doc_style_template = "template",
  page = s_page(...),  # ✓ Validated as tfl_page
  headers = add_header(...),  # ✓ Validated as proper structure
  bodyText = add_body_text(...),  # ✓ Validated for __default_* pattern
  footers = NULL,  # ✓ Optional
  styles = NULL,  # ✓ Optional
  # ... other parameters
)
```

### 5. CONSTANTS CONSOLIDATION
```r
# From constants.R - all defaults defined once
.const_default_page_size = "A4"
.const_default_page_orientation = "landscape"
.const_default_doc_template = "KeyStat_default"
.const_default_bodytext = "No data to report"
.const_bodytext_default_id_prefix = "__default"
.const_default_bodytext_order = 999
.const_max_header_footer_parts = 3L

# Used consistently throughout:
# - pkg_settings.R initializes defaults
# - spec_context.R validates/creates entries
# - spec_init.R applies settings
# - No hardcoded strings scattered in code
```

---

## Key Features

### Feature: Default Body Text Auto-Removal
```
Situation: User has settings with default "No data" message
spec <- tfl_init(data)
# spec has: bodyText { __default_001: {text: "No data to report"} }

# User wants to customize:
spec %>% add_body_text("Custom: Data not available")
#                  ↓
#        Check if any __default_* entries exist
#                  ↓
#        YES → Remove __default_* entries first
#                  ↓
#        Then add user's custom text
#                  ↓
# Result: bodyText { bodyText_1: {text: "Custom: Data not available"} }
```

### Feature: Settings Reuse Across Session
```
# Project A: Financial tables
tfl_set_options(
  page = s_page(size = "A4"),
  headers = add_header(NULL, c("Finance Report", "", "")),
  bodyText = add_body_text(NULL, "Financial data not available")
)
spec1 <- tfl_init(data1)
spec2 <- tfl_init(data2)
spec3 <- tfl_init(data3)
# All get Project A defaults

# Project B: Clinical tables
tfl_set_options(
  page = s_page(size = "Letter"),
  headers = add_header(NULL, c("Clinical Report", "", "")),
  bodyText = add_body_text(NULL, "Patient data not available")
)
spec4 <- tfl_init(data4)
spec5 <- tfl_init(data5)
# All get Project B defaults

# Reset to package defaults
tfl_reset_settings()
```

---

## Files Modified & Their Roles

| File | Changes | Purpose |
|------|---------|---------|
| **constants.R** | Add new constants for defaults | Single source of truth for all defaults |
| **pkg_settings.R** | Complete redesign | New API, validation, initialization |
| **spec_init.R** | Update `.fill_spec_defaults()` | Apply page/headers/footers to new specs |
| **spec_context.R** | Update `add_body_text.TFL_spec()` | Remove __default_* entries on override |
| **spec_context.R** | Add helper function | ID generation for default entries |

---

## Implementation Complexity Levels

### 🟢 EASY (Few dependencies, clear logic)
- Add new constants to constants.R
- Update `.fill_spec_defaults()` to apply page settings
- Update header/footer application in `.fill_spec_defaults()`

### 🟡 MEDIUM (Some validation, moderate changes)
- Redesign `tfl_set_options()` with named parameters
- Add validation for page/headers/footers objects
- Create ID generation helper for bodyText

### 🔴 HARD (Complex logic, careful design)
- Implement `__default_*` removal logic in `add_body_text.TFL_spec()`
- Ensure defaults merge correctly without duplicates
- Header/footer merging strategy (defaults + user additions)

---

## Risk & Mitigation

| Risk | Mitigation |
|------|-----------|
| **Breaking existing code** using `tfl_set_settings(...)` | Keep old function as deprecated wrapper OR clear migration guide |
| **Complex merging** of defaults + user additions | Clear documentation, explicit behavior (merge vs replace) |
| **`__default_*` IDs conflict** with user IDs | Document naming convention, validate on creation |
| **Circular dependencies** between functions | Careful import planning, maybe extract ID generation to separate file |
| **Performance** if too much validation | Validation only on set_options(), not on every tfl_init() |

---

## Success Metrics

After implementation, user should be able to:

✅ Set default page layout once, reuse in all specs  
✅ Set default headers/footers once, reuse in all specs  
✅ Have "No data" message without explicit definition  
✅ Override defaults per-spec without side effects  
✅ Use `tfl_set_options()` with clear, validated parameters  
✅ Read code and understand where defaults come from (constants.R)  
✅ See practical examples in documentation  
✅ Existing code still works (backwards compatible)  

---

## Questions Needing Answers Before Code Implementation

**CRITICAL (affects design)**:
1. When user adds custom bodyText, should `__default_*` entries be removed automatically or manually?
2. Should default headers merge with user headers, or replace them?
3. Named parameters or keep using dots for `tfl_set_options()`?

**IMPORTANT (affects scope)**:
4. Should we include `bodyTitles`, `bodySubtitles`, `contentWidth` in new API?
5. Should we support settings save/restore for multi-project workflows?

**NICE-TO-HAVE (can defer)**:
6. External config file support (JSON/YAML)?
7. S3 `TFL_settings` object with methods?
