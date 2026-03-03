#============================================================================= 
# ksTFL/R/spec_context.R
# Utilities for managing spec-schema function call contexts during TFL spec building
#=============================================================================

#' @importFrom rlang enquos enquo call2 quo_get_expr call_name call_args eval_tidy is_call call2 env eval_bare
#' @importFrom jsonlite toJSON
#' @importFrom utils modifyList
#' @importFrom checkmate assert_class assert_string assert_character assert_list
#' @importFrom cli cli_abort cli_warn cli_alert_success
#' @importFrom purrr map_chr
NULL

# Package-local context marker environment (fallback for promise-evaluated helpers)
.context_marker_env <- new.env(parent = emptyenv())
# initialize stack
assign("stack", character(0), envir = .context_marker_env)

# ============================================================
# PART 1: CORE UTILITIES
# ============================================================


#' Auto-Generate Next Stub Order
#'
#' Calculates the next available stub column order number based on existing stubs.
#'
#' @param existing_stubs List. List of existing stub column specifications
#'
#' @return Integer. Next available stub order (minimum 1)
#'
#' @keywords internal
#' @noRd
.auto_stub_order <- function(existing_stubs) {
  if (length(existing_stubs) == 0) {
    return(1L)
  }
  
  existing_orders <- sapply(existing_stubs, function(x) x$stubOrder, USE.NAMES = FALSE)
  
  if (length(existing_orders) == 0) {
    return(1L)
  }
  
  if (any(!is.numeric(existing_orders))) {
    cli_abort("Internal error: all stubOrder values must be numeric in {.fn .auto_stub_order}")
  }
  
  max(existing_orders, na.rm = TRUE) + 1L
}

#' Set context marker in environment
#' 
#' @param env Environment to set context in
#' @param context Context name
#' @keywords internal
#' @noRd
.set_context <- function(env, context) {
  assign(".__tfl_context__", context, envir = env)
  # Push context onto package-local stack for fallback detection
  stack <- get("stack", envir = .context_marker_env)
  assign("stack", c(stack, context), envir = .context_marker_env)
  invisible(NULL)
}

#' Clear context marker from environment
#' 
#' @param env Environment to clear context from
#' @keywords internal
#' @noRd
.clear_context <- function(env) {
  if (exists(".__tfl_context__", envir = env, inherits = FALSE)) {
    remove(".__tfl_context__", envir = env)
  }
  # Pop package-local stack (if non-empty)
  stack <- get("stack", envir = .context_marker_env)
  if (length(stack) > 0) {
    assign("stack", utils::head(stack, -1), envir = .context_marker_env)
  }
  invisible(NULL)
}

#' Assert function is used in correct context
#' 
#' Robustly traverses up the calling environment chain to detect the context marker.
#' 
#' @param allowed_contexts Character vector of allowed contexts
#' @param fn_name Name of the function being called
#' @keywords internal
#' @noRd
.assert_context <- function(allowed_contexts, fn_name) {
  # Traverse up the parent frames to find the context marker
  depth <- 0
  max_depth <- 20  # should be sufficient for typical nesting
  current <- NULL
  env <- parent.frame()
  while (!is.null(env) && depth <= max_depth) {
    if (exists(".__tfl_context__", envir = env, inherits = FALSE)) {
      current <- get(".__tfl_context__", envir = env, inherits = FALSE)
      break
    }
    depth <- depth + 1
    env <- parent.frame(depth)
  }
  
  if (!is.null(current)) {
    if (!current %in% allowed_contexts) {
      cli_abort(c(
        "{.fn {fn_name}} can only be used inside:",
        paste0("* {.fn ", allowed_contexts, "}")
      ))
    }
    return(invisible(TRUE))
  }

  # Fallback: if no context found in the call frames, check the package-local stack
  stack <- get("stack", envir = .context_marker_env)
  if (length(stack) > 0 && any(stack %in% allowed_contexts)) {
    return(invisible(TRUE))
  }
  
  # If we get here, no context was found
  if (length(allowed_contexts) == 1) {
    cli_abort(c(
      "{.fn {fn_name}} can only be used inside {.fn {allowed_contexts}}",
      x = "No TFL spec building context detected"
    ))
  } else {
    cli_abort(c(
      "{.fn {fn_name}} can only be used inside:",
      paste0("* {.fn ", allowed_contexts, "}"),
      x = "No TFL spec building context detected"
    ))
  }
}

# ============================================================
# PART 2: SCHEMA VALIDATION
# ============================================================

# Cache environment for schema properties
.schema_cache_env <- new.env(parent = emptyenv())

#' Get allowed properties for a schema path
#' 
#' @param type Type of schema element
#' @return Character vector of allowed properties
#' @keywords internal
#' @noRd
.get_allowed_properties <- function(type) {
  # Initialize cache if not exists
  if (!exists("cache", envir = .schema_cache_env)) {
    assign("cache", .const_schema_properties, envir = .schema_cache_env)
  }
  
  get("cache", envir = .schema_cache_env)[[type]] %||% character(0)
}

#' Validate Parameters Against Allowed Schema Properties
#'
#' Checks that all provided parameters exist in the allowed properties for a schema element.
#' Generates detailed error messages with suggestions if invalid parameters are found.
#'
#' @param params Named list of parameters to validate
#' @param type Character. Type of schema element (e.g., "font", "paragraph", "column")
#' @param fn_name Character. Name of the function calling this validation (for error messages)
#'
#' @return Invisibly NULL if validation passes. Aborts with error if invalid parameters found.
#'
#' @keywords internal
#' @noRd
.validate_params <- function(params, type, fn_name) {
  if (!is.list(params)) {
    cli_abort("{.arg params} must be a list in {.fn {fn_name}}")
  }
  
  if (!is.character(type) || length(type) != 1) {
    cli_abort("Internal error: {.arg type} must be a single character string in {.fn {fn_name}}")
  }
  
  allowed <- .get_allowed_properties(type)
  
  if (length(allowed) == 0) {
    cli_abort("Unknown schema type {.str {type}} in {.fn {fn_name}}")
  }
  
  provided <- names(params)
  invalid <- setdiff(provided, allowed)
  
  if (length(invalid) > 0) {
    cli_abort(c(
      "Invalid parameter{?s} in {.fn {fn_name}}:",
      x = paste0("{.arg ", invalid, "}", collapse = ", "),
      i = paste("Allowed:", paste0("{.arg ", allowed, "}", collapse = ", "))
    ))
  }
  
  invisible(NULL)
}

#' Centralized Validation Wrapper
#'
#' @description Convenience wrapper for .validate_params that extracts
#' context from the calling function automatically. Reduces boilerplate
#' in functions that follow standard parameter validation patterns.
#'
#' @param params Named list of parameters to validate
#' @param type Character. Type of schema element (e.g., "font", "paragraph")
#' @param fn_name Optional character. Function name (auto-detected if NULL)
#'
#' @return Invisibly NULL if validation passes
#'
#' @keywords internal
#' @noRd
.validate <- function(params, type, fn_name = NULL) {
  if (is.null(fn_name)) {
    # Auto-detect calling function name
    fn_name <- as.character(sys.call(-1)[[1]])
  }
  .validate_params(params, type, fn_name)
}

#' Validate Required Parameters
#'
#' Checks that all required parameters are present in the provided parameter list.
#'
#' @param params Named list of parameters  
#' @param required_fields Character vector of required field names
#' @param fn_name Character. Name of the function calling this validation
#'
#' @return Invisibly NULL if validation passes. Aborts with error if required fields missing.
#'
#' @keywords internal
#' @noRd
.validate_required <- function(params, required_fields, fn_name) {
  if (!is.list(params)) {
    cli_abort("{.arg params} must be a list in {.fn {fn_name}}")
  }
  
  if (!is.character(required_fields) || length(required_fields) == 0) {
    cli_abort("Internal error: {.arg required_fields} must be a non-empty character vector")
  }
  
  missing <- setdiff(required_fields, names(params))
  if (length(missing) > 0) {
    cli_abort(c(
      "Missing required parameter{?s} in {.fn {fn_name}}:",
      x = paste0("{.arg ", missing, "}", collapse = ", ")
    ))
  }
  
  invisible(NULL)
}

#' Validate Enum Value
#'
#' Checks that a value belongs to a set of allowed enumeration values.
#'
#' @param value The value to validate (can be NULL, which is allowed)
#' @param allowed Character vector of allowed values
#' @param param_name Character. Name of the parameter (for error messages)
#' @param fn_name Character. Name of the function being validated
#'
#' @return Invisibly NULL. Aborts with error if value not in allowed set.
#'
#' @keywords internal
#' @noRd
.validate_enum <- function(value, allowed, param_name, fn_name) {
  if (is.null(value)) {
    return(invisible(NULL))
  }
  
  if (!is.character(allowed) || length(allowed) == 0) {
    cli_abort("Internal error: {.arg allowed} must be non-empty character vector")
  }
  
  if (!value %in% allowed) {
    cli_abort(c(
      "Invalid value for {.arg {param_name}} in {.fn {fn_name}}:",
      x = paste0("Got: {.str {value}}"),
      i = paste("Allowed:", paste("{.str {allowed}}", collapse = ", "))
    ))
  }
  
  invisible(NULL)
}

#' Validate Pattern Match
#'
#' Checks that a value matches a regular expression pattern. Useful for validating
#' format strings and codes.
#'
#' @param value Character value to validate (can be NULL)
#' @param pattern Character. Regular expression pattern
#' @param param_name Character. Name of the parameter (for error messages)
#' @param fn_name Character. Name of the function being validated
#' @param description Character. Optional description of expected format
#'
#' @return Invisibly NULL. Aborts with error if value doesn't match pattern.
#'
#' @keywords internal
#' @noRd
.validate_pattern <- function(value, pattern, param_name, fn_name, description = NULL) {
  if (is.null(value)) {
    return(invisible(NULL))
  }
  
  if (!is.character(value) || length(value) != 1) {
    cli_abort("{.arg {param_name}} must be a single character string in {.fn {fn_name}}")
  }
  
  if (!is.character(pattern) || length(pattern) != 1) {
    cli_abort("Internal error: {.arg pattern} must be a single character string")
  }
  
  if (!grepl(pattern, value, perl = TRUE)) {
    msg <- c(
      "Invalid format for {.arg {param_name}} in {.fn {fn_name}}:",
      x = paste0("Got: {.str {value}}")
    )
    if (!is.null(description)) {
      msg <- c(msg, i = description)
    }
    cli_abort(msg)
  }
  
  invisible(NULL)
}

#' Validate Color Value
#'
#' Checks that a color value is either a valid hex code or a predefined color name.
#' Color names are case-insensitive.
#'
#' @param value Character value to validate (can be NULL)
#' @param param_name Character. Name of the parameter (for error messages)
#' @param fn_name Character. Name of the function being validated
#' @param description Character. Optional description of expected format
#'
#' @return Invisibly NULL. Aborts with error if value doesn't match pattern or isn't a valid color name.
#'
#' @keywords internal
#' @noRd
.validate_color <- function(value, param_name, fn_name, description = NULL) {
  if (is.null(value)) {
    return(invisible(NULL))
  }
  
  if (!is.character(value) || length(value) != 1) {
    cli_abort("{.arg {param_name}} must be a single character string in {.fn {fn_name}}")
  }
  
  # Check if it's a hex code
  if (grepl(.const_pattern_hex_color, value, perl = TRUE)) {
    return(invisible(NULL))
  }
  
  color_names <- names(.const_color_hex_map)
  
  # Check if it's a predefined color name (case-insensitive)
  if (tolower(value) %in% tolower(color_names)) {
    return(invisible(NULL))
  }
  
  # If we get here, it's invalid
  msg <- c(
    "Invalid color value for {.arg {param_name}} in {.fn {fn_name}}:",
    x = paste0("Got: {.str {value}}"),
    i = "Must be a hex code (e.g., '#FF0000') or a predefined color name",
    i = paste("Predefined colors:", paste(color_names[1:min(15, length(color_names))], collapse = ", "), "...")
  )
  if (!is.null(description)) {
    msg <- c(msg, i = description)
  }
  cli_abort(msg)
}

#' Normalize Color Value to Hex Code
#'
#' Converts a color value to hex code format for storage in the spec.
#' If the value is a color name, converts it to the corresponding hex code.
#' If the value is already a hex code, returns it unchanged.
#' If the value is NULL, returns NULL.
#'
#' @param color Character. Color value as hex code or color name (case-insensitive)
#'
#' @return Character. Hex code color value (e.g., "#FF0000"), or NULL if input is NULL
#'
#' @details
#' This function should be called on color values before storing them in the spec
#' to ensure consistent hex code storage regardless of input format.
#'
#' @keywords internal
#' @noRd
.normalize_color <- function(color) {
  if (is.null(color)) {
    return(NULL)
  }
  
  # Check if it's already a hex code
  if (grepl(.const_pattern_hex_color, color, perl = TRUE)) {
    return(color)
  }
  
  # Try to match as color name (case-insensitive)
  color_lower <- tolower(color)
  color_idx <- match(color_lower, tolower(names(.const_color_hex_map)))
  
  if (!is.na(color_idx)) {
    return(.const_color_hex_map[[color_idx]])
  }
  
  # Should not reach here if validation was done before calling this
  cli_abort(c(
    "Invalid color value {.str {color}} in {.fn .normalize_color}:",
    i = "This should have been caught by .validate_color() validation"
  ))
}


# ============================================================
# PART 3: REUSABLE SPEC BUILDERS (Internal, can be reused)
# ============================================================

