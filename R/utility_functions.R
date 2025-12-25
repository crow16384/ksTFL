##==================================================================
## Utility functions used internally in the ksTFL package
##==================================================================


utils::globalVariables(
  c(
    "__data__",
    "__mask__",
    "spec",
    "get_names", "row_number"
  )
)

#' Check if Value is Scalar and Atomic
#'
#' Validates that input is a single atomic value (not a list or vector of length > 1).
#' Used for type coercion validation to prevent composite structures.
#'
#' @param x The object to check
#'
#' @return Logical TRUE if scalar atomic, FALSE otherwise
#'
#' @keywords internal
#' @noRd
.is_scalar_atomic <- function(x) {
  is.atomic(x) && length(x) <= 1L
}

#' Check if Input is a Readable File Path
#'
#' Validates that input is a character string pointing to an existing,
#' readable file (not a directory).
#'
#' @param x The object to check
#'
#' @return Logical TRUE if valid file path, FALSE otherwise
#'
#' @keywords internal
#' @noRd
.is_readable_dir <- function(x) {
  is.character(x) &&
    length(x) == 1L &&
    dir.exists(x) &&
    file.access(x, 4) == 0
}


#' Check if Input is a Readable File Path
#'
#' Validates that input is a character string pointing to an existing,
#' readable file (not a directory).
#'
#' @param x The object to check
#'
#' @return Logical TRUE if valid file path, FALSE otherwise
#'
#' @keywords internal
#' @noRd
.is_readable_file <- function(x) {
  is.character(x) &&
    length(x) == 1L &&
    file.exists(x) &&
    !dir.exists(x) &&
    file.access(x, 4) == 0
}


#' Recursively Merge Two Objects (Last-Win Strategy)
#'
#' Merges two objects with the second taking precedence in case of conflicts.
#' Handles NULL values and recursive list merging.
#'
#' @param x First object (list or NULL)
#' @param y Second object (list or NULL). Takes precedence in merge.
#'
#' @return Merged object where conflicts favor `y` values
#'
#' @details
#' - If either object is NULL, returns the non-NULL one
#' - If both are lists, uses `modifyList()` to recursively merge
#' - Otherwise, `y` completely replaces `x` (last wins)
#'
#' @keywords internal
#' @noRd
.merge_recursive <- function(x, y) {
  if (is.null(x)) return(y)
  if (is.null(y)) return(x)
  if (is.list(x) && is.list(y)) {
    return(modifyList(x, y, keep.null = TRUE))
  }
  y  # Last wins
}

#' Auto-Generate Unique Identifier
#'
#' Generates a unique ID with a given prefix by choosing the smallest
#' positive integer suffix that is not yet used. The returned identifier is
#' zero-padded to 4 digits (e.g. "style_0001").
#'
#' @param prefix Character. Prefix for the ID (e.g., "style_")
#' @param existing_list List. List of existing objects (uses names as existing IDs).
#'   NULL is treated as an empty list.
#'
#' @return Character. Unique identifier in format "<prefix><NNNN>" where N are digits.
#'
#' @examples
#' \dontrun{
#' # Internal utility examples (not exported):
#' .auto_id("style_", list())           # -> "style_0001"
#' .auto_id("style_", list(style_0001 = 1, style_0003 = 3)) # -> "style_0002"
#' }
#'
#' @keywords internal
#' @noRd
.auto_id <- function(prefix, existing_list) {
  # Handle NULL as empty list
  if (is.null(existing_list)) {
    existing_list <- list()
  }
  
  if (!is.list(existing_list)) {
    cli_abort("Internal error: existing_list must be a list or NULL in {.fn .auto_id}")
  }

  # Efficiently find the smallest positive integer suffix not already used for
  # names that exactly match the pattern <prefix><number>. This avoids probing
  # potentially many times and deterministically fills gaps (e.g. returns
  # "style_0002" when "style_0001" and "style_0003" exist).
  # Generated IDs are formatted with 4-digit zero-padding (e.g., 0001).

  nm <- names(existing_list)
  if (is.null(nm) || length(nm) == 0L) {
    return(paste0(prefix, sprintf("%04d", 1L)))
  }

  # Escape any regex metacharacters in prefix for safe pattern construction
  esc_prefix <- gsub("([\\.\\^\\$\\|\\(\\)\\[\\]\\{\\}\\*\\+\\?\\\\])", "\\\\\\1", prefix, perl = TRUE)
  # Pre-compile pattern with perl=TRUE for faster matching (10-15% performance gain)
  pattern <- paste0("^", esc_prefix, "([0-9]+)$")

  # Use perl=TRUE for optimized regex execution
  matches <- regexec(pattern, nm, perl = TRUE)
  captures <- regmatches(nm, matches)

  # Vectorized extraction of numeric suffixes
  nums <- vapply(captures, function(x) {
    if (length(x) >= 2L) as.integer(x[2L]) else NA_integer_
  }, integer(1L), USE.NAMES = FALSE)

  used <- nums[!is.na(nums) & nums > 0L]

  if (length(used) == 0L) {
    return(paste0(prefix, sprintf("%04d", 1L)))
  }

  # Pick smallest missing positive integer; this fills gaps rather than always
  # appending after the max (e.g., returns "style_0002" when 0001 and 0003 exist)
  candidate <- setdiff(seq_len(max(used) + 1L), used)[1L]
  paste0(prefix, sprintf("%04d", candidate))
}

