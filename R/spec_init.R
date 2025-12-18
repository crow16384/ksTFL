#' Internal: Initialize a TFL Specification Object
#'
#' This internal function creates and initializes a TFL (Tables, Figures,
#' Listings and Text) specification object. It is intended to be called by the
#' public facing wrappers `create_table()`, `create_figure()` and
#' `create_text()`. Users should call the wrappers instead of this function.
#'
#' @param data A data frame to build the table from (for tables), a file path
#'   for figures, or NULL for text documents.
#' @param cols Tidyselect expression indicating which columns from `data` to
#'   include in the spec. Defaults to `everything()` (all columns). This
#'   argument is captured and passed from the public wrappers using
#'   quosures.
#' @param docPrefix Optional character string to prefix the document title
#'   (e.g., "Table 14.1").
#' @param id Unused parameter (reserved for future use).
#' @param docType Character. Document type: one of "Table", "Text", or
#'   "Figure". Defaults to "Table".
#'
#' @return A TFL_spec object.
#'
#' @keywords internal
.tfl_init <- function(data = NULL, cols = everything(), docPrefix = NULL, id = NULL, docType = "Table") {
  
  # Validate docType
  docType <- match.arg(docType, c("Table", "Text", "Figure"))
  
  # Initialize empty spec with defaults
  spec <- .const_empty_spec
  spec <- .fill_spec_defaults(spec)
  
  # Handle Figure docType (no data required)
  if (docType == "Figure") {
    if (is.null(data) || (!is.character(data) && length(data) != 1L)) {
      cli_abort(c(
        "Document type `Figure` requires path to the figure file:",
        x = "data argument is missing or invalid",
        i = "Provide file path in data argument (e.g., data = 'path/to/figure.png')"
      ))
    }
    if (!.is_readable_file(data)) {
      cli_abort(c(
        "Document type `Figure` requires a readable file path:",
        x = "Provided data {.val {data}} is not a valid file path or is not readable"
      ))
    }

    spec$document$docType <- docType
    spec$document$hasData <- FALSE
    spec$document$columns <- NULL
    spec$document$stubColumns <- NULL
    spec$document$dataRef <- list(data)
    class(spec) <- "TFL_spec"
    return(spec)
  }
  
  if (docType == "Text") {
    if (!is.null(data)) {
      cli_abort(c(
        "Document type `Text` does not accept data:",
        x = "Provide data = NULL when docType = {.str Text}",
        i = "Text documents are narrative-only without tabular data"
      ))
    }
    spec$document$docType <- docType
    spec$document$hasData <- FALSE
    spec$document$stubColumns <- NULL
    spec$document$columns <- NULL
    class(spec) <- "TFL_spec"
    return(spec)
  }
  
  # For Table docType, data is required
  if (is.null(data)) {
    cli_abort(c(
      "Document type {.str {docType}} requires a data frame:",
      x = "Provide a data.frame object via the data argument",
      i = "Use docType = {.str Figure} or {.str Text} if no data is needed"
    ))
  }
  
  checkmate::assert_data_frame(data, .var.name = "data")
  
  # Create evaluation environment for expressions
  eval_env <- .create_data_env(data, funcs = .env_func_list)
  
  # Capture and evaluate column selection
  cols_quo <- enquo(cols)
  data_cols <- .get_data_column_names(data, !!cols_quo)
  # Validate selected column names are unique
  checkmate::assert_names(data_cols, type = "unique", .var.name = "selected columns")
  
  # Detect whether data has rows
  has_data <- nrow(data) > 0L
  
  # Initialize column specifications with auto-detected properties
  if(length(data_cols) > 0) columns <- .init_column_specs(data, data_cols) else {
    columns <- list()
    cli_abort(c(
      "No columns selected for the table:",
      x = "The column selection expression returned zero columns",
      i = "Ensure that the data frame has columns and the selection is valid"
    ))
  }
  
  # Set document properties
  spec$document <- list(
    docType = docType,
    hasData = has_data
  )
  
  spec$columns <- columns
  
  # Store metadata for later use (data environment and column mapping)
  spec$.metadata <- list(
    report_cols = data_cols,
    data_env = eval_env
  )
  
  # Add optional docPrefix if provided
  if (!is.null(docPrefix)) {
    checkmate::assert_character(docPrefix, len = 1, .var.name = "docPrefix")
    spec$document$docPrefix <- docPrefix
  }
  
  #class(spec) <- c("TFL_spec", "TFL_table_spec")
  class(spec) <- "TFL_spec"
  spec
}

