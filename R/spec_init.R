#' Initialize a TFL Specification Object
#'
#' Creates and initializes a TFL (Tables, Figures, Listings) specification object
#' for building structured clinical reports. The spec object serves as a container
#' for document metadata, column definitions, styles, and content.
#'
#' @param data A data frame to build the table from. Required when `docType`
#'   is "Table", otherwise must be NULL.
#' @param docType Character. Document type: one of "Table", "Text", or "Figure".
#'   Defaults to "Table".
#' @param cols Tidyselect expression indicating which columns from `data` to include
#'   in the spec. Defaults to `everything()` (all columns).
#' @param docPrefix Optional character string to prefix the document title (e.g., "Table 14.1")
#' @param id Unused parameter (reserved for future use).
#'
#' @return A TFL_spec object ready for further modification with functions like
#'   `add_style()`, `define_cols()`, `add_title()`, etc.
#'
#' @details
#' The initialization process:
#' 1. Creates empty spec structure with default values from package settings
#' 2. Validates document type and data compatibility
#' 3. Auto-selects columns based on tidyselect expression
#' 4. Auto-detects data types and generates format specifications
#' 5. Creates data evaluation environment for expressions
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   # Initialize with no data (for Figure)
#'   spec <- tfl_init()
#'
#'   # Initialize with data for a table
#'   spec <- tfl_init(data = mtcars, docType = "Table")
#'
#'   # Select specific columns
#'   spec <- tfl_init(mtcars, docType = "Table", cols = c(cyl, mpg, hp))
#' }
tfl_init <- function(data = NULL, cols = everything(), docPrefix = NULL, id = NULL, docType = "Table") {
  
  # Validate docType
  docType <- match.arg(docType, c("Table", "Text", "Figure"))
  
  # Initialize empty spec with defaults
  spec <- .const_emty_spec
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
    class(spec) <- c("TFL_spec", "TFL_figure_spec")
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
    class(spec) <- c("TFL_spec", "TFL_text_spec")
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
      isColBreak    = FALSE,
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
  
  settings <- tfl_get_settings()
  
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
  }
  if (is.null(spec$document$bodySubtitles)) {
    spec$document$bodySubtitles <- settings$body_subtitles
  }
  if (is.null(spec$document$bodyFootnotes)) {
    spec$document$bodyFootnotes <- settings$body_footnotes
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
  
  # Initialize other schema properties as empty lists if not present
  schema_keys <- c("headers", "footers", "dataRef", "stubColumns", "columns", 
                   "styleRows", "titles", "subtitles", "footnotes", "bodyText",
                   "styles")
  for (key in schema_keys) {
    if (is.null(spec[[key]])) {
      spec[[key]] <- list()
    }
  }
  
  invisible(spec)
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
            call = expr(tfl_init())
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