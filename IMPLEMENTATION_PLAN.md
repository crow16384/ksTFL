# TFL Settings System Refactoring - Implementation Plan

## Current State Analysis

### Existing Implementation
- **pkg_settings.R**: Basic settings storage using environment `.options_env`
- **Settings structure**: Flat list with some nested structures (page, headers, footers, bodyText, styles)
- **API**: `tfl_set_settings(...)`  uses dots for flexible arguments
- **Functions**: `tfl_get_settings()`, `tfl_get_setting()`, `tfl_set_settings()`, `tfl_reset_settings()`
- **Integration**: `spec_init.R` calls `tfl_get_settings()` via `.fill_spec_defaults()`

### Current Limitations
1. **Page Settings**: Defaults exist but hardcoded, users can't use `s_page()` modifier functions
2. **Headers/Footers**: Can be set but no easy way to use `add_header()` / `add_footer()` functions
3. **Body Text**: Has basic `bodyText` list but no default "No data" message or `__default_nnn` pattern
4. **API Issues**: Using `...` makes it hard to handle complex types (e.g., objects from s_page())
5. **Documentation**: No clear guidance on workflow or what settings are available

---

## Proposed Improvements (5 Components)

### 1. PAGE SETTINGS MANAGEMENT

#### Requirements
- User can set default page size, orientation, and margins using `s_page()` function
- `tfl_init()` reads these page defaults from settings
- User can override defaults per-TFL if needed

#### Implementation Approach
```
Current: page = list(size = "A4", orientation = "landscape")
Proposed: page = tfl_page_object created via s_page()
```

**Changes needed**:
- Modify `tfl_set_options()` to accept named `page = s_page(...)` parameter
- Update constants to reference page defaults from settings
- Ensure `tfl_init()` applies page settings via `set_document_style()` after init
- Add validation that `page` parameter is either NULL or tfl_page object

#### Code Locations
- `pkg_settings.R`: Update defaults structure and validation
- `spec_init.R`: Add page settings application in `.fill_spec_defaults()`
- `constants.R`: Add page-related constants (already partially exist)

---

### 2. HEADERS & FOOTERS MANAGEMENT

#### Requirements
- User can set default headers/footers in settings (e.g., company name, standard footer)
- Use `add_header()` / `add_footer()` functions to define settings
- `tfl_init()` applies these defaults to new specs
- User can override per-TFL

#### Implementation Approach
```
Settings stores headers/footers as structured data that can be applied via functions
Allow both:
  - tfl_set_options(headers = list(c("text1", "text2")))  [raw list]
  - tfl_set_options(headers = add_header(NULL, c("text1", "text2")))  [via function]
```

**Changes needed**:
- Extend `add_header.TFL_options()` and `add_footer.TFL_options()` to work with settings
- Modify `tfl_set_options()` to accept `headers` and `footers` parameters
- Update `.fill_spec_defaults()` to apply headers/footers from settings
- Ensure headers/footers can be chained/merged with user additions

#### Code Locations
- `spec_context.R`: Enhance `add_header.TFL_options()`, `add_footer.TFL_options()`
- `pkg_settings.R`: Support headers/footers in settings workflow
- `spec_init.R`: Apply headers/footers in `.fill_spec_defaults()`

---

### 3. BODY TEXT MANAGEMENT (Most Complex)

#### Requirements
3a) **Default Text**: Define global "No data to report" message
3b) **Session Override**: User can redefine default via `tfl_set_options()`
3c) **ID Pattern**: Default bodyText uses special IDs: `__default_nnn` (e.g., `__default_001`)
3d) **Removal on Override**: When user calls `add_body_text()` on TFL_spec, remove any `__default_*` entries first

#### Implementation Approach

**Step 1: Add bodyText to defaults**
```r
bodyText = list(
  "__default_001" = list(
    text = list("No data to report"),
    order = 999,  # High order so appears at end
    styleRef = NULL
  )
)
```

**Step 2: ID Generation Pattern**
- When adding bodyText via settings: auto-generate `__default_NNN` IDs
- When adding bodyText via `add_body_text()`: use normal IDs (auto-generated or user-provided)
- Helper function: `.generate_bodytext_id(prefix, counter)`

**Step 3: Default Cleanup on Override**
- Modify `add_body_text.TFL_spec()` to:
  - Detect if any `__default_*` bodyText entries exist
  - If user is adding new bodyText, remove all `__default_*` entries first
  - This prevents mix of defaults with user-defined entries

**Step 4: Enhanced `add_body_text()` Workflow**
```r
# User flow:
tfl_init(data) %>%
  add_body_text("Custom no-data message")  # This automatically removes __default_* entries

# Settings flow:
tfl_set_options(
  bodyText = add_body_text(NULL, text = "Company standard: No data")
)
```

#### Code Locations
- `constants.R`: Add `.const_default_bodytext` constant
- `pkg_settings.R`: Initialize bodyText with default message
- `spec_context.R`: Update `add_body_text.TFL_spec()` to remove `__default_*` entries
- Helper function: `.generate_bodytext_id()` in `spec_init.R` or `utils.R`

---

### 4. TFL_SET_OPTIONS API IMPROVEMENT

#### Current Issue
```r
# Current (using dots):
tfl_set_options(
  doc_style_template = "template",
  page = s_page(...),  # PROBLEM: s_page() returns object, dots don't handle well
  headers = add_header(NULL, ...),  # PROBLEM: complex objects
  bodyText = add_body_text(...)  # PROBLEM: list of entries
)
```

#### Options to Consider

**Option A: Keep dots but add validation logic**
- Pros: Backwards compatible
- Cons: Harder to validate complex types
- Implementation: Check each value's class inside function

