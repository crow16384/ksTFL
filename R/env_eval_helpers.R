#' @importFrom tidyselect all_of
NULL

#' Create a Data Evaluation Environment
#'
#' Initialize a working environment where expressions can be evaluated in the context
#' of a data frame. The environment includes the data and a set of helper functions
#' that can reference data columns and custom functions.
#'
#' @param data A data frame to include in the environment
#' @param funcs A named list of functions to include in the environment. These functions
#'   will be evaluated in the created environment with access to `__data__` and `__mask__`.
#'
#' @return An environment containing:
#'   - All functions from `funcs`
#'   - The raw data as `__data__`
#'   - A data mask as `__mask__` for tidyverse-style evaluation
#'
#' @keywords internal
#' @examples
#' \dontrun{
#'   menv <- .create_data_env(mtcars, list())
#'   with(menv, row_number())
#'   with(menv, eval_tidy(quote(cyl + am), env = `__mask__`))
#' }
.create_data_env <- function(data, funcs) {
  # Create a "top-level" environment that contains:
  #  - all functions in `funcs`
  #  - the raw data under the name `__data__`
  # The parent environment is the caller's environment, so it can see variables there.
  topmask <- list2env(append(funcs, list(`__data__` = data)), parent = .GlobalEnv)
  
  # For each function in `funcs`, set its environment to `topmask`.
  # This means that when the function is called, it can access `__data__` and other functions in topmask.
  for (nm in names(funcs)) {
    environment(topmask[[nm]]) <- topmask
  }
  
  # Create a new environment that holds the data (`data`) with `topmask` as its parent
  mask <- new_environment(data, parent = topmask)
  
  # Wrap it as a "data mask" (likely from rlang/tidyverse), which allows special data evaluation
  mask <- new_data_mask(mask, topmask)
  
  # Create the final function environment (`fn_env`) containing:
  #  - the same functions as `funcs`
  #  - the raw data as `__data__`
  #  - the data mask as `__mask__`
  # Its parent is the caller's environment
  fn_env <- list2env(append(funcs, list(`__data__` = data, `__mask__` = mask)), parent = caller_env())
  
  # Set each function's environment inside `fn_env` to point to `fn_env` itself.
  # This ensures that when the function is called, it sees `__data__` and `__mask__` correctly.
  for (nm in names(funcs)) {
    environment(fn_env[[nm]]) <- fn_env
  }
  
  # Set the environment of the `__mask__` object to the `fn_env` so that
  # operations inside the mask can see the functions and data in `fn_env`
  environment(fn_env$`__mask__`) <- fn_env
  
  # Return the final environment containing everything
  fn_env
}



#' Get Selected Data Column Indices
#'
#' Helper function to return the data column names/order as a named vector using
#' tidyselect functionality. Supports tidyverse selection syntax (e.g., `everything()`,
#' `c()`, named expressions).
#'
#' @param .data A data frame to select columns from
#' @param ... Column selection expressions (tidyselect syntax)
#' \itemize{
#'   \item `everything()` — selects all columns.
#'   \item `c(col1, col2)` or multiple symbols — select specific columns by name.
#'   \item Helper helpers: `starts_with()`, `contains()`, `matches()`, etc.
#'   \item Negation: use `-col` or `!matches()` to exclude columns.
#'   \item External character vectors (unquoted symbols that evaluate to character vectors) are supported and will be wrapped with `all_of()`.
#' }
#' @param .selenv Environment for evaluating column expressions (default: calling environment)
#' @param .strict Logical. If `TRUE` (default), require exact column matches
#'
#' @return A named integer vector with column indices, where names are column names
#'
#' @details
#' Supports:
#' - `everything()` - all columns
#' - `c(col1, col2)` - specific columns
#' - Character vectors via external variables
#'
#' @keywords internal
#' @examples
#' \dontrun{
#'   .get_data_columns(mtcars, everything())
#'   .get_data_columns(mtcars, c(cyl, mpg))
#'   .get_data_columns(mtcars, cyl, mpg, gear)
#' }
.get_data_columns <- function(.data, ..., .selenv = NULL, .strict = TRUE) {
  dots <- enquos(..., .named = FALSE)
  
  if (length(dots) == 0) {
    cli_abort(c(
      "No column expressions provided in {.fn .get_data_columns}",
      i = "Provide column selection expressions (e.g., everything(), c(col1, col2))"
    ))
  }
  
  .selenv <- .selenv %||% caller_env()
  
  # Convert dots to a list of expressions, handling external vectors
  exprs <- lapply(dots, function(q) {
    expr <- quo_get_expr(q)
    env <- quo_get_env(q)
    
    # Handle symbols that might be external vectors
    if (is_symbol(expr)) {
      # Try to evaluate the symbol
      value <- tryCatch(
        eval(expr, envir = env),
        error = function(e) NULL
      )
      
      # If it's a character vector, wrap in all_of()
      if (is.character(value)) {
        return(expr(all_of(!!expr)))
      }
    }
    
    # For everything else, return the expression as is
    expr
  })
  
  # Build the selection expression
  select_expr <- expr(c(!!!exprs))
  
  tryCatch(
    tidyselect::eval_select(
      select_expr,
      data = .data,
      env = .selenv,
      strict = .strict
    ),
    error = function(e) {
      cli_abort(c(
        "Invalid column selection:",
        x = conditionMessage(e)
      ))
    }
  )
}