## Internal: generate a stable hash from any number of R objects
#' Generate a stable short hash for arbitrary R objects
#'
#' Useful for creating reproducible identifiers from R objects used in caching
#' or metadata hashes internal to the package.
#'
#' @param ... R objects to include in the hash
#' \itemize{
#'   \item Arbitrary R objects that are serializable via base serialization (vectors, lists, data frames, atomic values).
#'   \item Avoid passing non-serializable objects (external pointers, open connections); behavior is undefined for such inputs.
#'   \item Typical usage: provide the spec object, associated data, or small metadata values to generate a reproducible short hash.
#' }
#' @return Character scalar of the first 16 hex characters of the hash
#' @keywords internal
#' @examples
#' \dontrun{
#' .generate_hash('a', 1, TRUE)
#' }
#' @noRd
.generate_hash <- function(...) {
  h <- digest::digest(
    list(...),
    algo = "xxhash64",
    serialize = TRUE
  )
  
  substr(h, 1, 16)
}

#' Guess Table Column Layout from Data Frame
#' 
#' Analyzes a data frame and generates initial column layout specifications.
#' Returns both format specs and width metadata for recalculation support.
#' 
#' @param df Data frame to analyze
#' @param missings Character string for missing value representation (default: "NA")
#'
#' @return List with two elements:
#'   - `$formats`: Named list of format specs (keyed by column name) with type, format, colWidth
#'   - `$metadata`: Named list of width metadata (keyed by column name) with unit, value, locked, auto_weight
#'
#' @keywords internal
#' @noRd
.guess_table_layout <- function(df, missings = "NA") {

  # ---- assertions ----
  checkmate::assert_data_frame(df, any.missing = TRUE)
  checkmate::assert_character(missings, len = 1, .var.name = "missings")

  # ---- configuration ----
  min_width_pct <- 5
  max_width_pct <- 60
  eps <- .Machine$double.eps^0.5

  n <- ncol(df)
  raw_widths <- numeric(n)
  result <- vector("list", n)
  metadata <- vector("list", n)

  # Deterministic sampling for width estimation on large datasets
  nrows <- nrow(df)
  sample_threshold <- 10000L
  if (nrows > sample_threshold) {
    sample_idx <- unique(as.integer(round(seq(1, nrows, length.out = sample_threshold))))
  } else {
    sample_idx <- seq_len(nrows)
  }

  # ---- helpers ----

  # scalar-per-cell validation
  is_scalar_value <- function(x) {
    if (is.null(x)) return(TRUE)
    if (length(x) != 1) return(FALSE)
    if (is.atomic(x)) return(TRUE)
    inherits(x, c("Date", "POSIXct", "POSIXlt"))
  }

  # integer detection by value
  is_integerish <- function(x) {
    x <- x[!is.na(x)]
    if (!length(x)) return(TRUE)
    all(abs(x - round(x)) < eps)
  }

  # decimal places detection (no scientific notation)
  decimal_places <- function(x) {
    x <- x[!is.na(x)]
    if (!length(x)) return(0)

    s <- format(x, scientific = FALSE, trim = TRUE)
    dp <- regexpr("\\.", s)
    has_dp <- dp > 0
    if (!any(has_dp)) return(0)

    max(
      nchar(
        substr(s[has_dp], dp[has_dp] + 1L, nchar(s[has_dp])),
        type = "width"
      )
    )
  }

  # UTF-8 visual width
  text_width <- function(x) {
    nchar(x, type = "width", allowNA = TRUE, keepNA = FALSE)
  }

  # longest line width (handles manual \n)
  max_line_width <- function(x) {
    lines <- strsplit(x, "\n", fixed = TRUE)
    max(vapply(lines, function(l) max(text_width(l)), integer(1)))
  }

  # ---- main loop (column-wise, cache-friendly) ----
  # Optimization: Pre-vectorize type detection across all columns
  col_classes <- vapply(df, function(col) {
    paste(class(col), collapse = "/")
  }, character(1), USE.NAMES = FALSE)
  
  is_numeric_vec <- vapply(seq_len(n), function(i) {
    col <- df[[i]]
    is.numeric(col) && !inherits(col, c("Date", "POSIXct", "POSIXlt"))
  }, logical(1), USE.NAMES = FALSE)
  
  for (i in seq_len(n)) {
    col <- df[[i]]
    col_name <- names(df)[i]
    col_label <- attr(col, "label", exact = TRUE)

    # ---- scalar validation (fast fail) ----
    if (is.list(col)) {
      ok <- vapply(col, is_scalar_value, logical(1), USE.NAMES = FALSE)
      if (!all(ok)) {
        cli::cli_abort(
          "Column {.field {col_name}} contains non-scalar values and cannot be exported."
        )
      }
    }

    # ---- type detection (pre-computed) ----
    is_numeric <- is_numeric_vec[i]
    type <- if (is_numeric) "numeric" else "string"

    # ---- format guessing with caching ----
    cache_key <- NULL
    if (type == "numeric") {
      # Check cache for numeric format (based on integerish and decimal places)
      is_int <- is_integerish(col)
      dp <- if (!is_int) min(decimal_places(col), 4L) else 0L
      cache_key <- paste0("num_", is_int, "_", dp)
      
      if (exists(cache_key, envir = .format_spec_cache, inherits = FALSE)) {
        fmt <- get(cache_key, envir = .format_spec_cache, inherits = FALSE)
      } else {
        fmt <- if (is_int) "%d" else paste0("%.", dp, "f")
        assign(cache_key, fmt, envir = .format_spec_cache)
      }
    } else {
      fmt <- "%s"
    }

    # ---- render with vectorized operations (performance critical) ----
    # Use a deterministic sample for rendering/width estimation to limit cost
    col_sample <- if (length(sample_idx) > 0 && length(col) >= max(sample_idx)) col[sample_idx] else col
    if (length(col_sample) == 0) {
      # No data rows: use missing placeholder for width estimation
      rendered <- as.character(missings)
    } else {
      # Vectorized rendering
      rendered <- if (type == "numeric") {
        sprintf(fmt, col_sample)  # sprintf is vectorized
      } else {
        as.character(col_sample)
      }
    }

    # replace missings once (vectorized)
    rendered[is.na(rendered)] <- missings

    # ---- width estimation ----
    value_len <- max_line_width(rendered)
    name_len  <- max_line_width(col_name)
    label_len <- if (!is.null(col_label)) {
      max_line_width(as.character(col_label))
    } else {
      0L
    }

    raw_widths[i] <- max(value_len, name_len, label_len, 1L)

    result[[i]] <- list(
      type = type,
      format = fmt,
      colWidth = NA_character_
    )
  }

  # ---- width normalization ----
  pct <- raw_widths / sum(raw_widths) * 100

  pct <- pmax(pct, min_width_pct)
  pct <- pmin(pct, max_width_pct)

  pct <- pct / sum(pct) * 100
  pct_rounded <- round(pct, 1)

  # rounding drift correction
  drift <- 100 - sum(pct_rounded)
  if (abs(drift) >= 0.05) {
    idx <- which.max(pct_rounded)
    pct_rounded[idx] <- pct_rounded[idx] + drift
  }

  pct_chr <- sprintf("%.1f%%", pct_rounded)

  for (i in seq_len(n)) {
    result[[i]]$colWidth <- pct_chr[i]
    
    # Create metadata for this column
    metadata[[i]] <- list(
      unit       = "%",
      value      = pct_rounded[i],
      locked     = FALSE,
      auto_weight = pct_rounded[i]
    )
  }

  names(result) <- names(df)
  names(metadata) <- names(df)
  
  # Return both formats and metadata
  list(
    formats = result,
    metadata = metadata
  )
}