#' Internal Font Specification Builder
#'
#' Constructs and validates a font specification list.
#'
#' @param font_name Character. Font family name (Arial, Courier New, Times New Roman, Calibri)
#' @param font_size Character. Font size with units (e.g., "12pt")
#' @param bold Logical. Whether text should be bold
#' @param italic Logical. Whether text should be italic
#' @param underline Logical. Whether text should be underlined
#' @param color Character. Text color as hex code (e.g., "#000000") or color name (e.g., "red", "blue")
#' @param highlight Character. Background highlight color as hex code or color name
#'
#' @return List with validated font properties (NULL values excluded)
#'
#' @keywords internal
#' @noRd
.font_spec <- function(font_name = NULL, font_size = NULL, bold = NULL, 
                       italic = NULL, underline = NULL, color = NULL, 
                       highlight = NULL) {
  params <- as.list(environment())
  params <- params[!sapply(params, is.null)]
  
  # Validate font_name enum
  if (!is.null(font_name)) {
    .validate_enum(font_name, .const_font_names, "font_name", ".font_spec")
  }
  
  # Validate font_size pattern (e.g., "12pt", "11.5pt")
  if (!is.null(font_size)) {
    .validate_pattern(font_size, .const_pattern_font_size, 
                      "font_size", ".font_spec", "Must be like '12pt'")
  }
  
  # Validate and normalize color values (hex codes or color names)
  if (!is.null(color)) {
    .validate_color(color, "color", ".font_spec", 
                    "Must be hex code (e.g., '#000000') or color name (e.g., 'red', 'blue')")
    params$color <- .normalize_color(color)
  }
  
  if (!is.null(highlight)) {
    .validate_color(highlight, "highlight", ".font_spec",
                    "Must be hex code (e.g., '#FFFF00') or color name (e.g., 'yellow', 'red')")
    params$highlight <- .normalize_color(highlight)
  }
  
  # Validate logical flags
  if (!is.null(bold) && !is.logical(bold)) {
    cli_abort("{.arg bold} must be logical (TRUE/FALSE) in {.fn .font_spec}")
  }
  if (!is.null(italic) && !is.logical(italic)) {
    cli_abort("{.arg italic} must be logical (TRUE/FALSE) in {.fn .font_spec}")
  }
  if (!is.null(underline) && !is.logical(underline)) {
    cli_abort("{.arg underline} must be logical (TRUE/FALSE) in {.fn .font_spec}")
  }
  
  params
}

#' Internal Spacing Specification Builder
#'
#' Constructs and validates spacing parameters for paragraphs.
#'
#' @param before Character. Space before paragraph (e.g., "12pt")
#' @param after Character. Space after paragraph (e.g., "6pt")
#' @param line_spacing Numeric. Line spacing multiplier (minimum 1)
#'
#' @return List with validated spacing properties (NULL values excluded)
#'
#' @keywords internal
#' @noRd
.spacing_spec <- function(before = NULL, after = NULL, line_spacing = NULL) {
  params <- as.list(environment())
  params <- params[!sapply(params, is.null)]
  
  # Validate spacing values
  if (!is.null(before)) {
    .validate_pattern(before, .const_pattern_spacing, 
                      "before", ".spacing_spec", "Must be like '12pt', '10mm'")
  }
  
  if (!is.null(after)) {
    .validate_pattern(after, .const_pattern_spacing, 
                      "after", ".spacing_spec", "Must be like '6pt', '10mm'")
  }
  
  # Validate line_spacing as numeric >= 1
  if (!is.null(line_spacing)) {
    if (!is.numeric(line_spacing) || length(line_spacing) != 1) {
      cli_abort("{.arg line_spacing} must be a single numeric value in {.fn .spacing_spec}")
    }
    if (line_spacing < .const_min_line_spacing) {
      cli_abort(c(
        "{.arg line_spacing} must be >= {.const_min_line_spacing} in {.fn .spacing_spec}:",
        x = paste("Got:", line_spacing)
      ))
    }
  }
  
  params
}

#' Internal indents specification builder
#' 
#' @param left Left indent
#' @param right Right indent
#' @param first_line First line indent
#' @return Indents specification list
#' @keywords internal
#' @noRd
.indents_spec <- function(left = NULL, right = NULL, first_line = NULL) {
  params <- as.list(environment())
  params <- params[!sapply(params, is.null)]
  
  if (!is.null(left)) {
    .validate_pattern(left, .const_pattern_indents, "left", "indents_spec",
                      "Must be like '10mm', '0.5in', '2.54cm', or '36pt'")
  }
  if (!is.null(right)) {
    .validate_pattern(right, .const_pattern_indents, "right", "indents_spec",
                      "Must be like '10mm', '0.5in', '2.54cm', or '36pt'")
  }
  if (!is.null(first_line)) {
    .validate_pattern(first_line, .const_pattern_indents, "first_line", "indents_spec",
                      "Must be like '10mm', '0.5in', '2.54cm', or '36pt' (negative for hanging indent)")
  }
  
  params
}

#' Internal paragraph specification builder
#' 
#' @param alignment Text alignment
#' @param spacing Spacing specification
#' @param indents Indents specification
#' @param word_style Base Word style
#' @return Paragraph specification list
#' @keywords internal
#' @noRd
.paragraph_spec <- function(alignment = NULL, spacing = NULL, indents = NULL, 
                            word_style = NULL) {
  params <- list()
  
  if (!is.null(alignment)) {
    .validate_enum(alignment, .const_alignment_values, "alignment", "paragraph_spec")
    params$alignment <- alignment
  }
  
  if (!is.null(word_style)) {
    .validate_enum(word_style, .const_word_styles, "word_style", "paragraph_spec")
    params$word_style <- word_style
  }
  
  if (!is.null(spacing)) {
    # Enforce only tfl_spacing-derived objects or exact shape lists
    if (inherits(spacing, "tfl_spacing")) {
      params$spacing <- unclass(spacing)
    } else if (is.list(spacing)) {
      .validate_params(spacing, "spacing", "s_paragraph")
      params$spacing <- spacing
    } else {
      cli_abort(c(
        "{.fn s_paragraph} requires {.arg spacing} created by {.fn s_spacing} or a list with keys: ",
        paste0("{.arg ", .get_allowed_properties("spacing"), "}", collapse = ", ")
      ))
    }
  }
  
  if (!is.null(indents)) {
    if (inherits(indents, "tfl_indents")) {
      params$indents <- unclass(indents)
    } else if (is.list(indents)) {
      .validate_params(indents, "indents", "s_paragraph")
      params$indents <- indents
    } else {
      cli_abort(c(
        "{.fn s_paragraph} requires {.arg indents} created by {.fn s_indents} or a list with keys: ",
        paste0("{.arg ", .get_allowed_properties("indents"), "}", collapse = ", ")
      ))
    }
  }
  
  params
}

#' Internal border specification builder
#' 
#' @param color Border color as hex code or color name
#' @param width Border width
#' @param line_style Line style
#' @return Border specification list
#' @keywords internal
#' @noRd
.border_spec <- function(color = NULL, width = NULL, line_style = NULL) {
  params <- as.list(environment())
  params <- params[!sapply(params, is.null)]
  
  if (!is.null(color)) {
    .validate_color(color, "color", "border_spec",
                    "Must be hex code (e.g., '#000000') or color name (e.g., 'black', 'red')")
    params$color <- .normalize_color(color)
  }
  
  if (!is.null(width)) {
    .validate_pattern(width, .const_pattern_border_width, "width", "border_spec")
  }
  
  if (!is.null(line_style)) {
    .validate_enum(line_style, .const_line_styles, "line_style", "border_spec")
  }
  
  params
}

#' Internal borders specification builder
#' 
#' @param top Top border specification
#' @param bottom Bottom border specification
#' @param left Left border specification
#' @param right Right border specification
#' @return Borders specification list
#' @keywords internal
#' @noRd
.borders_spec <- function(top = NULL, bottom = NULL, left = NULL, right = NULL) {
  params <- list()
  
  if (!is.null(top)) params$top <- top
  if (!is.null(bottom)) params$bottom <- bottom
  if (!is.null(left)) params$left <- left
  if (!is.null(right)) params$right <- right
  
  params
}

#' Internal table style specification builder
#' 
#' @param background_color Cell background color
#' @param row_height Row height
#' @param vertical_alignment Vertical alignment
#' @param text_orientation Text orientation
#' @param borders Borders specification
#' @return Table style specification list
#' @keywords internal
#' @noRd
.table_style_spec <- function(background_color = NULL, row_height = NULL,
                              vertical_alignment = NULL, text_orientation = NULL,
                              borders = NULL) {
  params <- list()
  
  if (!is.null(background_color)) {
    .validate_color(background_color, "background_color", "table_style_spec",
                    "Must be hex code (e.g., '#D9D9D9') or color name (e.g., 'gray', 'lightblue')")
    params$background_color <- .normalize_color(background_color)
  }
  
  if (!is.null(row_height)) {
    .validate_pattern(row_height, .const_pattern_row_height, 
                      "row_height", "table_style_spec",
                      "Must be like '12pt', '0.5in', '1.27cm', '12.7mm', or 'auto'")
    params$row_height <- row_height
  }
  
  if (!is.null(vertical_alignment)) {
    .validate_enum(vertical_alignment, .const_vertical_alignment,
                   "vertical_alignment", "table_style_spec")
    params$vertical_alignment <- vertical_alignment
  }
  
  if (!is.null(text_orientation)) {
    .validate_enum(text_orientation, .const_text_orientation,
                   "text_orientation", "table_style_spec")
    params$text_orientation <- text_orientation
  }
  
  if (!is.null(borders)) {
    params$borders <- borders
  }
  
  params
}

#' Internal margins specification builder
#' 
#' @param top Top margin
#' @param bottom Bottom margin
#' @param left Left margin
#' @param right Right margin
#' @param header Header margin
#' @param footer Footer margin
#' @return Margins specification list
#' @keywords internal
#' @noRd
.margins_spec <- function(top, bottom, left, right, header, footer) {
  params <- as.list(environment())
  
  for (margin in names(params)) {
    .validate_pattern(params[[margin]], .const_pattern_margins, margin, "margins_spec",
                      "Must be like '1in', '2.54cm', '25.4mm', or '72pt'")
  }
  
  params
}

#' Internal page specification builder (for context-based usage)
#'
#' @param size Page size
#' @param orientation Page orientation
#' @param margins Margins specification
#'
#' @return Page specification list
#' @keywords internal
#' @noRd
.page_spec <- function(size = .const_default_page_size, 
                       orientation = .const_default_page_orientation, 
                       margins) {
  .validate_enum(size, .const_page_sizes, "size", "page_spec")
  .validate_enum(orientation, .const_page_orientations, "orientation", "page_spec")
  
  # Validate margins keys if a raw list is passed
  if (is.list(margins)) {
    .validate_params(margins, "margins", "p_page")
  }
  
  list(size = size, orientation = orientation, margins = margins)
}

#' Internal column format specification builder
#' 
#' @param type Data type
#' @param format Format string
#' @param missings Missing value handling
#' @param colWidth Column width
#' @param valueStyleRef Character vector of style IDs for cell values
#' @return Column format specification list
#' @keywords internal
#' @noRd
.col_format_spec <- function(type=NULL, format = NULL, missings = NULL, 
                             colWidth = NULL, valueStyleRef = NULL) {
  # Only validate and include type if it's provided (not NULL)
  if (!is.null(type)) {
    .validate_enum(type, .const_column_types, "type", "col_format_spec")
  }
  
  params <- list()
  
  # Only include non-NULL parameters
  if (!is.null(type)) params$type <- type
  if (!is.null(format)) params$format <- format
  if (!is.null(missings)) params$missings <- missings
  
  if (!is.null(colWidth)) {
    .validate_pattern(colWidth, .const_pattern_col_width, 
                      "colWidth", "col_format_spec",
                      "Must be like '20%', '2in', or '5cm'")
    params$colWidth <- colWidth
  }
  
  if (!is.null(valueStyleRef)) params$valueStyleRef <- valueStyleRef
  
  params
}

# ============================================================
# PART 4: EXPORTED STYLE MODIFIERS (with s_ prefix)
# ============================================================

#' Define font properties for a style
#' 
#' This function can only be used inside \code{\link{add_style}}.
#' 
#' @param font_name Font family name. One of: "Arial", "Courier New", 
#'   "Times New Roman", "Calibri"
#' @param font_size Font size with units, e.g. "12pt"
#' @param bold Logical, whether text is bold
#' @param italic Logical, whether text is italic
#' @param underline Logical, whether text is underlined
#' @param color Text color as hex (e.g., "#000000") or color name (e.g., "red", "blue")
#' @param highlight Background highlight color as hex (e.g., "#FFFF00") or color name (e.g., "yellow")
#' 
#' @return A font specification object (for internal use)
#' @export
#' 
#' @seealso [add_style()] for applying styles, [s_paragraph()], [s_table_style()] for other style components
#' 
#' @examples
#' \dontrun{
#' spec <- create_text() |>
#'   add_style("my_style",
#'     s_font(font_name = "Arial", font_size = "12pt", bold = TRUE)
#'   )
#' }
s_font <- function(font_name = NULL, font_size = NULL, bold = NULL, 
                   italic = NULL, underline = NULL, color = NULL, 
                   highlight = NULL) {
  .assert_context(c("add_style"), "s_font")
  
  spec <- .font_spec(
    font_name = font_name,
    font_size = font_size,
    bold = bold,
    italic = italic,
    underline = underline,
    color = color,
    highlight = highlight
  )
  
  structure(spec, class = c("tfl_font", "tfl_style_modifier"))
}

#' Define spacing properties for paragraphs
#' 
#' This function can only be used inside \code{\link{s_paragraph}}.
#' 
#' @param before Space before paragraph, e.g. "6pt"
#' @param after Space after paragraph, e.g. "6pt"
#' @param line_spacing Line spacing multiplier, minimum 1
#' 
#' @return A spacing specification object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- create_text() |>
#'   add_style("my_style",
#'     s_paragraph(
#'       alignment = "center",
#'       spacing = s_spacing(before = "12pt", after = "6pt")
#'     )
#'   )
#' }
s_spacing <- function(before = NULL, after = NULL, line_spacing = NULL) {
  .assert_context(c("s_paragraph"), "s_spacing")
  
  spec <- .spacing_spec(before = before, after = after, line_spacing = line_spacing)
  structure(spec, class = c("tfl_spacing", "tfl_nested_modifier"))
}

