## Spec serialization helpers
##
## This module is responsible for preparing and serializing `TFL_report` objects
## into JSON documents that conform to the package JSON schema suitable for the
## C++ renderer.
##


#' Internal: Recursively Remove NULL Values
#'
#' @description Walks through nested list structure and removes all NULL-valued
#' elements. This prevents jsonlite from serializing NULLs as empty objects/arrays.
#'
#' @param x List or atomic value
#'
#' @return List with NULL values removed
#'
#' @keywords internal
#' @noRd
.remove_nulls_recursive <- function(x) {
  if (!is.list(x)) return(x)
  
  # Filter out NULL elements
  x <- x[!vapply(x, is.null, logical(1))]
  
  # Recurse into remaining elements
  x <- lapply(x, .remove_nulls_recursive)
  
  x
}

#' Save TFL Report to JSON with Data Files
#'
#' Serializes a TFL_report object to JSON format along with associated data files
#' (for tables) or figure files (for figures). Validates the report structure,
#' processes each specification by its docType, and writes all outputs to disk.
#'
#' @param report A TFL_report object (output from `create_report()`)
#' @param docFileName Character string. Name of the rendered document file that will be
#'   created by the C++ renderer (e.g., "report.docx"). This value is stored in the
#'   `_metadata/docFileName` property of the exported JSON spec.
#' @param outDir Character string. Output directory where the C++ renderer will save
#'   the rendered document. This path is stored in the `_metadata/outDir` property.
#'   If not provided, defaults to `tfl_get_option("output_directory")`.
#' @param metaPath Character string. Directory where this function will save the JSON spec
#'   and associated data files. If not provided, a temporary directory is created.
#'   Default: `tempdir()`
#' @param prettify Logical. If TRUE, format JSON output with indentation and line breaks
#'   for readability. Default: FALSE (compact format)
#' @param insertTOC Logical. When `TRUE` the renderer prepends a Table of Contents
#'   page (using a `{ TOC \f \h \z }` field) before the first spec. Requires at least
#'   one `add_title()` or `add_subtitle()` call with `toclevel` set. Defaults to
#'   the `insertTOC` package option (see `tfl_set_options()`). Default `FALSE`.
#' @param tocTitle Character. Heading text placed above the TOC field on the TOC page.
#'   Defaults to the `tocTitle` package option (default `"Table of Contents"`).
#'   Set to `""` to omit the heading.
#'
#' @return Invisibly returns a list with:
#'   - `spec_file`: Name of the saved spec JSON file (hash-based filename)
#'   - `datetime`: Timestamp when the report was saved (ISO 8601 format)
#'   - `metaPath`: Directory where files were saved
#'
#' @details
#' The function performs the following steps:
#' \enumerate{
#'   \item Validates input is a TFL_report object
#'   \item Serializes the report using `serialize_spec()` to validate against schema
#'   \item Processes each specification by docType:
#'     \item{Text:} Drops `.metadata` (no additional files needed)
#'     \item{Table:} Extracts data, filters to included columns, saves as JSON
#'     \item{Figure:} Copies image file with original extension preserved
#'   \item Creates `_metadata` section with `outDir` and `docFileName`
#'   \item Serializes the complete fixed object to JSON
#'   \item Returns information about saved files
#' }
#'
#' Error Conditions:
#' - Report class is not TFL_report
#' - Table/Figure spec has `hasData=TRUE` but no actual data available
#' - dataRef has multiple entries (currently only single file references supported)
#' - File I/O errors when writing JSON or copying files
#'
#' @export
#'
#' @examples
#' \dontrun{
#' spec1 <- create_table(mtcars)
#' spec2 <- create_text()
#' report <- create_report(spec1, spec2)
#'
#' # Save with explicit parameters
#' result <- save_report(
#'   report,
#'   docFileName = "report.docx",
#'   outDir = "/output/path",
#'   metaPath = "/meta/path"
#' )
#'
#' # Save with defaults (uses tempdir and tfl_options)
#' result <- save_report(report, docFileName = "report.docx")
#'
#' cat("Spec saved as:", result$spec_file, "\n")
#' cat("Saved to:", result$metaPath, "\n")
#'
#' # Generate a report with an auto-populated TOC page
#' t1 <- create_table(adsl) |>
#'   add_title("Table 1: Demographics", toclevel = 1) |>
#'   set_document(hasData = TRUE)
#'
#' t2 <- create_table(advs) |>
#'   add_title("Table 2: Vital Signs by Visit", toclevel = 1) |>
#'   add_subtitle("#ByGroup1", toclevel = 2) |>
#'   set_document(hasData = TRUE)
#'
#' report <- create_report(t1, t2)
#' save_report(
#'   report,
#'   docFileName  = "tables.docx",
#'   outDir       = "output/",
#'   insertTOC    = TRUE,
#'   tocTitle     = "List of Tables"
#' )
#' # Open tables.docx in Word, click the TOC placeholder, press F9 to populate it.
#' }
save_report <- function(report, docFileName, outDir = NULL, metaPath = NULL, prettify = FALSE,
                        insertTOC = NULL, tocTitle = NULL) {
  
  # ---- Validation ----
  if (!inherits(report, "TFL_report")) {
    cli_abort("Input {.arg report} must be of class TFL_report")
  }
  
  checkmate::assert_character(docFileName, len = 1, any.missing = FALSE, .var.name = "docFileName")
  
  # Set defaults
  if (is.null(outDir)) {
    outDir <- tfl_get_option("output_directory")
  }
  checkmate::assert_character(outDir, len = 1, any.missing = FALSE, .var.name = "outDir")

  if (is.null(insertTOC)) {
    insertTOC <- tfl_get_option("insertTOC")
  }
  checkmate::assert_logical(insertTOC, len = 1, any.missing = FALSE, .var.name = "insertTOC")

  if (is.null(tocTitle)) {
    tocTitle <- tfl_get_option("tocTitle")
  }
  checkmate::assert_character(tocTitle, len = 1, any.missing = FALSE, .var.name = "tocTitle")
  
  # Normalize outDir to full system path
  outDir <- normalizePath(outDir, winslash = "/", mustWork = FALSE)
  
  if (is.null(metaPath)) {
    metaPath <- tempdir()
  }
  checkmate::assert_character(metaPath, len = 1, any.missing = FALSE, .var.name = "metaPath")
  
  # Create metaPath if it doesn't exist
  if (!dir.exists(metaPath)) {
    dir.create(metaPath, recursive = TRUE, showWarnings = FALSE)
  }
  
  # ---- Serialize report to get validated fixed object ----
  serialized <- serialize_spec(report)
  fixed <- serialized$fixed
  
  # ---- Process each spec by docType and handle data/files ----
  for (spec_key in names(fixed)) {
    spec <- fixed[[spec_key]]
    doc_type <- spec$document$docType
    
    if (doc_type == "Table") {
      .save_table_data(spec, metaPath)
    } else if (doc_type == "Figure") {
      .save_figure_file(spec, metaPath)
    }
    # For "Text", no additional processing needed
  }
  
  # ---- Remove .metadata from all specs ----
  for (spec_key in names(fixed)) {
    fixed[[spec_key]]$.metadata <- NULL
  }
  
  # ---- Create _metadata section ----
  now <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
  metadata_section <- list(
    outDir = outDir,
    docFileName = docFileName,
    datetime = now,
    insertTOC = insertTOC,
    tocTitle = tocTitle
  )
  
  # ---- Wrap fixed with _metadata ----
  # Use list() instead of c() to preserve NULL values in nested structures
  final_export <- c(
    list(`_metadata` = metadata_section),
    fixed
  )
  
  # ---- Remove NULL values recursively before JSON serialization ----
  # This prevents jsonlite from serializing NULLs as {} or []
  final_export <- .remove_nulls_recursive(final_export)
  
  # ---- Generate spec filename hash ----
  spec_hash <- .generate_hash(final_export)
  spec_filename <- paste0(spec_hash, ".json")
  spec_filepath <- file.path(metaPath, spec_filename)
  
  # ---- Serialize final export to JSON ----
  # CRITICAL: Use force=TRUE to ensure NULL values serialize as null, not {}
  json_output <- jsonlite::toJSON(
    final_export, 
    auto_unbox = TRUE, 
    pretty = prettify, 
    digits = NA,
    null = "null"
  )
  writeLines(json_output, con = spec_filepath)
  
  # ---- Update _index.json ----
  # Collect dataRefs from all specs for the index
  all_data_refs <- unique(unlist(lapply(names(fixed), function(k) {
    refs <- fixed[[k]][["dataRef"]]
    if (is.null(refs)) character(0) else as.character(unlist(refs))
  })))
  n_specs_in_report <- length(setdiff(names(final_export), "_metadata"))
  .update_spec_index(
    meta_dir   = metaPath,
    spec_file  = spec_filename,
    doc_file   = docFileName,
    datetime   = now,
    n_specs    = n_specs_in_report,
    data_refs  = all_data_refs
  )

  # ---- Return metadata ----
  result <- list(
    spec_file = spec_filename,
    datetime = now,
    metaPath = metaPath
  )
  
  cli_alert_success("Report saved successfully")
  cli_alert_info("Spec file: {spec_filename}")
  cli_alert_info("Data files saved to: {metaPath}")
  
  invisible(result)
}

