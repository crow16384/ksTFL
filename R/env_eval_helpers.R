##initialize a working envir where we can evaluate pre-defined expressions on the data
## data - data.frame to include in the environment
## funcs - named list of functions to include in the environment (these functions will be evaluated in the created environment first)
## @internal
##examples:
## with(menv, row_number())
## with(menv, first(cyl))
## with(menv, eval_tidy(quote(cyl+am), env = `__mask__`))
## with(menv, eval_tidy(quote(row_number() %% 2), env = `__mask__`))
## exp <- expr(firstOf(cyl)); with(menv, eval(!!exp)) #eval is internal env function helper

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



## helper Function to return the data column names/order as named vector using the tidyselect functionality.
## example: .get_data_columns(mtcars, everything())
## example: .get_data_columns(mtcars, c(cyl, mpg))
## example: .get_data_columns(mtcars, cyl, mpg, gear)
## example: .get_data_columns(mtcars, my_cols)  # where my_cols is a variable in the calling environment
## @internal
.get_data_columns <- function(.data, ..., .selenv = NULL, .strict = TRUE) {
  dots <- enquos(..., .named = FALSE)
  
  if (length(dots) == 0) {
    stop("No column expressions provided.", call. = FALSE)
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
      stop("Invalid column selection:\n", conditionMessage(e), call. = FALSE)
    }
  )
}

## return only the names of the selected data columns
## @internal
## example: .get_data_column_names(mtcars, everything())
.get_data_column_names <- function(.data, ..., .selenv=NULL, .strict=T) {
  col_indices <- .get_data_columns(.data, ..., .selenv = .selenv, .strict = .strict)
  names(col_indices)
}

## function to evaluate expression in the data env
##@internal
## example:
## .env_eval(cyl+am)
## exp <- expr(firstOf(cyl)); .env_eval(!!exp)
.env_eval <- function(expr, env=menv) {
  expr <- enexpr(expr)
  eval_tidy(expr, env = env$`__mask__`)
}


############################################################################
# Below are internal functions that will be embedded into the working env to have preceedence over other functions
############################################################################

##functions that attached to data env. returns the logical vector with TRUE at each first change of values of provided variables
##@internal
##example:
##.env_eval(firstOf(cyl))
##.env_eval(firstOf(cyl, am))
.eval_firstOf <- function(..., data=`__data__`) {
  cols <- get_names(...)
  # Extract columns
  m <- data[cols]
  
  if (nrow(m) == 0) return(logical(0))  # empty df
  
  if (nrow(m) == 1) return(TRUE)        # single row
  
  # Compare consecutive rows
  prev <- m[-nrow(m), , drop = FALSE]
  curr <- m[-1, , drop = FALSE]
  
  # Logical vector: TRUE if any column differs OR NA appears
  diff_flag <- apply(
    cbind(prev, curr),
    1,
    function(row) {
      p <- row[1:(length(row)/2)]
      c <- row[(length(row)/2 + 1):length(row)]
      any(is.na(p) | is.na(c) | p != c)
    }
  )
  
  unname(c(TRUE, diff_flag))
}

##functions that attached to data env. returns the logical vector with TRUE at each last change of values of provided variables
##@internal
##example:
##.env_eval(lastOf(cyl))
##.env_eval(lastOf(cyl, am))
.eval_lastOf <- function(..., data=`__data__`) {
  cols <- get_names(...)
  # Extract columns
  m <- data[cols]
  
  if (nrow(m) == 0) return(logical(0))  # empty df
  
  if (nrow(m) == 1) return(TRUE)        # single row
  
  # Compare consecutive rows
  prev <- m[-nrow(m), , drop = FALSE]
  curr <- m[-1, , drop = FALSE]
  
  # Logical vector: TRUE if any column differs OR NA appears
  diff_flag <- apply(
    cbind(prev, curr),
    1,
    function(row) {
      p <- row[1:(length(row)/2)]
      c <- row[(length(row)/2 + 1):length(row)]
      any(is.na(p) | is.na(c) | p != c)
    }
  )

  unname(c(diff_flag, TRUE))
}

##functions that attached to data env. returns the names of the selected data columns
##@internal
##example:
##.env_eval(get_names(cyl, am)) - return c("cyl", "am")
.eval_get_names <- function(..., .data=`__data__`, .selenv=NULL, .strict=T) {
   names(.get_data_columns(.data, ..., .selenv = .selenv, .strict = .strict))
  }

##functions that attached to data env. returns the row numbers of the data
##@internal
##example:
##.env_eval(row_numbers()) - return c(1,2,3,...,nrow(data))
.eval_row_numbers <- function(.data=`__data__`) {
  seq_len(nrow(.data))
}

##functions that attached to data env. returns logical vector with TRUE at every nth row
##@internal
##example:
##.env_eval(every_nth(3)) - return logical vector with TRUE at every 3rd row
.eval_every_nth <- function(n) {
  ((row_numbers() - 1) %% n) == 0
}

##function to evaluate expression in the data env
##@internal
##example:
## with(menv, eval(cyl+am))
.eval_in_env <- function(expr) {
  expr <- enexpr(expr)

  eval_tidy(expr, env = `__mask__`)  # evaluate each in the data mask
}

##list of functions to be included in the data env
##@internal
.env_func_list <- list(
  firstOf    = .eval_firstOf,
  lastOf     = .eval_lastOf,
  get_names  = .eval_get_names,
  row_number = .eval_row_numbers,
  every_nth  = .eval_every_nth,
  eval       = .eval_in_env
)