#' Define indentation properties for paragraphs
#' 
#' This function can only be used inside \code{\link{s_paragraph}}.
#' 
#' @param left Left indent, e.g. "10mm"
#' @param right Right indent, e.g. "10mm"
#' @param first_line First line indent (negative for hanging), e.g. "-5mm"
#' 
#' @return An indents specification object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- create_text() |>
#'   add_style("my_style",
#'     s_paragraph(
#'       indents = s_indents(left = "10mm", first_line = "-5mm")
#'     )
#'   )
#' }
s_indents <- function(left = NULL, right = NULL, first_line = NULL) {
  .assert_context(c("s_paragraph"), "s_indents")
  
  spec <- .indents_spec(left = left, right = right, first_line = first_line)
  structure(spec, class = c("tfl_indents", "tfl_nested_modifier"))
}

#' Define paragraph properties for a style
#' 
#' This function can only be used inside \code{\link{add_style}}.
#' 
#' @param alignment Text alignment: "left", "right", "center", "justify", "distributed"
#' @param spacing Spacing object created with \code{\link{s_spacing}} or a list with keys: before, after, line_spacing
#' @param indents Indents object created with \code{\link{s_indents}} or a list with keys: left, right, first_line
#' @param word_style Base Word style to inherit from
#' 
#' @return A paragraph specification object
#' @export
#' 
#' @seealso [add_style()] for applying styles, [s_spacing()], [s_indents()] for nested components,
#'   [s_font()], [s_table_style()] for other style components
#' 
#' @examples
#' \dontrun{
#' spec <- create_text() |>
#'   add_style("my_style",
#'     s_paragraph(
#'       alignment = "center",
#'       spacing = s_spacing(before = "12pt", after = "6pt"),
#'       word_style = "Normal"
#'     )
#'   )
#' }
s_paragraph <- function(alignment = NULL, spacing = NULL, indents = NULL, 
                        word_style = NULL) {
  .assert_context(c("add_style"), "s_paragraph")
  
  # Set context for nested functions
  .frame_env <- sys.frame()
  .set_context(.frame_env, "s_paragraph")
  on.exit(.clear_context(.frame_env))
  
  # Build spec with strict validation on spacing/indents shapes
  spec <- .paragraph_spec(
    alignment = alignment,
    spacing = spacing,
    indents = indents,
    word_style = word_style
  )
  
  # Validate final paragraph payload keys
  .validate_params(spec, "paragraph", "s_paragraph")
  
  structure(spec, class = c("tfl_paragraph", "tfl_style_modifier"))
}

#' Define border properties
#' 
#' This function can only be used inside \code{\link{s_borders}}.
#' 
#' @param color Border color as hex (e.g., "#000000") or color name (e.g., "black", "red")
#' @param width Border width, e.g. "1pt"
#' @param line_style Line style: "single", "double", "dashed", "dotted", "thick", "none"
#' 
#' @return A border specification object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- create_text() |>
#'   add_style("my_style",
#'     s_table_style(
#'       borders = s_borders(
#'         bottom = s_border(color = "#000000", width = "2pt", line_style = "single")
#'       )
#'     )
#'   )
#' }
s_border <- function(color = NULL, width = NULL, line_style = NULL) {
  .assert_context(c("s_borders"), "s_border")
  
  spec <- .border_spec(color = color, width = width, line_style = line_style)
  .validate_params(spec, "border", "s_border")
  structure(spec, class = c("tfl_border", "tfl_nested_modifier"))
}

#' Define borders for table cells
#' 
#' This function can only be used inside \code{\link{s_table_style}}.
#' 
#' @param top Top border created with \code{\link{s_border}}
#' @param bottom Bottom border created with \code{\link{s_border}}
#' @param left Left border created with \code{\link{s_border}}
#' @param right Right border created with \code{\link{s_border}}
#' 
#' @return A borders specification object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- create_text() |>
#'   add_style("my_style",
#'     s_table_style(
#'       borders = s_borders(
#'         top = s_border(width = "1pt"),
#'         bottom = s_border(width = "2pt", line_style = "double")
#'       )
#'     )
#'   )
#' }
s_borders <- function(top = NULL, bottom = NULL, left = NULL, right = NULL) {
  .assert_context(c("s_table_style"), "s_borders")
  
  # Set context for nested functions
  .frame_env <- sys.frame()
  .set_context(.frame_env, "s_borders")
  on.exit(.clear_context(.frame_env))
  
  # Extract nested specs
  if (inherits(top, "tfl_border")) top <- unclass(top)
  if (inherits(bottom, "tfl_border")) bottom <- unclass(bottom)
  if (inherits(left, "tfl_border")) left <- unclass(left)
  if (inherits(right, "tfl_border")) right <- unclass(right)
  
  spec <- .borders_spec(top = top, bottom = bottom, left = left, right = right)
  .validate_params(spec, "borders", "s_borders")
  
  # Validate nested border shapes if present
  for (side in .const_border_sides) {
    if (!is.null(spec[[side]])) {
      .validate_params(spec[[side]], "border", paste0("s_borders$", side))
    }
  }
  
  structure(spec, class = c("tfl_borders", "tfl_nested_modifier"))
}

#' Define table-specific styling
#' 
#' This function can only be used inside \code{\link{add_style}}.
#' 
#' @param background_color Cell background color as hex code or color name
#' @param row_height Row height, e.g. "15mm" or "auto"
#' @param vertical_alignment Vertical alignment: "top", "center", "bottom"
#' @param text_orientation Text orientation: "horizontal", "vertical_90", "vertical_270"
#' @param borders Borders object created with \code{\link{s_borders}}
#' 
#' @seealso [add_style()] for applying styles, [s_borders()], [s_border()] for border components,
#'   [s_font()], [s_paragraph()] for other style components
#' 
#' @return A table style specification object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- create_text() |>
#'   add_style("header_style",
#'     s_table_style(
#'       background_color = "#D9D9D9",
#'       vertical_alignment = "center",
#'       borders = s_borders(
#'         bottom = s_border(color = "#000000", width = "2pt")
#'       )
#'     )
#'   )
#' }
s_table_style <- function(background_color = NULL, row_height = NULL,
                          vertical_alignment = NULL, text_orientation = NULL,
                          borders = NULL) {
  .assert_context(c("add_style"), "s_table_style")
  
  # Set context for nested functions
  .frame_env <- sys.frame()
  .set_context(.frame_env, "s_table_style")
  on.exit(.clear_context(.frame_env))
  
  # Extract nested specs
  if (inherits(borders, "tfl_borders")) {
    borders <- unclass(borders)
  }
  
  spec <- .table_style_spec(
    background_color = background_color,
    row_height = row_height,
    vertical_alignment = vertical_alignment,
    text_orientation = text_orientation,
    borders = borders
  )
  
  .validate_params(spec, "table_style", "s_table_style")
  if (!is.null(spec$borders)) {
    .validate_params(spec$borders, "borders", "s_table_style$borders")
    for (side in .const_border_sides) {
      if (!is.null(spec$borders[[side]])) {
        .validate_params(spec$borders[[side]], "border", paste0("s_table_style$borders$", side))
      }
    }
  }
  
  structure(spec, class = c("tfl_table_style", "tfl_style_modifier"))
}

#' Define page margins
#' 
#' This function can only be used inside \code{\link{p_page}}.
#' 
#' @param top Top margin, e.g. "25mm"
#' @param bottom Bottom margin, e.g. "25mm"
#' @param left Left margin, e.g. "20mm"
#' @param right Right margin, e.g. "20mm"
#' @param header Header margin, e.g. "12mm"
#' @param footer Footer margin, e.g. "12mm"
#' 
#' @return A margins specification object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- create_text() |>
#'   add_style("page_style",
#'     p_page(
#'       size = "A4",
#'       orientation = "landscape",
#'       margins = p_margins(
#'         top = "25mm", bottom = "25mm",
#'         left = "20mm", right = "20mm",
#'         header = "12mm", footer = "12mm"
#'       )
#'     )
#'   )
#' }
p_margins <- function(top=NULL, bottom=NULL, left=NULL, right=NULL, header=NULL, footer=NULL) {
  .assert_context(c("p_page"), "p_margins")
  
  params <- list(
    top = top, bottom = bottom, 
    left = left, right = right, 
    header = header, footer = footer
  )
  params <- params[!sapply(params, is.null)]
  
  spec <- .margins_spec(
    top = params$top, bottom = params$bottom, 
    left = params$left, right = params$right, 
    header = params$header, footer = params$footer
  )
  .validate_params(spec, "margins", "p_margins")
  structure(spec, class = c("tfl_margins", "tfl_nested_modifier"))
}

#' Define page settings
#' 
#' This function can only be used inside \code{\link{set_page_style}}.
#' 
#' @param size Page size: "A4", "A3", "Letter", "Legal", "Executive"
#' @param orientation Page orientation: "portrait" or "landscape"
#' @param margins Margins object created with \code{\link{p_margins}} or a list with keys: top, bottom, left, right, header, footer
#' 
#' @return A page specification object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- create_text() |>
#'   set_page_style(
#'     docTemplate = "KeyStat_default",
#'     page = p_page(
#'       size = "A4",
#'       orientation = "landscape",
#'       margins = p_margins(
#'         top = "25mm", bottom = "25mm",
#'         left = "20mm", right = "20mm",
#'         header = "12mm", footer = "12mm"
#'       )
#'     )
#'   )
#' }
p_page <- function(size = .const_default_page_size, 
                   orientation = .const_default_page_orientation, 
                   margins = NULL) {
  .assert_context(c("set_page_style"), "p_page")
  
  # Set context for nested functions
  .frame_env <- sys.frame()
  .set_context(.frame_env, "p_page")
  on.exit(.clear_context(.frame_env))
  
  # Extract nested specs
  if (inherits(margins, "tfl_margins")) {
    margins <- unclass(margins)
  } else if (is.list(margins)) {
    .validate_params(margins, "margins", "p_page")
  }
  
  spec <- .page_spec(size = size, orientation = orientation, margins = margins)
  .validate_params(spec, "page", "p_page")
  structure(spec, class = c("tfl_page", "tfl_document_modifier"))
}

 


 

# ============================================================
# PART 5: EXPORTED CONTEXT FUNCTIONS
# ============================================================


#' Process Style Modifier and Return Path
#' 
#' Generic helper to extract path and payload from a style modifier object.
#' This allows style modifiers to be reused across different spec classes.
#' 
#' @param modifier Style modifier object (e.g., tfl_font, tfl_paragraph)
#' @return List with `path` (character) and `payload` (list)
#' @keywords internal
#' @noRd
.process_style_modifier <- function(modifier) {
  if (!inherits(modifier, "tfl_style_modifier")) {
    cli_abort(c(
      "Invalid style modifier",
      x = "Modifier must inherit from 'tfl_style_modifier'",
      i = "Use: {.fn s_font}, {.fn s_paragraph}, or {.fn s_table_style}"
    ))
  }
  
  modifier_class <- class(modifier)[1]
  path <- .const_modifier_paths[[modifier_class]]
  
  if (is.null(path)) {
    cli_abort("Unknown modifier class: {modifier_class}")
  }
  
  payload <- unclass(modifier)
  
  list(path = path, payload = payload)
}

#' Validate Style Modifier Payload
#' 
#' Validates a style modifier payload against schema and nested structures.
#' This can be reused by different spec class implementations.
#' 
#' @param path Character. Target path (e.g., "font", "paragraph")
#' @param payload List. Modifier payload to validate
#' @param fn_name Character. Function name for error messages
#' @keywords internal
#' @noRd
.validate_style_payload <- function(path, payload, fn_name = "add_style") {
  # Validate payload against schema cache before merging
  .validate_params(payload, path, fn_name)
  
  # Validate nested shapes as needed
  if (path == "paragraph") {
    if (!is.null(payload$spacing)) {
      .validate_params(payload$spacing, "spacing", paste0(fn_name, "$paragraph.spacing"))
    }
    if (!is.null(payload$indents)) {
      .validate_params(payload$indents, "indents", paste0(fn_name, "$paragraph.indents"))
    }
  }
  if (path == "table_style" && !is.null(payload$borders)) {
    .validate_params(payload$borders, "borders", paste0(fn_name, "$table_style.borders"))
    for (side in .const_border_sides) {
      if (!is.null(payload$borders[[side]])) {
        .validate_params(payload$borders[[side]], "border", 
                        paste0(fn_name, "$table_style.borders$", side))
      }
    }
  }
}

#' Add or update a style definition
#' 
#' Generic function to add or update style definitions. Dispatches to class-specific
#' methods, allowing different spec classes to implement their own style handling.
#' 
#' Define styling for various document elements. Multiple calls to the same
#' modifier function will merge with last-win strategy.
#' 
#' Available modifiers inside this function:
#' \itemize{
#'   \item \code{\link{s_font}} - Font properties
#'   \item \code{\link{s_paragraph}} - Paragraph formatting
#'   \item \code{\link{s_table_style}} - Table cell styling
#' }
#' 
#' @param spec Spec object (dispatches on class)
#' @param id Style identifier (auto-generated if NULL)
#' @param ... Style modifiers created with s_* functions
#' \itemize{
#'   \item \code{\link{s_font}} — font properties.
#'   \item \code{\link{s_paragraph}} — paragraph-level formatting (may include nested \code{\link{s_spacing}} and \code{\link{s_indents}}).
#'   \item \code{\link{s_table_style}} — table-cell styling (may include nested \code{\link{s_borders}} / \code{\link{s_border}}).
#' }
#' 
#' @return Updated spec object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- create_text() |>
#'   add_style("header",
#'     s_font(font_name = "Arial", font_size = "14pt", bold = TRUE),
#'     s_paragraph(alignment = "center"),
#'     s_table_style(background_color = "#D9D9D9")
#'   ) |>
#'   # Multiple calls merge with last-win
#'   add_style("header",
#'     s_font(color = "#FF0000")  # Adds color, keeps other font properties
#'   )
#' }
add_style <- function(spec, id, ...) {
  UseMethod("add_style", spec)
}

