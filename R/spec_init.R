
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
tfl_init <- function(data = NULL, cols = everything(), docPrefix = NULL, docType = 'Table') {

  #initialize empty spec structure
  spec <- .const_emty_spec
  class(spec) <- "TFL_spec"


  docType <- match.arg(docType, c('Table', 'Listing', 'Figure'))

  # Handle Figure docType (no data required)
  if (docType == 'Figure') {
    checkmate::assert_null(data, .var.name = "data (must be NULL for Figure docType)")
    
    spec <- .const_emty_spec
    spec$document <- list(docType = 'Figure', hasData = FALSE)
    if (!is.null(docPrefix)) {
      spec$document$docPrefix <- docPrefix
    }
    class(spec) <- "TFL_spec"
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
      label = col_name,  # Auto-populate label from column name
      isVisible = TRUE   # Auto-populate default visibility
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
      report_cols = names(data_cols)
    )
  )
  
  # Add optional docPrefix if provided
  if (!is.null(docPrefix)) {
    checkmate::assert_character(docPrefix, len = 1, .var.name = "docPrefix")
    spec$document$docPrefix <- docPrefix
  }

  spec
}