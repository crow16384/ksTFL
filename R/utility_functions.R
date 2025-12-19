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
#' used in TFL_init() to pre-populate column definitions
#' @noRd 
.guess_table_layout <- function(df) {
  checkmate::assert_data_frame(df, .var.name = "df")

  if (!exists(".const_default_missing_value", inherits = TRUE)) {
    cli::cli_abort(c(
      "Internal configuration missing: {.var .const_default_missing_value} not found.",
      i = "Ensure constants are defined (e.g. in R/constants.R) and the package is loaded."
    ))
  }

  min_width_pct <- 5
  max_width_pct <- 60
  eps <- .Machine$double.eps^0.5

  n <- ncol(df)
  result <- vector("list", n)
  raw_widths <- numeric(n)

  # ---- helpers ----

  is_scalar_value <- function(x) {
    if (is.null(x)) return(TRUE)
    if (length(x) != 1) return(FALSE)
    if (is.atomic(x)) return(TRUE)
    if (inherits(x, c("Date", "POSIXct", "POSIXlt"))) return(TRUE)
    FALSE
  }

  is_integerish <- function(x) {
    x <- x[!is.na(x)]
    if (!length(x)) return(TRUE)
    all(abs(x - round(x)) < eps)
  }

  decimal_places <- function(x) {
    x <- x[!is.na(x)]
    if (!length(x)) return(0)

    s <- format(x, scientific = FALSE, trim = TRUE)
    dp <- regexpr("\\.", s)
    has_dp <- dp > 0
    if (!any(has_dp)) return(0)

    max(nchar(substr(s[has_dp], dp[has_dp] + 1, nchar(s[has_dp]))))
  }

  for (i in seq_len(n)) {
    col <- df[[i]]
    col_name <- names(df)[i]
    col_label <- attr(col, "label", exact = TRUE)

    # ---- scalar check ----
    if (is.list(col)) {
      bad <- vapply(col, function(x) !is_scalar_value(x), logical(1))
      if (any(bad)) {
        cli::cli_abort(c(
          "Column '{col_name}' contains non-scalar values and cannot be exported.",
          x = "List elements must be atomic scalars or Date/POSIX objects."
        ))
      }
    }

    # ---- type ----
    is_numeric <- is.numeric(col) &&
      !inherits(col, c("Date", "POSIXct", "POSIXlt"))

    type <- if (is_numeric) "numeric" else "string"

    # ---- format ----
    if (type == "numeric") {
      if (is_integerish(col)) {
        fmt <- "%d"
      } else {
        dp <- min(decimal_places(col), 4)
        fmt <- paste0("%.", dp, "f")
      }
    } else {
      fmt <- "%s"
    }

    # ---- render for width ----
    rendered <- if (type == "numeric") {
      out <- sprintf(fmt, col)
      format(out, scientific = FALSE)
    } else {
      as.character(col)
    }

    rendered[is.na(rendered)] <- .const_default_missing_value

    value_len <- max(nchar(rendered), na.rm = TRUE)
    name_len  <- nchar(col_name)
    label_len <- if (!is.null(col_label)) nchar(as.character(col_label)) else 0

    raw_widths[i] <- max(value_len, name_len, label_len, 1)

    result[[i]] <- list(
      type = type,
      format = fmt,
      colWidth = NA_character_
    )
  }

  # ---- width normalization ----
  pct <- raw_widths / sum(raw_widths) * 100

  # enforce min / max
  pct <- pmax(pct, min_width_pct)
  pct <- pmin(pct, max_width_pct)

  # renormalize
  pct <- pct / sum(pct) * 100

  # round to 1 dp
  pct_rounded <- round(pct, 1)

  # fix rounding drift
  drift <- 100 - sum(pct_rounded)
  if (abs(drift) >= 0.05) {
    idx <- which.max(pct_rounded)
    pct_rounded[idx] <- pct_rounded[idx] + drift
  }

  pct_chr <- sprintf("%.1f%%", pct_rounded)

  for (i in seq_len(n)) {
    result[[i]]$colWidth <- pct_chr[i]
  }

  names(result) <- names(df)
  result
}