#' Add or update a style definition for TFL_spec
#' 
#' @param spec TFL_spec object
#' @param id Style identifier (auto-generated if NULL)
#' @param ... Style modifiers created with s_* functions
#' \itemize{
#'   \item Allowed modifiers: `s_font()`, `s_paragraph()`, `s_table_style()`.
#'   \item `s_paragraph()` may itself contain nested modifiers `s_spacing()` and `s_indents()`.
#'   \item Modifiers are merged into the named style using a last-win strategy.
#' }
#' @return Updated spec object
#' @export
add_style.TFL_spec <- function(spec, id, ...) {
  assert_class(spec, "TFL_spec")
  
  # Auto-generate ID if needed
  #if (is.null(id)) {
  #  id <- .auto_id("style_", spec$attribs$styles)
  #}
  
  # Initialize style if needed
  if (is.null(spec$attribs$styles[[id]])) {
    spec$attribs$styles[[id]] <- list()
  }
  
  # Set context in the current call frame so nested `s_*` modifiers
  # (which are evaluated as promises) can detect the `add_style` context.
  .frame_env <- sys.frame()
  .set_context(.frame_env, "add_style")
  on.exit(.clear_context(.frame_env))
  
  # Capture modifiers as quosures and evaluate them inside the add_style frame
  mod_quos <- rlang::enquos(...)

  # Process each modifier after forcing it in the add_style frame so
  # nested s_* helpers can detect the context marker during evaluation.
  for (i in seq_along(mod_quos)) {
    mod <- rlang::eval_tidy(mod_quos[[i]], env = .frame_env)
    # Extract path and payload using reusable helper
    mod_info <- .process_style_modifier(mod)
    path <- mod_info$path
    payload <- mod_info$payload

    # Validate using reusable helper
    .validate_style_payload(path, payload, "add_style")

    # Merge with last-win
    current <- spec$attribs$styles[[id]][[path]]
    spec$attribs$styles[[id]][[path]] <- .merge_recursive(current, payload)
  }
  
  spec
}

#' Add or update a style definition for TFL_options
#' 
#' @param spec TFL_options style branch object
#' @param id Style identifier (name) 
#' @param ... Style modifiers created with s_* functions
#' \itemize{
#'   \item Allowed modifiers: `s_font()`, `s_paragraph()`, `s_table_style()`.
#'   \item `s_paragraph()` may itself contain nested modifiers `s_spacing()` and `s_indents()`.
#'   \item Modifiers are merged into the named style using a last-win strategy.
#' }
#' @return Updated spec object
#' @export
add_style.TFL_options <- function(spec, id = NULL, ...) {
  # Initialize style if needed
  if (is.null(spec$styles[[id]])) {
    spec$styles[[id]] <- list()
  }
  
  # Set context in the current call frame so nested `s_*` modifiers
  # are evaluated with the correct context marker.
  .frame_env <- sys.frame()
  .set_context(.frame_env, "add_style")
  on.exit(.clear_context(.frame_env))
  
  # Capture modifiers as quosures and evaluate them inside the add_style frame
  mod_quos <- rlang::enquos(...)

  # Process each modifier after forcing it in the add_style frame so
  # nested s_* helpers can detect the context marker during evaluation.
  for (i in seq_along(mod_quos)) {
    mod <- rlang::eval_tidy(mod_quos[[i]], env = .frame_env)
    # Extract path and payload using reusable helper
    mod_info <- .process_style_modifier(mod)
    path <- mod_info$path
    payload <- mod_info$payload

    # Validate using reusable helper
    .validate_style_payload(path, payload, "add_style")

    # Merge with last-win
    current <- spec$styles[[id]][[path]]
    spec$styles[[id]][[path]] <- .merge_recursive(current, payload)
  }
  class(spec) <- "TFL_options_style"
  spec
}


#' Default method for add_style
#' 
#' @param spec Spec object
#' @param id Style identifier
#' @param ... Style modifiers
#' \itemize{
#'   \item Functions created with `s_*()` helpers (e.g., `s_font()`, `s_paragraph()`).
#'   \item These modifiers are evaluated in the `add_style()` context and merged into the style definition.
#' }
#' @return Error if no method found
#' @export
add_style.default <- function(spec, id = NULL, ...) {
  cli_abort(c(
    "No method for {.fn add_style} for class {.cls {class(spec)[1]}}",
    i = "Style modifiers can be reused, but {.fn add_style} must be implemented for each spec class"
  ))
}

#' Combine multiple style names for explicit grouping
#' 
#' Helper function to group multiple style names together for explicit application 
#' to columns or elements. Useful when using \code{\link{define_cols}} or other 
#' functions with multiple columns and you want to either:
#' \itemize{
#'   \item Recycle the same group of styles to all columns: 
#'         \code{labelStyleRef = f_combine("style1", "style2")}
#'   \item Create explicit one-to-one mappings:
#'         \code{labelStyleRef = c(f_combine("s1", "s2"), f_combine("s3"), "style4")}
#' }
#' 
#' @param ... Character strings representing style names to combine
#' \itemize{
#'   \item Each argument must be a single character string naming a style.
#'   \item Returned object has class `tfl_style_combine` to signal grouped style application.
#' }
#' 
#' @return Character vector with class "tfl_style_combine" containing all provided style names.
#'   This special class signals to style resolution functions that these styles should be
#'   applied together as a group (merged with last-win strategy during `create_report()`).
#' @export
#' 
#' @examples
#' \dontrun{
#' # Combine styles for recycling to all columns
#' styles <- f_combine("label_style", "emphasis", "bold")
#' 
#' # Use in define_cols for one-to-one mapping
#' spec <- create_table(data) |>
#'   define_cols(c("id", "age"),
#'     labelStyleRef = c(
#'       f_combine("id_label", "key"),
#'       f_combine("numeric_label")
#'     )
#'   )
#' }
f_combine <- function(...) {
  styles <- list(...)
  
  # Validate each argument is a single character string
  for (i in seq_along(styles)) {
    if (!is.character(styles[[i]]) || length(styles[[i]]) != 1) {
      cli_abort(c(
        "Argument {i} to {.fn f_combine} must be a single character string",
        i = "Got: {.cls {class(styles[[i]])[1]}} with length {length(styles[[i]])}"
      ))
    }
  }
  
  # Return as character vector with special class to track it as a combined group
  result <- as.character(styles)
  class(result) <- c("tfl_style_combine", "character")
  result
}

#' S3 method for c() with tfl_style_combine objects
#' 
#' When combining tfl_style_combine objects with c(), preserve them as list elements
#' rather than flattening. This enables explicit one-to-one style mapping.
#'
#' @param ... Objects to combine
#' \itemize{
#'   \item Accepts `tfl_style_combine` objects and plain character strings.
#'   \item `tfl_style_combine` objects are preserved as single list elements to enable one-to-one mappings.
#'   \item Character strings are added as separate list elements.
#' }
#' @param recursive Ignored
#' @return List of style references
#' @keywords internal
#' @method c tfl_style_combine
#' @export
c.tfl_style_combine <- function(..., recursive = FALSE) {
  args <- list(...)
  
  # Collect all arguments, preserving tfl_style_combine objects as list elements
  result <- list()
  for (arg in args) {
    if (inherits(arg, "tfl_style_combine")) {
      # Remove class and add as a single element
      result[[length(result) + 1]] <- unclass(arg)
    } else if (is.character(arg)) {
      # Add character strings as-is
      result[[length(result) + 1]] <- arg
    } else {
      # Fallback for other types
      result[[length(result) + 1]] <- arg
    }
  }
  
  # Return as list (will be detected as one-to-one mapping by ._resolve_style_refs)
  result
}

