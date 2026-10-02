#=============================================================================
# ksTFL/R/rowstyle_actions.R
# Conditional column and row actions for clinical TFL specifications
#=============================================================================

#' @importFrom rlang enquo enquos quo_get_expr quo_get_env is_quosure eval_tidy
#' @importFrom checkmate assert_class assert_string assert_character assert_list
#' @importFrom cli cli_abort cli_warn
#' @importFrom tidyselect eval_select
NULL

# ============================================================
# PART 1: PUBLIC API - COMPUTE COLS AND ACTION BUILDERS
# ============================================================

#' Define Conditional Row Actions for Tables
#'
#' Declares a set of styling, merging, and row insertion actions to be applied
#' to rows matching a condition. Actions are captured as unevaluated expressions
#' and evaluated later during `create_report()`. Supports complex conditions using
#' data columns and helper functions.
#'
#' @param spec A TFL_spec object (must have docType = "Table")
#' @param cond An unquoted logical expression to be evaluated in the data environment.
#'   Can reference:
#'   \itemize{
#'     \item Data columns directly (e.g., `col1 > 10`, `Parameter == "Pulse"`)
#'     \item Condition helpers evaluated over the data: `firstOf()`, `lastOf()`,
#'       `firstRow()`, `lastRow()`, `rowNumber()`, `everyNth()`, `firstOfBlock()`
#'       (see Details)
#'   }
#'   Must return a logical vector of length equal to `nrow(data)`, or a single
#'   `TRUE`/`FALSE` scalar (applies the actions to all rows / no rows).
#' @param ... Action function calls: `c_style()`, `c_merge()`, `c_addrow()`,
#'   `c_glue()`, `c_clear()`, `c_pageBreak()`.
#'   Multiple actions allowed, including duplicates. Actions are captured
#'   unevaluated and execute in arrival order: argument order within one
#'   `compute_cols()` call, then call order across piped calls.
#'
#' @return Modified `spec` object with appended action metadata in `spec$.metadata$compute_cols`.
#'   Invisibly returns the updated spec to enable piping workflows.
#'
#' @seealso [c_style()], [c_merge()], [c_addrow()] for action functions used within `compute_cols()`
#'
#' @details
#' **Condition helpers** (available only inside `cond`; they operate on the
#' raw data frame):
#' \itemize{
#'   \item `firstOf(col)` / `lastOf(col)`: `TRUE` at the first/last row of each
#'     RUN of equal values (run-length semantics). The input must be sorted so
#'     that each logical group is contiguous, otherwise a value that
#'     re-appears later counts as a new run. Multiple columns
#'     (`firstOf(col1, col2)`) test combined run boundaries.
#'   \item `firstRow()` / `lastRow()`: single-row markers at absolute positions.
#'   \item `rowNumber()`: integer row index, usable in arbitrary expressions.
#'   \item `everyNth(n)`: `TRUE` every n-th row starting from row 1.
#'   \item `firstOfBlock(col, n = 1, offset = 0)`: `TRUE` on the first row of
#'     every n-th run-block of `col` (after the first block).
#' }
#'
#' **Execution Timeline:**
#' 1. `compute_cols()` captures condition and actions (no evaluation)
#' 2. Appends to `spec$.metadata$compute_cols` list
#' 3. During `create_report()`, conditions are evaluated and matched rows identified
#' 4. Actions are applied to matching rows (styling, merging, row insertion)
#' 5. StyleRows are serialized to JSON
#'
#' **Constraints:**
#' - Only allowed for docType = "Table"
#' - Multiple `compute_cols()` calls accumulate on the same spec
#' - Actions on the same row from different `compute_cols()` blocks are aggregated
#' - Conditions must be deterministic (no NA values allowed)
#'
#' **Action Functions** (used inside `compute_cols()`):
#' \itemize{
#'   \item `c_style(cols, styleRef)`: Apply style(s) to columns in matching rows
#'   \item `c_merge(cols, styleRef = NULL)`: Merge adjacent columns in matching rows
#'   \item `c_addrow(pos, value_from = NULL, styleRef = NULL)`: Insert row above/below matching rows
#'   \item `c_pageBreak()`: Insert a page break at the matching row (no args)
#'   \item `c_glue(cols, position, glue_col = NULL, text = NULL, separator = NULL)`: Concatenate a data column value or literal text to matching cell text
#'   \item `c_clear(cols)`: Clear the display text of matching cells (render as blank)
#' }
#'
#' @examples
#'   spec <- create_table(mtcars)
#'   spec <- add_style(spec, id = "bold", s_font(bold = TRUE))
#'   spec <- add_style(spec, id = "red", s_font(color = "red"))
#'   spec <- add_style(spec, id = "highlight", s_table_style(background_color = "#FFFF00"))
#'
#'   # Style columns in rows where cyl starts a new run (sorted input!)
#'   spec <- compute_cols(spec, firstOf(cyl), c_style(c(mpg, hp), styleRef = "bold"))
#'
#'   # Style and merge columns in rows with high hp
#'   spec <- compute_cols(spec, hp > 200,
#'     c_style(hp, styleRef = "red"),
#'     c_merge(c(wt, qsec), styleRef = "highlight")
#'   )
#'
#'   # Empty separator row above each new cyl run
#'   spec <- compute_cols(spec, firstOf(cyl), c_addrow(pos = "above"))
#'
#'   # Row with content copied from a column (bare symbol or quoted name)
#'   spec <- compute_cols(spec, lastOf(cyl), c_addrow(pos = "below", value_from = mpg))
#'
#'   # Page break before each new cyl run; scalar condition = all rows
#'   spec <- compute_cols(spec, firstOf(cyl), c_pageBreak())
#'   spec <- compute_cols(spec, TRUE, c_style(disp, "red"))
#'
#'   # Actions execute in arrival order (here: wt is cleared, then re-filled)
#'   spec <- compute_cols(spec, gear == 4, c_clear(wt), c_glue(wt, "after", text = "t"))
#'
#' @export
compute_cols <- function(spec, cond, ...) {
  # Validate spec
  checkmate::assert_class(spec, "TFL_spec", .var.name = "spec")

  # Verify spec is a Table
  if (spec$document$docType != "Table") {
    cli_abort(c(
      "{.fn compute_cols} is only allowed for docType = {.str Table}",
      x = "Current spec has docType = {.str {spec$document$docType}}",
      i = "Only tables support conditional row actions"
    ))
  }

  # Capture unevaluated condition
  cond_quo <- enquo(cond)

  # Capture all action expressions
  action_quos <- enquos(...)

  if (length(action_quos) == 0) {
    cli_abort(c(
      "{.fn compute_cols} requires at least one action",
      x = "No actions provided (c_style, c_merge, c_addrow)",
      i = "Example: {.fn compute_cols}(spec, cond, {.fn c_style}(cols, styleRef))"
    ))
  }

  # Set context for action functions
  current_env <- environment()
  .set_context(current_env, "compute_cols")

  # Initialize compute_cols list if needed
  if (is.null(spec$.metadata$compute_cols)) {
    spec$.metadata$compute_cols <- list()
  }

  # Append new block
  spec$.metadata$compute_cols[[length(spec$.metadata$compute_cols) + 1L]] <- list(
    cond = cond_quo,
    actions = action_quos
  )

  # Clear context
  .clear_context(current_env)

  invisible(spec)
}