#' Internal: Save Table Data
#'
#' Extracts table data from spec metadata, filters to included columns,
#' and saves as JSON file.
#'
#' @param spec TFL_spec object with docType="Table"
#' @param metaPath Directory to save data JSON file
#'
#' @keywords internal
#' @noRd
.save_table_data <- function(spec, metaPath) {
  
  # Validate dataRef
  data_ref <- spec$dataRef
  if (is.null(data_ref) || length(data_ref) == 0) {
    if (spec$document$hasData) {
      cli_abort(c(
        "Table spec has {.code hasData=TRUE} but {.code dataRef} is empty",
        x = "Cannot save table data without a dataRef filename"
      ))
    }
    # If hasData=FALSE and no dataRef, skip data saving
    return(invisible(NULL))
  }
  
  # Validate single dataRef entry
  if (length(data_ref) > 1) {
    cli_abort(c(
      "Table spec has multiple dataRef entries",
      x = "Currently only single file references are supported",
      i = "Found {length(data_ref)} entries: {paste(data_ref, collapse=', ')}"
    ))
  }
  
  # Extract data from metadata
  data_env <- spec$.metadata$data_env
  has_data_flag <- isTRUE(spec$document$hasData)
  data_missing  <- is.null(data_env) || is.null(data_env$`__data__`)
  data_empty    <- !data_missing && nrow(data_env$`__data__`) == 0L

  if (data_missing && has_data_flag) {
    cli_abort(c(
      "Table spec has {.code hasData=TRUE} but no data found in metadata",
      x = "Expected data at {.code spec$.metadata$data_env$`__data__`}"
    ))
  }

  # No-data fallback: when hasData=FALSE, data is absent, or data has 0 rows,
  # write an empty JSON payload so the renderer falls back to body text
  # (e.g. the default "No data to report"). Avoids jsonlite errors on
  # vctrs_unspecified columns of skeleton tibbles.
  if (!has_data_flag || data_missing || data_empty) {
    json_output <- jsonlite::toJSON(
      list(),
      pretty = FALSE,
      digits = 8,
      null = NULL,
      na = NULL,
      dataframe = "columns",
      factor = "string"
    )
    data_filepath <- file.path(metaPath, paste0(data_ref, ".json"))
    writeLines(json_output, con = data_filepath)
    return(invisible(NULL))
  }

  # Get full data and filter to report columns
  full_data <- data_env$`__data__`
  report_cols <- spec$.metadata$report_cols
  
  if (is.null(report_cols) || length(report_cols) == 0) {
    # No columns selected, write empty JSON
    filtered_data <- list()
  } else {
    # Filter to columns that exist in both report_cols and full_data
    cols_to_keep <- intersect(report_cols, names(full_data))
    if (length(cols_to_keep) == 0) {
      cli_abort(c(
        "No matching columns found between report definition and data",
        x = "Report columns: {paste(report_cols, collapse=', ')}",
        x = "Data columns: {paste(names(full_data), collapse=', ')}"
      ))
    }
    filtered_data <- full_data[, cols_to_keep, drop = FALSE]
  }
  
  # Drop rownames (they get exported as _row column to JSON, which is not needed)
  rownames(filtered_data) <- NULL
  
  # Serialize data to JSON
  json_output <- jsonlite::toJSON(
    filtered_data,
    pretty = FALSE,
    digits = 8,
    null = NULL,
    na = NULL,
    dataframe = "columns",
    factor = "string"
  )
  
  # Save to file
  data_filepath <- file.path(metaPath, paste0(data_ref, ".json"))
  writeLines(json_output, con = data_filepath)
  
  invisible(NULL)
}