#' Define or modify column properties
#' 
#' Modify properties of existing columns. Can modify single column or batch update
#' multiple columns. All parameters support 1-to-many recycling: provide a single value 
#' to apply to all columns, or a vector matching the length of `cols` for one-to-one mapping.
#' Multiple calls merge with last-win strategy.
#' 
#' @param spec TFL spec object (must be initialized with \code{\link{create_table}})
#' @param cols Columns to modify using tidyselect syntax. Accepts:
#'   \itemize{
#'     \item Named columns: \code{c("age", "group")}
#'     \item Column ranges: \code{age:group}
#'     \item Helper functions: \code{starts_with("age_")}, \code{contains("_pct")}
#'     \item Negation: \code{-id} or \code{!matches("^temp")}
#'   }
#' @param label Column label (length 1 or length of cols; \code{NA} skips that position)
#' @param isID Whether column is identifier (length 1 or length of cols; \code{NA} skips that position)
#' @param isVisible Whether column is visible in report output (length 1 or length of cols;
#'   \code{NA} skips that position).
#'   When set to FALSE, column is hidden from output and automatically assigned width "0.0cm".
#'   Invisible columns do NOT participate in width recalculation; only visible columns are included.
#'   Cannot set `colWidth` for invisible columns (error raised if attempted).
#' @param isGrouping Whether column defines groups (length 1 or length of cols; \code{NA} skips that position)
#' @param isPaging Whether column defines pages (length 1 or length of cols; \code{NA} skips that position)
#' @param labelStyleRef List of style names to be applied. Provided styles will be merged with last-win strategy for report. 
#'   Can be: single string (recycled), character vector from \code{\link{f_combine}} (recycled), 
#'   or list of \code{\link{f_combine}} results or \code{NA} sentinels (one-to-one mapping to columns).
#'   Use \code{NA} as a list element to skip updating \code{labelStyleRef} for that column.
#' @param isColBreak Whether column triggers page break (length 1 or length of cols; \code{NA} skips that position)
#' @param dedupe Whether to deduplicate values (length 1 or length of cols; \code{NA} skips that position)
#' @param blankAfter Whether to add blank after value change (length 1 or length of cols; \code{NA} skips that position)
#' @param type Data type for column format: "string" or "numeric" (length 1 or length of cols;
#'   \code{NA} skips that position). Optional; omit to preserve existing.
#' @param format Format string for numeric data (sprintf style), e.g. "%.1f" (length 1 or length of cols;
#'   \code{NA} skips that position). Optional.
#' @param missings How to display missing values in columns (length 1 or length of cols;
#'   \code{NA} skips that position). Optional.
#' @param colWidth Column width, e.g. "2in", "5cm", "20%" (length 1 or length of cols;
#'   \code{NA} skips that position — the column's width is left unchanged). Optional.
#'   When at least one non-\code{NA} value is specified, affected columns are marked as LOCKED and
#'   automatic recalculation of remaining unlocked columns is triggered if \code{autoColWidth = TRUE}
#'   in \code{tfl_set_options()}. Locked columns maintain their exact width while unlocked columns
#'   normalize to fill remaining available space.
#' @param valueStyleRef Style names to apply to cell values. Provided styles will be merged with last-win strategy for report.
#'   Use \code{NA} as a list element to skip updating \code{valueStyleRef} for that column. 
#'  return Updated TFL_spec object with modified column definitions. Changes are merged with existing
#'   column properties using last-win strategy. When `colWidth` is specified or `isVisible` changes,
#'   automatic width recalculation is triggered (if `autoColWidth = TRUE`).
#' 
#' @details
#' Column Width Management:
#' 
#' Widths are managed through a LOCKED/UNLOCKED/VISIBLE partitioning system:
#' \itemize{
#'   \item VISIBLE columns: included in width calculations (isVisible != FALSE)
#'   \item LOCKED columns: exact width specified via colWidth parameter (any unit: %, cm, in, mm, pt)
#'   \item UNLOCKED columns: automatically recalculated to fill available space
#'   \item INVISIBLE columns: hidden from output (isVisible = FALSE), assigned width "0.0cm", excluded from calculations
#' }
#'
#' When `colWidth` is specified (or visibility changes), columns are marked as LOCKED and remaining 
#' UNLOCKED columns are automatically recalculated (if `autoColWidth = TRUE`, the default):
#' \itemize{
#'   \item Only VISIBLE UNLOCKED columns participate in recalculation
#'   \item Locked columns (any unit) maintain their exact specified width
#'   \item Unlocked visible columns normalize proportionally to fill remaining available space
#'   \item All visible columns' widths sum to 100% with 1 decimal place precision
#'   \item Invisible columns stay at "0.0cm" and don't affect other widths
#' }
#' To disable auto-recalculation, use `tfl_set_options(autoColWidth = FALSE)`.
#' 
#' Invisible Column Behavior:
#' \itemize{
#'   \item `isVisible = FALSE` automatically sets `colWidth = "0.0cm"`
#'   \item Cannot set `colWidth` on invisible columns (raises error)
#'   \item Invisible columns are excluded from width recalculation entirely
#'   \item Shown with "hidden" flag in spec preview
#' }
#' 
#' @return Updated spec object
#' @export
#' 
#' @examples
#' \dontrun{
#' data <- data.frame(id = 1:10, age = rnorm(10, 45, 10), group = rep(c("A", "B"), 5))
#' 
#' # Single column with format
#' spec <- create_table(data) |>
#'   define_cols("age",
#'     label = "Age (years)",
#'     type = "numeric", format = "%.1f", colWidth = "10%"
#'   )
#' 
#' # Batch update with single value
#' spec <- create_table(data) |>
#'   define_cols(c("id", "age", "group"),
#'     isVisible = TRUE  # Applied to all three
#'   )
#' 
#' # Batch update with mapped values
#' spec <- create_table(data) |>
#'   define_cols(c("id", "age"),
#'     label = c("Subject ID", "Age (years)"),  # One-to-one mapping
#'     isID = c(TRUE, FALSE)
#'   )
#' 
#' # Batch format update with mixed recycling
#' spec <- create_table(data) |>
#'   define_cols(c("id", "age"),
#'     type = "numeric",  # Single value recycled to both columns
#'     colWidth = c("10%", "15%")  # Different widths for each column
#'   )
#' 
#' # Multiple calls merge
#' spec <- create_table(data) |>
#'   define_cols("age",
#'     label = "Age",
#'     type = "numeric", format = "%.0f"
#'   ) |>
#'   define_cols("age",
#'     label = "Age (years)",  # Overrides previous label
#'     colWidth = "15%"  # Merges with format, keeping type and format
#'   )
#' 
#' # Apply style references - single value recycled to all columns
#' spec <- create_table(data) |>
#'   define_cols(c("age", "id"),
#'     labelStyleRef = f_combine("label_style", "emphasis")
#'   )
#' 
#' # Apply different styles combinations to different columns
#' spec <- create_table(data) |>
#'   define_cols(c("id", "age", "group"),
#'     labelStyleRef = c(
#'       f_combine("id_label", "key"),
#'       f_combine("numeric_label", "emphasis"),
#'       f_combine("categorical_label")
#'     )
#'   )
#' 
#' # Column width auto-recalculation (when autoColWidth = TRUE, the default):
#' # Initial widths are automatically distributed (e.g., id=33.3%, age=33.3%, group=33.4%)
#' spec <- create_table(data) |>
#'   define_cols("id", colWidth = "20%")  # Lock id at 20%
#'   # Result: id=20%, age and group auto-recalculate to fill remaining 80%
#'   # 
#' # Multiple colWidth calls preserve previous locks:
#' spec <- create_table(data) |>
#'   define_cols("id", colWidth = "20%")  # Lock id at 20%
#'   |> define_cols("age", colWidth = "15%")  # Lock age at 15%
#'   # Result: id=20% (locked), age=15% (locked), group=65% (fills remaining)
#' 
#' # Disable auto-recalculation to manage widths manually:
#' tfl_set_options(autoColWidth = FALSE)  # Turn off auto-recalculation
#' spec <- create_table(data) |>
#'   define_cols(c("id", "age", "group"), colWidth = c("25%", "30%", "45%"))
#'   # Widths stay exactly as specified, no automatic recalculation
#' tfl_set_options(autoColWidth = TRUE)  # Re-enable (restore default)
#' 
#' 
#' # Using tidyselect helpers
#' spec <- create_table(data) |>
#'   define_cols(starts_with("age"),
#'     label = "Age-related metric",
#'     type = "numeric", format = "%.1f"
#'   )
#' 
#' # Using negation with tidyselect
#' spec <- create_table(data) |>
#'   define_cols(-id,  # Exclude id column
#'     isVisible = TRUE
#'   )
#' 
#' # Using column range
#' spec <- create_table(data) |>
#'   define_cols(age:group,  # All columns from age to group
#'     labelStyleRef = "emphasis"
#'   )
#' 
#' # Hide column from output while keeping data for conditional logic
#' spec <- create_table(data) |>
#'   define_cols("age",
#'     isVisible = FALSE  # Automatically sets width to "0.0cm"
#'   )
#'   # Result: age column hidden, other columns recalculated to sum to 100%
#' }
define_cols <- function(spec, cols, 
                        label = NULL, isID = NULL, 
                        isVisible = NULL, isGrouping = NULL, isPaging = NULL,
                        labelStyleRef = NULL, isColBreak = NULL, dedupe = NULL,
                        blankAfter = NULL,
                        type = NULL, format = NULL, missings = NULL, 
                        colWidth = NULL, valueStyleRef = NULL) {
  assert_class(spec, "TFL_spec")
  cols <- enquos(cols)
  cols <- .get_data_column_names(spec$.metadata$data_env$`__data__`, !!!cols)

  cols <- intersect(cols, names(spec$columns)) #keep only columns that exist in spec definition
  assert_character(cols, min.len = 1)
  
  # Check that all cols exist
  missing_cols <- setdiff(cols, names(spec$columns))
  if (length(missing_cols) > 0) {
    cli_abort(c(
      "Some columns specified in {.fn define_cols} not found in report definition:",
      x = paste(missing_cols, collapse = ", "),
      i = "Ensure the table was initialized with correct columns set"
    ))
  }
  
  # Track if user is setting colWidth or changing visibility (which affects width distribution).
  # A vector like c("13%", NA, "12%") counts as "user set colwidth" because at least one
  # position is non-NA; positions with NA are silently skipped.
  user_set_colwidth <- !is.null(colWidth) && any(!is.na(colWidth))
  user_changed_visibility <- !is.null(isVisible) && any(!is.na(isVisible))
  
  # Collect non-format parameters
  param_names <- c("label", "isID", "isVisible", "isGrouping", 
                   "isPaging", "labelStyleRef", "isColBreak", "dedupe", "blankAfter")
  params_list <- list(
    label = label, isID = isID, isVisible = isVisible,
    isGrouping = isGrouping, isPaging = isPaging, labelStyleRef = labelStyleRef,
    isColBreak = isColBreak, dedupe = dedupe, blankAfter = blankAfter
  )
  
  # Handle labelStyleRef specially with resolve logic
  if (!is.null(labelStyleRef)) {
    resolved_styleref <- ._resolve_style_refs(labelStyleRef, length(cols), "labelStyleRef")
    params_list$labelStyleRef <- resolved_styleref
  }
  
  # Handle valueStyleRef specially with resolve logic (same as labelStyleRef)
  resolved_valuestyleref <- NULL
  if (!is.null(valueStyleRef)) {
    resolved_valuestyleref <- ._resolve_style_refs(valueStyleRef, length(cols), "valueStyleRef")
  }
  
  # Collect format parameters (only include if non-NULL)
  format_param_names <- c("type", "format", "missings", "colWidth")
  format_params_list <- list(
    type = type, format = format, missings = missings, 
    colWidth = colWidth
  )
  # Filter out NULL values
  format_params_list <- format_params_list[!vapply(format_params_list, is.null, logical(1))]
  
  # Validate parameter lengths for non-format params (excluding labelStyleRef which is already resolved)
  n_cols <- length(cols)
  for (pname in setdiff(param_names, "labelStyleRef")) {
    pval <- params_list[[pname]]
    if (!is.null(pval)) {
      if (length(pval) != 1 && length(pval) != n_cols) {
        cli_abort(c(
          "{.arg {pname}} must have length 1 or length of {.arg cols} ({n_cols}) in {.fn define_cols}",
          x = "Got length {length(pval)}"
        ))
      }
    }
  }
  
  # Validate parameter lengths for format params (excluding valueStyleRef which is already resolved)
  for (pname in setdiff(names(format_params_list), "valueStyleRef")) {
    pval <- format_params_list[[pname]]
    if (!is.null(pval)) {
      if (length(pval) != 1 && length(pval) != n_cols) {
        cli_abort(c(
          "{.arg {pname}} must have length 1 or length of {.arg cols} ({n_cols}) in {.fn define_cols}",
          x = "Got length {length(pval)}"
        ))
      }
    }
  }
  
  # Apply to each column
  for (i in seq_along(cols)) {
    col_id <- cols[i]
    
    # Build params for this column
    col_params <- list()
    
    # Handle non-format parameters
    for (pname in param_names) {
      pval <- params_list[[pname]]
      if (!is.null(pval)) {
        # For labelStyleRef, it's already a list from ._resolve_style_refs;
        # NA sentinel means "skip this column".
        if (pname == "labelStyleRef") {
          val <- pval[[i]]
          if (!identical(val, NA)) {
            col_params[[pname]] <- val
          }
        } else {
          col_val <- if (length(pval) == 1L) pval else pval[i]
          # NA means "do nothing for this column position"
          if (!is.na(col_val)) {
            col_params[[pname]] <- col_val
          }
        }
      }
    }
    
    # Build format spec for this column if any format params are provided
    if (length(format_params_list) > 0 || !is.null(resolved_valuestyleref)) {
      # Extract values for this column with 1-or-n recycling.
      # NA values mean "skip this column position" — they are not added.
      col_format_params <- list()
      for (fpname in names(format_params_list)) {
        fpval <- format_params_list[[fpname]]
        col_val <- if (length(fpval) == 1L) fpval else fpval[i]
        if (!is.na(col_val)) {
          col_format_params[[fpname]] <- col_val
        }
      }
      
      # Add resolved valueStyleRef for this column (already resolved as a list).
      # NA sentinel means "skip this column".
      if (!is.null(resolved_valuestyleref)) {
        val <- resolved_valuestyleref[[i]]
        if (!identical(val, NA)) {
          col_format_params$valueStyleRef <- val
        }
      }
      
      # Only compute and merge format spec when at least one format param applies
      if (length(col_format_params) > 0) {
        format_spec <- do.call(.col_format_spec, col_format_params)
        existing_format <- spec$columns[[col_id]]$format
        col_params$format <- .merge_recursive(existing_format, format_spec)
      }
    }
    
    # Validate known keys for column
    .validate_params(col_params, "column", "define_cols")
    
    # Merge with last-win
    spec$columns[[col_id]] <- .merge_recursive(spec$columns[[col_id]], col_params)
    
    # ---- Handle isVisible = FALSE cases ----
    # Get the actual isVisible value for this column (after merge)
    col_is_visible <- spec$columns[[col_id]]$isVisible
    is_now_invisible <- !is.null(col_is_visible) && isFALSE(col_is_visible)
    
    # Check 1: User cannot set colWidth for invisible columns.
    # NA at this column's position is treated as "do nothing" so no error is raised.
    if (is_now_invisible && user_set_colwidth && !is.null(colWidth)) {
      col_colwidth <- if (length(colWidth) == 1L) colWidth else colWidth[i]
      if (!is.na(col_colwidth)) {
        cli_abort(c(
          "Cannot set {.arg colWidth} for invisible column {.str {col_id}}",
          x = "Column {.str {col_id}} has {.arg isVisible = FALSE}",
          i = "Invisible columns automatically have {.arg colWidth = \"0.0cm\"}"
        ))
      }
    }
    
    # Check 2: Auto-set colWidth = "0.0cm" for invisible columns
    if (is_now_invisible) {
      spec$columns[[col_id]]$format$colWidth <- "0.0cm"
      if (!is.null(spec$.metadata$colWidths[[col_id]])) {
        spec$.metadata$colWidths[[col_id]]$locked <- TRUE
        spec$.metadata$colWidths[[col_id]]$unit <- "cm"
        spec$.metadata$colWidths[[col_id]]$value <- 0.0
      }
    }
    
    # If user set colWidth, update metadata to mark as locked.
    # NA at this column's position is treated as "do nothing" — skip the lock entirely.
    if (user_set_colwidth && !is.null(colWidth)) {
      col_colwidth <- if (length(colWidth) == 1L) colWidth else colWidth[i]
      if (!is.na(col_colwidth)) {
        width_info <- .parse_colwidth(col_colwidth)
        
        if (is.null(width_info)) {
          cli_abort(c(
            "Invalid format for {.arg colWidth}:",
            x = "{.str {col_colwidth}} is not in a recognized format",
            i = "Use patterns like {.str 25%}, {.str 3.5cm}, {.str 10mm}, or {.str 1in}"
          ))
        }
        
        .validate_colwidth_minimum(width_info, col_colwidth)
        
        if (width_info$unit == "%") {
          .validate_relative_colwidth(spec, col_id, width_info$value, col_colwidth)
        }
        
        if (!is.null(spec$.metadata$colWidths[[col_id]])) {
          spec$.metadata$colWidths[[col_id]]$locked <- TRUE
          spec$.metadata$colWidths[[col_id]]$unit <- width_info$unit
          spec$.metadata$colWidths[[col_id]]$value <- width_info$value
        }
      }
    }
  }
  
  # If user set colWidth or changed visibility, and autoColWidth is enabled, recalculate remaining columns
  if (user_set_colwidth || user_changed_visibility) {
    auto_col_width <- tfl_get_option("autoColWidth")
    if (auto_col_width) {
      spec <- .recalculate_col_widths(spec)
    }
  }
  
  spec
}

#' Add a title
#'
#' Add a title to the specification. Multiple calls add multiple title groups.
#' Calling with the same ID merges with last-win strategy.
#'
#' @param spec TFL spec object.
#' @param text Character vector of title text lines. Multiple elements are
#'   rendered as separate lines within the same title paragraph.
#' @param id Title identifier (auto-generated if `NULL`).
#' @param styleRef Character vector of style names to apply. Styles are merged
#'   with last-win strategy.
#' @param order Integer ordering key (auto-assigned if `NULL`).
#' @param toclevel Optional integer 1--9. When set, the **first page** occurrence
#'   of this title is marked as a Table of Contents entry at the given level.
#'   Multi-line titles are concatenated with a space for the TOC entry text;
#'   inline styling tags (e.g. `<b>`, `<i>`) are stripped automatically.
#'
#'   To generate a TOC page, set `toclevel` here and either call
#'   `tfl_set_options(insertTOC = TRUE)` for the whole session or pass
#'   `insertTOC = TRUE` to `save_report()`. The renderer will prepend a
  #'   "Table of Contents" page with a `{ TOC \f \h \z }` field. Open the generated