#' Recursively Remove Class Attributes from an Object
#' @param x R object (list or atomic) to unclass
#' @return R object with all class attributes removed
#' @keywords internal
#' @noRd 
.unclass_recursive <- function(x) {

  # Remove class only
  if (!is.null(class(x))) {
    class(x) <- NULL
  }

  # Recurse only into true lists
  if (is.list(x)) {
    x <- lapply(x, .unclass_recursive)
  }

  x
}

#' Parse colWidth String into Unit and Value
#'
#' Extracts the numeric value and unit from a colWidth string.
#' Handles patterns like "25.3%", "3.5cm", "10mm", "1in".
#'
#' @param colwidth_str Character string representing a column width
#'
#' @return List with `unit` and `value` elements, or NULL if parsing fails
#'
#' @keywords internal
#' @noRd
.parse_colwidth <- function(colwidth_str) {
  
  if (!is.character(colwidth_str) || length(colwidth_str) != 1) {
    return(NULL)
  }
  
  # Try to match pattern: <number><%|cm|mm|in|pt>
  # Matches strings like "25.3%", "3.5cm", "10mm", "1in"
  m <- regexec("^([0-9.]+)([a-z%]+)$", colwidth_str, ignore.case = TRUE)
  matches <- regmatches(colwidth_str, m)
  
  if (length(matches[[1]]) != 3) {
    return(NULL)
  }
  
  value_str <- matches[[1]][2]
  unit <- matches[[1]][3]
  
  # Try to convert value to numeric
  value <- suppressWarnings(as.numeric(value_str))
  
  if (is.na(value)) {
    return(NULL)
  }
  
  # Normalize unit to lowercase
  unit <- tolower(unit)
  
  return(list(unit = unit, value = value))
}