#' Initialize Column Specifications from Data
#'
#' Creates initial column specification list with auto-detected properties for each
#' data column. Assigns default values and retrieves format specifications.
#'
#' @param data A data frame to extract columns from
#' @param data_cols Character vector of column names to initialize
#'
#' @return List of column specifications, keyed by column name
#'
#' @keywords internal
.init_column_specs <- function(data, data_cols) {
  columns <- list()
  
  for (col_idx in seq_along(data_cols)) {
    col_name <- data_cols[col_idx]
    col_vector <- data[[col_name]]
    
    # Validate column extraction
    if (is.null(col_vector)) {
      cli_abort(c(
        "Failed to extract column {.str {col_name}} from data frame:",
        x = "Column selection may be invalid"
      ))
    }
    
    columns[[col_name]] <- list(
      colOrder      = col_idx,
      label         = .get_col_label(col_vector) %||% col_name,
      isVisible     = TRUE,
      isID          = FALSE,
      isGrouping    = FALSE,
      isPaging      = FALSE,
      labelStyleRef = NULL,
      .isColBreak   = FALSE,
      dedupe        = FALSE,
      blankAfter    = FALSE,
      format        = .get_data_format(col_vector, col_name) %||% NULL
    )
  }
  
  columns
}

#' Fill Specification with Schema-Compliant Defaults
#'
#' Populates a TFL spec object with default values from package settings. Ensures
#' all required top-level structure exists and initializes optional fields as empty lists.
#'
#' @param spec TFL spec object to populate with defaults
#'
#' @return Updated spec object with defaults applied
#'
#' @details
#' Initializes:
#' - Document-level properties (body titles, subtitles, footnotes placement, etc.)
#' - Document style template and references
#' - Schema-defined optional fields as empty lists
#'
#' @keywords internal
.fill_spec_defaults <- function(spec) {
  if (!is.list(spec)) {
    cli_abort("{.arg spec} must be a list in {.fn .fill_spec_defaults}")
  }
  
  settings <- tfl_get_options()
  
  # Ensure required top-level structure exists
  if (is.null(spec$document)) {
    spec$document <- list()
  }
  if (is.null(spec$attribs)) {
    spec$attribs <- list()
  }
  
  # Populate document properties from settings (only schema-defined fields)
  if (is.null(spec$document$bodyTitles)) {
    spec$document$bodyTitles <- settings$body_titles
    spec$document$bodyTitles <- unclass(spec$document$bodyTitles)
  }
  if (is.null(spec$document$bodySubtitles)) {
    spec$document$bodySubtitles <- settings$body_subtitles
    spec$document$bodySubtitles <- unclass(spec$document$bodySubtitles)
  }
  if (is.null(spec$document$bodyFootnotes)) {
    spec$document$bodyFootnotes <- settings$body_footnotes
    spec$document$bodyFootnotes <-  unclass(spec$document$bodyFootnotes)
  }
  if (is.null(spec$document$isContinues)) {
    spec$document$isContinues <- settings$is_continues
  }
  if (is.null(spec$document$contentWidth)) {
    spec$document$contentWidth <- settings$content_width
  }
  
  # Initialize documentStyle structure if needed
  if (is.null(spec$attribs$documentStyle)) {
    spec$attribs$documentStyle <- list(docTemplate = settings$doc_style_template)
  } else if (is.null(spec$attribs$documentStyle$docTemplate)) {
    spec$attribs$documentStyle$docTemplate <- settings$doc_style_template
  }
  
  if (is.null(spec$attribs$styles)) {
    spec$attribs$styles <- settings$styles
    spec$attribs$styles <- unclass(spec$attribs$styles)
  }

  # Initialize other schema properties as empty lists if not present
  schema_keys <- c("headers", "footers", "dataRef", "stubColumns", "columns", 
                   "styleRows", "titles", "subtitles", "footnotes", "bodyText")
  for (key in schema_keys) {
    if (is.null(spec[[key]])) {
      spec[[key]] <- list()
    }
  }
  
  # Apply settings to spec
  # Apply headers from settings
  if (length(settings$headers) > 0) {
    spec$headers <- settings$headers
    spec$headers <- unclass(spec$headers)
  }
  
  # Apply footers from settings
  if (length(settings$footers) > 0) {
    spec$footers <- settings$footers
    spec$footers <- unclass(spec$footers)
  }
  
  # Apply bodyText from settings (including defaults)
  if (length(settings$bodyText) > 0) {
    spec$bodyText <- settings$bodyText
    spec$bodyText <- unclass(spec$bodyText)
  }
  
  # Apply page settings from settings if they exist
  if (!is.null(settings$page)) {
    spec$attribs$documentStyle$page <- settings$page
    spec$attribs$documentStyle$page <- unclass(spec$attribs$documentStyle$page)
  }
  
  invisible(spec)
}

