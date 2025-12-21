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
.set_context <- function(env, context) {
  assign(".__tfl_context__", context, envir = env)
  invisible(NULL)
}

#' Clear context marker from environment
#' 
#' @param env Environment to clear context from
#' @keywords internal
.clear_context <- function(env) {
  if (exists(".__tfl_context__", envir = env)) {
    remove(".__tfl_context__", envir = env)
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
  
  if (!grepl(pattern, value)) {
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
.validate_color <- function(value, param_name, fn_name, description = NULL) {
  if (is.null(value)) {
    return(invisible(NULL))
  }
  
  if (!is.character(value) || length(value) != 1) {
    cli_abort("{.arg {param_name}} must be a single character string in {.fn {fn_name}}")
  }
  
  # Check if it's a hex code
  if (grepl(.const_pattern_hex_color, value)) {
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
.normalize_color <- function(color) {
  if (is.null(color)) {
    return(NULL)
  }
  
  # Check if it's already a hex code
  if (grepl(.const_pattern_hex_color, color)) {
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
.col_format_spec <- function(type=NULL, format = NULL, missings = NULL, 
                             colWidth = NULL, valueStyleRef = NULL) {
  .validate_enum(type, .const_column_types, "type", "col_format_spec")
  
  params <- list(type = type)
  
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
  .set_context(parent.frame(), "s_paragraph")
  on.exit(.clear_context(parent.frame()))
  
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
  .set_context(parent.frame(), "s_borders")
  on.exit(.clear_context(parent.frame()))
  
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
  .set_context(parent.frame(), "s_table_style")
  on.exit(.clear_context(parent.frame()))
  
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
  .set_context(parent.frame(), "p_page")
  on.exit(.clear_context(parent.frame()))
  
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

#' Combine Multiple Style Names
#' 
#' Helper function to explicitly group multiple style names together for assignment to a single element.
#' Useful with \code{\link{define_cols}} when mapping different styles to different columns.
#' 
#' @param ... Character strings representing style names to combine
#' \itemize{
#'   \item Each argument must be a single character string naming a style declared via `add_style()`.
#'   \item Use `f_combine()` to group multiple style names that should be applied together.
#'   \item The returned value is a character vector (or object of class `tfl_style_combine` in some variants).
#' }
#' 
#' @return A character vector of style names
#' @export
#' 
#' @examples
#' \dontrun{
#' # All columns get both styles
#' spec <- create_table(data) |>
#'   define_cols(c("age", "sex"),
#'     labelStyleRef = f_combine("label_style", "emphasis")
#'   )
#' 
#' # Different styles for different columns
#' spec <- create_table(data) |>
#'   define_cols(c("age", "sex"),
#'     labelStyleRef = c(
#'       f_combine("age_label_style", "numeric_emphasis"),
#'       f_combine("sex_label_style", "categorical_emphasis")
#'     )
#'   )
#' }
f_combine <- function(...) {
  styles <- list(...)
  
  # Ensure all arguments are character strings
  for (i in seq_along(styles)) {
    if (!is.character(styles[[i]]) || length(styles[[i]]) != 1) {
      cli_abort(c(
        "{.fn f_combine} requires character string arguments",
        x = "Argument {i} is not a single character string",
        i = "Use: {.fn f_combine}('style1', 'style2', ...)"
      ))
    }
  }
  
  # Return as character vector
  as.character(styles)
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
  
  # Set context in the calling environment
  .set_context(parent.frame(), "add_style")
  on.exit(.clear_context(parent.frame()))
  
  # Capture modifiers
  modifiers <- list(...)
  
  # Process each modifier
  for (mod in modifiers) {
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
  
  # Set context in the calling environment
  .set_context(parent.frame(), "add_style")
  on.exit(.clear_context(parent.frame()))
  
  # Capture modifiers
  modifiers <- list(...)
  
  # Process each modifier
  for (mod in modifiers) {
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
#' @return Object of class "tfl_style_combine" (character vector with special class)
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
#' @param label Column label (length 1 or length of cols)
#' @param isID Whether column is identifier (length 1 or length of cols)
#' @param isVisible Whether column is visible (length 1 or length of cols)
#' @param isGrouping Whether column defines groups (length 1 or length of cols)
#' @param isPaging Whether column defines pages (length 1 or length of cols)
#' @param labelStyleRef List of style names to be applied. Provided styles will be merged with last-win strategy for report. 
#'   Can be: single string (recycled), character vector from \code{\link{f_combine}} (recycled), 
#'   or list of \code{\link{f_combine}} results (one-to-one mapping to columns)
#' @param isColBreak Whether column triggers page break (length 1 or length of cols)
#' @param dedupe Whether to deduplicate values (length 1 or length of cols)
#' @param blankAfter Whether to add blank after value change (length 1 or length of cols)
#' @param type Data type for column format: "string" or "numeric" (length 1 or length of cols). Optional; omit to preserve existing.
#' @param format Format string for numeric data (sprintf style), e.g. "%.1f" (length 1 or length of cols). Optional.
#' @param missings How to display missing values in columns (length 1 or length of cols). Optional.
#' @param colWidth Column width, e.g. "2in", "5cm", "20%" (length 1 or length of cols). Optional.
#' @param valueStyleRef Style names to apply to cell values. Provided styles will be merged with last-win strategy for report. 
#'   Can be: single string (recycled), character vector from \code{\link{f_combine}} (recycled), 
#'   or list of \code{\link{f_combine}} results (one-to-one mapping to columns). Optional.
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
  
  # Track if user is setting colWidth so we can trigger recalculation later
  user_set_colwidth <- !is.null(colWidth)
  
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
        # For labelStyleRef, it's already a list from ._resolve_style_refs
        if (pname == "labelStyleRef") {
          col_params[[pname]] <- pval[[i]]
        } else {
          col_params[[pname]] <- if (length(pval) == 1) pval else pval[i]
        }
      }
    }
    
    # Build format spec for this column if any format params are provided
    if (length(format_params_list) > 0 || !is.null(resolved_valuestyleref)) {
      # Extract values for this column with 1-or-n recycling
      col_format_params <- list()
      for (fpname in names(format_params_list)) {
        fpval <- format_params_list[[fpname]]
        col_format_params[[fpname]] <- if (length(fpval) == 1) fpval else fpval[i]
      }
      
      # Add resolved valueStyleRef for this column (already resolved as a list)
      if (!is.null(resolved_valuestyleref)) {
        col_format_params$valueStyleRef <- resolved_valuestyleref[[i]]
      }
      
      # Create format spec using .col_format_spec()
      format_spec <- do.call(.col_format_spec, col_format_params)
      
      # Merge with existing format
      existing_format <- spec$columns[[col_id]]$format
      col_params$format <- .merge_recursive(existing_format, format_spec)
    }
    
    # Validate known keys for column
    .validate_params(col_params, "column", "define_cols")
    
    # Merge with last-win
    spec$columns[[col_id]] <- .merge_recursive(spec$columns[[col_id]], col_params)
    
    # If user set colWidth, update metadata to mark as locked
    if (user_set_colwidth && !is.null(colWidth)) {
      col_colwidth <- if (length(colWidth) == 1) colWidth else colWidth[i]
      # Extract unit and value from colWidth
      width_info <- .parse_colwidth(col_colwidth)
      
      # Validate colWidth format
      if (is.null(width_info)) {
        cli_abort(c(
          "Invalid format for {.arg colWidth}:",
          x = "{.str {col_colwidth}} is not in a recognized format",
          i = "Use patterns like {.str 25%}, {.str 3.5cm}, {.str 10mm}, or {.str 1in}"
        ))
      }
      
      if (!is.null(spec$.metadata$colWidths[[col_id]])) {
        spec$.metadata$colWidths[[col_id]]$locked <- TRUE
        spec$.metadata$colWidths[[col_id]]$unit <- width_info$unit
        spec$.metadata$colWidths[[col_id]]$value <- width_info$value
      }
    }
  }
  
  # If user set colWidth and autoColWidth is enabled, recalculate remaining columns
  if (user_set_colwidth) {
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
#' @param spec TFL spec object
#' @param text Character vector of title text lines
#' @param id Title identifier (auto-generated if NULL)
#' @param styleRef List of style names to be applied. Provided styles will be merged with last-win strategy for report
#' @param order Order of title group (auto-assigned if NULL)
#' 
#' @return Updated spec object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- create_text() |>
#'   add_title(c("Study ABC-123", "Demographics Table")) |>
#'   add_title("Full Analysis Set", styleRef = c("subtitle_style", "emphasis"))
#' }
add_title <- function(spec, text, id = NULL, styleRef = NULL, order = NULL) {
  assert_class(spec, "TFL_spec")
  
  if (is.null(id)) {
    id <- .auto_id("title_", spec$titles)
  }
  
  if (is.null(order)) {
    order <- length(spec$titles) + 1L
  }
  
  new_data <- list(
    text = as.character(text),
    styleRef = styleRef,
    order = as.integer(order)
  )
  new_data <- new_data[!sapply(new_data, is.null)]
  
  # Merge with existing if ID exists
  .validate_params(new_data, "text_group", "add_title")
  spec$titles[[id]] <- .merge_recursive(spec$titles[[id]], new_data)
  
  spec
}

#' Add a subtitle
#' 
#' Add a subtitle to the specification. Multiple calls add multiple subtitle groups.
#' Calling with the same ID merges with last-win strategy.
#' 
#' @param spec TFL spec object
#' @param text Character vector of subtitle text lines
#' @param id Subtitle identifier (auto-generated if NULL)
#' @param styleRef List of style names to be applied. Provided styles will be merged with last-win strategy for report
#' @param order Order of subtitle group (auto-assigned if NULL)
#' 
#' @return Updated spec object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- create_text() |>
#'   add_subtitle("Safety Analysis Set") |>
#'   add_subtitle("Data Cutoff: 2025-12-14", styleRef = "footnote_style")
#' }
add_subtitle <- function(spec, text, id = NULL, styleRef = NULL, order = NULL) {
  assert_class(spec, "TFL_spec")
  
  if (is.null(id)) {
    id <- .auto_id("subtitle_", spec$subtitles)
  }
  
  if (is.null(order)) {
    order <- length(spec$subtitles) + 1L
  }
  
  new_data <- list(
    text = as.character(text),
    styleRef = styleRef,
    order = as.integer(order)
  )
  new_data <- new_data[!sapply(new_data, is.null)]
  
  .validate_params(new_data, "text_group", "add_subtitle")
  spec$subtitles[[id]] <- .merge_recursive(spec$subtitles[[id]], new_data)
  
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
#' @param styleRef List of style names to be applied. Provided styles will be merged with last-win strategy for report
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
  
  if (is.null(id)) {
    id <- .auto_id("footnote_", spec$footnotes)
  }
  
  if (is.null(order)) {
    order <- length(spec$footnotes) + 1L
  }
  
  new_data <- list(
    text = as.character(text),
    styleRef = styleRef,
    order = as.integer(order)
  )
  new_data <- new_data[!sapply(new_data, is.null)]
  
  .validate_params(new_data, "text_group", "add_footnote")
  spec$footnotes[[id]] <- .merge_recursive(spec$footnotes[[id]], new_data)
  
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
#' @param styleRef List of style names to be applied. Provided styles will be merged with last-win strategy for report
#' @param order Order of body text group (auto-assigned if NULL)
#' 
#' @return Updated spec object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- create_text() |>
#'   set_document(docType = "Table", hasData = FALSE) |>
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
#' @param styleRef List of style names to be applied. Provided styles will be merged with last-win strategy for report
#' @param order Order of body text group (auto-assigned if NULL)
#' @return Updated spec object
#' @export
add_body_text.TFL_spec <- function(spec, text = NULL, id = NULL, styleRef = NULL, order = NULL) {
  assert_class(spec, "TFL_spec")  
  # Auto-remove default body text entries when user adds custom content
  if (!is.null(text)) {
    default_ids <- grep(paste0("^", .const_bodytext_default_id_prefix, "_"), 
                       names(spec$bodyText), value = TRUE)
    for (default_id in default_ids) {
      spec$bodyText[[default_id]] <- NULL
    }
  }
  
  if (is.null(id)) {
    id <- .auto_id("body_", spec$bodyText)
  }
  
  if (is.null(order)) {
    order <- length(spec$bodyText) + 1L
  }
  
  new_data <- list(
    text = as.character(text),
    styleRef = styleRef,
    order = as.integer(order)
  )
  new_data <- new_data[!sapply(new_data, is.null)]
  
  .validate_params(new_data, "text_group", "add_body_text")
  spec$bodyText[[id]] <- .merge_recursive(spec$bodyText[[id]], new_data)
  
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
#' @param styleRef List of style names to be applied. Provided styles will be merged with last-win strategy for report
#' @param order Order of body text group (auto-assigned if NULL)
#' @return Updated options object
#' @export
add_body_text.TFL_options <- function(spec, text = NULL, id = NULL, styleRef = NULL, order = NULL) {
  assert_class(spec, "TFL_options")  
  # When user sets custom bodyText in options, remove all existing defaults
  # BUT first capture the max number to generate next sequential ID
  if (!is.null(text)) {
    default_ids <- grep(paste0("^", .const_bodytext_default_id_prefix, "_"), 
                       names(spec$bodyText), value = TRUE)
    
    # Find the max number BEFORE removal
    if (length(default_ids) > 0) {
      numbers <- as.numeric(gsub(paste0(.const_bodytext_default_id_prefix, "_"), "", default_ids))
      max_number <- max(numbers, na.rm = TRUE)
    } else {
      max_number <- 0
    }
    
    # Remove all defaults
    for (default_id in default_ids) {
      spec$bodyText[[default_id]] <- NULL
    }
  }
  
  # Auto-generate ID using __default_NNN pattern if NULL
  if (is.null(id)) {
    if (!is.null(text) && exists("max_number") && max_number > 0) {
      # User added custom text: generate next sequential ID
      next_num <- max_number + 1
      id <- sprintf("%s_%04d", .const_bodytext_default_id_prefix, next_num)
    } else {
      # No user text or no existing defaults: use the helper
      id <- .generate_default_bodytext_id(spec$bodyText)
    }
  }
  
  if (is.null(order)) {
    order <- .const_default_bodytext_order
  }
  
  new_data <- list(
    text = as.character(text),
    styleRef = styleRef,
    order = as.integer(order)
  )
  new_data <- new_data[!sapply(new_data, is.null)]
  
  if (!is.null(text)) {
    .validate_params(new_data, "text_group", "add_body_text")
  }
  
  spec$bodyText[[id]] <- .merge_recursive(spec$bodyText[[id]], new_data)
  class(spec) <- "TFL_options_bodytext"
  spec
}

#' Default method for add_body_text
#' 
#' @param spec Spec object
#' @param text Character vector of body text lines
#' @param id Body text identifier
#' @param styleRef List of style names to be applied. Provided styles will be merged with last-win strategy for report
#' @param order Order
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
  
  if (length(header_parts) > .const_max_header_footer_parts) {
    cli_abort("{.fn add_header} accepts maximum { .const_max_header_footer_parts} parts (left, center, right)")
  }
  
  # Handle level parameter
  if (!is.null(level)) {
    # Try to replace at specific level
    checkmate::assert_number(level, lower = 1, finite = TRUE)
    level <- as.integer(level)
    
    # Only replace if level exists
    if (level <= length(spec$headers)) {
      spec$headers[[level]] <- header_parts
      return(spec)
    }
    # Otherwise ignore and treat as append
  }
  
  # Add as new row
  spec$headers <- c(spec$headers %||% list(), list(header_parts))
  
  spec
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
  
  if (length(header_parts) > .const_max_header_footer_parts) {
    cli_abort("{.fn add_header} accepts maximum { .const_max_header_footer_parts} parts (left, center, right)")
  }
  
  # Handle level parameter
  if (!is.null(level)) {
    checkmate::assert_number(level, lower = 1, finite = TRUE)
    level <- as.integer(level)
    
    # Only replace if level exists
    if (level <= length(spec$headers)) {
      spec$headers[[level]] <- header_parts
      return(spec)
    }
    # Otherwise ignore and treat as append
  }
  
  # Add as new row to headers list
  spec$headers <- c(spec$headers %||% list(), list(header_parts))
  class(spec) <- "TFL_options_header"
  spec
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
  
  if (length(footer_parts) > .const_max_header_footer_parts) {
    cli_abort("{.fn add_footer} accepts maximum { .const_max_header_footer_parts} parts (left, center, right)")
  }
  
  # Handle level parameter
  if (!is.null(level)) {
    checkmate::assert_number(level, lower = 1, finite = TRUE)
    level <- as.integer(level)
    
    # Only replace if level exists
    if (level <= length(spec$footers)) {
      spec$footers[[level]] <- footer_parts
      return(spec)
    }
    # Otherwise ignore and treat as append
  }
  
  # Add as new row
  spec$footers <- c(spec$footers %||% list(), list(footer_parts))
  
  spec
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
  
  if (length(footer_parts) > .const_max_header_footer_parts) {
    cli_abort("{.fn add_footer} accepts maximum { .const_max_header_footer_parts} parts (left, center, right)")
  }
  
  # Handle level parameter
  if (!is.null(level)) {
    checkmate::assert_number(level, lower = 1, finite = TRUE)
    level <- as.integer(level)
    
    # Only replace if level exists
    if (level <= length(spec$footers)) {
      spec$footers[[level]] <- footer_parts
      return(spec)
    }
    # Otherwise ignore and treat as append
  }
  # Add as new row to footers list
  spec$footers <- c(spec$footers %||% list(), list(footer_parts))
  class(spec) <- "TFL_options_footer"
  spec
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
#' Define a spanning header that covers multiple columns.
#' 
#' @param spec TFL spec object
#' @param cols Character vector of column IDs to span
#' @param label Spanning header label
#' @param stubOrder Order of stub header (auto-generated if NULL)
#' @param id Stub column identifier (auto-generated if NULL)
#' @param labelStyleRef List of style names to be applied. Provided styles will be merged with last-win strategy for report
#' 
#' @return Updated spec object
#' @export
#' 
#' @examples
#' \dontrun{
#' data <- data.frame(id = 1:10, age = rnorm(10, 45, 10), sex = sample(c("M", "F"), 10, TRUE))
#' spec <- create_table(data) |>
#'   add_stub_column(
#'     cols = c("age", "sex"),
#'     label = "Demographics",
#'     labelStyleRef = c("stub_label_style", "bold")
#'   )
#' }
add_stub_column <- function(spec, cols, label, stubOrder = NULL, id = NULL, 
                            labelStyleRef = NULL) {
  assert_class(spec, "TFL_spec")
  assert_character(cols)
  
  if (is.null(id)) {
    id <- .auto_id("stub_", spec$stubColumns)
  }
  
  # Validate required fields
  required <- c("cols", "label")
  provided <- list(cols = cols, label = label)
  .validate_required(provided, required, "add_stub_column")
  
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
  .validate_params(params, "stub_column", "add_stub_column")

  # Merge with existing stub if present
  spec$stubColumns[[id]] <- .merge_recursive(spec$stubColumns[[id]], params)

  spec
}

#' Set document properties
#' 
#' Define document-level properties. Multiple calls merge with last-win strategy.
#' 
#' @param spec TFL spec object
#' @param docPrefix Output prefix and number according to SAP
#' @param glueNumType Whether to glue type and number to first title
#' @param docOrder Order of output when combining documents
#' @param isContinues Whether page breaks should be ignored
#' @param contentWidth Width of content, e.g. "100%", "25cm", "10in"
#' @param bodyTitles Whether to place titles in body (vs header)
#' @param bodyFootnotes Whether to place footnotes in body (vs footer)
#' @param hasData Whether document has data to report
#' @param bodySubtitles Whether to place subtitles in body (vs header)
#' 
#' @return Updated spec object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- create_text() |>
#'   set_document(
#'     docType = "Table",
#'     docPrefix = "Table 14.1",
#'     hasData = TRUE,
#'     bodyTitles = TRUE
#'   )
#' }
set_document <- function(spec, docPrefix = NULL, glueNumType = NULL,
                         docOrder = NULL, isContinues = NULL, contentWidth = NULL,
                         bodyTitles = NULL, bodyFootnotes = NULL, hasData = NULL,
                         bodySubtitles = NULL) {
  assert_class(spec, "TFL_spec")
  
  
  if (is.null(hasData) & is.null(spec$document$hasData)) {
    cli_warn(c(
      "hasData not specified in {.fn set_document}",
      i = "Set hasData = TRUE if there is data to report, FALSE otherwise"
    ))
  }
  
  params <- list(
    docPrefix = docPrefix,
    glueNumType = glueNumType,
    docOrder = docOrder,
    isContinues = isContinues,
    contentWidth = contentWidth,
    bodyTitles = bodyTitles,
    bodyFootnotes = bodyFootnotes,
    hasData = hasData,
    bodySubtitles = bodySubtitles,
    
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
  
  spec
}

#' Set document style properties
#' 
#' Set document-level style configuration. Multiple calls merge with last-win strategy.
#' 
#' @param spec TFL spec object
#' @param docTemplate Name of predefined document template
#' @param page Page settings object created with \code{\link{p_page}} or a list with keys: size, orientation, margins
#' 
#' @return Updated spec object
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
set_page_style <- function(spec, docTemplate = NULL, page = NULL) {
  UseMethod("set_page_style", spec)
}

#' Set document style properties
#' 
#' Set document-level style configuration. Multiple calls merge with last-win strategy.
#' 
#' @param spec TFL spec object
#' @param docTemplate Name of predefined document template
#' @param page Page settings object created with \code{\link{p_page}} or a list with keys: size, orientation, margins
#' 
#' @return Updated spec object
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
set_page_style.TFL_spec <- function(spec, docTemplate = NULL, page = NULL) {
  assert_class(spec, "TFL_spec")
  
  # Set context in the calling environment
  .set_context(parent.frame(), "set_page_style")
  on.exit(.clear_context(parent.frame()))
  
  params <- list()
  
  if (!is.null(docTemplate)) {
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

#' Set document style properties
#' 
#' Set document-level style configuration. Multiple calls merge with last-win strategy.
#' 
#' @param spec TFL spec object
#' @param docTemplate Name of predefined document template
#' @param page Page settings object created with \code{\link{p_page}} or a list with keys: size, orientation, margins
#' 
#' @return Updated spec object
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
set_page_style.TFL_options <- function(spec, docTemplate = NULL, page = NULL) {
  assert_class(spec, "TFL_options")
  
  # Set context in the calling environment
  .set_context(parent.frame(), "set_page_style")
  on.exit(.clear_context(parent.frame()))
  
  params <- list()
  
  if (!is.null(docTemplate)) {
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
._resolve_style_refs <- function(style_refs, num_cols, param_name = "styleRef") {
  if (is.null(style_refs)) {
    return(rep(list(NULL), num_cols))
  }
  
  # Case 1: Character vector (single style or f_combine result)
  if (is.character(style_refs)) {
    # Recycle to all columns
    return(rep(list(style_refs), num_cols))
  }
  
  # Case 2: List (assumed to be from f_combine results or explicit mapping)
  if (is.list(style_refs)) {
    # Validate all elements are either NULL or character vectors
    for (i in seq_along(style_refs)) {
      if (!is.null(style_refs[[i]]) && !is.character(style_refs[[i]])) {
        cli_abort(c(
          "Element {i} of {param_name} list must be NULL or character vector",
          i = "Got: {.cls {class(style_refs[[i]])[1]}}"
        ))
      }
    }
    
    # Check if this is a mapping (one element per column) or recycling (one element)
    if (length(style_refs) == 1) {
      # Single element - recycle to all columns
      return(rep(list(style_refs[[1]]), num_cols))
    } else if (length(style_refs) == num_cols) {
      # One-to-one mapping
      return(style_refs)
    } else {
      # Length mismatch
      cli_abort(c(
        "Length of {param_name} list ({length(style_refs)}) must equal 1 or {num_cols} (number of columns)",
        i = "For recycling a single mapping, use: {.fn f_combine}(...)",
        i = "For explicit mapping, provide exactly {num_cols} elements in a list or vector"
      ))
    }
  }
  
  # Invalid type
  cli_abort(c(
    "{param_name} must be NULL, a character vector, or a list of character vectors",
    i = "Got: {.cls {class(style_refs)[1]}}"
  ))
}

#' Validate TFL specification for consistency
#' 
#' Performs additional consistency checks beyond schema validation.
#' 
#' @param spec TFL spec object
#' @param verbose Whether to show validation details
#' @return Logical indicating if all checks passed
#' 
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



