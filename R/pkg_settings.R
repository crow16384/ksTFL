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
    footnotePlace       = "repeated",
    isContinues         = FALSE,
    continuousSection   = FALSE,
    contentWidth        = "100%",
    figureWidth         = "6in",
    figureHeight        = "4in",
    figureDevice        = "svg",
    figureScaleMode     = .const_figure_scale_modes[1L],
    
    # Data display defaults
    missings            = .const_default_missing_value,
    autoColWidth        = TRUE,
    minColWidth         = 0.5,  # Minimum relative column width (%) for unlocked columns
    
    # Content
    headers             = .const_options_header_footer,
    footers             = .const_options_header_footer,
    bodyText            = .const_options_bodytext,
    styles              = .const_options_styles,
    
    # Table of Contents
    insertTOC           = FALSE,
    tocTitle            = "Table of Contents",

    # Metadata/Output
    output_directory    = ".",
    meta_directory      = NULL
), class = "TFL_options")


# Initialize current settings to defaults
.options_env$settings <- .options_env$defaults


#' Return the active package options
#'
#' Returns the current session settings for ksTFL as a named list. These are
#' the effective values used when building specs and rendering documents.
#'
#' @details
#' The returned object is the internal settings list stored in the package
#' environment. Modifying the returned object will not change package state;
#' use `tfl_set_options()` to update settings for the current session.
#'
#' @return A named list representing the current ksTFL options.
#'
#' @examples
#' \dontrun{
#' # Inspect all current settings
#' tfl_get_options()
#' }
#'
#' @export
tfl_get_options <- function() {
  return(.options_env$settings)
}