# ============================================================
# PART 2: ACTION BUILDER FUNCTIONS (Context-Aware)
# ============================================================

#' Apply Style to Columns in Conditional Rows
#'
#' Declares a style or combination of styles to be applied to specified columns
#' in rows matching the parent `compute_cols()` condition.
#'
#' @param cols Tidyselect expression for column selection
#'   (e.g., `c(col1, col2)`, `everything()`, `starts_with("x")`)
#' @param styleRef Character. Name of the style to apply (defined via `add_style()`).
#'   Can be a single style name (e.g., `"bold"`) or result of `f_combine()` for
#'   combining multiple styles (e.g., `f_combine("bold", "red")`).
#'   When multiple styles are provided via `f_combine()`, they are merged in the
#'   order listed (last wins for conflicting properties).
#'
#' @return Quosure structure (internal use within `compute_cols()`)
#'
#' @details
#' Must be called inside `compute_cols()`. Columns are resolved using
#' tidyselect syntax against the table data.
#'
#' **Behavior:**
#' \itemize{
#'   \item Same column styled multiple times in one row: last style wins, warning issued
#'   \item Same column styled from different `compute_cols()` calls on same row:
#'     non-conflicting properties COMBINE (e.g. bold then italic yields
#'     bold-italic); on a conflicting property the later block wins
#'     (automatic style combination consolidated via `create_report()`).
#'   \item Multiple columns in one call: all receive the same style(s)
#' }
#'
#' **Style Combination:**
#' - Use `f_combine("style1", "style2")` to apply multiple styles together
#' - During `create_report()`, combined styles are consolidated into a single hash
#' - Consolidation only happens for new specs (not pre-processed reports)
#'
#' @seealso [compute_cols()] for conditional row actions, [c_merge()], [c_addrow()] for other action types
#'
#' @examples
#'   spec <- create_table(mtcars) |>
#'     add_style("bold", s_font(bold = TRUE)) |>
#'     add_style("red", s_font(color = "red"))
#'
#'   # Single style on one column
#'   spec <- compute_cols(spec, cyl == 6, c_style(mpg, styleRef = "bold"))
#'
#'   # Single style on multiple columns
#'   spec <- compute_cols(spec, hp > 100, c_style(c(mpg, wt), styleRef = "red"))
#'
#'   # Combined styles on columns (last argument wins per property)
#'   spec <- compute_cols(spec, cyl == 8, c_style(mpg, styleRef = f_combine("bold", "red")))
#'
#' @export
c_style <- function(cols, styleRef) {
  # Validate context
  .assert_context("compute_cols", "c_style")

  # Capture column expression for later tidyselect resolution
  cols_quo <- enquo(cols)

  # Validate styleRef: single string or f_combine() result (character vector)
  checkmate::assert_character(
    styleRef,
    min.len = 1L,
    any.missing = FALSE,
    .var.name = "styleRef"
  )

  # Return as a marker object for parsing in .finalize_compute_cols()
  structure(
    list(
      type = "style",
      cols = cols_quo,
      styleRef = styleRef
    ),
    class = "tfl_action_style"
  )
}

#' Merge Adjacent Columns in Conditional Rows
#'
#' Declares adjacent columns to be merged in rows matching the parent
#' `compute_cols()` condition. Merged columns appear as a single spanned cell.
#'
#' @param cols Tidyselect expression for column selection. Must resolve
#'   to at least 2 columns that are consecutive in the report column order.
#' @param styleRef Character vector or result of `f_combine()`. Optional style
#'   to apply to the merged cell. If NULL, no special styling.
#'
#' @return Quosure structure (internal use within `compute_cols()`)
#'
#' @details
#' Must be called inside `compute_cols()`. Columns must be adjacent in the
#' final report column order.
#'
#' **Validation:**
#' \itemize{
#'   \item Immediate: columns exist and are consecutive (error if not)
#'   \item Deferred: overlapping merge ranges within/across `compute_cols()`
#'     calls: a warning is issued and the FIRST-defined merge wins (later
#'     overlapping merges are dropped)
#' }
#'
#' **Behavior:**
#' - Multiple merge actions in one row: all applied if non-overlapping
#' - The merged cell keeps the LEADER (first) column's text; the other cells
#'   are suppressed. A later `c_glue()` targeting a non-leader merged cell is
#'   silently skipped — glue the leader column instead, or merge first via
#'   argument order (merge -> clear -> glue is the canonical rebuild idiom).
#'
#' @seealso [compute_cols()] for conditional row actions, [c_style()], [c_addrow()] for other action types
#'
#' @examples
#'   spec <- create_table(mtcars) |>
#'     add_style("group_header", s_table_style(background_color = "#D9D9D9"))
#'
#'   # Merge two adjacent columns for four-cylinder rows
#'   spec <- compute_cols(spec, cyl == 4, c_merge(c(mpg, cyl), styleRef = "group_header"))
#'
#'   # Merge without style
#'   spec <- compute_cols(spec, cyl == 8, c_merge(c(wt, qsec)))
#'
#' @export
c_merge <- function(cols, styleRef = NULL) {
  # Validate context
  .assert_context("compute_cols", "c_merge")

  # Capture column expression for later tidyselect resolution
  cols_quo <- enquo(cols)

  # Validate styleRef if provided: single string or f_combine() result
  if (!is.null(styleRef)) {
    checkmate::assert_character(
      styleRef,
      min.len = 1L,
      any.missing = FALSE,
      .var.name = "styleRef"
    )
  }

  # Return as a marker object for parsing in .finalize_compute_cols()
  structure(
    list(
      type = "merge",
      cols = cols_quo,
      styleRef = styleRef
    ),
    class = "tfl_action_merge"
  )
}

