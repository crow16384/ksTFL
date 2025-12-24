# Module: Conditional Column & Row Actions for Clinical TFL Spec (R)
Context

You are extending an existing R package used to define metadata for clinical TFL (Tables, Figures, Listings) generation.
Our goal in general is to provide user possibility to conditionally define a set of actions to be performed by the python renderer on the table rows.
The new functionality should be created in the separate rowstyle_actions.R module. Common functions can be placed to utility-functions.R. If any functions that you can re-use already exists - use them instead of writing a duplicate. don't be lazy, think deeper and always double-check the existing functions implementation. Don't try to guess or imaging - read existing code and roxygens. 
Any global constant values can be placed to constants.R or existing can be reused from there.

## Key existing components:

spec$.metadata$data_env
An evaluation environment created using helpers defined in env_eval_helpers.R.
This environment:

Contains the full dataset as __data__

Supports tidyverse-style data masking

Provides helper functions like:

firstOf(), lastOf()

row_number(), every_nth()

.get_data_column_names() to resolve the tidyselect cols

.env_eval(expr) for evaluating expressions within our data environment

spec$.metadata$report_cols
Character vector defining which columns are rendered in the final table. Also, names(spec$columns can be used - whatever is easier)

spec$styleRows (not in .metadata)
A list of row action objects, one per data row, describing row-level rendering actions.
Each element is either:
- NULL (no actions for this row)
- A list with elements: $style, $merge, $add_row (as appropriate)

The list structure is preserved throughout spec processing and serialized to JSON only
at the final serialization step in serialize_spec(). This eliminates fragile JSON 
string parsing/manipulation and keeps the code cleaner and safer.

# Goal

Implement a declarative DSL that allows users to define conditional row actions (styling, merging, inserting rows) in R, evaluated later during spec finalization.

The DSL must:

Allow multiple calls

Accumulate unevaluated expressions

Evaluate everything once, during create_report(spec)

Produce one JSON action object per row (use the schema_serialize functionality to get the JSON restructured in accordance with row_style_actions_schema_v0.json)

Be safe, validated, and deterministic (clinical reporting)

Public API to Implement
compute_cols()
compute_cols(
  spec,
  cond,
  action1,
  action2,
  ...
)

Rules:

cond required

cond is evaluated via .env_eval(cond)

cond must return logical(nrow(data))

cond may reference any column in data_env and can use embedded functions. e.g. cond may be like col1>0, or firstOf(cyl, am), or col1==1 & col2 > col3 etc.. 

Actions must be function calls only

multiple calls of compute_cols() is allowed on the spec object. 

multiple actions are allowed (including repeating the same action name) within each call of compute_cols(). 

compute_cols() is only allowed when spec docType is 'Table'

Supported actions:

style(cols, styleRef)

merge(cols, styleRef = NULL)

add_row(pos = c("above","below"), value_from, styleRef = NULL)

Behavior

compute_cols() does not evaluate anything

It captures unevaluated expressions

It appends metadata to spec$.metadata$compute_cols

Returns modified spec

Internal Storage (Unevaluated)

Each call to compute_cols() appends:

spec$.metadata$compute_cols <- list(
  list(
    cond = <quosure>,
    actions = list(<quosure>, <quosure>, ...)
  ),
  ...
)

Column Rules
Context	Allowed
cond	Any column in data_env
cols, value_from	Must exist in spec$.metadata$report_cols or names(spec$columns)
styleRef - name of the style defined in the spec. Styles can be combined using existing f_combine() logic. Create_report() during sanitization should apply the same style combining logic as it currently does for other combined styles. 

Violations → error

Column selection must use:

.get_data_column_names(
  data,
  ...,
  .selenv = spec$.metadata$data_env
)

Supported Actions
1. style(cols, styleRef)

cols: tidyselect (use .get_data_column_names() )

styleRef: string

Multiple styles allowed per row

If same column styled multiple times → last wins merge (or warning)

2. merge(cols, styleRef = NULL)

cols:

tidyselect (use .get_data_column_names() )

must resolve to ≥2 columns