#' Generate Default Body Text ID
#'
#' Creates unique IDs for default body text entries using the __default_NNN pattern.
#' Used internally to track which body text entries are defaults vs user-defined.
#'
#' @param existing_entries List of existing body text entries (to find next available ID)
#'
#' @return Character string like "__default_001", "__default_002", etc.
#'
#' @examples
#' # No existing defaults -> __default_001
#' .generate_default_bodytext_id()
#'
#' # With existing default IDs
#' .generate_default_bodytext_id(list(__default_001 = list(), __default_002 = list()))
#' # -> "__default_003"
#'
#' @keywords internal
.generate_default_bodytext_id <- function(existing_entries = NULL) {
  # Find all existing default IDs
  default_ids <- if (!is.null(existing_entries)) {
    grep(paste0("^", .const_bodytext_default_id_prefix, "_"), 
         names(existing_entries), value = TRUE)
  } else {
    character(0)
  }
  
  # Extract numeric suffixes and find max
  if (length(default_ids) > 0) {
    numbers <- as.numeric(gsub(paste0(.const_bodytext_default_id_prefix, "_"), "", default_ids))
    next_num <- max(numbers, na.rm = TRUE) + 1
  } else {
    next_num <- 1
  }
  
  # Format with leading zeros
  sprintf("%s_%03d", .const_bodytext_default_id_prefix, next_num)
}

#' Extract Column Display Label
#'
#' Retrieves the display label for a data column from its attributes, falling back
#' to NULL if no label is defined or if the label is empty.
#'
#' @param col A data column vector (e.g., data$var1)
#'
#' @return Character string of the column label, or NULL if undefined or empty.
#'   An empty string is treated as NULL.
#'
#' @details
#' Checks for a "label" attribute on the column. Returns the label if it exists and
#' is non-empty; otherwise returns NULL.
#'
#' This function is used during spec initialization to populate column definitions
#' with user-provided labels from the source data.
#'
#' @keywords internal
.get_col_label <- function(col) {
  if (!is.atomic(col) && !is.vector(col)) {
    cli_warn("Input to {.fn .get_col_label} appears to be non-vector type")
  }
  
  label <- attr(col, "label")
  if (is.null(label) || (is.character(label) && nchar(label) == 0L)) {
    return(NULL)
  }
  
  if (!is.character(label)) {
    cli_warn(
      "Column label attribute is not character: {.cls {class(label)}}. ",
      "Treating as NULL."
    )
    return(NULL)
  }
  
  label
}

#' Determine Data Type and Generate Format Specification
#'
#' Inspects a data column and returns a format specification with type and
#' formatting directives based on the column's class. Supports numeric, integer,
#' character, and date types with automatic conversion handling.
#'
#' @param col A data column vector (e.g., data$var1)
#' @param col_name Character string naming the column, used in warning/error messages.
#'   Optional.
#'
#' @return A format specification list created with \code{.col_format_spec()},
#'   containing fields:
#'   - \code{type}: Character ("numeric" or "string")
#'   - \code{format}: Printf-style format string or NULL
#'
#' @details
#' Type detection and format assignment:
#' \itemize{
#'   \item{integer:} type="numeric", format="%d"
#'   \item{double/numeric:} type="numeric", format="%.1f"
#'   \item{character:} type="string", format=NULL
#'   \item{Date/POSIXct/POSIXlt:} type="string" with warning about ISO conversion
#'   \item{Other coercible types:} type="string" with warning about implicit conversion
#'   \item{Non-coercible types:} Raises error with remediation guidance
#' }
#'
#' @keywords internal
.get_data_format <- function(col, col_name = NULL) {
  if (!is.atomic(col) && !is.vector(col)) {
    cli_abort(
      "Expected atomic vector for {.arg col} in {.fn .get_data_format}, ",
      "got {.cls {class(col)[[1]]}}"
    )
  }
  
  col_class <- class(col)[1L]
  col_label <- if (!is.null(col_name) && nchar(col_name) > 0L) {
    paste0(col_name)
  } else {
    ""
  }
  
  switch(col_class,
    "integer" = {
      # Integer type: use %d format for whole numbers
      .col_format_spec(type = "numeric", format = "%d")
    },
    "numeric" =,
    "double" = {
      # Numeric/double type: use %.1f for decimal precision
      .col_format_spec(type = "numeric", format = "%.1f")
    },
    "character" = {
      # Character type: no specific format needed
      .col_format_spec(type = "string", format = NULL)
    },
    "Date" =,
    "POSIXct" =,
    "POSIXlt" = {
      # Date/time types: convert to ISO string with user notice
      cli_warn(
        "Column {.str {col_label}} has class {.cls {col_class}} and will be converted to ISO 8601 date/time {.cls string} format in output."
      )
      .col_format_spec(type = "string", format = NULL)
    },
    # Default: Try to coerce unknown types to character
    {
      .coerce_unknown_type(col, col_name, col_class, col_label)
    }
  )
}