#' Insert Additional Row in Conditional Rows
#'
#' Declares an additional row to be inserted above or below rows matching
#' the parent `compute_cols()` condition. Content can optionally be copied from a
#' specified column; if omitted, creates an empty separator row.
#'
#' @param pos Character. Position for insertion: "above" or "below".
#' @param value_from Unquoted column name or quoted column name string. Optional
#'   source column for the inserted row's content (both `value_from = PARAM` and
#'   `value_from = "PARAM"` are accepted). The value is copied into the FIRST
#'   cell of the synthetic row, which spans the full table width. If NULL or
#'   missing, creates an empty separator row (a common styled divider idiom).
#' @param styleRef Character vector or result of `f_combine()`. Optional style
#'   to apply to the inserted row. If NULL, no special styling. The inserted
#'   row's cell is owned by this `styleRef`: later `c_style()` blocks do NOT
#'   repaint it (later `c_clear()`/`c_glue()` on the source column DO reach it —
#'   the synthetic row shares the source cell link).
#'
#' @return Quosure structure (internal use within `compute_cols()`)
#'
#' @seealso [compute_cols()] for conditional row actions, [c_style()], [c_merge()] for other action types
#'
#' @details
#' Must be called inside `compute_cols()`.
#'
#' **Behavior:**
#' - Multiple `c_addrow()` calls accumulate; rows are inserted adjacent to the
#'   source row, pushing earlier inserts away. Consequence: two inserts in ONE
#'   call put the FIRST argument farthest from the source, while two inserts in
#'   SEPARATE piped calls put the LATER call closest to the source — stack
#'   order is fully controllable via call/argument order.
#' - Coexists with other actions on the same row.
#' - If `value_from` is provided, must resolve to exactly one spec column
#'   (multi-column selection is an error).
#' - If `value_from` is NULL or missing, creates an empty separator row.
#' - With `pos = "above"` + `value_from`, the section-header idiom
#'   (hide a label column, `firstOf()` + addrow) builds group headers.
#'
#' **Stackable Actions:**
#' Actions within a single `compute_cols()` call execute **sequentially in the
#' order specified**: `c_addrow()` sees values modified by earlier `c_glue()`
#' actions (the synthetic row copies the ALREADY-GLUED text), allowing
#' compound cell values (e.g., "PARAM: VISIT") in inserted rows.
#'
#' @examples
#'   lab <- data.frame(
#'     PARAM = c("ALT", "ALT", "AST"), VISIT = c("W1", "W2", "W1"),
#'     VAL = c(25, 28, 30), stringsAsFactors = FALSE)
#'   spec <- create_table(lab) |>
#'     add_style("grp", s_font(bold = TRUE))
#'
#'   # Empty separator row above each ALT run
#'   spec <- compute_cols(spec, firstOf(PARAM), c_addrow(pos = "above"))
#'
#'   # Section-header row carrying the group value, styled
#'   spec <- compute_cols(spec, firstOf(PARAM),
#'     c_addrow(pos = "above", value_from = PARAM, styleRef = "grp"))
#'
#'   # Stackable: addrow sees the glued value
#'   spec <- compute_cols(spec, PARAM == "AST",
#'     c_glue(PARAM, "after", glue_col = VISIT, separator = ": "),
#'     c_addrow("above", value_from = PARAM))  # inserted row shows "AST: W1"
#'
#' @export
c_addrow <- function(pos, value_from = NULL, styleRef = NULL) {
  # Validate context
  .assert_context("compute_cols", "c_addrow")

  # Validate pos
  pos <- match.arg(pos, c("above", "below"))

  # Capture value_from expression
  value_from_quo <- enquo(value_from)

  # Validate styleRef if provided: single string or f_combine() result
  if (!is.null(styleRef)) {
    checkmate::assert_character(
      styleRef,
      min.len = 1L,
      any.missing = FALSE,
      .var.name = "styleRef"
    )
  }

  # Return as a marker object for parsing in .finalize_compute_cols()
  structure(
    list(
      type = "addrow",
      pos = pos,
      value_from = value_from_quo,
      styleRef = styleRef
    ),
    class = "tfl_action_addrow"
  )
}


#' Insert a page break at the matching row
#'
#' Used inside [compute_cols()] to signal the renderer to start a new page
#' at every row matching the condition. Takes no arguments.
#'
#' @details
#' Must be called inside `compute_cols()`. Each match emits a page-level
#' break: with the default `isContinues = FALSE` the table is split into one
#' Word table per page segment and the column header row is re-emitted per
#' segment; the other actions of the same call still apply to their rows.
#' Combines with any sibling action (e.g. `c_style()` to emphasize the new
#' page start).
#'
#' @return Action marker (internal use within `compute_cols()`)
#' @seealso [compute_cols()], [c_style()], [c_addrow()], [c_merge()]
#' @export
#' @examples
#' \dontrun{
#' data <- data.frame(
#'   group = c("A", "A", "B", "B", "C"),
#'   value = c(1, 2, 3, 4, 5)
#' )
#'
#' # Force a new page at the start of each group
#' spec <- create_table(data) |>
#'   compute_cols(firstOf(group), c_pageBreak()) |>
#'   create_report() |>
#'   write_doc(name = "pagebreak_demo", outDir = tempdir(),
#'             metaPath = tempdir(), verbose = FALSE)
#' }
c_pageBreak <- function() {
  .assert_context("compute_cols", "c_pageBreak")

  structure(
    list(
      type = "page_break"
    ),
    class = "tfl_action_pagebreak"
  )
}