#'   document in Word, click inside the TOC area, and press **F9** to populate it.
#'
#' @return Updated spec object.
#' @export
#'
#' @examples
#' \dontrun{
#' # Basic multi-line title (no TOC)
#' spec <- create_table(adsl) |>
#'   add_title(c("Study ABC-123", "Table 1: Demographics")) |>
#'   add_title("Full Analysis Set", styleRef = "subtitle_style")
#'
#' # Title marked for TOC at level 1 — renderer will emit a TC field on the first page
#' spec <- create_table(adsl) |>
#'   add_title("Table 1: Demographics", toclevel = 1)
#'
#' # Full TOC workflow across a multi-spec report
#' t1 <- create_table(adsl) |>
#'   add_title("Table 1: Demographics", toclevel = 1) |>
#'   set_document(hasData = TRUE)
#'
#' t2 <- create_table(advs) |>
#'   add_title("Table 2: Vital Signs", toclevel = 1) |>
#'   set_document(hasData = TRUE)
#'
#' report <- create_report(t1, t2)
#' save_report(report, docFileName = "tables.docx", insertTOC = TRUE)
#' # Open tables.docx in Word, click the TOC placeholder, press F9 to update.
#' }
add_title <- function(spec, text, id = NULL, styleRef = NULL, order = NULL, toclevel = NULL) {
  assert_class(spec, "TFL_spec")
  spec <- .add_text_group_impl(spec = spec, target = "titles", text = text, id = id,
                               styleRef = styleRef, order = order, toclevel = toclevel,
                               id_prefix = "title_", fn_name = "add_title")
  spec
}


# Internal helper for adding title/subtitle/footnote/body text groups for TFL_spec
.add_text_group_impl <- function(spec, target, text, id = NULL, styleRef = NULL, order = NULL,
                                toclevel = NULL,
                                id_prefix = NULL, fn_name = NULL,
                                remove_defaults = FALSE, default_prefix = NULL,
                                default_order = NULL, as_options_class = FALSE,
                                options_class = NULL) {
  if (isTRUE(remove_defaults) && !is.null(text) && !is.null(default_prefix)) {
    default_ids <- grep(paste0("^", default_prefix, "_"), names(spec[[target]]), value = TRUE)
    for (d in default_ids) {
      spec[[target]][[d]] <- NULL
    }
  }

  if (is.null(id)) {
    if (!is.null(id_prefix)) {
      id <- .auto_id(id_prefix, spec[[target]])
    } else if (!is.null(default_prefix)) {
      # generate __default_NNN style id
      id <- .generate_default_bodytext_id(spec[[target]])
    } else {
      cli_abort("Internal error: id_prefix or default_prefix required for .add_text_group_impl")
    }
  }

  if (is.null(order)) {
    if (!is.null(default_order)) {
      order <- as.integer(default_order)
    } else {
      order <- length(spec[[target]]) + 1L
    }
  }

  if (!is.null(toclevel)) {
    toc_int <- as.integer(toclevel)
    if (is.na(toc_int) || length(toc_int) != 1L || toc_int < 1L || toc_int > 9L) {
      cli_abort("{.arg toclevel} must be an integer between 1 and 9 in {.fn {fn_name}}")
    }
    toclevel <- toc_int
  }

  new_data <- list(
    text = as.character(text),
    styleRef = styleRef,
    order = as.integer(order),
    toclevel = toclevel
  )
  new_data <- new_data[!sapply(new_data, is.null)]

  .validate_params(new_data, "text_group", fn_name)
  spec[[target]][[id]] <- .merge_recursive(spec[[target]][[id]], new_data)

  if (isTRUE(as_options_class) && !is.null(options_class)) {
    class(spec) <- options_class
  }

  spec
}

#' Add a subtitle
#'
#' Add a subtitle to the specification. Multiple calls add multiple subtitle groups.
#' Calling with the same ID merges with last-win strategy.
#'
#' @param spec TFL spec object.
#' @param text Character vector of subtitle text lines. May contain `#ByGroup1`,
#'   `#ByGroup2`, … placeholders that are replaced at render time with the current
#'   value of the first, second, … grouping/paging column on each page.
#' @param id Subtitle identifier (auto-generated if `NULL`).
#' @param styleRef Character vector of style names to apply. Styles are merged
#'   with last-win strategy.
#' @param order Integer ordering key (auto-assigned if `NULL`).
#' @param toclevel Optional integer 1--9. When set, this subtitle is marked as a
#'   Table of Contents entry at the given level.
#'
#'   **Static subtitles** (no `#ByGroupX` placeholders): the TC entry is emitted
#'   only on the **first page** of the spec, producing a single TOC entry.
#'
#'   **Dynamic subtitles** (containing `#ByGroupX`): a TC entry is emitted on
#'   **every page**, so each distinct group value gets its own TOC entry. The
#'   resolved (substituted) text is used as the TOC entry text.
#'
#'   In both cases, multi-line subtitles are concatenated with a space and inline
#'   styling tags are stripped for the TOC entry text. Use together with
#'   `add_title(toclevel = )` and `tfl_set_options(insertTOC = TRUE)` or
#'   `save_report(insertTOC = TRUE)`.
#'
#' @return Updated spec object.
#' @export
#'
#' @examples
#' \dontrun{
#' # Static subtitle — one TOC entry for the whole report
#' spec <- create_table(adsl) |>
#'   add_title("Table 1: Demographics", toclevel = 1) |>
#'   add_subtitle("Safety Analysis Set", toclevel = 2) |>
#'   add_subtitle("Data Cutoff: 2025-12-14")
#'
#' # Dynamic subtitle — one TOC entry per group value (e.g. one per visit)
#' spec <- create_table(advs) |>
#'   add_title("Table 2: Vital Signs by Visit and Parameter", toclevel = 1) |>
#'   add_subtitle("#ByGroup1 - #ByGroup2", toclevel = 2)
#'
#' # Generate the TOC page
#' report <- create_report(spec)
#' save_report(report, docFileName = "tables.docx", insertTOC = TRUE)
#' # Open tables.docx in Word, click the TOC placeholder, press F9 to update.
#' }
add_subtitle <- function(spec, text, id = NULL, styleRef = NULL, order = NULL, toclevel = NULL) {
  assert_class(spec, "TFL_spec")
  spec <- .add_text_group_impl(spec = spec, target = "subtitles", text = text, id = id,
                               styleRef = styleRef, order = order, toclevel = toclevel,
                               id_prefix = "subtitle_", fn_name = "add_subtitle")
  spec
}




#' Add a footnote
#' 
#' Add a footnote to the specification. Multiple calls add multiple footnote groups.
#' Calling with the same ID merges with last-win strategy.
#' 
#' @param spec TFL spec object
#' @param text Character vector of footnote text lines
#' @param id Footnote identifier (auto-generated if NULL)
#' @param styleRef Character vector of style names or result of `f_combine()`. Merged with last-win strategy.
#' @param order Order of footnote group (auto-assigned if NULL)
#' 
#' @return Updated spec object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- create_text() |>
#'   add_footnote("Data source: Clinical database lock 2025-12-01") |>
#'   add_footnote("Missing values displayed as 'N/A'", styleRef = c("footnote_style", "emphasis"))
#' }
add_footnote <- function(spec, text, id = NULL, styleRef = NULL, order = NULL) {
  assert_class(spec, "TFL_spec")
  spec <- .add_text_group_impl(spec = spec, target = "footnotes", text = text, id = id,
                               styleRef = styleRef, order = order,
                               id_prefix = "footnote_", fn_name = "add_footnote")
  spec
}

#' Add body text
#' 
#' Add body text (e.g., when no data to display)
#' 
#' Generic function to add body text. Dispatches to class-specific methods,
#' allowing different spec classes to implement their own body text handling.
#' 
#' Multiple calls add multiple text groups. Calling with the same ID merges with last-win strategy.
#' 
#' @param spec Spec object (dispatches on class)
#' @param text Character vector of body text lines
#' @param id Body text identifier (auto-generated if NULL)
#' @param styleRef Character vector of style names or result of `f_combine()`. Merged with last-win strategy.
#' @param order Order of body text group (auto-assigned if NULL)
#'
#' @return Updated spec object
#' @export
#'
#' @examples
#' \dontrun{
#' spec <- create_text() |>
#'   set_document(hasData = FALSE) |>
#'   add_body_text("No data available for the specified criteria", styleRef = c("error_style", "bold"))
#' }
add_body_text <- function(spec = NULL, text = NULL, id = NULL, styleRef = NULL, order = NULL) {
  UseMethod("add_body_text", spec)
}

#' Add body text for TFL_spec
#' 
#' When adding body text to a spec that has default body text entries (IDs starting with __default_),
#' they are automatically removed to avoid mixing defaults with user-defined content.
#' 
#' @param spec TFL_spec object
#' @param text Character vector of body text lines
#' @param id Body text identifier (auto-generated if NULL)
#' @param styleRef Character vector of style names or result of `f_combine()`. Merged with last-win strategy.
#' @param order Order of body text group (auto-assigned if NULL)
#' @return Updated spec object
#' @export
add_body_text.TFL_spec <- function(spec, text = NULL, id = NULL, styleRef = NULL, order = NULL) {
  assert_class(spec, "TFL_spec")  
  # Auto-remove default body text entries when user adds custom content
  assert_class(spec, "TFL_spec")
  spec <- .add_text_group_impl(spec = spec, target = "bodyText", text = text, id = id,
                               styleRef = styleRef, order = order,
                               id_prefix = "body_", fn_name = "add_body_text",
                               remove_defaults = TRUE, default_prefix = .const_bodytext_default_id_prefix)
  spec
}

#' Add body text for TFL_options
#' 
#' When adding body text to TFL options (global settings), automatically removes any existing
#' default body text entries (__default_NNN) and starts adding new ones from __default_002 onwards.
#' 
#' @param spec TFL_options object
#' @param text Character vector of body text lines
#' @param id Body text identifier (auto-generated as __default_NNN if NULL)
#' @param styleRef Character vector of style names or result of `f_combine()`. Merged with last-win strategy.
#' @param order Order of body text group (auto-assigned if NULL)
#' @return Updated options object
#' @export
add_body_text.TFL_options <- function(spec, text = NULL, id = NULL, styleRef = NULL, order = NULL) {
  assert_class(spec, "TFL_options")
  spec <- .add_text_group_impl(spec = spec, target = "bodyText", text = text, id = id,
                               styleRef = styleRef, order = order,
                               id_prefix = NULL, fn_name = "add_body_text",
                               remove_defaults = TRUE, default_prefix = .const_bodytext_default_id_prefix,
                               default_order = .const_default_bodytext_order,
                               as_options_class = TRUE, options_class = "TFL_options_bodytext")
  spec
}

#' Default method for add_body_text
#' 
#' @param spec Spec object
#' @param text Character vector of body text lines
#' @param id Body text identifier
#' @param styleRef Character vector of style names or result of `f_combine()`. Merged with last-win strategy.
#' @param order Order of body text group
#' @return Error if no method found
#' @export
add_body_text.default <- function(spec, text = NULL, id = NULL, styleRef = NULL, order = NULL) {
  cli_abort(c(
    "No method for {.fn add_body_text} for class {.cls {class(spec)[1]}}",
    i = "Implement {.fn add_body_text.{class(spec)[1]}} to add body text support"
  ))
}

#' Add a header row
#' 
#' Generic function to add header rows. Dispatches to class-specific methods,
#' allowing headers to be added to both spec objects and global options.
#' 
#' Each call adds a new header row. Per schema, headers are arrays of arrays (each call = one row).
#' 
#' @param spec Spec object (dispatches on class)
#' @param ... Up to 3 character strings (left, center, right)
#' \itemize{
#'   \item Positional parts represent left, center and right header/footer cells respectively.
#'   \item Supply fewer than 3 parts if some cells should be empty; use empty string "" for explicit empties.
#'   \item Each call appends one header/footer row; use the `level` parameter to replace an existing row.
#' }
#' @param level Optional numeric index. If provided, replaces header at that row. If NULL, appends next row.
#' 
#' @return Updated spec object
#' @export
#' 
#' @examples
#' \dontrun{
#' # Add to a spec object
#' spec <- create_text() |>
#'   add_header("Study ABC-123", "CONFIDENTIAL", "Page {PAGE}") |>
#'   add_header("Protocol v2.0", "", "Date: {DATE}")
#' 
#' # Add to global options
#' options <- tfl_get_options()
#' options <- add_header(options, "Study ABC-123", "CONFIDENTIAL", "Page {PAGE}")
#' }
add_header <- function(spec = NULL, ..., level = NULL) {
  # Spec context: spec IS a TFL_spec or TFL_options object
  UseMethod("add_header", spec)
}


# Internal helper to add header/footer rows for both spec and options
.add_header_footer_impl <- function(spec, parts, target = c("headers", "footers"), level = NULL, as_options_class = NULL) {
  parts <- as.character(parts)

  if (length(parts) > .const_max_header_footer_parts) {
    cli_abort("{.fn add_header/add_footer} accepts maximum { .const_max_header_footer_parts} parts (left, center, right)")
  }

  if (!is.null(level)) {
    checkmate::assert_number(level, lower = 1, finite = TRUE)
    level <- as.integer(level)
    if (level <= length(spec[[target]])) {
      spec[[target]][[level]] <- parts
      return(spec)
    }
    # otherwise fall through and append
  }

  spec[[target]] <- c(spec[[target]] %||% list(), list(parts))

  if (!is.null(as_options_class) && as_options_class) {
    # For options variants, ensure class is set appropriately
    if (identical(target, "headers")) class(spec) <- "TFL_options_header"
    if (identical(target, "footers")) class(spec) <- "TFL_options_footer"
  }

  spec
}

#' Add a header row for TFL_spec
#' 
#' @param spec TFL_spec object
#' @param ... Up to 3 character strings (left, center, right)
#' \itemize{
#'   \item Positional parts represent left, center and right header/footer cells respectively.
#'   \item Supply fewer than 3 parts if some cells should be empty; use empty string "" for explicit empties.
#'   \item Each call appends one header/footer row; use the `level` parameter to replace an existing row.
#' }
#' @param level Optional numeric index. If provided, replaces header at that row. If NULL, appends next row.
#' @return Updated spec object
#' @export
add_header.TFL_spec <- function(spec, ..., level = NULL) {
  checkmate::assert_class(spec, "TFL_spec")
  header_parts <- as.character(c(...))
  .add_header_footer_impl(spec = spec, parts = header_parts, target = "headers", level = level)
}