#' Internal: Save Figure File
#'
#' Copies figure file from spec metadata to output directory,
#' preserving the original file extension.
#'
#' @param spec TFL_spec object with docType="Figure"
#' @param metaPath Directory to save figure file
#'
#' @keywords internal
#' @noRd
.save_figure_file <- function(spec, metaPath) {
  
  # Validate dataRef
  data_ref <- spec$dataRef
  if (is.null(data_ref) || length(data_ref) == 0) {
    if (spec$document$hasData) {
      cli_abort(c(
        "Figure spec has {.code hasData=TRUE} but {.code dataRef} is empty",
        x = "Cannot save figure without a dataRef filename"
      ))
    }
    return(invisible(NULL))
  }
  
  # Validate single dataRef entry
  if (length(data_ref) > 1) {
    cli_abort(c(
      "Figure spec has multiple dataRef entries",
      x = "Currently only single file references are supported",
      i = "Found {length(data_ref)} entries: {paste(data_ref, collapse=', ')}"
    ))
  }
  
  # Get source filepath from metadata
  source_filepath <- spec$.metadata$filePath
  if (is.null(source_filepath) || !file.exists(source_filepath)) {
    if (spec$document$hasData) {
      cli_abort(c(
        "Figure spec has {.code hasData=TRUE} but file not found",
        x = "Expected file at: {source_filepath}"
      ))
    }
    return(invisible(NULL))
  }
  
  # Get file extension from source
  file_ext <- tools::file_ext(source_filepath)
  
  # Construct destination filename with extension
  dest_filename <- if (nchar(file_ext) > 0) {
    paste0(data_ref, ".", file_ext)
  } else {
    data_ref
  }
  
  dest_filepath <- file.path(metaPath, dest_filename)
  
  # Copy file
  if (!file.copy(source_filepath, dest_filepath, overwrite = TRUE)) {
    cli_abort(c(
      "Failed to copy figure file to meta folder",
      x = "Source: {.path {source_filepath}}",
      x = "Destination: {.path {dest_filepath}}"
    ))
  }
  
  invisible(NULL)
}