#' Concatenate a Value to Cell Text in Conditional Rows
#'
#' Declares a glue action to concatenate a value — from a data column or a
#' literal string — to the display text of specified cells in rows matching
#' the parent `compute_cols()` condition.
#'
#' @param cols Tidyselect expression for the target columns
#'   (e.g., `col1`, `c(col1, col2)`, `starts_with("x")`).
#'   Must resolve to visible (non-hidden) report columns only.
#' @param position Character. Concatenation side: `"before"` prepends the glue
#'   value to the existing cell text; `"after"` appends it.
#' @param glue_col Optional. Unquoted column name whose formatted value is
#'   concatenated onto the target cells. The column may be hidden (not in the
#'   visible column list). Mutually exclusive with `text`.
#' @param text Optional. A single literal character string to concatenate onto
#'   the target cells. Mutually exclusive with `glue_col`.
#' @param separator Character string inserted between the existing cell text and
#'   the glued value when both sides are non-empty. Defaults to `""` (direct
#'   concatenation). When either side is empty, no separator is inserted.
#'
#' @return Quosure-style marker (internal use within `compute_cols()`)
#'
#' @details
#' Must be called inside `compute_cols()`.
#'
#' **Constraints:**
#' \itemize{
#'   \item Exactly one of `glue_col` or `text` must be provided. NOTE: inside
#'     `compute_cols()` actions are parsed from the unevaluated call, so this
#'     is enforced only by the interactive `c_glue()` builder; when BOTH are
#'     supplied in a `compute_cols()` call the parser silently prefers
#'     `glue_col` and ignores `text` (tracked for a package fix — see
#'     Finding-need-further-attention.md U1).
#'   \item `cols` resolves only visible report columns via tidyselect.
#'   \item `glue_col` can reference any data column, including hidden ones.
#'   \item `glue_col` must not overlap with `cols`.
#'   \item `text` must be a single string (length > 1 is a hard error).
#' }
#'
#' **Behavior:**
#' \itemize{
#'   \item When the glue value (from `glue_col` or `text`) is empty or `NA`,
#'     the action is silently skipped for that row/cell.
#'   \item When a target cell was suppressed by deduplication (`dedupe = TRUE`
#'     on that column), the glued text lands on the RAW cell but is not
#'     painted (render-level suppression wins) — effectively invisible; glue a
#'     non-suppressed column or the first row of each run instead.
#'   \item Glue onto a target cell whose own value is `NA` renders just the
#'     glued part (no \"NA\" text appears).
#'   \item When a target cell is suppressed by a concurrent `c_merge()` action
#'     (i.e., it is a non-leader merged cell), the glue is silently skipped.
#'   \item The merge leader cell is glued normally when `c_glue()` targets a
#'     column involved in `c_merge()` as the first column.
#'   \item Multiple `c_glue()` calls on the same column accumulate in call order.
#' }
#'
#' **Interaction with other actions:**
#' \itemize{
#'   \item `c_style()`: Fully compatible — styling and text modification are independent.
#'   \item `c_merge()`: Compatible. Non-leader (suppressed) merge cells are
#'     skipped; the merge-leader cell is glued normally. When a rebuild of a
#'     merged total row is intended, keep the canonical argument order
#'     merge -> clear -> glue inside ONE `compute_cols()` call.
#'   \item `c_addrow()`: **Stackable** — when used together in the same `compute_cols()`,
#'     `c_addrow()` sees glued values. This allows building compound cell values
#'     (e.g., "PARAM: VISIT") before using them in inserted rows.
#'   \item `c_pageBreak()`: Fully compatible.
#' }
#'
#' **Stackable Actions:**
#' Actions within a single `compute_cols()` call execute **sequentially in the order
#' specified**. This means `c_glue()` modifications are visible to subsequent `c_addrow()`
#' actions in the same call, enabling complex multi-step transformations.
#'
#' @seealso [compute_cols()], [c_style()], [c_merge()], [c_addrow()]
#'
#' @examples
#'   lab <- data.frame(
#'     PARAM = c("ALT", "ALT", "AST"), VISIT = c("W1", "W2", "W1"),
#'     UNIT  = c("U/L", "U/L", "U/L"), stringsAsFactors = FALSE)
#'   spec <- create_table(lab) |>
#'     add_style("bold", s_font(bold = TRUE)) |>
#'     define_cols(UNIT, isVisible = FALSE)
#'
#'   # Append a unit from a hidden column
#'   spec <- compute_cols(spec, TRUE,
#'     c_glue(PARAM, "after", glue_col = UNIT, separator = " "))
#'
#'   # Prepend a literal marker
#'   spec <- compute_cols(spec, PARAM == "AST",
#'     c_glue(PARAM, "before", text = "*"))
#'
#'   # Combine with c_style() - independent operations
#'   spec <- compute_cols(spec, PARAM == "ALT",
#'     c_glue(VISIT, "before", text = "Visit: "),
#'     c_style(VISIT, styleRef = "bold"))
#'
#'   # Stackable with c_addrow() - the added row sees glued values
#'   spec <- compute_cols(spec, PARAM == "ALT",
#'     c_glue(PARAM, "after", glue_col = VISIT, separator = ": "),
#'     c_addrow("above", value_from = PARAM))  # inserted row shows "ALT: W1"
#'
#' @export
c_glue <- function(cols, position, glue_col = NULL, text = NULL, separator = NULL) {
  .assert_context("compute_cols", "c_glue")

  cols_quo     <- enquo(cols)
  glue_col_quo <- enquo(glue_col)
  glue_col_expr <- quo_get_expr(glue_col_quo)

  has_glue_col <- !is.null(glue_col_expr)
  has_text     <- !is.null(text)

  if (has_glue_col && has_text) {
    cli_abort(c(
      "{.fn c_glue} requires either {.arg glue_col} or {.arg text}, not both",
      x = "Both {.arg glue_col} and {.arg text} were provided",
      i = "Use {.arg glue_col} to reference a data column, or {.arg text} for a literal string"
    ))
  }
  if (!has_glue_col && !has_text) {
    cli_abort(c(
      "{.fn c_glue} requires either {.arg glue_col} or {.arg text}",
      x = "Neither was provided",
      i = "Example: {.code c_glue(col1, \"after\", glue_col = unit_col)}"
    ))
  }

  position <- match.arg(position, c("before", "after"))

  if (has_text) {
    checkmate::assert_character(text, len = 1L, .var.name = "text")
  }
  if (!is.null(separator)) {
    checkmate::assert_character(separator, len = 1L, any.missing = FALSE, .var.name = "separator")
  }

  structure(
    list(
      type      = "glue",
      cols      = cols_quo,
      position  = position,
      glue_col  = if (has_glue_col) glue_col_quo else NULL,
      text      = if (has_text) text else NULL,
      separator = if (is.null(separator)) "" else separator
    ),
    class = "tfl_action_glue"
  )
}

#' Clear Cell Content in Conditional Rows
#'
#' Declares a clear action that blanks the display text of specified cells in
#' rows matching the parent `compute_cols()` condition. The cells are rendered
#' empty without affecting their column structure, width, or styling.
#'
#' @param cols Tidyselect expression for the target columns to blank
#'   (e.g., `col1`, `c(col1, col2)`, `starts_with("x")`).
#'   Must resolve to visible (non-hidden) report columns only.
#'
#' @return Quosure-style marker (internal use within `compute_cols()`)
#'
#' @details
#' Must be called inside `compute_cols()`.
#'
#' **Behavior:**
#' \itemize{
#'   \item Sets the RENDERED cell text to `""` for matching rows. The clear is
#'     display-only: conditions in `compute_cols()` keep seeing the RAW data
#'     values, and the column still participates in width/format resolution.
#'   \item Actions execute in ARRIVAL order (argument order within the call,
#'     then pipe order across calls) — clear is not automatically "first".
#'     Placing `c_clear()` before `c_glue()` on the same column turns the pair
#'     into a full REPLACEMENT (glue lands on the emptied cell); placing
#'     `c_glue()` before `c_clear()` wipes the cell afterwards.
#'   \item Compatible with `c_style()`: styling is independent of text content.
#'   \item When `c_merge()` spans a cleared leader cell, the merged span
#'     renders as a blank merged cell.
#' }
#'
#' @seealso [compute_cols()], [c_style()], [c_merge()], [c_glue()]
#'
#' @examples
#'   spec <- create_table(mtcars)
#'
#'   # Blank the disp column for four-cylinder rows
#'   spec <- compute_cols(spec, cyl == 4, c_clear(disp))
#'
#'   # Clear then re-fill from another column (full replacement:
#'   # canonical merge -> clear -> glue ordering inside ONE call)
#'   spec2 <- create_table(mtcars) |>
#'     compute_cols(hp == 62,
#'       c_clear(carb),
#'       c_glue(carb, "after", text = "-"))
#'
#' @export
c_clear <- function(cols) {
  .assert_context("compute_cols", "c_clear")

  cols_quo <- enquo(cols)

  structure(
    list(
      type = "clear",
      cols = cols_quo
    ),
    class = "tfl_action_clear"
  )
}

# ============================================================
# PART 3: INTERNAL FINALIZATION HELPERS
# ============================================================