**Option B: Switch to named parameters (RECOMMENDED)**
```r
tfl_set_options <- function(
  doc_style_template = NULL,
  page = NULL,
  headers = NULL,
  footers = NULL,
  bodyText = NULL,
  styles = NULL,
  bodyTitles = NULL,
  bodySubtitles = NULL,
  bodyFootnotes = NULL,
  isContinues = NULL,
  contentWidth = NULL,
  output_directory = NULL
) { ... }
```
- Pros: Explicit, easier to validate, works with complex objects
- Cons: Longer signature, requires documentation
- Implementation: Use NULL defaults, only update non-NULL values

**Option C: Hybrid - keep dots but add helper functions**
```r
# Instead of direct tfl_set_options(page = s_page(...)):
# Use:
tfl_set_default_page(size = "A4", orientation = "landscape", margins = ...)
tfl_set_default_headers(...)
tfl_set_default_footers(...)
```
- Pros: Specialized functions easier to understand
- Cons: More functions to maintain

#### Recommendation
**Implement Option B** with backwards compatibility wrapper:
- New signature with named parameters
- Internal helper function to merge with current settings
- Keep `.tfl_set_settings_legacy()` for backwards compatibility
- Update all documentation

#### Code Changes
```r
# New function signature:
tfl_set_options <- function(
  doc_style_template = NULL,
  page = NULL,
  headers = NULL,
  footers = NULL,
  bodyText = NULL,
  styles = NULL,
  # ... other parameters
) {
  # Validation for each parameter
  if (!is.null(page)) {
    if (!inherits(page, "tfl_page")) {
      cli_abort("page must be created with s_page() function")
    }
  }
  # Similar validation for others...
  
  # Merge with existing settings
  settings <- tfl_get_settings()
  updates <- list(
    doc_style_template = doc_style_template %||% settings$doc_style_template,
    page = page %||% settings$page,
    # ... etc
  )
  # Apply updates
}
```

---

### 5. CONSTANT CONSOLIDATION & INTEGRATION

#### Current Constants (from constants.R)
- `.const_default_page_size = "A4"`
- `.const_default_page_orientation = "landscape"`
- `.const_default_doc_template = "KeyStat_default"`
- `.const_max_header_footer_parts = 3L`

#### New Constants Needed
- `.const_default_bodytext = "No data to report"`
- `.const_bodytext_default_id_prefix = "__default"`
- `.const_default_bodytext_order = 999` (appears at end)

#### Integration Checklist
- [ ] Replace all hardcoded defaults in `pkg_settings.R` with constants
- [ ] Replace all hardcoded strings in `spec_context.R` with constants (where appropriate)
- [ ] Create helper function `.get_default_bodytext_id()` that uses constants
- [ ] Use constants in all settings initialization and validation
- [ ] Document all constants with explanatory comments

---

## Implementation Sequence (Recommended Order)

### Phase 1: Foundation (Constants & API)
1. **Update constants.R** - Add new constants for bodyText defaults
2. **Redesign tfl_set_options()** - Implement named parameter API with validation

### Phase 2: Page Settings
3. **pkg_settings.R** - Update to use constants, ensure page object support
4. **spec_init.R** - Integrate page settings into `.fill_spec_defaults()`

### Phase 3: Headers & Footers
5. **spec_context.R** - Enhance TFL_options methods for headers/footers
6. **pkg_settings.R** - Wire headers/footers into settings workflow
7. **spec_init.R** - Apply headers/footers in spec initialization

### Phase 4: Body Text (Most Complex)
8. **Helper function** - Add `.generate_bodytext_id()` and default detection
9. **pkg_settings.R** - Initialize bodyText with `__default_001` entry
10. **spec_context.R** - Update `add_body_text.TFL_spec()` to remove defaults
11. **spec_init.R** - Apply bodyText defaults in `.fill_spec_defaults()`

### Phase 5: Testing & Documentation
12. **Integration testing** - Verify all settings flow correctly
13. **Update roxygen** - Document new parameter structure
14. **Add examples** - Show practical usage patterns

---

## Key Questions Before Implementation

1. **Body Text ID Pattern**: 
   - Should `__default_001` always exist, or only if explicitly set?
   - What order value should default bodyText use?
   - Should it be user-editable after `tfl_init()`?

2. **Header/Footer Merging**:
   - Should default headers merge with user-added headers, or replace?
   - How do we handle duplicates?

3. **Page Settings**:
   - Should users be able to set margins separately, or only via `s_page()`?
   - How do we handle `s_margins()` inside `s_page()`?

4. **Backwards Compatibility**:
   - Should we deprecate the old `tfl_set_settings(...)`?
   - How long should we support both APIs?

5. **Scope**:
   - Should `styles` also be settable with default styling?
   - Should document properties like `contentWidth`, `bodyTitles` be part of this?

---

## Files to Modify

1. **constants.R** - Add new constants
2. **pkg_settings.R** - Major refactoring (defaults, API, validation)
3. **spec_context.R** - Update content functions for TFL_options class
4. **spec_init.R** - Apply settings during initialization
5. **spec_context.R** - Add ID generation helper function

---

## Success Criteria

✅ Users can define page defaults with `s_page()` and reuse across session  
✅ Users can define header/footer defaults and apply automatically  
✅ Default "No data" bodyText appears without explicit definition  
✅ Users can override defaults per-TFL without side effects  
✅ `tfl_set_options()` is type-safe and validates complex objects  
✅ Code uses constants consistently, no hardcoded strings  
✅ Backwards compatibility maintained or clearly deprecated  
✅ Clear documentation with practical examples  
