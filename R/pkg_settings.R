#=============================================================================
# ksTFL/R/pkg_settings.R
# Package settings management for ksTFL
# keeps track of user-configurable settings for the package in a given R session
#=============================================================================

# Environment to store package settings
.options_env <- new.env(parent = emptyenv())


# Initialize default settings
.options_env$defaults <- structure(list(
    # Page settings (template, size, orientation)
    doc_style_template  = .const_default_doc_template,
    page                = .const_options_page, #structure to keep page settings (class TFL_options)
    
    # Document Renderer Defaults
    bodyTitles          = TRUE,
    bodySubtitles       = TRUE,
    bodyFootnotes       = TRUE,
    gluePrefix          = TRUE,
    isContinues         = FALSE,
    contentWidth        = "100%",
    
    # Content
    headers             = .const_options_header_footer,
    footers             = .const_options_header_footer,
    bodyText            = .const_options_bodytext,
    styles              = .const_options_styles,
    
    # Metadata/Output
    output_directory    = '.'
), class = "TFL_options")


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
    cli_abort(c(
      "Unknown option {.arg name} in {.fn tfl_get_option}",
      x = paste0("Unknown option: ", name),
      i = "Use tfl_get_options() to list available option names"
    ))
  }
  return(.options_env$settings[[name]])
}

#' Update the session package settings
#'
#' Provides intelligent detection and routing of settings changes. Accepts either:
#' - Named direct values: `tfl_set_options(bodyTitles = FALSE, contentWidth = "95%")`
#' - Settings objects from functions: `tfl_set_options(add_header(c("Title")))`
#' - Page settings: `tfl_set_options(page = p_page(size = "Letter", orientation = "portrait"))`
#' - Mixed: `tfl_set_options(add_header(...), add_footer(...), page = p_page(...))`
#'
#' @param ... Named arguments OR settings objects returned from add_header(), add_footer(), add_body_text(), or page = p_page(...)
#' @return The updated settings list, returned invisibly.
#' @export
tfl_set_options <- function(..., bodyTitles = NULL, bodySubtitles = NULL,
                         bodyFootnotes = NULL, gluePrefix = NULL,
                         isContinues = NULL, contentWidth = NULL, output_directory='.') {
  
  params <- as.list(environment())
  params <- params[!sapply(params, is.null)]

  for (pname in names(params)) {
    if (pname %in% names(.options_env$settings)) {
      .options_env$settings[[pname]] <- params[[pname]]
    } else {
      cli_warn("Unknown setting name: {pname}. Skipping.")
    }
  }

  args_list <- enquos(...)

  body_texts_cnt <- 0

  for (q in args_list) {

    opts <- structure(list(), class = "TFL_options")
    
    call <- quo_get_expr(q)
    
      if (is_call(call)) {

        fn   <- call[[1]]
        args <- as.list(call)[-1]

        if(as.character(fn)=="add_style") {
          opts$styles <- .options_env$settings$styles
        } else
        if (as.character(fn)=="add_header") {
          opts$headers <- .options_env$settings$headers
        } else
        if(as.character(fn)=="add_footer") {
          opts$footers <- .options_env$settings$footers
        } else
        if (as.character(fn)=="set_page_style") {
          opts$attribs$documentStyle$page <- .options_env$settings$page
          opts$attribs$documentStyle$docTemplate <- .options_env$settings$doc_style_template
          class(opts$attribs$documentStyle) <- "TFL_options"
        } else
        if(as.character(fn)=="add_body_text") {
          body_texts_cnt <- body_texts_cnt + 1
          if (body_texts_cnt > 1) {
            cli_abort("Multiple {.fn add_body_text} calls detected in tfl_set_opts() invocation. Only one default body text is allowed")
          }
          opts$bodyText <- .options_env$settings$bodyText
        } else {
          cli_abort("Function {.fn {as.character(fn)}} is not supported in tfl_set_opts()")
        }
        
        # rebuild call with object as FIRST argument
        new_call <- call2(fn, quote(opts), !!!args)
        
        opts <- eval_bare(new_call,env = env(opts = opts))

        if (inherits(opts, "TFL_options_style") && length(opts) > 0) {
          .options_env$settings$styles <- opts$styles
          class(.options_env$settings$styles) <- "TFL_options"
        } else
        if (inherits(opts, "TFL_options_header") && length(opts) > 0) {
          .options_env$settings$headers <- opts$headers
          class(.options_env$settings$headers) <- "TFL_options"
        } else
        if (inherits(opts, "TFL_options_footer") && length(opts) > 0) {
          .options_env$settings$footers <- opts$footers
          class(.options_env$settings$footers) <- "TFL_options"
        } else
        if (inherits(opts, "TFL_options_bodytext") && length(opts) > 0) {
          .options_env$settings$bodyText <- opts$bodyText
          class(.options_env$settings$bodyText) <- "TFL_options"
        }else
        if (inherits(opts, "TFL_options_pagestyle") && length(opts) > 0) {
          .options_env$settings$page <- opts$attribs$documentStyle$page
          .options_env$settings$doc_style_template <- opts$attribs$documentStyle$docTemplate
          class(.options_env$settings$page) <- "TFL_options"
        } 

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