#' Add a header row for TFL_options
#' 
#' Adds a header row to the global TFL options, which can be used as defaults
#' for all spec objects.
#' 
#' @param spec TFL_options object
#' @param ... Up to 3 character strings (left, center, right)
#' \itemize{
#'   \item Positional parts represent left, center and right header/footer cells respectively.
#'   \item Supply fewer than 3 parts if some cells should be empty; use empty string "" for explicit empties.
#'   \item Each call appends one header/footer row; use the `level` parameter to replace an existing row.
#' }
#' @param level Optional numeric index. If provided, replaces header at that row. If NULL, appends next row.
#' @return Updated options object
#' @export
add_header.TFL_options <- function(spec, ..., level = NULL) {
  checkmate::assert_class(spec, "TFL_options")
  header_parts <- as.character(c(...))
  .add_header_footer_impl(spec = spec, parts = header_parts, target = "headers", level = level, as_options_class = TRUE)
}

#' Default method for add_header
#' 
#' @param spec Spec object
#' @param ... Header parts
#' \itemize{
#'   \item Up to 3 positional character strings: left, center, right.
#'   \item Use an empty string "" to represent an empty cell.
#'   \item The `level` parameter can be used to replace an existing row instead of appending.
#' }
#' @return Error if no method found
#' @export
add_header.default <- function(spec, ...) {
  cli_abort(c(
    "No method for {.fn add_header} for class {.cls {class(spec)[1]}}",
    i = "Implement {.fn add_header.{class(spec)[1]}} to add header support"
  ))
}

#' Add a footer row
#' 
#' Generic function to add footer rows. Dispatches to class-specific methods,
#' allowing footers to be added to both spec objects and global options.
#' 
#' Each call adds a new footer row. Per schema, footers are arrays of arrays (each call = one row).
#' 
#' @param spec Spec object (dispatches on class)
#' @param ... Up to 3 character strings (left, center, right)
#' \itemize{
#'   \item Positional parts represent left, center and right header/footer cells respectively.
#'   \item Supply fewer than 3 parts if some cells should be empty; use empty string "" for explicit empties.
#'   \item Each call appends one header/footer row; use the `level` parameter to replace an existing row.
#' }
#' @param level Optional numeric index. If provided, replaces footer at that row. If NULL, appends next row.
#' 
#' @return Updated spec object
#' @export
#' 
#' @examples
#' \dontrun{
#' # Add to a spec object
#' spec <- create_text() |>
#'   add_footer("Company Name", "", "Page {PAGE} of {NUMPAGES}") |>
#'   add_footer("", "Confidential", "")
#' 
#' # Add to global options
#' options <- tfl_get_options()
#' options <- add_footer(options, "Company Name", "", "Page {PAGE} of {NUMPAGES}")
#' }
add_footer <- function(spec = NULL, ..., level = NULL) {
  # Spec context: spec IS a TFL_spec or TFL_options object
  UseMethod("add_footer", spec)
}

#' Add a footer row for TFL_spec
#' 
#' @param spec TFL_spec object
#' @param ... Up to 3 character strings (left, center, right)
#' \itemize{
#'   \item Positional parts represent left, center and right header/footer cells respectively.
#'   \item Supply fewer than 3 parts if some cells should be empty; use empty string "" for explicit empties.
#'   \item Each call appends one header/footer row; use the `level` parameter to replace an existing row.
#' }
#' @param level Optional numeric index. If provided, replaces footer at that row. If NULL, appends next row.
#' @return Updated spec object
#' @export
add_footer.TFL_spec <- function(spec, ..., level = NULL) {
  checkmate::assert_class(spec, "TFL_spec")
  footer_parts <- as.character(c(...))
  .add_header_footer_impl(spec = spec, parts = footer_parts, target = "footers", level = level)
}

#' Add a footer row for TFL_options
#' 
#' Adds a footer row to the global TFL options, which can be used as defaults
#' for all spec objects.
#' 
#' @param spec TFL_options object
#' @param ... Up to 3 character strings (left, center, right)
#' @param level Optional numeric index. If provided, replaces footer at that row. If NULL, appends next row.
#' @return Updated options object
#' @export
add_footer.TFL_options <- function(spec, ..., level = NULL) {
  checkmate::assert_class(spec, "TFL_options")
  footer_parts <- as.character(c(...))
  .add_header_footer_impl(spec = spec, parts = footer_parts, target = "footers", level = level, as_options_class = TRUE)
}

#' Default method for add_footer
#' 
#' @param spec Spec object
#' @param ... Footer parts
#' \itemize{
#'   \item Up to 3 positional character strings: left, center, right.
#'   \item Use an empty string "" to represent an empty cell.
#'   \item The `level` parameter can be used to replace an existing row instead of appending.
#' }
#' @return Error if no method found
#' @export
add_footer.default <- function(spec, ...) {
  cli_abort(c(
    "No method for {.fn add_footer} for class {.cls {class(spec)[1]}}",
    i = "Implement {.fn add_footer.{class(spec)[1]}} to add footer support"
  ))
}

#' Add stub (spanning) column definition
#' 
#' Define a spanning header that covers multiple columns. Can be used to create
#' multi-level headers by specifying different `stubOrder` values.
#' 
#' @param spec TFL spec object
#' @param cols Columns to span using tidyselect syntax. Accepts:
#'   \itemize{
#'     \item Named columns: \code{c("age", "sex")}
#'     \item Column ranges: \code{age:sex}
#'     \item Helper functions: \code{starts_with("age_")}, \code{contains("_pct")}
#'     \item Negation: \code{-id} or \code{!matches("^temp")}
#'   }
#' @param label Spanning header label
#' @param stubOrder Order of stub header (auto-generated if NULL). Used to create
#'   multi-level headers: lower numbers appear abbelowove higher numbers. Multiple stubs
#'   at the same order are allowed if their column sets do not overlap.
#' @param id Stub column identifier (auto-generated if NULL)
#' @param labelStyleRef List of style names to be applied. Provided styles will be merged with last-win strategy for report
#' 
#' @return Updated spec object
#' @export
#' 
#' @details
#' ## Column Overlap Rules
#' 
#' Stubs at the **same** `stubOrder` cannot share columns (to avoid ambiguous headers).
#' However, stubs at **different** `stubOrder` values can overlap freely.
#'
#' This allows hierarchical header structures:
#' - `stubOrder = 1`: first-level grouping above the column headers
#' - `stubOrder = 2`: next-level grouping above the first-level etc..
#'
#'
#' @examples
#' \dontrun{
#' data <- data.frame(
#'   id = 1:10, 
#'   age = rnorm(10, 45, 10), 
#'   sex = sample(c("M", "F"), 10, TRUE),
#'   weight = rnorm(10, 70, 10),
#'   height = rnorm(10, 170, 10)
#' )
#' 
#' # Example 1: Single-level spanning header
#' spec <- create_table(data) |>
#'   add_span_header(
#'     cols = c(age, sex),  # Using tidyselect (unquoted column names)
#'     label = "Demographics",
#'     labelStyleRef = c("stub_label_style", "bold")
#'   )
#'
#' # Example 2: Two-level header hierarchy
#' spec <- create_table(data) |>
#'   add_span_header(cols = c(age, sex, weight, height), label = "All Measurements", stubOrder = 0) |>
#'   add_span_header(cols = c(age, sex), label = "Demographics", stubOrder = 1) |>
#'   add_span_header(cols = c(weight, height), label = "Physical", stubOrder = 1)
#'
#' # Example 3: Three-level header hierarchy
#' spec <- create_table(data) |>
#'   add_span_header(cols = starts_with("a") | starts_with("w") | starts_with("h"), 
#'                   label = "Main Data", stubOrder = 0) |>
#'   add_span_header(cols = c(age, sex), label = "Demographics", stubOrder = 1) |>
#'   add_span_header(cols = c(weight, height), label = "Physical", stubOrder = 1) |>
#'   add_span_header(cols = age, label = "Age Details", stubOrder = 2)
#'
#' # Example 4: Using tidyselect helpers
#' spec <- create_table(data) |>
#'   add_span_header(cols = contains("age"), label = "Age-related", stubOrder = 0) |>
#'   add_span_header(cols = matches("^w"), label = "Weight", stubOrder = 0)
#'
#' # Example 5: Negation to exclude columns
#' spec <- create_table(data) |>
#'   add_span_header(cols = -id, label = "Measurements", stubOrder = 0)
#'
#' # Example 6: Multiple non-overlapping stubs at same level
#' spec <- create_table(data) |>
#'   add_span_header(cols = c(age, sex), label = "Group1", stubOrder = 1) |>
#'   add_span_header(cols = c(weight, height), label = "Group2", stubOrder = 1)  # OK: no overlap
#' }
#' 
#' @details
#' Multiple calls with the same `stubOrder` are allowed as long as their column sets 
#' do not overlap. This enables building complex header structures incrementally.
add_span_header <- function(spec, cols, label, stubOrder = NULL, id = NULL, 
                            labelStyleRef = NULL) {
  assert_class(spec, "TFL_spec")
  
  # Process tidyselect expressions
  cols <- enquos(cols)
  cols <- .get_data_column_names(spec$.metadata$data_env$`__data__`, !!!cols)
  
  cols <- intersect(cols, names(spec$columns))  # keep only columns that exist in spec definition
  assert_character(cols, min.len = 1)
  
  if (is.null(id)) {
    id <- .auto_id("stub_", spec$stubColumns)
  }
  
  # Validate required fields
  required <- c("cols", "label")
  provided <- list(cols = cols, label = label)
  .validate_required(provided, required, "add_span_header")
  
  # Auto-generate stubOrder if NULL
  if (is.null(stubOrder)) {
    stubOrder <- .auto_stub_order(spec$stubColumns)
  } else {
    stubOrder <- as.integer(stubOrder)
  }
  
  # Check for overlapping columns at the same stubOrder (duplicates allowed if no overlap)
  for (existing_id in names(spec$stubColumns)) {
    existing <- spec$stubColumns[[existing_id]]
    if (existing$stubOrder == stubOrder) {
      overlap <- intersect(cols, existing$cols)
      if (length(overlap) > 0) {
        cli_abort(c(
          "Column overlap detected in stub columns at order {stubOrder}:",
          x = "Columns {paste(overlap, collapse = ', ')} already in stub '{existing_id}'",
          i = "Multiple stubs with the same order are allowed only if their column sets do not overlap"
        ))
      }
    }
  }
  
  params <- list(
    label = label,
    labelStyleRef = labelStyleRef,
    stubOrder = as.integer(stubOrder),
    cols = as.character(cols)
  )

  # Resolve labelStyleRef mapping for the stub (single element expected)
  if (!is.null(labelStyleRef)) {
    resolved <- ._resolve_style_refs(labelStyleRef, 1, "labelStyleRef")
    params$labelStyleRef <- resolved[[1]]
  }

  # Validate params against schema (stub_column)
  .validate_params(params, "stub_column", "add_span_header")

  # Merge with existing stub if present
  spec$stubColumns[[id]] <- .merge_recursive(spec$stubColumns[[id]], params)

  spec
}

#' Set document properties
#'
#' Define document-level properties. Multiple calls merge with last-win strategy.
#' Document type (`docType`) is set automatically by `create_table()`,
#' `create_figure()`, or `create_text()` and cannot be changed here. Global
#' document order (`docOrder`) is assigned by `create_report()`.
#'
#' @param spec TFL spec object
#' @param isContinues Whether page breaks should be ignored
#' @param contentWidth Width of content, e.g. "100%", "25cm", "10in"
#' @param footnotePlace Character; controls where footnotes are rendered.
#'   One of `"doc_footer"` (place inside the Word footer, below footer rows),
#'   `"repeated"` (place under the table on every page),
#'   or `"last_page"` (place under the table on the last page only).
#'   Default `"repeated"`.
#' @param hasData Whether document has data to report
#' @param docTemplate Character. Template to use for rendering. Accepts either:
#'   \itemize{
#'     \item Name of a bundled template (see `tfl_list_templates()`).
#'     \item Full path to a custom styles JSON file.
#'   }
#' 
#' @return Updated spec object
#' @export
#'
#' @examples
#' \dontrun{
#' spec <- create_text() |>
#'   set_document(
#'     hasData = TRUE
#'   )
#' }
set_document <- function(spec, isContinues = NULL, contentWidth = NULL,
                         footnotePlace = NULL, hasData = NULL,
                         docTemplate = NULL) {
  assert_class(spec, "TFL_spec")
  
  
  if (is.null(hasData) & is.null(spec$document$hasData)) {
    cli_warn(c(
      "hasData not specified in {.fn set_document}",
      i = "Set hasData = TRUE if there is data to report, FALSE otherwise"
    ))
  }
  
  params <- list(
    isContinues = isContinues,
    contentWidth = contentWidth,
    footnotePlace = footnotePlace,
    hasData = hasData
  )
  params <- params[!sapply(params, is.null)]
  
  # Validate
  .validate_params(params, "document", "set_document")
  
  if (!is.null(contentWidth)) {
    .validate_pattern(contentWidth, .const_pattern_content_width, 
                      "contentWidth", "set_document",
                      "Must be like '100%', '6.5in', or '16.51cm'")
  }
  
  # Merge with last-win
  spec$document <- .merge_recursive(spec$document, params)

  if (!is.null(docTemplate)) {
    set_page_style(spec, docTemplate = docTemplate)
  } else {
    spec
  }
}