#' Finalize Compute Cols - Evaluate Conditions and Build Row Actions
#'
#' Internal function called during `create_report()` to evaluate all
#' accumulated `compute_cols()` calls and generate JSON-serializable
#' row action descriptions.
#'
#' @param spec A TFL_spec object with compute_cols metadata
#'
#' @return Modified spec with `spec$.metadata$styleRows` populated
#'   as a character vector of JSON strings, one per data row.
#'
#' @keywords internal
#' @noRd
.finalize_compute_cols <- function(spec) {
  # Early exit if no compute_cols blocks
  if (is.null(spec$.metadata$compute_cols) ||
      length(spec$.metadata$compute_cols) == 0) {
    return(spec)
  }

  data <- spec$.metadata$data_env$`__data__`
  n <- nrow(data)
  report_cols <- spec$.metadata$report_cols

  # Initialize row actions list
  # Each element: list(style=list(), merge=list(), add_row=list(), glue=list(), page_break=list())
  row_actions <- vector("list", n)
  for (i in seq_len(n)) {
    row_actions[[i]] <- list(
      style      = list(),
      clear      = list(),
      merge      = list(),
      glue       = list(),
      add_row    = list(),
      page_break = list()
    )
  }

  # Process each compute_cols block
  for (block_idx in seq_along(spec$.metadata$compute_cols)) {
    block <- spec$.metadata$compute_cols[[block_idx]]
    # Evaluate condition in data environment
    # Pass the quosure directly; .env_eval will handle it correctly
    ##cond_vec <- eval_tidy(quo_get_expr(block$cond), env = spec$.metadata$data_env$`__mask__`)
    cond_vec <- .env_eval(!!quo_get_expr(block$cond), env = spec$.metadata$data_env)
    # Allow scalar TRUE/FALSE as shorthand for all/no rows
    if (is.logical(cond_vec) && length(cond_vec) == 1L && !is.na(cond_vec)) {
      cond_vec <- rep(cond_vec, n)
    }
    # Validate condition
    if (!is.logical(cond_vec) || length(cond_vec) != n) {
      cli_abort(c(
        "Condition in {.fn compute_cols} must return logical vector of length {n}",
        x = "Got {typeof(cond_vec)} of length {length(cond_vec)}",
        i = "Condition: {quo_get_expr(block$cond)}"
      ))
    }

    if (any(is.na(cond_vec))) {
      cli_abort(c(
        "Condition in {.fn compute_cols} cannot return NA values",
        x = "Found {sum(is.na(cond_vec))} NA value(s)",
        i = "Condition: {quo_get_expr(block$cond)}"
      ))
    }

    # Apply actions to matching rows
    matching_rows <- which(cond_vec)

    action_seq <- -1L  # Track action sequence for ordered execution (increments to 0 on first use)
    for (action_quo in block$actions) {
      action_seq <- action_seq + 1L
      
      # Extract the actual action object and its environment
      action_obj <- quo_get_expr(action_quo)
      action_env <- quo_get_env(action_quo)

      # Parse and apply action
      if (is.call(action_obj) && as.character(action_obj[[1]]) == "c_style") {
        # Parse style action
        parsed_action <- .parse_action_style(
          action_obj,
          action_env,
          spec,
          data,
          report_cols
        )
        parsed_action$seq <- action_seq

        # Apply to matching rows
        for (i in matching_rows) {
          row_actions[[i]]$style <- .append_style_action(
            row_actions[[i]]$style,
            parsed_action,
            block_idx
          )
        }
      } else if (is.call(action_obj) && as.character(action_obj[[1]]) == "c_clear") {
        # Parse clear action
        parsed_action <- .parse_action_clear(
          action_obj,
          action_env,
          spec,
          data,
          report_cols
        )
        parsed_action$seq <- action_seq

        # Apply to matching rows
        for (i in matching_rows) {
          row_actions[[i]]$clear <- .append_clear_action(
            row_actions[[i]]$clear,
            parsed_action
          )
        }
      } else if (is.call(action_obj) && as.character(action_obj[[1]]) == "c_merge") {
        # Parse merge action
        parsed_action <- .parse_action_merge(
          action_obj,
          action_env,
          spec,
          data,
          report_cols
        )
        parsed_action$seq <- action_seq

        # Apply to matching rows
        for (i in matching_rows) {
          row_actions[[i]]$merge <- .append_merge_action(
            row_actions[[i]]$merge,
            parsed_action
          )
        }
      } else if (is.call(action_obj) && as.character(action_obj[[1]]) == "c_addrow") {
        # Parse addrow action
        parsed_action <- .parse_action_addrow(
          action_obj,          action_env,          spec,
          data,
          report_cols
        )
        parsed_action$seq <- action_seq

        # Apply to matching rows
        for (i in matching_rows) {
          row_actions[[i]]$add_row <- .append_addrow_action(
            row_actions[[i]]$add_row,
            parsed_action
          )
        }
      } else if (is.call(action_obj) && as.character(action_obj[[1]]) == "c_glue") {
        # Parse glue action
        parsed_action <- .parse_action_glue(
          action_obj,
          action_env,
          spec,
          data,
          report_cols
        )
        parsed_action$seq <- action_seq

        # Apply to matching rows
        for (i in matching_rows) {
          row_actions[[i]]$glue <- .append_glue_action(
            row_actions[[i]]$glue,
            parsed_action
          )
        }
      } else if (is.call(action_obj) && as.character(action_obj[[1]]) == "c_pageBreak") {
        # Page break has no arguments
        parsed_action <- list(seq = action_seq)

        for (i in matching_rows) {
          row_actions[[i]]$page_break <- .append_pagebreak_action(
            row_actions[[i]]$page_break,
            parsed_action
          )
        }
      }
    }
  }

  # Sanitize row actions (resolve conflicts, combine styles)
  row_actions <- .sanitize_row_actions(row_actions, spec, report_cols)

  # Store row actions as R list structure (will be serialized at end of report prep)
  spec$styleRows <- .build_stylerows_list(row_actions)

  # Clear compute_cols after finalization (it's been processed)
  spec$.metadata$compute_cols <- NULL

  spec
}

#' Parse c_style() Action Call
#'
#' Extracts cols and styleRef from a c_style() function call and resolves
#' column names using tidyselect.
#'
#' @param action_call A function call object (result of quo_get_expr)
#' @param action_env Environment from the quosure (for evaluating arguments)
#' @param spec TFL_spec object
#' @param data Data frame
#' @param report_cols Character vector of report column names
#'
#' @return List with cols (character vector) and styleRef (character)
#'
#' @keywords internal
#' @noRd
.parse_action_style <- function(action_call, action_env, spec, data, report_cols) {
  # Extract arguments from the call object
  args <- rlang::call_args(action_call)
  cols_expr <- args[[1]]
  styleRef <- eval(args[[2]], envir = action_env)

  # Resolve column names using existing .get_data_column_names helper
  col_names <- .get_data_column_names(data, !!cols_expr)

  col_names <- intersect(col_names, report_cols)  # keep only columns that exist in spec definition
  assert_character(col_names, min.len = 1)

  # Validate all resolved columns exist in report_cols
  missing_cols <- setdiff(col_names, report_cols)
  if (length(missing_cols) > 0) {
    cli_abort(c(
      "Column(s) in {.fn c_style} action not found in spec columns",
      x = "Missing: {paste(missing_cols, collapse = ', ')}",
      i = "Available columns: {paste(report_cols, collapse = ', ')}"
    ))
  }

  list(cols = col_names, styleRef = styleRef)
}