must be adjacent in report_cols order

Multiple merge ranges allowed per row

Merge ranges must not intersect

Intersections:

warn if resolvable

error if ambiguous

3. add_row(pos, value_from, styleRef = NULL)

Inserts one row per call

pos: "above" or "below"

value_from: single column (character after resolution)

Multiple add_row() allowed

Order of appearance must be preserved

Coexists with other actions on same row

Evaluation Phase (Executed in create_report())
Overview

Implement a finalization step that:

Evaluates all conditions

Expands actions per row

Resolves conflicts

Serializes per-row JSON

Populates spec$.metadata$styleRows

Pseudocode Outline - needs to be adapted for our package
.finalize_compute_cols <- function(spec) {
  data <- spec$.metadata$data_env$`__data__`
  n <- nrow(data)

  row_actions <- vector("list", n)

  for (block in spec$.metadata$compute_cols) {
    cond_vec <- .env_eval(!!block$cond)

    validate_condition(cond_vec, n)

    for (i in which(cond_vec)) {
      for (action in block$actions) {
        parsed <- parse_action(action, spec, data)
        row_actions[[i]] <- append_action(row_actions[[i]], parsed)
      }
    }
  }

  row_actions <- sanitize_row_actions(row_actions, spec)

  spec$.metadata$styleRows <- serialize_row_actions(row_actions)
  spec
}

Internal Row Action Structure

Before serialization, each row uses:

row_actions[[i]] <- list(
  style   = list(),   # list of {cols, style}
  merge   = list(),   # list of {cols, style?}
  add_row = list()    # list of {pos, value_from, style?}
)

Conflict Resolution Rules
Conditions

Must be logical

Must match nrow(data)

No NA allowed

Style

Same column styled multiple times → last wins, warning

Merge

Non-adjacent columns → error

Overlapping ranges → warning → error if unresolved

Add row

No conflicts

Preserve order exactly

JSON Output Contract (Per Row)

Each row is serialized into one JSON object or NULL.

JSON Shape (see row_style_actions_schema_v0.json)
{
  "style": [
    { "cols": ["ARM", "TRT"], "style": "font_bold" },
    { "cols": ["VALUE"], "style": "text_red" }
  ],
  "merge": [
    { "cols": ["ARM", "TRT"], "style": "group" }
  ],
  "add_row": [
    { "pos": "above", "value_from": "ARM", "style": "subhead" }
  ]
}


Rows with no actions → empty json, since NULLs could be dropped during serialization, but we need to keep the spec$styleRows the same length as data.

Preserve array order

Use jsonlite::toJSON(auto_unbox = TRUE)

Implementation Expectations

Prefer simple lists and helper functions

Fail early on structural errors

Use warnings for resolvable conflicts

Code must be readable and testable (clinical reporting context)

### Files to Reference

env_eval_helpers.R

.env_eval()

.get_data_column_names()

evaluation helpers (firstOf, lastOf, etc.)

schemas/row_style_actions_schema_v0.json

utility_functions.R

create_report.R


## Deliverables

compute_cols() (exported)

c_style() (exported, context-aware)

c_merge() (exported, context-aware)

c_addrow() (exported, context-aware)

Internal helpers:

action parsing

validation

conflict resolution

JSON serialization

Integration into create_report(spec)

## Implementation Clarifications (Dec 23, 2025)

### Action Functions Naming & Behavior
- Action functions renamed: `style()` → `c_style()`, `merge()` → `c_merge()`, `add_row()` → `c_addrow()`
- All are **exported** but **context-aware** (must be called inside `compute_cols()`)
- Context validation via `.assert_context("compute_cols", fn_name)` pattern

### Column Selection Support
- All column specifications (cols, value_from) support full **tidyselect syntax**
- Use `.get_data_column_names(.data, ..., .selenv = spec$.metadata$data_env)` for resolution
- Consistent with `define_cols()` behavior

### Merge Validation
- **Immediate check** (in `c_merge()` function): verify specified columns exist and are consecutive in report_cols order
- **Deferred check** (in finalization): detect overlapping merge ranges across multiple `compute_cols()` calls
  - If resolvable: issue warning, allow merge
  - If ambiguous: error abort