#' Retrieve a single package option
#'
#' Fetch a single named option from the active ksTFL settings. This is a
#' convenience wrapper around `tfl_get_options()` that returns one element or
#' throws a friendly error if the option does not exist.
#'
#' @param name Character(1). Name of the option to fetch. Common options:
#'   `"page"`, `"styles"`, `"footnotePlace"`,
#'   `"isContinues"`, `"contentWidth"`, `"missings"`, `"autoColWidth"`,
#'   `"minColWidth"`, `"insertTOC"`, `"tocTitle"`, `"output_directory"`,
#'   `"meta_directory"`.
#'
#' @return The value associated with `name` (type depends on the option).
#'
#' @examples
#' \dontrun{
#' # Get the current page settings
#' tfl_get_option("page")
#'
#' # Check whether TOC generation is enabled
#' tfl_get_option("insertTOC")
#' tfl_get_option("tocTitle")
#' }
#'
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
#' Update ksTFL session options. This function accepts:
#' \itemize{
#'   \item{Named scalar options (e.g. `contentWidth = "95%"`, `missings = "."`).}
#'   \item{Settings objects produced by helper constructors such as `add_header()`, `add_footer()`, `add_body_text()`, or page objects from `p_page()`.}
#'   \item{A mixture of both named values and settings objects.}
#' }
#'
#' The function tries to intelligently route each supplied object into the
#' appropriate internal settings slot (headers, footers, styles, bodyText, page).
#'
#' @param ... Named arguments OR settings objects returned from helper constructors.
#' \itemize{
#'   \item Named scalar options (e.g. `contentWidth = "95%"`, `missings = "."`).
#'   \item Settings objects produced by helper constructors such as `add_header()`, `add_footer()`, `add_style()`, `add_body_text()`, and `set_page_style(`p_page(`p_margins()`)`)`.
#'   \item A mixture of both named values and settings objects is accepted; the function routes each into the appropriate internal slot.
#' }
#' @param docTemplate Character; name of a predefined bundled template (e.g. `"Default"`,
#'   `"Navy_Pro"`) or a file path to an external template JSON file. When `NULL` (default) the
#'   current session template is left unchanged. Use `tfl_reset_options()` to restore the
#'   built-in default (`"Default"`).
#' @param footnotePlace Character; controls where footnotes are rendered.
#'   One of `"doc_footer"` (place inside the Word footer, below footer rows),
#'   `"repeated"` (place under the table on every page),
#'   or `"last_page"` (place under the table on the last page only).
#'   Default `"repeated"`.
#' @param isContinues Logical; override continuation behavior.
#' @param contentWidth Character; width for content area (e.g. "100%", "95%").
#' @param missings Character; default representation for missing values (e.g. "", ".", "NA", "---").
#'   Default is an empty string ("").
#' @param autoColWidth Logical; enable automatic column width recalculation when user sets `colWidth` via `define_cols()`.
#'   Default TRUE. When TRUE, locked columns maintain exact width while unlocked columns normalize to fill remaining space.
#'   Set FALSE to disable auto-recalculation and manage widths manually.
#' @param minColWidth Numeric; minimum relative column width (%) for unlocked columns during recalculation.
#'   Default 0.5. Used to validate that relative widths don't squeeze columns below acceptable minimum.
#' @param figureWidth Character; default width for figure output (e.g. `"6in"`, `"16cm"`).
#'   Applied when `create_figure()` specs do not specify their own width.
#' @param figureHeight Character; default height for figure output (e.g. `"4in"`, `"10cm"`).
#'   Applied when `create_figure()` specs do not specify their own height.
#' @param figureDevice Character; graphics device used for figure rendering
#'   (e.g. `"png"`, `"pdf"`, `"svg"`). Default depends on system capabilities.
#' @param figureScaleMode Character; how figures are scaled into the page content area.
#'   Typically `"fit"` (scale to fit) or `"exact"` (use exact dimensions).
#' @param insertTOC Logical; when `TRUE` the renderer prepends a Table of Contents
#'   page (using a `{ TOC \f \h \z }` field) before the first spec. Requires at least
#'   one `add_title()` or `add_subtitle()` call with `toclevel` set. Default `FALSE`.
#'   Can be overridden per-render via `save_report(insertTOC = )`.
#' @param tocTitle Character; heading text placed above the TOC field on the TOC page.
#'   Default `"Table of Contents"`. Set to `""` to omit the heading.
#'   Can be overridden per-render via `save_report(tocTitle = )`.
#' @param output_directory Character; path to default output directory of rendered document.
#' @param meta_directory Character; path to default directory for intermediate
#'   metadata (JSON specs, data, and asset files) created during rendering.
#'
#' @return The updated settings list, returned invisibly. Use `tfl_get_options()` to inspect.
#'
#' @examples
#' \dontrun{
#' # Set a named option
#' tfl_set_options(contentWidth = "95%", missings = ".")
#'
#' # Set a predefined bundled template
#' tfl_set_options(docTemplate = "Navy_Pro")
#'
#' # Set an external template file
#' tfl_set_options(docTemplate = "/path/to/my_template.json")
#'
#' # Update page style via helper
#'  tfl_set_options(
#'    set_page_style(page= p_page(
#'    size = "Letter",
#'    orientation = "portrait",
#'    margins = p_margins(top = "1in", bottom = "1in", left = "0.75in", right = "0.75in")
#'  )))
#' 
#' # Add default header and footer via helpers
#' tfl_set_options(
#'   add_header(c("Left Header", "Center Header", "Right Header")),
#'   add_footer(c("Left Footer", "Center Footer", "Right Footer"))
#' )
#' 
#' # Add default body text via helper
#' tfl_set_options(
#'   add_body_text("This is the default body text for all text specs.")
#' )
#' 
#' # Control automatic column width recalculation
#' # Enable auto-recalculation (default):
#' tfl_set_options(autoColWidth = TRUE)
#' spec <- create_table(data) |>
#'   define_cols("id", colWidth = "20%")  # Locks id, others auto-adjust
#'
#' # Disable auto-recalculation for manual width management:
#' tfl_set_options(autoColWidth = FALSE)
#' spec <- create_table(data) |>
#'   define_cols(c("id", "age"), colWidth = c("20%", "30%"))  # Exact widths, no auto-adjust
#'
#' # Enable TOC page for all reports in the session
#' tfl_set_options(insertTOC = TRUE, tocTitle = "List of Tables")
#' # Then mark individual titles/subtitles with toclevel:
#' spec <- create_table(adsl) |>
#'   add_title("Table 1: Demographics", toclevel = 1)
#' # save_report() will now prepend a TOC page automatically.
#' # In Word: click the TOC placeholder and press F9 to populate it.
#' }
#' @export
tfl_set_options <- function(..., docTemplate = NULL,
                         footnotePlace = NULL,
                         isContinues = NULL, contentWidth = NULL, missings = NULL,
                         figureWidth = NULL, figureHeight = NULL,
                         figureDevice = NULL,
                         figureScaleMode = NULL,
                         autoColWidth = NULL, minColWidth = NULL,
                         insertTOC = NULL, tocTitle = NULL,
                         output_directory = NULL, meta_directory = NULL) {

  if (!is.null(docTemplate)) {
    checkmate::assert_string(docTemplate, .var.name = "docTemplate")
    .options_env$settings$doc_style_template <- docTemplate
  }

  params <- as.list(environment())
  params$docTemplate <- NULL
  params <- params[!vapply(params, is.null, logical(1L))]

  figure_params <- params[c("figureWidth", "figureHeight", "figureDevice", "figureScaleMode")]
  figure_params <- figure_params[!vapply(figure_params, is.null, logical(1))]
  params <- params[setdiff(names(params), names(figure_params))]

  for (pname in names(params)) {
    if (pname %in% names(.options_env$settings)) {
      val <- params[[pname]]

      # Type checks for known option names
      if (pname %in% c("isContinues", "autoColWidth", "insertTOC")) {
        checkmate::assert_logical(val, len = 1, any.missing = FALSE, .var.name = pname)
      } else if (pname == "footnotePlace") {
        checkmate::assert_choice(val, choices = c("doc_footer", "repeated", "last_page"), .var.name = pname)
      } else if (pname == "minColWidth") {
        checkmate::assert_numeric(val, len = 1, lower = 0, any.missing = FALSE, .var.name = pname)
      } else if (pname %in% c("doc_style_template", "missings", "tocTitle")) {
        checkmate::assert_character(val, len = 1, any.missing = FALSE, .var.name = pname)
      } else if (pname %in% c("output_directory", "meta_directory")) {
        if (!.is_readable_dir(val)) {
          cli_warn("The specified directory {.var {val}} does not exist or is not writable.")
        }
      } else if (pname %in% c("contentWidth")) {
        .validate_pattern(contentWidth, .const_pattern_content_width,
                      "contentWidth", "tfl_set_options",
                      "Must be like '100%', '6.5in', or '16.51cm'")
      } else if (pname %in% c("figureWidth", "figureHeight")) {
        .validate_pattern(val, .const_pattern_figure_size,
                      pname, "tfl_set_options",
                      "Must be like '70%', '6.5in', '16.51cm', '120pt', or '40mm'")
      } else {
        # Fallback: if a default exists, warn when types differ
        default_val <- .options_env$defaults[[pname]]
        if (!is.null(default_val) && !inherits(val, class(default_val))) {
          cli_warn("Setting {.var {pname}} has unexpected type; expected {.cls {class(default_val)[1]}}")
        }
      }

      .options_env$settings[[pname]] <- val
    } else {
      cli_warn("Unknown setting name: {pname}. Skipping.")
    }
  }

  if (length(figure_params) > 0) {
    if (!is.null(figure_params$figureScaleMode)) {
      checkmate::assert_choice(figure_params$figureScaleMode,
                               choices = .const_figure_scale_modes,
                               .var.name = "figureScaleMode")
    }
    if (!is.null(figure_params$figureDevice)) {
      checkmate::assert_choice(figure_params$figureDevice,
                               choices = .const_figure_devices,
                               .var.name = "figureDevice")
    }
    if (!is.null(figure_params$figureWidth)) {
      .validate_pattern(figure_params$figureWidth, .const_pattern_figure_size,
                        "figureWidth", "tfl_set_options",
                        "Must be like '70%', '6.5in', '16.51cm', '120pt', or '40mm'")
    }
    if (!is.null(figure_params$figureHeight)) {
      .validate_pattern(figure_params$figureHeight, .const_pattern_figure_size,
                        "figureHeight", "tfl_set_options",
                        "Must be like '70%', '6.5in', '16.51cm', '120pt', or '40mm'")
    }

    resolved_mode <- figure_params$figureScaleMode %||% .options_env$settings$figureScaleMode %||% .const_figure_scale_modes[1L]
    resolved_width <- figure_params$figureWidth %||% .options_env$settings$figureWidth
    resolved_height <- figure_params$figureHeight %||% .options_env$settings$figureHeight

    normalized <- .validate_figure_dimension_settings(
      width = resolved_width,
      height = resolved_height,
      figureScaleMode = resolved_mode,
      fn_name = "tfl_set_options",
      default_width = .options_env$defaults$figureWidth %||% "6in",
      default_height = .options_env$defaults$figureHeight %||% "4in"
    )

    if (!is.null(figure_params$figureDevice)) {
      .options_env$settings$figureDevice <- figure_params$figureDevice
    }

    .options_env$settings$figureScaleMode <- normalized$figureScaleMode
    if (normalized$figureScaleMode == .const_figure_scale_modes[1L] &&
        (!is.null(figure_params$figureWidth) || !is.null(figure_params$figureHeight) || !is.null(figure_params$figureScaleMode))) {
      .options_env$settings$figureWidth <- normalized$width
      .options_env$settings$figureHeight <- normalized$height
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
            cli_abort("Multiple {.fn add_body_text} calls detected in tfl_set_options() invocation. Only one default body text is allowed")
          }
          opts$bodyText <- .options_env$settings$bodyText
        } else {
          cli_abort("Function {.fn {as.character(fn)}} is not supported in tfl_set_options()")
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
          if (!is.null(.options_env$settings$page)) {
            class(.options_env$settings$page) <- "TFL_options"
          }
        } 

    }
    
  }
  invisible(.options_env$settings)
}


