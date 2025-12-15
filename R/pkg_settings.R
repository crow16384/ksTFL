### Package settings management for ksTFL
### keeps track of user-configurable settings for the package in a given R session


# Environment to store package settings
.options_env <- new.env(parent = emptyenv())


# Initialize default settings
.options_env$defaults <- list(
    spec_schema_file = "spec_schema_v0.json",
    style_schema_file = "styles_schema_v0.json",
    row_style_schema_file = "row_styles_schema_v0.json",
    font = "Arial",
    page_size = "A4",
    page_orientation = "landscape",
    doc_style_template = "KeyStat_default",
    
    # Study Metadata
    protocol_number = character(0),
    study_title = character(0),
    sponsor_name = character(0),
    compound_name = character(0),
    data_cutoff_date = character(0),
    sap_version = character(0),
    
    # Document Defaults
    body_titles = TRUE,
    body_subtitles = TRUE,
    body_footnotes = TRUE,
    glue_prefix = TRUE,
    #default_doc_order = 1,
    is_continues = FALSE,
    content_width = "100%",
    
    # Content
    headers = list(),
    footers = list(),
    #default_styles = NULL,
    
    # Validation
    strict_validation = TRUE,
    verbose_output = FALSE,
    #warn_on_default = TRUE,
    enforce_additional_properties = FALSE,
    
    # Metadata/Output
    output_directory = '.'
)
class(.options_env$defaults) <- "TFL_options"

# Initialize current settings to defaults
.options_env$settings <- .options_env$defaults

#' Return the active package settings
#'
#' @return A named list representing the current ksTFL settings.
#' @export
tfl_get_settings <- function() {
  return(.options_env$settings)
}

#' Retrieve a single package setting
#'
#' @param name Name of the setting to fetch.
#' @return The value associated with `name`.
#' @export
tfl_get_setting <- function(name) {
  if (!name %in% names(.options_env$settings)) {
    stop("Unknown setting: ", name)
  }
  return(.options_env$settings[[name]])
}

#' Update the package settings
#'
#' @param ... Named arguments corresponding to ksTFL settings.
#' @return The updated settings list, returned invisibly.
#' @export
tfl_set_settings <- function(...) {
    ##!TODO: validate settings, e.g., check types, allowed values, etc., plus check that some options like headers/footers are lists and requires special handling, 
    ##      e.g. setting using wrapper functions to add/remove headers/footers
  new_settings <- list(...)

  # Validate names
  valid_names <- names(.options_env$settings)
  invalid_names <- setdiff(names(new_settings), valid_names)

  if (length(invalid_names) > 0) {
    stop("Invalid setting names: ", paste(invalid_names, collapse = ", "))
  }

  # Update settings
  .options_env$settings[names(new_settings)] <- new_settings
  invisible(.options_env$settings)
}

#' Reset settings to their defaults
#'
#' @return The defaults list, returned invisibly.
#' @export
tfl_reset_settings <- function() {
  .options_env$settings <- .options_env$defaults
  invisible(.options_env$settings)
}