#' Get Selected Data Column Names
#'
#' Extract the names of columns selected using tidyselect syntax.
#'
#' @param .data A data frame to select columns from
#' @param ... Column selection expressions (tidyselect syntax)
#' \itemize{
#'   \item `everything()` — selects all columns.
#'   \item `c(col1, col2)` or listing symbols — select specific columns by name.
#'   \item Helper helpers: `starts_with()`, `ends_with()`, `contains()`, `matches()`, etc.
#'   \item Negation: use `-id` or `!matches()` to exclude columns.
#' }
#' @param .selenv Environment for evaluating column expressions (default: calling environment)
#' @param .strict Logical. If `TRUE` (default), require exact column matches
#'
#' @return A character vector of column names
#'
#' @keywords internal
#' @examples
#' \dontrun{
#'   .get_data_column_names(mtcars, everything())
#'   .get_data_column_names(mtcars, c(cyl, mpg))
#' }
.get_data_column_names <- function(.data, ..., .selenv=NULL, .strict=T) {
  col_indices <- .get_data_columns(.data, ..., .selenv = .selenv, .strict = .strict)
  names(col_indices)
}

#' Evaluate Expression in Data Environment
#'
#' Evaluate an expression within a data environment, with access to data columns
#' and helper functions.
#'
#' @param expr An expression to evaluate (will be quoted)
#' @param env An environment object (default: `spec$.metadata$data_env`).
#'   Must contain `__mask__` for tidyverse-style evaluation.
#'
#' @return The result of evaluating `expr` in the data environment
#'
#' @keywords internal
#' @examples
#' \dontrun{
#'   .env_eval(cyl + am)
#'   exp <- expr(firstOf(cyl))
#'   .env_eval(!!exp)
#' }
.env_eval <- function(expr, env=spec$.metadata$data_env) {
  expr <- enexpr(expr)
  eval_tidy(expr, env = env$`__mask__`)
}


############################################################################
# Below are internal functions that will be embedded into the working env to have preceedence over other functions
############################################################################

# Internal helper to compute change flags for adjacent rows
.eval_change_of <- function(which = c("first", "last"), ..., data = `__data__`) {
  which <- match.arg(which)
  cols <- get_names(...)
  # Extract columns
  m <- data[cols]

  if (nrow(m) == 0) return(logical(0))  # empty df
  if (nrow(m) == 1) return(TRUE)        # single row

  prev <- m[-nrow(m), , drop = FALSE]
  curr <- m[-1, , drop = FALSE]

  diff_flag <- apply(
    cbind(prev, curr),
    1,
    function(row) {
      p <- row[1:(length(row)/2)]
      c <- row[(length(row)/2 + 1):length(row)]
      any(is.na(p) | is.na(c) | p != c)
    }
  )

  if (which == "first") {
    return(unname(c(TRUE, diff_flag)))
  }
  unname(c(diff_flag, TRUE))
}

#' Find First Occurrence of Changed Values
#'
#' Returns a logical vector indicating the first row of each distinct combination
#' of values in the specified columns.
#'
#' @param ... Column names (unquoted or as character vector)
#' \itemize{
#'   \item Accepts one or more column names as unquoted symbols (e.g., `cyl`) or as a character vector.
#'   \item Supports tidyselect-style helpers when evaluated in a data mask (e.g., `starts_with()`, `contains()`).
#'   \item Multiple columns may be supplied and will be evaluated against the `__data__` object in the data environment.
#' }
#' @param data The data frame to evaluate (default: `__data__` from environment)
#'
#' @return A logical vector with `TRUE` at the first row of each value change,
#'   and `TRUE` for the first row. Returns logical(0) for empty data,
#'   and `TRUE` for single-row data.
#'
#' @keywords internal
#' @examples
#' \dontrun{
#'   .env_eval(firstOf(cyl))
#'   .env_eval(firstOf(cyl, am))
#' }
.eval_firstOf <- function(..., data=`__data__`) {
  .eval_change_of("first", ..., data = data)
}

