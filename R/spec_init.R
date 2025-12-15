
.data_env <- new.env(parent = emptyenv())

#' Initialize a TFL Specification Object
#'
#' Creates and initializes a TFL (Tables, Figures, Listings) specification object
#' for building structured clinical reports. The spec object serves as a container
#' for document metadata, column definitions, styles, and content.
#'
#' @param data A data frame to build the table/listing from. Required when `docType`
#'   is "Table" or "Listing", otherwise must be NULL.
#' @param docType Character. Document type: one of "Table", "Listing", or "Figure".
#'   Defaults to "Table".
#' @param cols Tidyselect expression indicating which columns from `data` to include
#'   in the spec. Defaults to `everything()` (all columns).
#' @param docPrefix Optional character string to prefix the document title (e.g., "Table 14.1")
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
tfl_init <- function(data = NULL, docPrefix = NULL, cols = everything(), docType = 'Table') {
  
  # Validate docType
  docType <- match.arg(docType, c('Table', 'Listing', 'Figure'))
  
  # Initialize empty spec with defaults
  spec <- .const_emty_spec
  spec <- .fill_spec_defaults(spec)
  
  # Handle Figure docType (no data required)
  if (docType == 'Figure') {
    if (!is.null(data)) {
      cli_abort(c(
        "Document type {.str Figure} does not accept data:",
        x = "Provide data = NULL when docType = {.str Figure}",
        i = "Figures are display-only documents without tabular data"
      ))
    }
    spec$document$docType <- docType
    spec$document$hasData <- FALSE
    class(spec) <- "TFL_spec"
    return(spec)
  }
  
  # For Table and Listing, data is required
  if (is.null(data)) {
    cli_abort(c(
      "Document type {.str {docType}} requires a data frame:",
      x = "Provide data argument (a data.frame object)",
      i = "Use docType = {.str Figure} if no data is needed"
    ))
  }
  
  checkmate::assert_data_frame(data, .var.name = "data")
  
  # Create evaluation environment for expressions
  eval_env <- .create_data_env(data, funcs = .env_func_list)
  
  # Capture and evaluate column selection
  cols_quo <- enquo(cols)
  data_cols <- .get_data_column_names(data, !!cols_quo)
  
  # Validate column names
  checkmate::assert_names(data_cols, type = "unique", .var.name = "selected columns")
  
  # Detect hasData based on number of rows
  hasData <- nrow(data) > 0L
  
  # Initialize column specifications with auto-detected properties
  columns <- list()
  for (var in seq_along(data_cols)) {
    col_name <- data_cols[var]
    col_vector <- data[[col_name]]
    
    # Validate column extraction
    if (is.null(col_vector)) {
      cli_abort(c(
        "Failed to extract column {.str {col_name}} from data frame:",
        x = "Column selection may be invalid"
      ))
    }
    
    columns[[col_name]] <- list(
      colOrder = var,
      label = .get_col_label(col_vector) %||% col_name,
      isVisible = TRUE,
      isID = FALSE,
      isGrouping = FALSE,
      isPaging = FALSE,
      labelStyleRef = NULL,
      isColBreak = FALSE,
      dedupe = FALSE,
      blankAfter = FALSE,
      format = .get_data_format(col_vector, col_name) %||% NULL
    )
  }
  
  # Set document properties
  spec$document <- list(
    docType = docType,
    hasData = hasData
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
  
  class(spec) <- "TFL_spec"
  spec
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
  
  # Populate attribs.documentStyle if not set
  if (is.null(spec$attribs$documentStyle)) {
    spec$attribs$documentStyle <- list()
  }
  if (is.null(spec$attribs$documentStyle$docTemplate)) {
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
    paste0(" {.str ", col_name, "}")
  } else {
    ""
  }
  
  # Integer type: use %d format for whole numbers
  if (col_class == "integer") {
    return(.col_format_spec(type = "numeric", format = "%d"))
  }
  
  # Double/numeric type: use %.1f for decimal precision
  if (col_class %in% c("numeric", "double")) {
    return(.col_format_spec(type = "numeric", format = "%.1f"))
  }
  
  # Character type: no specific format needed
  if (col_class == "character") {
    return(.col_format_spec(type = "string", format = NULL))
  }
  
  # Date/time types: convert to ISO string with user notice
  if (col_class %in% c("Date", "POSIXct", "POSIXlt")) {
    cli_warn(
      "Column{col_label} has class {.cls {col_class}} and will be ",
      "converted to ISO 8601 date/time string format in output."
    )
    return(.col_format_spec(type = "string", format = NULL))
  }
  
  # Try to coerce unknown types to character
  tryCatch(
    {
      # Test coercibility on first element
      test_val <- as.character(col[1L])
      
      cli_warn(
        "Column{col_label} has unsupported class {.cls {col_class}}. ",
        "Converting to string format."
      )
      return(.col_format_spec(type = "string", format = NULL))
    },
    error = function(e) {
      cli_abort(
        c(
          "Cannot format column{col_label} with class {.cls {col_class}}:",
          x = "This type cannot be coerced to character or numeric",
          i = "Supported types: integer, numeric, character, Date, POSIXct, POSIXlt",
          i = "Please convert the column to a supported type before use"
        )
      )
    }
  )
}