#' Coerce Unknown Column Type to String Format
#'
#' Attempts to coerce a column of unknown type to character format, with
#' warnings and error handling for problematic types.
#'
#' @param col The data column to coerce
#' @param col_name Character name of the column
#' @param col_class Character class of the column
#' @param col_label Formatted label string for error messages
#'
#' @return Format specification list for string type
#'
#' @keywords internal
.coerce_unknown_type <- function(col, col_name, col_class, col_label) {
  call <- caller_env()
  tryCatch(
    {
      # Test coercibility on first non-NA element
      test_idx <- which(!is.na(col))[1L]
      if (!is.na(test_idx)) {
        test_element <- col[[test_idx]]
        
        # Check if element is scalar or atomic (not a list or composite structure)
        if (!is.atomic(test_element) || length(test_element) > 1L) {
          cli_abort(
            c(
              "Cannot format column {.str {col_label}} with class {.cls {col_class}}:",
              x = "Values in this column are not scalar or atomic",
              i = "Supported types: integer, numeric, character, Date, POSIXct, POSIXlt",
              i = "Please convert the column to a supported type before use"
            ),
            call = expr(.tfl_init())
          )
        }
        
        test_char <- as.character(test_element)
      }
      
      cli_warn(
        "Column {.str {col_label}} has unsupported class {.cls {col_class}}. Converting to {.cls string} format."
      )
      .col_format_spec(type = "string", format = NULL)
    },
    error = function(e) {
      cli_abort(
        c(
          "Cannot format column {.str {col_label}} with class {.cls {col_class}}:",
          x = "This type cannot be coerced to character or numeric",
          i = "Supported types: integer, numeric, character, Date, POSIXct, POSIXlt",
          i = "Please convert the column to a supported type before use"
        )
      )
    }
  )
}


#' Create a Text Document Specification
#'
#' Create and initialize a TFL specification for narrative (text) documents.
#' This is a user-facing wrapper around the internal `.tfl_init()` initializer
#' and provides a clear, intention-revealing name for creating text-only
#' specifications. Text documents do not accept `data` and will have
#' `docType = "Text"` set on the resulting spec.
#'
#' @param docPrefix Optional character prefix for the document title.
#' @param id Unused; reserved for future extensions.
#'
#' @return A `TFL_spec` object with `docType = "Text"`.
#'
#' @examples
#' ## Create a simple text spec
#' spec <- create_text()
#'
#' ## With a prefix
#' spec <- create_text(docPrefix = "Text 1.1")
#'
#' @export
create_text <- function(docPrefix = NULL, id = NULL) {
  .tfl_init(data = NULL, cols = everything(), docPrefix = docPrefix, id = id, docType = "Text")
}


#' Create a Table Specification
#'
#' Create and initialize a TFL specification for tabular output. This wrapper
#' captures the tidyselect `cols` expression and forwards it to the internal
#' initializer. Use `create_table()` when you have a data frame that should be
#' rendered as a table.
#'
#' @param data A data frame to build the table from (required).
#' @param cols Tidyselect expression indicating which columns from `data` to
#'   include in the spec. Defaults to `everything()`.
#' @param docPrefix Optional character prefix for the document title.
#' @param id Unused; reserved for future extensions.
#'
#' @return A `TFL_spec` object with `docType = "Table"`.
#'
#' @examples
#' ## Basic usage with the built-in `mtcars` dataset
#' spec <- create_table(mtcars)
#'
#' ## Select specific columns using tidyselect
#' spec <- create_table(mtcars, cols = c(cyl, mpg, hp))
#'
#' ## Or by names
#' spec <- create_table(mtcars, cols = c("cyl", "mpg", "hp"))
#'
#' @export
create_table <- function(data = NULL, cols = everything(), docPrefix = NULL, id = NULL) {
  cols_quo <- enquo(cols)
  .tfl_init(data = data, cols = !!cols_quo, docPrefix = docPrefix, id = id, docType = "Table")
}


#' Create a Figure Specification
#'
#' Create and initialize a TFL specification for embedding a figure file. The
#' `filepath` parameter must be a single character path to a readable file. This
#' wrapper renames the `data` parameter from the internal initializer to
#' `filepath` for clarity.
#'
#' @param filepath Character path to the figure file (required).
#' @param docPrefix Optional character prefix for the document title.
#' @param id Unused; reserved for future extensions.
#'
#' @return A `TFL_spec` object with `docType = "Figure"` and `dataRef` set
#'   to the provided file path.
#'
#' @examples
#' ## Create a figure spec from a local PNG
#' spec <- create_figure("inst/images/example.png")
#'
#' @export
create_figure <- function(filepath, docPrefix = NULL, id = NULL) {
  .tfl_init(data = filepath, cols = everything(), docPrefix = docPrefix, id = id, docType = "Figure")
}
