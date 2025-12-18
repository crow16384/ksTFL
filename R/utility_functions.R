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