#' Parse c_merge() Action Call
#'
#' Extracts cols and styleRef from a c_merge() function call and resolves
#' column names, validating adjacency.
#'
#' @param action_call A function call object
#' @param action_env Environment from the quosure (for evaluating arguments)
#' @param spec TFL_spec object
#' @param data Data frame
#' @param report_cols Character vector of report column names
#'
#' @return List with cols (character vector) and styleRef (character or NULL)
#'
#' @keywords internal
#' @noRd
.parse_action_merge <- function(action_call, action_env, spec, data, report_cols) {
  # Extract arguments from the call object
  args <- rlang::call_args(action_call)
  cols_expr <- args[[1]]
  styleRef <- if (length(args) > 1 && !is.null(args[[2]])) {
    eval(args[[2]], envir = action_env)
  } else {
    NULL
  }

  # Resolve column names using existing .get_data_column_names helper
  col_names <- .get_data_column_names(data, !!cols_expr)
  col_names <- intersect(col_names, report_cols)  # keep only columns that exist in spec definition
  
  # Validate merge requirements
  if (length(col_names) < 2) {
    cli_abort(c(
      "{.fn c_merge} requires at least 2 columns",
      x = "Got {length(col_names)} column(s): {paste(col_names, collapse = ', ')}",
      i = "Provide multiple adjacent columns to merge"
    ))
  }

  # Validate all columns exist in report_cols
  missing_cols <- setdiff(col_names, report_cols)
  if (length(missing_cols) > 0) {
    cli_abort(c(
      "Column(s) in {.fn c_merge} action not found in spec columns",
      x = "Missing: {paste(missing_cols, collapse = ', ')}",
      i = "Available columns: {paste(report_cols, collapse = ', ')}"
    ))
  }

  # Check adjacency in report_cols order
  col_indices <- match(col_names, report_cols)
  sorted_indices <- sort(col_indices)

  # Verify consecutive
  expected_indices <- seq(sorted_indices[1], sorted_indices[length(sorted_indices)])
  if (!identical(sorted_indices, expected_indices)) {
    cli_abort(c(
      "{.fn c_merge} columns must be adjacent/consecutive",
      x = "Columns {paste(col_names, collapse = ', ')} are not consecutive in report order",
      i = "Report column order: {paste(report_cols, collapse = ', ')}"
    ))
  }

  list(cols = col_names, styleRef = styleRef)
}

#' Parse c_addrow() Action Call
#'
#' Extracts pos, value_from, and styleRef from a c_addrow() function call.
#'
#' @param action_call A function call object
#' @param action_env Environment from the quosure (for evaluating arguments)
#' @param spec TFL_spec object
#' @param data Data frame
#' @param report_cols Character vector of report column names
#'
#' @return List with pos, value_from (character), and styleRef (character or NULL)
#'
#' @keywords internal
#' @noRd
.parse_action_addrow <- function(action_call, action_env, spec, data, report_cols) {
  # Extract arguments from the call object (named list)
  args <- rlang::call_args(action_call)

  # Match arguments to c_addrow(pos, value_from = NULL, styleRef = NULL)
  # Use match.call to properly resolve positional + named args
  matched <- match.call(
    definition = c_addrow,
    call = action_call,
    expand.dots = FALSE
  )
  matched_args <- as.list(matched)[-1L]  # drop function name

  pos <- eval(matched_args[["pos"]], envir = action_env)

  value_from_expr <- matched_args[["value_from"]]

  styleRef <- if (!is.null(matched_args[["styleRef"]])) {
    eval(matched_args[["styleRef"]], envir = action_env)
  } else {
    NULL
  }

  # Handle missing or NULL value_from (empty separator row)
  value_from <- NULL
  if (!is.null(value_from_expr)) {
    # Resolve value_from to a single column name using existing helper
    value_from <- .get_data_column_names(data, !!value_from_expr)

    if (length(value_from) != 1) {
      cli_abort(c(
        "{.fn c_addrow} value_from must resolve to a single column",
        x = "Got {length(value_from)} column(s): {paste(value_from, collapse = ', ')}",
        i = "Use single column expression: c_addrow(pos = ..., value_from = col_name)",
        i = "Or omit value_from to create an empty separator row"
      ))
    }

    # Validate value_from exists in report_cols
    if (!(value_from %in% report_cols)) {
      cli_abort(c(
        "{.fn c_addrow} value_from column not found in spec columns",
        x = "Column {.val {value_from}} not found",
        i = "Available columns: {paste(report_cols, collapse = ', ')}"
      ))
    }
  }

  list(pos = pos, value_from = value_from, styleRef = styleRef)
}

#' Parse c_glue() Action Call
#'
#' Extracts cols, position, glue_col/text, and separator from a c_glue()
#' function call and resolves column names.
#'
#' @param action_call A function call object (result of quo_get_expr)
#' @param action_env Environment from the quosure (for evaluating arguments)
#' @param spec TFL_spec object
#' @param data Data frame (full data, including hidden columns)
#' @param report_cols Character vector of visible report column names
#'
#' @return List with cols, position, glue_col (or NULL), text (or NULL), separator
#'
#' @keywords internal
#' @noRd
.parse_action_glue <- function(action_call, action_env, spec, data, report_cols) {
  matched <- match.call(
    definition = c_glue,
    call = action_call,
    expand.dots = FALSE
  )
  matched_args <- as.list(matched)[-1L]

  # --- cols: visible columns only ---
  cols_expr <- matched_args[["cols"]]
  col_names <- .get_data_column_names(data, !!cols_expr)
  col_names <- intersect(col_names, report_cols)

  if (length(col_names) == 0L) {
    cli_abort(c(
      "Column(s) in {.fn c_glue} not found in visible spec columns",
      x = "No matching visible columns after tidyselect resolution",
      i = "Available visible columns: {paste(report_cols, collapse = ', ')}"
    ))
  }

  # --- position ---
  position <- eval(matched_args[["position"]], envir = action_env)
  position <- match.arg(position, c("before", "after"))

  # --- separator ---
  sep_expr  <- matched_args[["separator"]]
  separator <- if (!is.null(sep_expr)) eval(sep_expr, envir = action_env) else ""

  # --- source: glue_col or text (exactly one) ---
  glue_col_expr <- matched_args[["glue_col"]]
  text_expr     <- matched_args[["text"]]

  if (!is.null(glue_col_expr) && !is.null(text_expr)) {
    cli::cli_warn(c(
      "{.fn c_glue} received both {.arg glue_col} and {.arg text}; {.arg glue_col} wins.",
      i = "Remove one of them to silence this warning."
    ))
  }

  glue_col <- NULL
  text_val  <- NULL

  if (!is.null(glue_col_expr)) {
    # Resolve against the full data frame (visible + hidden columns)
    glue_col_names <- .get_data_column_names(data, !!glue_col_expr)

    if (length(glue_col_names) != 1L) {
      cli_abort(c(
        "{.fn c_glue} {.arg glue_col} must resolve to exactly one column",
        x = "Got {length(glue_col_names)} column(s): {paste(glue_col_names, collapse = ', ')}",
        i = "Provide a single column name for {.arg glue_col}"
      ))
    }

    glue_col <- glue_col_names[[1L]]

    if (glue_col %in% col_names) {
      cli_abort(c(
        "{.fn c_glue} {.arg glue_col} must not overlap with {.arg cols}",
        x = "{.val {glue_col}} appears in both {.arg glue_col} and {.arg cols}",
        i = "{.arg glue_col} is the value source; {.arg cols} are the target cells"
      ))
    }

  } else if (!is.null(text_expr)) {
    text_val <- eval(text_expr, envir = action_env)
    checkmate::assert_character(text_val, len = 1L, .var.name = "text")
  } else {
    cli_abort(c(
      "{.fn c_glue} requires either {.arg glue_col} or {.arg text}",
      x = "Neither was found in the call",
      i = "Provide one of: {.code glue_col = col_name} or {.code text = \"literal\"}"
    ))
  }

  list(
    cols      = col_names,
    position  = position,
    glue_col  = glue_col,
    text      = text_val,
    separator = separator
  )
}