### Style Combination Logic
**KEY BEHAVIOR**: When same column receives multiple styles from different `compute_cols()` calls on the same row:
- Automatically create combined/merged style (deep merge using `.merge_recursive()`)
- Similar to existing `f_combine()` consolidation behavior
- Example:
  ```r
  compute_cols(spec, col1 >= 10, c_style(col1, styleRef = "font_bold"))
  compute_cols(spec, col1 == 10, c_style(col1, styleRef = "text_red"))
  # Row where col1==10: both conditions true → combined style (font_bold + text_red merged)
  ```
- `create_report()` automatically consolidates all style combinations into single merged styles
- Existing combined styles (`f_combine()` style refs) are preserved and reused

### Empty Row Actions
- Rows with no actions serialize to empty string `""`
- Maintains fixed-length array in `spec$.metadata$styleRows` matching `nrow(data)`

### Initialization
- `spec$.metadata$compute_cols` initialized as empty list in `.tfl_init()` for Table docTypes only
- Text and Figure docTypes reject any `compute_cols()` calls (no data to evaluate)

### Integration Point in create_report()
**Execution order** (within create_report):
1. Flatten and validate input specs
2. **Finalize compute_cols()** → `.finalize_compute_cols(spec)` (evaluates conditions, builds row_actions)
3. **Consolidate styles** → both existing spec styles AND newly-created rowstyle combinations
4. Renumber docOrder and dataRef
5. Build final TFL_report

**Rationale**: Finalize rowstyle actions first, then consolidate all styles together in one pass (cleaner, single source of truth for style merging)

## Architecture: R List Structures vs JSON Strings (Dec 23, 2025 Refactoring)

### Design Decision
`spec$styleRows` is kept as a **list of R objects** throughout spec processing, with serialization to JSON occurring only at the final step in `serialize_spec()`. This eliminates the need for JSON string parsing/manipulation within the consolidation pipeline.

### Why This Design?

**Eliminated Fragility**:
- No JSON parsing/reparsing during style consolidation
- No `jsonlite::fromJSON()` silent data structure conversions
- No string-based conditional logic on JSON format

**Type Safety**:
- Native R data structures throughout pipeline
- Compiler can catch type mismatches
- Consistent treatment with other spec fields

**Cleaner Code**:
- Direct list iteration instead of JSON string checks
- Reuse existing `.replace_style_refs()` function for styleRows
- No special error handling for JSON parsing failures

**Single Serialization Point**:
- All JSON conversion happens in `serialize_spec()`
- `jsonlite::toJSON()` with `auto_unbox=TRUE` handles final JSON output
- Consistent with Python backend expectations

### Implementation Details

**R List Structure**:
```r
spec$styleRows[[row_idx]] = list(
  style = list(
    list(cols = c("col1", "col2"), style = "font_bold"),
    list(cols = c("col3"), style = c("text_red", "bg_yellow"))
  ),
  merge = list(
    list(cols = c("col1", "col2"), style = "merge_style")
  ),
  add_row = list(
    list(pos = "after", value_from = "col1", style = "add_style")
  )
)

# Or NULL if no actions for this row
spec$styleRows[[row_idx]] = NULL
```

**Serialization Pipeline**:
- `.finalize_compute_cols()` creates `spec$styleRows` as R list
- `._consolidate_styles_in_spec()` (in create_report) modifies lists directly via `.replace_style_refs()`
- `serialize_spec()` converts final list to JSON via `jsonlite::toJSON()`

**Collection and Replacement** (in create_report Phase 3):
```r
# Collect style refs - direct list iteration
for (row_obj in spec$styleRows) {
  if (!is.null(row_obj) && !is.null(row_obj$style)) {
    for (style_action in row_obj$style) {
      # Extract style reference...
    }
  }
}

# Replace style refs - recursive list modification
spec$styleRows[[i]] <- .replace_style_refs(spec$styleRows[[i]])
```