#' Find Last Occurrence of Changed Values
#'
#' Returns a logical vector indicating the last row of each distinct combination
#' of values in the specified columns.
#'
#' @param ... Column names (unquoted or as character vector)
#' \itemize{
#'   \item Accepts one or more column names as unquoted symbols (e.g., `cyl`) or as a character vector.
#'   \item Supports tidyselect-style helpers when evaluated in a data mask (e.g., `starts_with()`, `contains()`).
#'   \item Multiple columns may be supplied and will be evaluated against the `__data__` object in the data environment.
#' }
#' @param data The data frame to evaluate (default: `__data__` from environment)
#'
#' @return A logical vector with `TRUE` at the last row of each value change,
#'   and `TRUE` for the last row. Returns logical(0) for empty data,
#'   and `TRUE` for single-row data.
#'
#' @keywords internal
#' @examples
#' \dontrun{
#'   .env_eval(lastOf(cyl))
#'   .env_eval(lastOf(cyl, am))
#' }
.eval_lastOf <- function(..., data=`__data__`) {
  .eval_change_of("last", ..., data = data)
}

#' Get Names of Selected Columns in Environment
#'
#' Returns the names of the selected data columns using tidyselect syntax.
#' This function is designed to be called within a data evaluation environment.
#'
#' @param ... Column selection expressions (tidyselect syntax)
#' \itemize{
#'   \item Accepts tidyselect expressions (e.g., `everything()`, `c(col1, col2)`, helpers like `starts_with()`).
#'   \item Supports unquoted symbols that evaluate to external character vectors (these will be wrapped with `all_of()`).
#'   \item Expressions are evaluated in the data mask and must resolve to existing column names (unless `.strict = FALSE`).
#' }
#' @param .data The data frame to select from (default: `__data__` from environment)
#' @param .selenv Environment for evaluating column expressions (default: calling environment)
#' @param .strict Logical. If `TRUE` (default), require exact column matches
#'
#' @return A character vector of selected column names
#'
#' @keywords internal
#' @examples
#' \dontrun{
#'   .env_eval(get_names(cyl, am))  # Returns c("cyl", "am")
#' }
.eval_get_names <- function(..., .data=`__data__`, .selenv=NULL, .strict=T) {
   names(.get_data_columns(.data, ..., .selenv = .selenv, .strict = .strict))
  }

#' Get Row Numbers in Environment
#'
#' Returns a sequence of row numbers for the data in the evaluation environment.
#'
#' @param .data The data frame (default: `__data__` from environment)
#'
#' @return An integer vector of row numbers from 1 to nrow(.data)
#'
#' @keywords internal
#' @examples
#' \dontrun{
#'   .env_eval(row_numbers())  # Returns c(1, 2, 3, ..., nrow(data))
#' }
.eval_row_numbers <- function(.data=`__data__`) {
  seq_len(nrow(.data))
}

#' Select Every Nth Row
#'
#' Returns a logical vector with `TRUE` at every nth row.
#'
#' @param n Integer. The interval for selecting rows.
#'
#' @return A logical vector with `TRUE` at every nth row
#'
#' @keywords internal
#' @examples
#' \dontrun{
#'   .env_eval(every_nth(3))  # Returns logical vector TRUE at rows 1, 4, 7, 10, ...
#' }
.eval_every_nth <- function(n) {
  ((row_number() - 1) %% n) == 0
}

#' Evaluate Expression in Data Mask
#'
#' Evaluate an expression using tidyverse-style data masking within the
#' evaluation environment.
#'
#' @param expr An expression to evaluate (will be quoted)
#'
#' @return The result of evaluating `expr` in the data mask environment
#'
#' @details
#' This function uses the `__mask__` object from the evaluation environment,
#' which provides tidyverse-style data masking for column reference.
#'
#' @keywords internal
#' @examples
#' \dontrun{
#'   with(menv, eval(cyl + am))
#' }
.eval_in_env <- function(expr) {
  expr <- enexpr(expr)

  eval_tidy(expr, env = `__mask__`)  # evaluate each in the data mask
}

#' Helper Functions for Data Environment Evaluation
#'
#' A list of functions that are embedded into the data evaluation environment.
#' These functions have special access to `__data__` and `__mask__` and take
#' precedence over other functions in the evaluation context.
#'
#' Available functions:
#' \describe{
#'   \item{`firstOf(...)`}{Returns logical vector marking first occurrence of each value combination}
#'   \item{`lastOf(...)`}{Returns logical vector marking last occurrence of each value combination}
#'   \item{`get_names(...)`}{Returns character vector of selected column names}
#'   \item{`row_number()`}{Returns integer vector of row numbers}
#'   \item{`every_nth(n)`}{Returns logical vector for every nth row}
#'   \item{`eval(expr)`}{Evaluate expression with tidyverse data masking}
#' }
#'
#' @keywords internal
#' @details
#' These functions are designed to be called from within a data evaluation environment
#' created by `.create_data_env()` or accessed via `.env_eval()`.
#' @noRd 
.env_func_list <- list(
  firstOf    = .eval_firstOf,
  lastOf     = .eval_lastOf,
  get_names  = .eval_get_names,
  row_number = .eval_row_numbers,
  every_nth  = .eval_every_nth,
  eval       = .eval_in_env
)