#' Parse c_clear() Action Call
#'
#' Extracts and resolves cols from a c_clear() function call.
#'
#' @param action_call A function call object (result of quo_get_expr)
#' @param action_env Environment from the quosure (for evaluating arguments)
#' @param spec TFL_spec object
#' @param data Data frame
#' @param report_cols Character vector of visible report column names
#'
#' @return List with cols (character vector of visible column names)
#'
#' @keywords internal
#' @noRd
.parse_action_clear <- function(action_call, action_env, spec, data, report_cols) {
  args      <- rlang::call_args(action_call)
  cols_expr <- args[[1]]

  col_names <- .get_data_column_names(data, !!cols_expr)
  col_names <- intersect(col_names, report_cols)

  if (length(col_names) == 0L) {
    cli_abort(c(
      "Column(s) in {.fn c_clear} not found in visible spec columns",
      x = "No matching visible columns after tidyselect resolution",
      i = "Available visible columns: {paste(report_cols, collapse = ', ')}"
    ))
  }

  list(cols = col_names)
}


#' Append Clear Action to Row Actions List
#'
#' @param clear_list List of existing clear actions for the row
#' @param parsed_action List from `.parse_action_clear()`
#'
#' @return Updated clear_list with new action appended
#' @keywords internal
#' @noRd
.append_clear_action <- function(clear_list, parsed_action) {
  clear_list[[length(clear_list) + 1L]] <- list(
    cols = parsed_action$cols,
    seq = parsed_action$seq
  )
  clear_list
}


#' Append Style Action to Row Actions List
#'
#' Adds a style action to the row's style list. Handles duplicate column styling
#' with last-win strategy for intra-block duplicates (same compute_cols call),
#' while preserving cross-block duplicates for later combination.
#'
#' @param style_list List of existing style actions for the row
#' @param parsed_action List from `.parse_action_style()`
#' @param block_idx Integer index of the current compute_cols block
#'
#' @return Updated style_list with new action appended
#'
#' @keywords internal
#' @noRd
.append_style_action <- function(style_list, parsed_action, block_idx) {
  # Check for duplicate columns WITHIN the same compute_cols block only.
  # Cross-block duplicates are expected and will be combined later by
  # .combine_column_styles() via f_combine().
  same_block_cols <- unlist(lapply(
    Filter(function(x) identical(x$block_idx, block_idx), style_list),
    `[[`, "cols"
  ))
  duplicate_cols <- intersect(same_block_cols, parsed_action$cols)

  if (length(duplicate_cols) > 0) {
    cli_warn(c(
      "Column(s) styled multiple times in same {.fn compute_cols} block",
      i = "Duplicate column(s): {paste(duplicate_cols, collapse = ', ')}",
      i = "Using last style specified (last-wins strategy)"
    ))

    # Remove ONLY same-block actions whose columns overlap.
    # Surgically remove just the overlapping columns, keeping non-overlapping
    # columns from the same action intact.
    style_list <- Filter(Negate(is.null), lapply(style_list, function(x) {
      if (!identical(x$block_idx, block_idx)) return(x)
      remaining <- setdiff(x$cols, duplicate_cols)
      if (length(remaining) == 0L) return(NULL)
      x$cols <- remaining
      x
    }))
  }

  # Append new action with block index for tracking
  style_list[[length(style_list) + 1L]] <- list(
    cols = parsed_action$cols,
    styleRef = parsed_action$styleRef,
    block_idx = block_idx,
    seq = parsed_action$seq
  )

  style_list
}

#' Append Merge Action to Row Actions List
#'
#' Adds a merge action to the row's merge list.
#'
#' @param merge_list List of existing merge actions for the row
#' @param parsed_action List from `.parse_action_merge()`
#'
#' @return Updated merge_list with new action appended
#'
#' @keywords internal
#' @noRd
.append_merge_action <- function(merge_list, parsed_action) {
  merge_list[[length(merge_list) + 1L]] <- list(
    cols = parsed_action$cols,
    styleRef = parsed_action$styleRef,
    seq = parsed_action$seq
  )

  merge_list
}

#' Append Add-Row Action to Row Actions List
#'
#' Adds an add_row action to the row's add_row list.
#'
#' @param addrow_list List of existing add_row actions for the row
#' @param parsed_action List from `.parse_action_addrow()`
#'
#' @return Updated addrow_list with new action appended
#'
#' @keywords internal
#' @noRd
.append_addrow_action <- function(addrow_list, parsed_action) {
  addrow_list[[length(addrow_list) + 1L]] <- list(
    pos = parsed_action$pos,
    value_from = parsed_action$value_from,
    styleRef = parsed_action$styleRef,
    seq = parsed_action$seq
  )

  addrow_list
}


#' Append Page Break Action to Row Actions List
#'
#' Adds a page_break action to the row's page_break list.
#'
#' @param pb_list List of existing page_break actions for the row
#' @param parsed_action Parsed action (unused, placeholder)
#'
#' @return Updated pb_list with new action appended
#' @keywords internal
#' @noRd
.append_pagebreak_action <- function(pb_list, parsed_action) {
  pb_list[[length(pb_list) + 1L]] <- list(seq = parsed_action$seq)
  pb_list
}


