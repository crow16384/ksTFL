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
.is_readable_file <- function(x) {
  is.character(x) &&
    length(x) == 1L &&
    file.exists(x) &&
    !dir.exists(x) &&
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
.is_readable_dir <- function(x) {
  is.character(x) &&
    length(x) == 1L &&
    dir.exists(x) &&
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

  # Escape any regex metacharacters in prefix
  esc_prefix <- gsub("([\\.\\^\\$\\|\\(\\)\\[\\]\\{\\}\\*\\+\\?\\\\])", "\\\\\\1", prefix, perl = TRUE)
  pattern <- paste0("^", esc_prefix, "([0-9]+)$")

  matches <- regexec(pattern, nm)
  captures <- regmatches(nm, matches)

  nums <- vapply(captures, function(x) {
    if (length(x) >= 2) as.integer(x[2]) else NA_integer_
  }, integer(1))

  used <- nums[!is.na(nums) & nums > 0L]

  if (length(used) == 0L) {
    return(paste0(prefix, sprintf("%04d", 1L)))
  }

  # pick smallest missing positive integer; this fills gaps rather than always
  # appending after the max
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
  for (i in seq_len(n)) {
    col <- df[[i]]
    col_name <- names(df)[i]
    col_label <- attr(col, "label", exact = TRUE)

    # ---- scalar validation (fast fail) ----
    if (is.list(col)) {
      ok <- vapply(col, is_scalar_value, logical(1))
      if (!all(ok)) {
        cli::cli_abort(
          "Column {.field {col_name}} contains non-scalar values and cannot be exported."
        )
      }
    }

    # ---- type detection ----
    is_numeric <- is.numeric(col) &&
      !inherits(col, c("Date", "POSIXct", "POSIXlt"))

    type <- if (is_numeric) "numeric" else "string"

    # ---- format guessing ----
    if (type == "numeric") {
      if (is_integerish(col)) {
        fmt <- "%d"
      } else {
        dp <- min(decimal_places(col), 4L)
        fmt <- paste0("%.", dp, "f")
      }
    } else {
      fmt <- "%s"
    }

    # ---- render once per column (performance critical) ----
    rendered <- if (type == "numeric") {
      format(sprintf(fmt, col), scientific = FALSE)
    } else {
      as.character(col)
    }

    # replace missings once
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
  
  list(unit = unit, value = value)
}

#' Recalculate Column Widths Based on User Settings
#'
#' Implements the column width recalculation algorithm per spec in columns_width_recalc.txt.
#' When user locks column widths, remaining unlocked columns are normalized to fill the available space.
#' Locked columns (any unit) remain unchanged.
#'
#' Only recalculates when:
#' 1. User has set colWidth via define_cols() (marked as locked=TRUE)
#' 2. autoColWidth option is TRUE
#'
#' @param spec TFL_spec object with columns and metadata
#'
#' @return Updated spec with recalculated column widths in both:
#'   - spec$columns[[col_id]]$format$colWidth (display strings like "25.3%")
#'   - spec$.metadata$colWidths[[col_id]] (metadata for future recalculations)
#'
#' @details
#' Algorithm:
#' 1. Partition columns into LOCKED (locked=TRUE) and UNLOCKED (locked=FALSE)
#' 2. LOCKED columns retain their exact value (whether % or fixed units)
#' 3. For UNLOCKED columns:
#'    - Calculate available space (100% - sum of locked% columns)
#'    - Calculate weights based on auto_weight
#'    - Normalize to fill available space
#' 4. Round to 1 decimal place, apply drift correction to largest column
#' 5. Update both spec and metadata
#'
#' @keywords internal
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
  
  # ---- Step 1: Partition into LOCKED and UNLOCKED ----
  # Locked columns: locked == TRUE (any unit)
  # Unlocked columns: locked == FALSE
  locked_ids <- col_ids[vapply(col_ids, function(cid) {
    col_meta[[cid]]$locked
  }, logical(1))]
  
  unlocked_ids <- col_ids[!vapply(col_ids, function(cid) {
    col_meta[[cid]]$locked
  }, logical(1))]
  
  # ---- Edge case: no unlocked columns ----
  if (length(unlocked_ids) == 0) {
    # All columns are locked, nothing to recalculate
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
  
  # ---- Step 3: Calculate weights for unlocked columns ----
  weights <- numeric(length(unlocked_ids))
  names(weights) <- unlocked_ids
  
  for (i in seq_along(unlocked_ids)) {
    cid <- unlocked_ids[i]
    meta <- col_meta[[cid]]
    # Unlocked columns always use auto_weight
    weights[i] <- meta$auto_weight
  }
  
  # ---- Step 4: Normalize unlocked weights to fill available space ----
  total_weight <- sum(weights)
  if (total_weight <= 0) {
    return(spec)
  }
  
  normalized <- (weights / total_weight) * available_space
  
  # ---- Step 5: Round to 1 decimal place + drift correction ----
  pct_rounded <- round(normalized, 1)
  
  # Compute rounding drift
  drift <- available_space - sum(pct_rounded)
  
  # Apply drift to largest unlocked column
  if (abs(drift) >= 0.05) {
    idx_max <- which.max(pct_rounded)
    pct_rounded[idx_max] <- pct_rounded[idx_max] + drift
  }
  
  # ---- Step 6: Update spec with new widths for unlocked columns ----
  for (i in seq_along(unlocked_ids)) {
    cid <- unlocked_ids[i]
    
    # Update colWidth in spec
    spec$columns[[cid]]$format$colWidth <- sprintf("%.1f%%", pct_rounded[i])
    
    # Update metadata value
    spec$.metadata$colWidths[[cid]]$value <- pct_rounded[i]
  }
  
  # ---- Step 7: Locked columns remain unchanged ----
  # (Already have correct values in spec and metadata)
  
  spec
}