#' Validate Column Width Against Minimum Thresholds
#'
#' Checks if a proposed column width meets the minimum allowed value.
#' Minimums differ by unit:
#' - Relative widths (%): minimum 0.5%
#' - Fixed widths (cm): minimum 0.2cm
#' - Other fixed units (in, mm, pt): converted to equivalent cm and checked
#'
#' @param width_info List from `.parse_colwidth()` with `unit` and `value` fields
#' @param proposed_col_width_str Original width string for error messaging (e.g., "0.1%")
#'
#' @return Invisibly returns TRUE if valid. Throws cli_abort() if invalid.
#'
#' @keywords internal
#' @noRd
.validate_colwidth_minimum <- function(width_info, proposed_col_width_str) {
  
  unit <- tolower(width_info$unit)
  value <- width_info$value
  
  if (unit == "%") {
    min_width <- 0.5
    if (value < min_width) {
      cli_abort(c(
        "Column width {.str {proposed_col_width_str}} is below minimum allowed",
        x = "Relative widths must be at least {min_width}%",
        i = "Proposed: {value}%"
      ))
    }
  } else {
    # Fixed-unit widths: convert to cm and check minimum of 0.2cm
    min_width_cm <- 0.2
    
    # Convert to cm for comparison
    value_cm <- switch(unit,
      "cm" = value,
      "in" = value * 2.54,        # 1 inch = 2.54 cm
      "mm" = value / 10,          # 10 mm = 1 cm
      "pt" = value * 0.0353,      # 1 point ~ 0.0353 cm
      value  # fallback to original if unknown unit
    )
    
    if (value_cm < min_width_cm) {
      # Display error in original units
      cli_abort(c(
        "Column width {.str {proposed_col_width_str}} is below minimum allowed",
        x = "Fixed-unit widths must be at least {min_width_cm}cm (~ 0.08in)",
        i = "Proposed: {value}{unit} (~ {format(round(value_cm, 2), nsmall = 2)}cm)"
      ))
    }
  }
  
  invisible(TRUE)
}