#' Append Glue Action to Row Actions List
#'
#' Adds a glue action to the row's glue list. Multiple glue actions on the
#' same column accumulate in call order and are applied sequentially.
#'
#' @param glue_list List of existing glue actions for the row
#' @param parsed_action List from `.parse_action_glue()`
#'
#' @return Updated glue_list with new action appended
#' @keywords internal
#' @noRd
.append_glue_action <- function(glue_list, parsed_action) {
  glue_list[[length(glue_list) + 1L]] <- list(
    cols      = parsed_action$cols,
    position  = parsed_action$position,
    glue_col  = parsed_action$glue_col,
    text      = parsed_action$text,
    separator = parsed_action$separator,
    seq       = parsed_action$seq
  )
  glue_list
}


#' Sanitize Row Actions - Resolve Conflicts and Combine Styles
#'
#' Post-processes row actions to:
#' 1. Detect and handle overlapping merge ranges
#' 2. Combine multiple styles on same column from different compute_cols() blocks
#' 3. Validate no structural conflicts
#'
#' @param row_actions List of action lists, one per row
#' @param spec TFL_spec object
#' @param report_cols Character vector of report column names
#'
#' @return Updated row_actions with combined styles and validated merges
#'
#' @keywords internal
#' @noRd
.sanitize_row_actions <- function(row_actions, spec, report_cols) {
  # Process each row
  for (i in seq_along(row_actions)) {
    row_act <- row_actions[[i]]

    # 1. Check for overlapping merges
    if (length(row_act$merge) > 1) {
      row_actions[[i]] <- .check_merge_overlap(row_act, i, report_cols)
    }

    # 2. Combine multiple styles on same column
    if (length(row_actions[[i]]$style) > 1) {
      row_actions[[i]] <- .combine_column_styles(row_actions[[i]], i)
    }
  }

  row_actions
}

#' Check for Overlapping Merge Ranges
#'
#' Validates that merge ranges don't intersect. Issues warning if resolvable,
#' error if ambiguous.
#'
#' @param row_act Row action list with merge array
#' @param row_idx Row index for error messages
#' @param report_cols Report column names for reference
#'
#' @return Updated row_act (may remove conflicting merges)
#'
#' @keywords internal
#' @noRd
.check_merge_overlap <- function(row_act, row_idx, report_cols) {
  merges <- row_act$merge
  n_merges <- length(merges)

  # Check all pairs for overlap
  for (i in seq_len(n_merges - 1)) {
    for (j in seq(i + 1, n_merges)) {
      merge_i_cols <- merges[[i]]$cols
      merge_j_cols <- merges[[j]]$cols

      # Check for intersection
      overlap <- intersect(merge_i_cols, merge_j_cols)

      if (length(overlap) > 0) {
        cli_warn(c(
          "Overlapping merge ranges in row {row_idx}",
          i = "Merge 1: {paste(merge_i_cols, collapse = ', ')}",
          i = "Merge 2: {paste(merge_j_cols, collapse = ', ')}",
          i = "Overlapping: {paste(overlap, collapse = ', ')}",
          i = "Removing second merge to resolve conflict"
        ))

        # Remove second merge (last-wins principle)
        row_act$merge[[j]] <- NULL
      }
    }
  }

  # Compact the list (remove NULLs)
  row_act$merge <- Filter(Negate(is.null), row_act$merge)

  row_act
}

#' Combine Multiple Styles on Same Column
#'
#' When same column receives multiple styles in one row (from different
#' compute_cols blocks), creates a combined style reference. The actual
#' style merging happens in create_report's style consolidation phase.
#'
#' @param row_act Row action list with style array
#' @param row_idx Row index for reference in messages
#'
#' @return Updated row_act with combined style references
#'
#' @keywords internal
#' @noRd
.combine_column_styles <- function(row_act, row_idx) {
  styles <- row_act$style

  # Group styles by column
  col_styles <- list()

  for (style_action in styles) {
    for (col in style_action$cols) {
      if (is.null(col_styles[[col]])) {
        col_styles[[col]] <- list()
      }

      col_styles[[col]][[length(col_styles[[col]]) + 1L]] <- style_action$styleRef
    }
  }

  # Identify columns with multiple styles
  multi_style_cols <- names(col_styles)[sapply(col_styles, length) > 1]

  if (length(multi_style_cols) > 0) {
    # For columns with multiple styles, flatten into a single ordered vector.
    # Cannot use f_combine() here because style_refs may already contain
    # multi-element vectors from prior f_combine() calls.
    for (col in multi_style_cols) {
      style_refs <- col_styles[[col]]
      col_styles[[col]] <- structure(
        unlist(style_refs, use.names = FALSE),
        class = c("tfl_style_combine", "character")
      )
    }
  }

  # Rebuild style actions with combined style references
  new_styles <- list()

  # First, add all non-duplicate column styles
  for (style_action in styles) {
    non_dup_cols <- setdiff(style_action$cols, multi_style_cols)

    if (length(non_dup_cols) > 0) {
      new_styles[[length(new_styles) + 1L]] <- list(
        cols = non_dup_cols,
        styleRef = style_action$styleRef
      )
    }
  }

  # Then add combined styles for columns with multiple references
  for (col in multi_style_cols) {
    new_styles[[length(new_styles) + 1L]] <- list(
      cols = col,
      styleRef = col_styles[[col]]
    )
  }

  row_act$style <- new_styles

  row_act
}

#' Serialize Row Actions to JSON Strings
#'
#' Converts row action lists to JSON strings suitable for the schema.
#' Rows with no actions produce empty strings.
#'
#' @param row_actions List of action lists, one per row
#'
#' @return Character vector of JSON strings, length matching input
#'
#' Build styleRows List Structure
#'
#' Converts row_actions to a cleaner list structure for styleRows.
#' Keeps as R objects - JSON serialization happens later in serialize_spec().
#'
#' @param row_actions List of row action lists
#'
#' @return List of styleRows, each with style/merge/add_row (or NULL if no actions)
#'
#' @keywords internal
#' @noRd
.build_stylerows_list <- function(row_actions) {
  lapply(row_actions, function(row_act) {
    # Check if row has any actions
    has_style      <- length(row_act$style) > 0
    has_clear      <- length(row_act$clear) > 0
    has_merge      <- length(row_act$merge) > 0
    has_glue       <- length(row_act$glue) > 0
    has_addrow     <- length(row_act$add_row) > 0
    has_page_break <- length(row_act$page_break) > 0

    if (!has_style && !has_clear && !has_merge && !has_glue && !has_addrow && !has_page_break) {
      return(NULL)  # No actions for this row
    }

    # Build action object
    action_obj <- list()

    if (has_style) {
      # Strip internal block_idx before serialization
      action_obj$style <- lapply(row_act$style, function(s) {
        s$block_idx <- NULL
        s
      })
    }

    if (has_clear) {
      action_obj$clear <- row_act$clear
    }

    if (has_merge) {
      action_obj$merge <- row_act$merge
    }

    if (has_glue) {
      action_obj$glue <- row_act$glue
    }

    if (has_addrow) {
      action_obj$add_row <- row_act$add_row
    }

    if (has_page_break) {
      action_obj$page_break <- row_act$page_break
    }

    action_obj
  })
}
