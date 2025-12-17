### Package settings management for ksTFL
### keeps track of user-configurable settings for the package in a given R session


# Environment to store package settings
.options_env <- new.env(parent = emptyenv())


# Initialize default settings
.options_env$defaults <- list(
    
    #font = "Courier New", ##deprecated - should go to page style
    #page_size = "A4", ##deprecated - should go to page style
    #page_orientation = "landscape", ##deprecated - should go to page style
    doc_style_template = .const_default_doc_template,
    page= list(
        size = .const_default_page_size,
        orientation = .const_default_page_orientation
    ),
    
      # Document Defaults
    bodyTitles = TRUE,
    bodySubtitles = TRUE,
    bodyFootnotes = TRUE,
    gluePrefix = TRUE,
    #default_doc_order = 1,
    isContinues = FALSE,
    contentWidth = "100%",
    
    # Content
    headers = list(),
    footers = list(),
    bodyText = list(
        `__default_001` = list(
            text = .const_default_bodytext,
            styleRef = character(0),
            order = .const_default_bodytext_order
        )
    ),
    styles = list(),
    
    
    # Validation -- to be implemented later if required:
    #strict_validation = TRUE,
    #verbose_output = FALSE,
    #warn_on_default = TRUE,
    #enforce_additional_properties = FALSE,
    
    # Metadata/Output
    output_directory = '.'
)
class(.options_env$defaults) <- "TFL_options"

# Initialize current settings to defaults
.options_env$settings <- .options_env$defaults

#' Return the active package options
#'
#' @return A named list representing the current ksTFL options.
#' @export
tfl_get_options <- function() {
  return(.options_env$settings)
}

#' Retrieve a single package option
#'
#' @param name Name of the option to fetch.
#' @return The value associated with `name`.
#' @export
tfl_get_option <- function(name) {
  if (!name %in% names(.options_env$settings)) {
    stop("Unknown option: ", name)
  }
  return(.options_env$settings[[name]])
}

#' Update the package settings
#'
#' Provides intelligent detection and routing of settings changes. Accepts either:
#' - Named direct values: `tfl_set_options(bodyTitles = FALSE, contentWidth = "95%")`
#' - Settings objects from functions: `tfl_set_options(add_header(c("Title")))`
#' - Page settings: `tfl_set_options(page = s_page(size = "Letter", orientation = "portrait"))`
#' - Mixed: `tfl_set_options(add_header(...), add_footer(...), page = s_page(...))`
#'
#' @param ... Named arguments OR settings objects returned from add_header(), add_footer(), add_body_text(), or page = s_page(...)
#' @return The updated settings list, returned invisibly.
#' @export
tfl_set_options <- function(...) {
  args_list <- list(...)
  
  # Separate named settings from detected setting objects
  for (i in seq_along(args_list)) {
    arg <- args_list[[i]]
    arg_name <- names(args_list)[i]
    
    # Check if this is a detected setting object (has special class)
    if (inherits(arg, "tfl_header_setting")) {
      # REPLACE mode for headers - clear previous headers first
      .options_env$settings$headers <- list()
      # Route to add_header.TFL_options()
      # arg is a list of positional arguments (the header parts)
      # Extract level attribute
      level <- attr(arg, "level")
      # Call with unpacked arguments
      .options_env$settings <- do.call(
        "add_header.TFL_options",
        c(list(spec = .options_env$settings, level = level), arg)
      )
    } else if (inherits(arg, "tfl_footer_setting")) {
      # REPLACE mode for footers - clear previous footers first
      .options_env$settings$footers <- list()
      # Route to add_footer.TFL_options()
      # arg is a list of positional arguments (the footer parts)
      level <- attr(arg, "level")
      .options_env$settings <- do.call(
        "add_footer.TFL_options",
        c(list(spec = .options_env$settings, level = level), arg)
      )
    } else if (inherits(arg, "tfl_bodytext_setting")) {
      # Route to add_body_text.TFL_options()
      # arg is a named list: list(text = "...", id = NULL, styleRef = NULL, order = NULL)
      # Remove NULL values to avoid passing them explicitly
      arg_clean <- arg[!sapply(arg, is.null)]
      .options_env$settings <- do.call(
        "add_body_text.TFL_options",
        c(list(spec = .options_env$settings), arg_clean)
      )
    } else if (!is.null(arg_name) && arg_name != "") {
      # Named argument - validate against known settings
      valid_names <- names(.options_env$settings)
      if (!(arg_name %in% valid_names)) {
        # Special handling for page parameter
        if (arg_name == "page") {
          # Accept page objects from s_page() or plain lists
          if (inherits(arg, "tfl_page") || is.list(arg)) {
            .options_env$settings$page <- arg
          } else {
            cli_warn("Page parameter must be created with s_page() or be a list")
          }
        } else {
          cli_warn("Unknown setting name: {arg_name}. Skipping.")
        }
      } else {
        # Direct setting assignment
        .options_env$settings[[arg_name]] <- arg
      }
    } else if (is.null(arg_name) || arg_name == "") {
      # Unnamed argument that is not a special setting object - error
      cli_warn("Unnamed argument {i} is not recognized as a header/footer/bodyText setting")
    }
  }
  
  invisible(.options_env$settings)
}

#' Reset options to their defaults
#'
#' @return The defaults list, returned invisibly.
#' @export
tfl_reset_options <- function() {
  .options_env$settings <- .options_env$defaults
  invisible(.options_env$settings)
}