#' Reset all session options to package defaults
#'
#' Restores all ksTFL session options (headers, footers, body text, styles,
#' page settings, column width behavior, etc.) to their original package
#' defaults. Useful at the start of a new reporting session or after
#' experimenting with `tfl_set_options()`.
#'
#' @return The default options list, returned invisibly.
#' @seealso [tfl_set_options()], [tfl_get_options()], [tfl_get_option()]
#' @export
#' @examples
#' \dontrun{
#' # Set some session defaults
#' tfl_set_options(
#'   add_header("Study ABC", "Phase II", "CONFIDENTIAL"),
#'   add_footer("Company", "Page {PAGE}", "2025")
#' )
#'
#' # ... build tables ...
#'
#' # Reset everything back to package defaults
#' tfl_reset_options()
#' tfl_get_options()  # Confirm reset
#' }
tfl_reset_options <- function() {
  .options_env$settings <- .options_env$defaults
  invisible(.options_env$settings)
}


#' List available bundled templates
#'
#' Returns the names of all template JSON files bundled with the package in
#' `inst/templates/`. These names can be passed directly to
#' `set_page_style(docTemplate = ...)` or `tfl_set_options(docTemplate = ...)`.
#'
#' @return A character vector of template names (without the `.json` extension),
#'   sorted alphabetically.
#'
#' @examples
#' \dontrun{
#' tfl_list_templates()
#' }
#'
#' @export
tfl_list_templates <- function() {
  tmpl_dir <- system.file("templates", package = "ksTFL")
  if (!nzchar(tmpl_dir)) return(character(0L))
  files <- list.files(tmpl_dir, pattern = "\\.json$", full.names = FALSE)
  sort(tools::file_path_sans_ext(files))
}
