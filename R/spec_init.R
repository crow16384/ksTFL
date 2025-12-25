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
#' @param docType Character. Document type: one of "Table", "Text", or
#'   "Figure". Defaults to "Table".
#'
#' @return A TFL_spec object.
#'
#' @details
#' The initializer enforces docType-specific rules:
#' \itemize{
#'   \item{Table:} `data` must be a `data.frame` and `cols` selects included columns via tidyselect; the original data is copied into a data environment stored in `spec$.metadata$data_env` for later evaluation (styles/conditions).
#'   \item{Figure:} `data` must be a single file path string pointing to a readable file; no table columns are created.
#'   \item{Text:} `data` must be `NULL`; the spec is created without tabular columns.
#' }
#'
#' @keywords internal
#' @noRd
.fill_spec_defaults <- function(spec) {
  settings <- tfl_get_options()
  
  spec$document$bodyTitles <- unclass(settings$bodyTitles)
  spec$document$bodySubtitles <- unclass(settings$bodySubtitles)
  spec$document$bodyFootnotes <- unclass(settings$bodyFootnotes)
  spec$document$contentWidth <- unclass(settings$contentWidth)
  
  spec
}
  
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
#' @param docType Character. Document type: one of "Table", "Text", or
#'   "Figure". Defaults to "Table".
#'
#' @return A TFL_spec object.
#'
#' @details
#' The initializer enforces docType-specific rules:
#' \itemize{
#'   \item{Table:} `data` must be a `data.frame` and `cols` selects included columns via tidyselect; the original data is copied into a data environment stored in `spec$.metadata$data_env` for later evaluation (styles/conditions).
#'   \item{Figure:} `data` must be a single file path string pointing to a readable file; no table columns are created.
#'   \item{Text:} `data` must be `NULL`; the spec is created without tabular columns.
#' }
#'
#' @keywords internal
#' @noRd
.tfl_init <- function(data = NULL, cols = everything(), docPrefix = NULL, docType = "Table") {
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
    spec$document$docPrefix <- docPrefix
    spec$document$hasData <- FALSE
    spec$columns <- NULL
    spec$stubColumns <- NULL
    spec$.metadata$filePath <- normalizePath(file.path(data), winslash = "/", mustWork = FALSE)
    class(spec) <- "TFL_spec"
    spec$.metadata$hash <- .generate_hash(spec)
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
    spec$document$docPrefix <- docPrefix
    spec$document$hasData <- FALSE
    spec$stubColumns <- NULL
    spec$columns <- NULL
    class(spec) <- "TFL_spec"
    spec$.metadata$hash <- .generate_hash(spec)
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
  if(length(data_cols) > 0) {
    column_specs <- .init_column_specs(data, data_cols)
    columns <- column_specs$columns
    widths_metadata <- column_specs$widths_metadata
  } else {
    columns <- list()
    widths_metadata <- list()
    cli_abort(c(
      "No columns selected for the table:",
      x = "The column selection expression returned zero columns",
      i = "Ensure that the data frame has columns and the selection is valid"
    ))
  }
  
  docprops <- list(
    docType = docType,
    hasData = has_data,
    docPrefix = docPrefix
  )
  # Set document properties
  spec$document <- .merge_recursive(spec$document, docprops)
  
  spec$columns <- columns
  
  # Store metadata for later use (data environment, column mapping, width metadata, and rowstyle actions)
  spec$.metadata <- list(
    report_cols = data_cols,
    data_env = eval_env,
    colWidths = widths_metadata,
    compute_cols = list()  # Initialize for compute_cols() calls
  )
  
  # Add optional docPrefix if provided
  if (!is.null(docPrefix)) {
    checkmate::assert_character(docPrefix, len = 1, .var.name = "docPrefix")
    spec$document$docPrefix <- docPrefix
  }
  
  #class(spec) <- c("TFL_spec", "TFL_table_spec")
  class(spec) <- "TFL_spec"
  spec$.metadata$hash <- .generate_hash(spec)
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
#' @noRd
.init_column_specs <- function(data, data_cols) {
  columns <- list()
  
  # Get current missings value from options
  missings_value <- tfl_get_option("missings")
  layout_result <- .guess_table_layout(data[names(data) %in% data_cols], missings = missings_value)
  
  # Extract formats and metadata from the result
  formats <- layout_result$formats
  widths_metadata <- layout_result$metadata

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
      format        = formats[[col_name]] %||% NULL
    )
  }
  
  # Return columns and metadata for storage in spec$.metadata$colWidths
  list(
    columns = columns,
    widths_metadata = widths_metadata
  )
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
#' @noRd
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
    spec$document$isContinues <- settings$isContinues
  }
  if (is.null(spec$document$contentWidth)) {
    spec$document$contentWidth <- settings$contentWidth
  }
  if (is.null(spec$document$gluePrefix)) {
    spec$document$gluePrefix <- settings$gluePrefix
  }
  if (is.null(spec$document$bodyTitles)) {
    spec$document$bodyTitles <- settings$bodyTitles
  } 
  if (is.null(spec$document$bodySubtitles)) {
    spec$document$bodySubtitles <- settings$bodySubtitles
  }
  if (is.null(spec$document$bodyFootnotes)) {
    spec$document$bodyFootnotes <- settings$bodyFootnotes
  }
  if (is.null(spec$document$contentWidth)) {
    spec$document$contentWidth <- settings$contentWidth
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
#' \dontrun{
#' # No existing defaults -> `__default_001`
#' .generate_default_bodytext_id()
#'
#' # With existing default IDs
#' .generate_default_bodytext_id(list(`__default_001` = list(), `__default_002` = list()))
#' # -> "__default_003"
#' }
#' @keywords internal
#' @noRd
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
#' @noRd
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
#' @noRd
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
#'
#' @return A `TFL_spec` object with `docType = "Text"`.
#'
#' @examples
#' \dontrun{
#' ## Create a simple text spec
#' spec <- create_text()
#'
#' ## With a prefix
#' spec <- create_text(docPrefix = "Narrative 1.1")
#' }
#'
#' @export
create_text <- function(docPrefix = NULL) {
  .tfl_init(data = NULL, cols = everything(), docPrefix = docPrefix, docType = "Text")
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
#'   include in the report. Defaults to `everything()`.
#' @param docPrefix Optional character prefix for the document title. E.g. "Table 14.1". If provided will be prepended to the document title by `gluePrefix` logic (see `tfl_options`).
#'
#' @return A `TFL_spec` object with `docType = "Table"`.
#'
#' @details
#' Column Width Initialization:
#' Initial column widths are automatically calculated based on data values and their types and sum to 100%.
#' To lock specific columns and trigger automatic recalculation of others, use `define_cols()` with
#' the `colWidth` parameter (when `autoColWidth = TRUE` in the tfl_options, the default).
#' 
#' Example workflow:
#' \itemize{
#'   \item Create table: widths auto-distributed 
#'   \item `define_cols(id, colWidth="20%")`: locks id at 20%, others recalculated to fill 80% keeping intially detected proportions
#'   \item `define_cols(age, colWidth="2cm")`: locks age at fixed 2cm width, other relative columns recalculated to fill remaining space
#' }
#'
#' @export
#' @examples
#' \dontrun{
#' ## Basic usage with the built-in `mtcars` dataset
#' spec <- create_table(mtcars)
#'
#' ## Select specific columns using tidyselect
#' spec <- create_table(mtcars, cols = c(cyl, mpg, hp))
#' 
#' ## or using ranges:
#' spec <- create_table(mtcars, cyl:hp)
#'
#' ## or by excluding columns
#' spec <- create_table(mtcars, cols = -c(gear, carb))
#' 
#' ## or simple by names
#' spec <- create_table(mtcars, cols = c("cyl", "mpg", "hp"))
#' }
#'
create_table <- function(data = NULL, cols = everything(), docPrefix = NULL) {
  cols_quo <- enquo(cols)
  .tfl_init(data = data, cols = !!cols_quo, docPrefix = docPrefix, docType = "Table")
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
#'
#' @return A `TFL_spec` object with `docType = "Figure"` and `dataRef` set
#'   to the provided file path.
#'
#' @export
#' @examples
#' \dontrun{
#' ## Create a figure spec from a local PNG
#' spec <- create_figure("inst/images/example.png")
#' }
#'

create_figure <- function(filepath, docPrefix = NULL) {
  .tfl_init(data = filepath, cols = everything(), docPrefix = docPrefix, docType = "Figure")
}
