
.data_env <- new.env(parent = emptyenv())

#' Initializes a `TFL_spec` object for building Tables, Listings, or Figures
#'
#' @param data data.frame to build table/listing from. Required when docType is "Table" or "Listing", else can be NULL
#' @param docType character string indicating the document type. One of "Table", "Listing", "Figure". Optional, can be NULL.
#' @param cols Tidyselect expression indicating which columns from `data` to include in the spec. Defaults to `everything()`.
#' @param docPrefix Optional character string to prefix to the document Title.
#' @return an object of class `TFL_spec`
#' @export
#' @examples
#' spec <- tfl_init() # initialize spec object with no data and docType = "Figure"
#' spec <- tfl_init(data = my_data_frame, docType = "table") # initialize spec object with data for a table
#' spec <- tfl_init(mtcars, cyl:am) 
tfl_init <- function(data = NULL, docPrefix = NULL, cols = everything(), docType = 'Table') {

  #initialize empty spec structure
  spec <- .const_emty_spec
  class(spec) <- "TFL_spec"

  spec <- .fill_spec_defaults(spec)

  docType <- match.arg(docType, c('Table', 'Listing', 'Figure'))

  # Handle Figure docType (no data required)
  if (docType == 'Figure') {
    checkmate::assert_null(data, .var.name = "data (must be NULL for Figure docType)")
    spec$document <- hasData = FALSE
    return(spec)
  }
  
  # For Table and Listing, data is required
  checkmate::assert_data_frame(data, .var.name = "data")
  
  # Capture cols expression without evaluating it
  cols_quo <- enquo(cols)
  
  # Get selected columns using tidyselect
  data_cols <- .get_data_column_names(data, !!cols_quo)
  checkmate::assert_names(data_cols, type = "unique", .var.name = "selected columns")
  
  # Auto-detect hasData if not specified
  if (!is.null(data)) {
    hasData <- nrow(data) > 0
  } else {
    hasData <- FALSE
  }
  
  # Initialize columns structure with colOrder and auto-populated label from column names
  columns <- list()
  for (var in seq_along(data_cols)) {
    col_name <- data_cols[var]
    columns[[col_name]] <- list(
      colOrder = var,
      label = .get_col_label(data[[col_name]]) %||% col_name,  # Use helper to get label or column name
      isVisible = TRUE,   # Auto-populate default visibility
      isID = FALSE,      # Auto-populate default ID status
      isGrouping = FALSE, # Auto-populate default grouping status
      isPaging = FALSE,   # Auto-populate default paging status
      labelStyleRef = NULL, # Placeholder for label style reference
      isColBreak = FALSE,   # Auto-populate default column break status
      dedupe = FALSE,      # Auto-populate default dedupe status
      blankAfter = FALSE,
      format = .get_data_format(data[[col_name]], col_name) %||% NULL      # Auto-detected format
    )
  }
  
   
  # Initialize base TFL spec structure
  spec <- list(
    # Document properties
    document = list(
      docType = docType,
      hasData = hasData
    ),
    
    # Attributes (styling, templates)
    attribs = list(
      documentStyle = list(
        docTemplate = "KeyStat_default",
        styleOverrideID = NULL
      ),
      styles = list(),
      docFormat = "docx"
    ),
    
    # Column definitions
    columns = columns,
    
    # Metadata (internal, not exported to JSON)
    .metadata = list(
      report_cols = data_cols
    )
  )
  
  # Add optional docPrefix if provided
  if (!is.null(docPrefix)) {
    checkmate::assert_character(docPrefix, len = 1, .var.name = "docPrefix")
    spec$document$docPrefix <- docPrefix
  }

  spec
}

#' Fill in spec with schema-compliant defaults
#'
#' Populates spec object with default values from package settings for all
#' schema-defined fields.
#'
#' @param spec TFL spec object to populate with defaults
#'
#' @return Updated spec object with defaults applied
#'
#' @keywords internal
.fill_spec_defaults <- function(spec) {
  
  settings <- get_settings()
  
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
  
  # Initialize other schema properties as empty if not present
  schema_keys <- c("headers", "footers", "dataRef", "stubColumns", "columns", 
                   "styleRows", "titles", "subtitles", "footnotes", "bodyText")
  for (key in schema_keys) {
    if (is.null(spec[[key]])) {
      spec[[key]] <- NULL  # Explicitly null for optional fields
    }
  }
  
  return(spec)
}

#' Get column label or use column name as fallback
#'
#' @param col data column eg data$var1
#' @return The label from column object, or the column name if label is not assigned
#' @keywords internal
.get_col_label <- function(col) {
  
  label <- attr(col, "label")
  if (is.null(label) || label == "") {
    return(NULL)
  }
  return(label)
}

#' Determine data type and generate appropriate format specification
#'
#' Inspects a data column and returns a format specification with appropriate
#' type and format settings based on the column's class.
#'
#' @param col data column (e.g., data$var1)
#' @param col_name Name of the column for informative warnings
#' @return A format specification list created with .col_format_spec()
#'   - integer: type="numeric", format="%d"
#'   - double: type="numeric", format="%.1f"
#'   - character: type="string", format=NULL
#'   - Date/POSIXct/POSIXlt: type="string" with warning about ISO conversion
#'   - other types coercible to character: type="string" with warning
#'   - non-coercible types: abort with error
#' @keywords internal
.get_data_format <- function(col, col_name = NULL) {
  
  # Get the primary class of the column
  col_class <- class(col)[1]
  
  # Try to retrieve column name from the column object
  
  #col_info <- if (!is.null(col_name) && col_name != "") paste0("'{col_name}' ") else ""
  
  # Determine type and format based on column class
  if (col_class == "integer") {
    return(.col_format_spec(type = "numeric", format = "%d"))
  }
  
  if (col_class == "numeric" || col_class == "double") {
    return(.col_format_spec(type = "numeric", format = "%.1f"))
  }
  
  if (col_class == "character") {
    return(.col_format_spec(type = "string", format = NULL))
  }
  
  if (col_class %in% c("Date", "POSIXct", "POSIXlt")) {
    cli::cli_warn(
      "Column '{col_name}' will be converted to ISO string format in report."
    )
    return(.col_format_spec(type = "string", format = NULL))
  }
  
  # Try to coerce other types to character
  tryCatch(
    {
      as.character(col[1])  # Test if coercible
      cli::cli_warn(
        "Column '{col_name}' class '{col_class}' not explicitly supported. Treating as string type."
      )
      return(.col_format_spec(type = "string", format = NULL))
    },
    error = function(e) {
      cli::cli_abort(
        "Column '{col_name}' class '{col_class}' cannot be coerced to character or numeric format. \\
         Please convert to a supported type (numeric, integer, character, or date)."
      )
    }
  )
}