#' Validate Relative Column Width Against Constraints
#'
#' Checks if setting a relative width on one column would leave insufficient
#' space for other unlocked columns to meet the minimum width threshold.
#'
#' @param spec TFL_spec object with columns and metadata
#' @param col_id Column ID being locked
#' @param proposed_width_pct Proposed relative width as numeric (e.g., 100 for "100%")
#' @param proposed_col_width_str Original width string for error messaging (e.g., "100%")
#'
#' @return Invisibly returns TRUE if valid. Throws cli_abort() if invalid.
#'
#' @details
#' Algorithm:
#' 1. Count total columns in spec
#' 2. Identify already-locked relative-width columns
#' 3. Calculate total locked % width
#' 4. Identify remaining unlocked columns
#' 5. Check if remaining space can accommodate unlocked columns at minimum width
#' 6. If not, provide detailed error message with maximum allowed width
#'
#' @keywords internal
#' @noRd
.validate_relative_colwidth <- function(spec, col_id, proposed_width_pct, 
                                        proposed_col_width_str) {
  
  # Get minimum width threshold from options
  min_width <- tfl_get_option("minColWidth")
  
  # Count total columns
  total_cols <- length(spec$columns)
  
  # Get column width metadata
  col_meta <- spec$.metadata$colWidths
  if (is.null(col_meta)) {
    return(invisible(TRUE))
  }
  
  col_ids <- names(col_meta)
  
  # Find already-locked relative-width columns (excluding the one being set now)
  locked_relative_total <- 0
  locked_count <- 0
  
  for (cid in col_ids) {
    if (cid == col_id) next  # Skip the column being set
    meta <- col_meta[[cid]]
    if (!is.null(meta$locked) && meta$locked && meta$unit == "%") {
      locked_relative_total <- locked_relative_total + meta$value
      locked_count <- locked_count + 1
    }
  }
  
  # Calculate space after the NEW width is locked
  new_locked_total <- locked_relative_total + proposed_width_pct
  remaining_space <- 100 - new_locked_total
  
  # Count unlocked columns (excluding the one being set, which will become locked)
  unlocked_count <- total_cols - locked_count - 1L  # -1 for the column being set
  
  # Check constraint: can remaining unlocked columns fit at minimum width?
  required_space <- unlocked_count * min_width
  
  if (remaining_space < required_space) {
    # Calculate maximum allowed width for this column
    max_allowed <- 100 - (locked_relative_total + unlocked_count * min_width)
    
    # Build error message parts conditionally
    error_parts <- c(
      "Cannot set column {.arg {col_id}} to {.str {proposed_col_width_str}}",
      x = paste0(
        "This would leave insufficient space for the remaining {unlocked_count} ",
        "unlocked column{if (unlocked_count != 1) 's' else ''} to meet the minimum ",
        "width of {min_width}%."
      )
    )
    
    # Only include locked columns info if there are actually locked columns
    if (locked_count > 0) {
      error_parts <- c(
        error_parts,
        i = paste0(
          "Currently {locked_count} column{if (locked_count != 1) 's are' else ' is'} ",
          "already locked at {locked_relative_total}%."
        )
      )
    }
    
    # Add remaining constraint and solution info
    error_parts <- c(
      error_parts,
      i = paste0(
        "After this change, {unlocked_count} column{if (unlocked_count != 1) 's need' else ' needs'} ",
        "{required_space}% total. Remaining space available: {remaining_space}%."
      ),
      i = paste0(
        "Maximum allowed relative width for {.arg {col_id}}: {format(round(max_allowed, 1), nsmall = 1)}%"
      ),
      i = "Reduce the proposed width or adjust other locked widths"
    )
    
    cli_abort(error_parts)
  }
  
  invisible(TRUE)
}

