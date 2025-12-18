##==================================================================
## Utility functions used internally in the ksTFL package
##==================================================================

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
