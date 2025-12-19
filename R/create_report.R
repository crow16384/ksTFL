#' Combine Multiple TFL Specifications into a Single Report
#'
#' This function takes multiple TFL specification objects and combines them into
#' a single report object matching the spec_schema_v1 structure. Each spec is
#' keyed by a combination of its variable name and metadata hash.
#'
#' @param ... One or more objects of class `TFL_spec` to be combined.
#' \itemize{
#'   \item Each argument must be a `TFL_spec` produced by `create_table()`, `create_text()` or `create_figure()`.
#'   \item Arguments are keyed in the resulting report by the argument name combined with the spec metadata hash (see return value).
#' }
#'
#' @details
#' The function performs the following operations:
#' \enumerate{
#'   \item Validates that all inputs are of class `TFL_spec`
#'   \item Assigns a `docOrder` integer (1, 2, 3, ...) based on input position
#'   \item Updates each spec's `dataRef` to `<hash>_0001`, `<hash>_0002`, etc.
#'   \item Returns a named list keyed by `<varname>_<hash>`
#' }
#'
#' @return A named list where each element is a modified TFL_spec object,
#'   keyed by the pattern `<variable_name>_<hash>`.
#'
#' @examples
#' \dontrun{
#' spec1 <- create_table(mtcars)
#' spec2 <- create_text()
#' final_report <- create_report(spec1, spec2)
#' }
#'
#' @export
create_report <- function(...) {
  # Capture all arguments and their names
  specs_list <- list(...)
  spec_names <- as.character(substitute(list(...)))[-1]  # Remove 'list' element

  # Validate input is not empty
  if (length(specs_list) == 0) {
    cli_abort("create_report() requires at least one TFL_spec object")
  }

  # Validate all objects are TFL_spec
  for (i in seq_along(specs_list)) {
    if (!inherits(specs_list[[i]], "TFL_spec")) {
      cli_abort(c(
        "All arguments to create_report() must be of class TFL_spec",
        x = "Argument {i} ({.val {spec_names[[i]]}}) is of class {.cls {class(specs_list[[i]])}}"
      ))
    }
  }

  # Process each spec
  result <- list()

  for (i in seq_along(specs_list)) {
    spec <- specs_list[[i]]
    var_name <- spec_names[[i]]
    hash <- spec$.metadata$hash

    # Validate hash exists
    if (is.null(hash) || !is.character(hash) || hash == "") {
      cli_abort(c(
        "Spec object {.val {var_name}} has invalid or missing metadata hash",
        i = "Ensure the spec was properly initialized with create_table(), create_text(), or create_figure()"
      ))
    }

    # Create the key: <varname>_<hash>
    key <- paste0(var_name, "_", hash)

    # Update docOrder: 1-based index
    spec$document$docOrder <- as.integer(i)

    # Update dataRef: <hash>_<docOrder with 4-digit padding>
    doc_order_padded <- sprintf("%04d", i)
    spec$dataRef <- c(paste0(doc_order_padded, "_", hash))

    # Add to result list with the key
    result[[key]] <- spec
  }

  class(result) <- c("TFL_report", "list")
  return(result)
}