#' Recalculate Column Widths Based on User Settings
#'
#' Implements the column width recalculation algorithm per spec in columns_width_recalc.txt.
#' When user locks column widths, remaining unlocked columns are normalized to fill the available space.
#' Locked columns (any unit) remain unchanged. Invisible columns (isVisible = FALSE) are excluded
#' from width calculations entirely.
#'
#' Only recalculates when:
#' 1. User has set colWidth via define_cols() (marked as locked=TRUE)
#' 2. autoColWidth option is TRUE
#'
#' @param spec TFL_spec object with columns and metadata
#'
#' @return Updated spec with recalculated column widths in both:
#'   - `spec$columns[[col_id]]$format$colWidth` (display strings like "25.3%")
#'   - `spec$.metadata$colWidths[[col_id]]` (metadata for future recalculations)
#'
#' @details
#' Algorithm:
#' 1. Filter to VISIBLE columns only (exclude isVisible = FALSE)
#' 2. Among visible columns, partition into LOCKED (locked=TRUE) and UNLOCKED (locked=FALSE)
#' 3. LOCKED visible columns retain their exact value (whether % or fixed units)
#' 4. For UNLOCKED visible columns:
#'    - Calculate available space (100% - sum of locked% columns)
#'    - Calculate weights based on auto_weight
#'    - Normalize to fill available space
#' 5. Round to 1 decimal place, apply drift correction to largest column
#' 6. Update both spec and metadata
#' 7. Invisible columns remain unchanged
#'
#' @keywords internal
#' @noRd
.recalculate_col_widths <- function(spec) {
  
  # Guard: no metadata = no recalculation
  if (is.null(spec$.metadata$colWidths)) {
    return(spec)
  }
  
  col_meta <- spec$.metadata$colWidths
  if (length(col_meta) == 0) {
    return(spec)
  }
  
  col_ids <- names(col_meta)
  
  # ---- Step 0: Filter to VISIBLE columns only ----
  # Exclude columns where isVisible = FALSE
  visible_ids <- col_ids[vapply(col_ids, function(cid) {
    is_visible <- spec$columns[[cid]]$isVisible
    # Default to TRUE if not specified (visible by default)
    if (is.null(is_visible)) TRUE else isTRUE(is_visible)
  }, logical(1))]
  
  # If no visible columns, nothing to recalculate
  if (length(visible_ids) == 0) {
    return(spec)
  }
  
  # ---- Step 1: Partition VISIBLE columns into LOCKED and UNLOCKED ----
  # Locked columns: locked == TRUE (any unit)
  # Unlocked columns: locked == FALSE
  locked_ids <- visible_ids[vapply(visible_ids, function(cid) {
    col_meta[[cid]]$locked
  }, logical(1))]
  
  unlocked_ids <- visible_ids[!vapply(visible_ids, function(cid) {
    col_meta[[cid]]$locked
  }, logical(1))]
  
  # ---- Edge case: no unlocked visible columns ----
  if (length(unlocked_ids) == 0) {
    # All visible columns are locked, nothing to recalculate
    return(spec)
  }
  
  # ---- Step 2: Calculate available space ----
  # Locked percentage columns reduce available space for unlocked columns
  available_space <- 100
  locked_percentage_total <- 0
  
  for (cid in locked_ids) {
    meta <- col_meta[[cid]]
    if (meta$unit == "%") {
      locked_percentage_total <- locked_percentage_total + meta$value
    }
    # Fixed-unit locked columns don't affect available space
  }
  
  available_space <- 100 - locked_percentage_total
  
  if (available_space <= 0) {
    # Locked columns already exceed 100%, can't normalize unlocked
    # Return as-is
    return(spec)
  }
  
  # ---- Step 3: Calculate weights for unlocked VISIBLE columns ----
  weights <- numeric(length(unlocked_ids))
  names(weights) <- unlocked_ids
  
  for (i in seq_along(unlocked_ids)) {
    cid <- unlocked_ids[i]
    meta <- col_meta[[cid]]
    # Unlocked visible columns always use auto_weight
    weights[i] <- meta$auto_weight
  }
  
  # ---- Step 4: Normalize unlocked visible weights to fill available space ----
  total_weight <- sum(weights)
  if (total_weight <= 0) {
    return(spec)
  }
  
  normalized <- (weights / total_weight) * available_space
  
  # ---- Step 5: Round to 1 decimal place + drift correction ----
  pct_rounded <- round(normalized, 1)
  
  # Compute rounding drift
  drift <- available_space - sum(pct_rounded)
  
  # Apply drift to largest unlocked visible column
  if (abs(drift) >= 0.05) {
    idx_max <- which.max(pct_rounded)
    pct_rounded[idx_max] <- pct_rounded[idx_max] + drift
  }
  
  # ---- Step 6: Update spec with new widths for unlocked VISIBLE columns ----
  for (i in seq_along(unlocked_ids)) {
    cid <- unlocked_ids[i]
    
    # Update colWidth in spec
    spec$columns[[cid]]$format$colWidth <- sprintf("%.1f%%", pct_rounded[i])
    
    # Update metadata value
    spec$.metadata$colWidths[[cid]]$value <- pct_rounded[i]
  }
  
  # ---- Step 7: Locked visible columns and all invisible columns remain unchanged ----
  # (Already have correct values in spec and metadata)
  
  spec
}