#' Set document style properties
#'
#' Set document-level style configuration. Multiple calls merge with last-win strategy.
#'
#' @param spec TFL spec object
#' @param docTemplate Character. Template to use for rendering. Accepts either:
#'   \itemize{
#'     \item A predefined bundled template name (e.g. `"KeyStat_default"`, `"Navy_Pro"`).
#'       Use \code{tfl_list_templates()} to see all available names.
#'     \item A file path (absolute or relative) to an external template JSON file.
#'       The path must point to an existing file conforming to \code{styles_schema_v1.json}.
#'   }
#'   When \code{NULL} (default) the current session template is used.
#' @param page Page settings object created with \code{\link{p_page}} or a list with keys: size, orientation, margins
#'
#' @return Updated spec object
#' @export
#'
#' @examples
#' \dontrun{
#' # Use a predefined bundled template
#' spec <- create_text() |>
#'   set_page_style(
#'     docTemplate = "Navy_Pro",
#'     page = p_page(size = "A4", orientation = "landscape")
#'   )
#'
#' # Use an external template file
#' spec <- create_text() |>
#'   set_page_style(docTemplate = "/path/to/my_template.json")
#' }
set_page_style <- function(spec, docTemplate = NULL, page = NULL) {
  UseMethod("set_page_style", spec)
}

#' @rdname set_page_style
#' @export
set_page_style.TFL_spec <- function(spec, docTemplate = NULL, page = NULL) {
  assert_class(spec, "TFL_spec")
  
  # Set context in the current call frame so nested p_* helpers can detect it
  .frame_env <- sys.frame()
  .set_context(.frame_env, "set_page_style")
  on.exit(.clear_context(.frame_env))
  
  params <- list()
  
  if (!is.null(docTemplate)) {
    checkmate::assert_string(docTemplate, .var.name = "docTemplate")
    is_file_path <- grepl("[/\\\\]", docTemplate) || grepl("\\.json$", docTemplate, ignore.case = TRUE)
    if (is_file_path && !file.exists(docTemplate)) {
      cli_abort(c(
        "{.fn set_page_style} cannot find the external template file.",
        x = "File not found: {.path {docTemplate}}",
        i = "Provide a valid file path or use a predefined template name (see {.fn tfl_list_templates})"
      ))
    }
    params$docTemplate <- docTemplate
  }
  
  if (!is.null(page)) {
    # Extract nested specs
    if (inherits(page, "tfl_page")) {
      page <- unclass(page)
    } else if (is.list(page)) {
      .validate_params(page, "page", "set_page_style")
    } else {
      cli_abort(c(
        "{.fn set_page_style} requires {.arg page} created by {.fn p_page} or a list with keys: ",
        paste0("{.arg ", .get_allowed_properties("page"), "}", collapse = ", ")
      ))
    }
    
    # Validate nested shapes
    if (!is.null(page$margins)) {
      .validate_params(page$margins, "margins", "set_page_style$page.margins")
    }
    
    params$page <- page
  }
  
  # Validate params against schema
  .validate_params(params, "documentStyle", "set_page_style")
  
  spec$attribs$documentStyle <- .merge_recursive(spec$attribs$documentStyle, params)
  
  spec
}

#' @rdname set_page_style
#' @export
set_page_style.TFL_options <- function(spec, docTemplate = NULL, page = NULL) {
  assert_class(spec, "TFL_options")
  
  # Set context in the current call frame so nested p_* helpers can detect it
  .frame_env <- sys.frame()
  .set_context(.frame_env, "set_page_style")
  on.exit(.clear_context(.frame_env))
  
  params <- list()
  
  if (!is.null(docTemplate)) {
    checkmate::assert_string(docTemplate, .var.name = "docTemplate")
    is_file_path <- grepl("[/\\\\]", docTemplate) || grepl("\\.json$", docTemplate, ignore.case = TRUE)
    if (is_file_path && !file.exists(docTemplate)) {
      cli_abort(c(
        "{.fn set_page_style} cannot find the external template file.",
        x = "File not found: {.path {docTemplate}}",
        i = "Provide a valid file path or use a predefined template name (see {.fn tfl_list_templates})"
      ))
    }
    params$docTemplate <- docTemplate
  }
  
  if (!is.null(page)) {
    # Extract nested specs
    if (inherits(page, "tfl_page")) {
      page <- unclass(page)
    } else if (is.list(page)) {
      .validate_params(page, "page", "set_page_style")
    } else {
      cli_abort(c(
        "{.fn set_page_style} requires {.arg page} created by {.fn p_page} or a list with keys: ",
        paste0("{.arg ", .get_allowed_properties("page"), "}", collapse = ", ")
      ))
    }
    
    # Validate nested shapes
    if (!is.null(page$margins)) {
      .validate_params(page$margins, "margins", "set_page_style$page.margins")
    }
    
    params$page <- page
  }
  
  # Validate params against schema
  .validate_params(params, "documentStyle", "set_page_style")
  
  spec$attribs$documentStyle <- .merge_recursive(spec$attribs$documentStyle, params)
  class(spec) <- "TFL_options_pagestyle"
  spec
}

#' Resolve styleRef-like inputs into a list matching number of columns
#'
#' Internal helper used by column/label style resolution.
#'
#' @details
#' \itemize{
#'   \item NULL: returns a list of NULLs
#'   \item Character vector: recycled to all columns
#'   \item List of character vectors: returned as-is when length == num_cols or recycled when length == 1
#' }
#'
#' @param style_refs NULL, character vector, or list of character vectors
#' @param num_cols Integer number of columns to expand/recycle to
#' @param param_name Parameter name used in error messages (default: "styleRef")
#' @keywords internal
#' @noRd 
._resolve_style_refs <- function(style_refs, num_cols, param_name = "styleRef") {
  # Memoization: cache results for repeated calls with identical inputs
  cache_key <- paste0(
    digest::digest(style_refs, algo = "xxhash32"),
    "_",
    num_cols,
    "_",
    param_name
  )
  
  if (exists(cache_key, envir = .style_resolution_cache, inherits = FALSE)) {
    return(get(cache_key, envir = .style_resolution_cache, inherits = FALSE))
  }
  
  # Compute result
  result <- NULL
  
  if (is.null(style_refs) || identical(style_refs, NA)) {
    # NULL and bare NA both mean "no style / do nothing for all columns"
    result <- rep(list(NULL), num_cols)
  } else if (is.character(style_refs)) {
    # Case 1: Character vector (single style name or f_combine result)
    # Recycle to all columns.  Per-column NA skipping uses a list (see Case 2).
    result <- rep(list(style_refs), num_cols)
  } else if (is.list(style_refs)) {
    # Case 2: List (assumed to be from f_combine results or explicit mapping)
    # Validate all elements are NULL, NA (skip sentinel), or character vectors.
    for (i in seq_along(style_refs)) {
      el <- style_refs[[i]]
      if (!is.null(el) && !identical(el, NA) && !is.character(el)) {
        cli_abort(c(
          "Element {i} of {param_name} list must be NULL, NA, or character vector",
          i = "Got: {.cls {class(el)[1]}}"
        ))
      }
    }
    
    # Check if this is a mapping (one element per column) or recycling (one element)
    if (length(style_refs) == 1) {
      # Single element - recycle to all columns
      result <- rep(list(style_refs[[1]]), num_cols)
    } else if (length(style_refs) == num_cols) {
      # One-to-one mapping
      result <- style_refs
    } else {
      # Length mismatch
      cli_abort(c(
        "Length of {param_name} list ({length(style_refs)}) must equal 1 or {num_cols} (number of columns)",
        i = "For recycling a single mapping, use: {.fn f_combine}(...)",
        i = "For explicit mapping, provide exactly {num_cols} elements in a list or vector"
      ))
    }
  } else {
    # Invalid type
    cli_abort(c(
      "{param_name} must be NULL, a character vector, or a list of character vectors",
      i = "Got: {.cls {class(style_refs)[1]}}"
    ))
  }
  
  # Cache and return
  assign(cache_key, result, envir = .style_resolution_cache)
  result
}

#' Validate TFL specification for consistency
#' 
#' Performs additional consistency checks beyond schema validation.
#' 
#' @param spec TFL spec object
#' @param verbose Whether to show validation details
#' @return Logical indicating if all checks passed
#' @keywords internal
#' @noRd
#' @examples
#' \dontrun{
#' spec <- create_text() |>
#'   set_document(docType = "Table", hasData = TRUE)
#'   
#' check_spec_consistency(spec)
#' }
.check_spec_consistency <- function(spec, verbose = TRUE) {
  if (!inherits(spec, "TFL_spec")) {
    cli_abort("Object must be of class 'TFL_spec'")
  }
  
  issues <- list()
  
  # Check that required document fields are set
  if (is.null(spec$document$docType)) {
    issues <- c(issues, "Document type (docType) is not set")
  }
  
  if (is.null(spec$document$hasData)) {
    issues <- c(issues, "Data availability (hasData) is not set")
  }
  
  # Check style references exist in text groups
  check_style_refs <- function(text_groups, group_name) {
    for (id in names(text_groups)) {
      style_refs <- text_groups[[id]]$styleRef
      if (!is.null(style_refs)) {
        # Convert to vector if it's a single string (for backwards compatibility)
        if (!is.list(style_refs) && length(style_refs) == 1 && is.character(style_refs)) {
          style_refs <- list(style_refs)
        }
        # Check each style reference
        if (is.list(style_refs) || is.character(style_refs)) {
          for (style_ref in if (is.list(style_refs)) style_refs else list(style_refs)) {
            if (!is.null(style_ref) && !style_ref %in% names(spec$attribs$styles)) {
              issues <<- c(issues, 
                           paste0("Style reference '", style_ref, "' in ", group_name, 
                                  " '", id, "' not found in defined styles"))
            }
          }
        }
      }
    }
  }
  
  check_style_refs(spec$titles, "title")
  check_style_refs(spec$subtitles, "subtitle")
  check_style_refs(spec$footnotes, "footnote")
  check_style_refs(spec$bodyText, "body text")
  
  # Check column style references
  for (col_id in names(spec$columns)) {
    col <- spec$columns[[col_id]]
    
    # Check labelStyleRef (now array)
    if (!is.null(col$labelStyleRef)) {
      label_refs <- if (is.character(col$labelStyleRef) && length(col$labelStyleRef) > 0) {
        col$labelStyleRef
      } else if (is.list(col$labelStyleRef)) {
        unlist(col$labelStyleRef)
      } else {
        NULL
      }
      
      if (!is.null(label_refs)) {
        for (style_ref in label_refs) {
          if (!style_ref %in% names(spec$attribs$styles)) {
            issues <- c(issues, 
                        paste0("Column label style reference '", style_ref, 
                               "' for column '", col_id, "' not found in defined styles"))
          }
        }
      }
    }
    
    # Check valueStyleRef (now array)
    if (!is.null(col$format$valueStyleRef)) {
      value_refs <- if (is.character(col$format$valueStyleRef) && length(col$format$valueStyleRef) > 0) {
        col$format$valueStyleRef
      } else if (is.list(col$format$valueStyleRef)) {
        unlist(col$format$valueStyleRef)
      } else {
        NULL
      }
      
      if (!is.null(value_refs)) {
        for (style_ref in value_refs) {
          if (!style_ref %in% names(spec$attribs$styles)) {
            issues <- c(issues, 
                        paste0("Column value style reference '", style_ref, 
                               "' for column '", col_id, "' not found in defined styles"))
          }
        }
      }
    }
  }
  
  # Check stub column style references
  for (stub_id in names(spec$stubColumns)) {
    stub <- spec$stubColumns[[stub_id]]
    
    # Check labelStyleRef (now array)
    if (!is.null(stub$labelStyleRef)) {
      label_refs <- if (is.character(stub$labelStyleRef) && length(stub$labelStyleRef) > 0) {
        stub$labelStyleRef
      } else if (is.list(stub$labelStyleRef)) {
        unlist(stub$labelStyleRef)
      } else {
        NULL
      }
      
      if (!is.null(label_refs)) {
        for (style_ref in label_refs) {
          if (!style_ref %in% names(spec$attribs$styles)) {
            issues <- c(issues, 
                        paste0("Stub label style reference '", style_ref, 
                               "' for stub '", stub_id, "' not found in defined styles"))
          }
        }
      }
    }
  }
  
  # Check that columns referenced in stubs exist
  for (stub_id in names(spec$stubColumns)) {
    stub <- spec$stubColumns[[stub_id]]
    missing_cols <- setdiff(stub$cols, names(spec$columns))
    if (length(missing_cols) > 0) {
      issues <- c(issues, 
                  paste0("Columns referenced in stub '", stub_id, "' not found: ",
                         paste(missing_cols, collapse = ", ")))
    }
  }
  
  # NOTE: Duplicates of stubOrder are acceptable; only flag overlaps at same order.
  # Overlap detection is already done at add time. Here we can double-check:
  order_groups <- split(spec$stubColumns, sapply(spec$stubColumns, function(x) x$stubOrder))
  for (order_val in names(order_groups)) {
    group <- order_groups[[order_val]]
    col_sets <- lapply(group, function(x) x$cols)
    all_cols <- unlist(col_sets, use.names = FALSE)
    dup_cols <- unique(all_cols[duplicated(all_cols)])
    if (length(dup_cols) > 0) {
      stubs_with_dup <- names(group)[sapply(group, function(x) any(dup_cols %in% x$cols))]
      issues <- c(issues,
                  paste0("Stub order ", order_val, " has overlapping columns: ",
                         paste(dup_cols, collapse = ", "),
                         " used by stubs ", paste(stubs_with_dup, collapse = ", ")))
    }
  }
  
  # Report issues
  if (length(issues) > 0) {
    if (verbose) {
      cli_warn(c(
        "Specification consistency issues found:",
        paste0("!", " ", issues)
      ))
    }
    return(FALSE)
  }
  
  if (verbose) {
    cli_alert_success("All consistency checks passed")
  }
  
  TRUE
}



