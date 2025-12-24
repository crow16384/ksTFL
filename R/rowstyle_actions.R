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
#' and evaluated later during `create_report()`.
#'
#' @param spec A TFL_spec object (must have docType = "Table")
#' @param cond An unquoted logical expression to be evaluated in the data environment.
#'   Can reference data columns and helper functions (e.g., `firstOf()`, `col1 > 10`).
#'   Must return a logical vector of length equal to `nrow(data)`.
#' @param ... Action function calls: `c_style()`, `c_merge()`, `c_addrow()`.
#'   Multiple actions allowed, including duplicates. Actions are captured unevaluated.
#'
#' @return Modified `spec` object with appended action metadata.
#'   Invisibly returns the spec for piping.
#'
#' @details
#' **Behavior:**
#' - Does NOT evaluate condition or actions (deferred until `create_report()`)
#' - Appends to `spec$.metadata$compute_cols` list
#' - Only allowed for docType = "Table"
#' - Multiple `compute_cols()` calls accumulate on the same spec
#'
#' **Action Functions** (used inside `compute_cols()`):
#' - `c_style(cols, styleRef)`: Apply style to columns
#' - `c_merge(cols, styleRef = NULL)`: Merge adjacent columns
#' - `c_addrow(pos, value_from, styleRef = NULL)`: Insert row above/below
#'
#' @examples
#' \dontrun{
#'   spec <- create_table(mtcars)
#'   spec <- add_style(spec, id = "bold", s_font(bold = TRUE))
#'   spec <- add_style(spec, id = "red", s_font(color = "red"))
#'
#'   # Make first group rows bold
#'   spec <- compute_cols(spec, firstOf(cyl), c_style(mpg, styleRef = "bold"))
#'
#'   # Make rows with high hp red
#'   spec <- compute_cols(spec, hp > 200, c_style(hp, styleRef = "red"))
#' }
#'
#' @export
#' @noRd
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
#' Declares a style to be applied to specified columns in rows matching
#' the parent `compute_cols()` condition.
#'
#' @param cols Tidyselect expression for column selection
#'   (e.g., `c(col1, col2)`, `everything()`, `starts_with("x")`)
#' @param styleRef Character. Name of the style to apply.
#'   Can be a single style name or result of `f_combine()` for multiple styles.
#'
#' @return Quosure structure (internal use within `compute_cols()`)
#'
#' @details
#' Must be called inside `compute_cols()`. Columns are resolved using
#' tidyselect syntax against the table data.
#'
#' **Behavior:**
#' - Same column styled multiple times in one row: last style wins, warning issued
#' - Same column styled from different `compute_cols()` calls on same row:
#'   automatic style combination (deep merge, similar to `f_combine()`)
#'
#' @examples
#' \dontrun{
#'   compute_cols(spec, hp > 150, c_style(c(hp, wt), styleRef = "bold"))
#' }
#'
#' @export
c_style <- function(cols, styleRef) {
  # Validate context
  .assert_context("compute_cols", "c_style")

  # Capture column expression for later tidyselect resolution
  cols_quo <- enquo(cols)

  # Validate styleRef
  checkmate::assert_character(
    styleRef,
    len = 1L,
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
#' `compute_cols()` condition.
#'
#' @param cols Tidyselect expression for column selection. Must resolve
#'   to at least 2 columns that are consecutive in the report column order.
#' @param styleRef Character. Optional style to apply to the merged cell.
#'   If NULL, no special styling. Can be a single style or `f_combine()` result.
#'
#' @return Quosure structure (internal use within `compute_cols()`)
#'
#' @details
#' Must be called inside `compute_cols()`. Columns must be adjacent in the
#' final report column order.
#'
#' **Validation:**
#' - Immediate: columns exist and are consecutive (error if not)
#' - Deferred: overlapping merge ranges from multiple `compute_cols()` calls
#'   (warning if resolvable, error if ambiguous)
#'
#' @examples
#' \dontrun{
#'   compute_cols(spec, group == "A", c_merge(c(col1, col2), styleRef = "group_header"))
#' }
#'
#' @export
c_merge <- function(cols, styleRef = NULL) {
  # Validate context
  .assert_context("compute_cols", "c_merge")

  # Capture column expression for later tidyselect resolution
  cols_quo <- enquo(cols)

  # Validate styleRef if provided
  if (!is.null(styleRef)) {
    checkmate::assert_character(
      styleRef,
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
#' the parent `compute_cols()` condition, with content copied from a
#' specified column.
#'
#' @param pos Character. Position for insertion: "above" or "below".
#' @param value_from Character or unquoted column name. Source column
#'   for the inserted row's content.
#' @param styleRef Character. Optional style to apply to the inserted row.
#'   If NULL, no special styling. Can be a single style or `f_combine()` result.
#'
#' @return Quosure structure (internal use within `compute_cols()`)
#'
#' @details
#' Must be called inside `compute_cols()`.
#'
#' **Behavior:**
#' - Multiple `c_addrow()` calls in one `compute_cols()` accumulate
#' - Order of appearance is preserved
#' - Coexists with other actions on same row
#' - `value_from` must exist in spec columns (data_env reference)
#'
#' @examples
#' \dontrun{
#'   compute_cols(spec, lastOf(treatment), c_addrow(pos = "below", value_from = "treatment"))
#' }
#'
#' @export
c_addrow <- function(pos, value_from, styleRef = NULL) {
  # Validate context
  .assert_context("compute_cols", "c_addrow")

  # Validate pos
  pos <- match.arg(pos, c("above", "below"))

  # Capture value_from expression
  value_from_quo <- enquo(value_from)

  # Validate styleRef if provided
  if (!is.null(styleRef)) {
    checkmate::assert_character(
      styleRef,
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
  # Each element: list(style = list(), merge = list(), addrow = list())
  row_actions <- vector("list", n)
  for (i in seq_len(n)) {
    row_actions[[i]] <- list(
      style = list(),
      merge = list(),
      add_row = list()
    )
  }

  # Process each compute_cols block
  for (block in spec$.metadata$compute_cols) {
    # Evaluate condition in data environment
    # Pass the quosure directly; .env_eval will handle it correctly
    ##cond_vec <- eval_tidy(quo_get_expr(block$cond), env = spec$.metadata$data_env$`__mask__`)
    cond_vec <- .env_eval(!!quo_get_expr(block$cond), spec$.metadata$data_env)
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

    for (action_quo in block$actions) {
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

        # Apply to matching rows
        for (i in matching_rows) {
          row_actions[[i]]$style <- .append_style_action(
            row_actions[[i]]$style,
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

        # Apply to matching rows
        for (i in matching_rows) {
          row_actions[[i]]$add_row <- .append_addrow_action(
            row_actions[[i]]$add_row,
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
  # Extract arguments from the call object
  args <- rlang::call_args(action_call)
  pos <- eval(args[[1]], envir = action_env)
  value_from_expr <- args[[2]]
  styleRef <- if (length(args) > 2 && !is.null(args[[3]])) {
    eval(args[[3]], envir = action_env)
  } else {
    NULL
  }

  # Resolve value_from to a single column name using existing helper
  value_from <- .get_data_column_names(data, !!value_from_expr)

  if (length(value_from) != 1) {
    cli_abort(c(
      "{.fn c_addrow} value_from must resolve to a single column",
      x = "Got {length(value_from)} column(s): {paste(value_from, collapse = ', ')}",
      i = "Use single column expression: c_addrow(pos = ..., value_from = col_name)"
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

  list(pos = pos, value_from = value_from, styleRef = styleRef)
}

#' Append Style Action to Row Actions List
#'
#' Adds a style action to the row's style list. Handles duplicate column styling
#' with last-win strategy and warning.
#'
#' @param style_list List of existing style actions for the row
#' @param parsed_action List from `.parse_action_style()`
#'
#' @return Updated style_list with new action appended
#'
#' @keywords internal
#' @noRd
.append_style_action <- function(style_list, parsed_action) {
  # Check for duplicate columns in current row
  existing_cols <- unlist(lapply(style_list, `[[`, "cols"))
  duplicate_cols <- intersect(existing_cols, parsed_action$cols)

  if (length(duplicate_cols) > 0) {
    cli_warn(c(
      "Column(s) styled multiple times in same row",
      i = "Duplicate column(s): {paste(duplicate_cols, collapse = ', ')}",
      i = "Using last style specified (last-wins strategy)"
    ))

    # Remove existing actions for duplicate columns
    style_list <- Filter(function(x) {
      !any(x$cols %in% duplicate_cols)
    }, style_list)
  }

  # Append new action
  style_list[[length(style_list) + 1L]] <- list(
    cols = parsed_action$cols,
    styleRef = parsed_action$styleRef
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
    styleRef = parsed_action$styleRef
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
    styleRef = parsed_action$styleRef
  )

  addrow_list
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

      col_styles[[col]][[length(col_styles[[col]]) + 1L]] <- style_action$style
    }
  }

  # Identify columns with multiple styles
  multi_style_cols <- names(col_styles)[sapply(col_styles, length) > 1]

  if (length(multi_style_cols) > 0) {
    # For columns with multiple styles, use f_combine() to create a reference
    for (col in multi_style_cols) {
      style_refs <- col_styles[[col]]
      # Create combined style reference using f_combine pattern
      col_styles[[col]] <- do.call(f_combine, as.list(style_refs))
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
        styleRef = style_action$style
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
#' @keywords internal
#' @noRd
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
    has_style <- length(row_act$style) > 0
    has_merge <- length(row_act$merge) > 0
    has_addrow <- length(row_act$add_row) > 0

    if (!has_style && !has_merge && !has_addrow) {
      return(NULL)  # No actions for this row
    }

    # Build action object
    action_obj <- list()

    if (has_style) {
      action_obj$style <- row_act$style
    }

    if (has_merge) {
      action_obj$merge <- row_act$merge
    }

    if (has_addrow) {
      action_obj$add_row <- row_act$add_row
    }

    action_obj
  })
}
