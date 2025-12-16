# ============================================================
# TFL Spec Builder - Clean Architecture with Prefixed Functions
# ============================================================

#' @importFrom rlang enquos quo_get_expr call_name call_args eval_tidy is_call
#' @importFrom jsonlite toJSON
#' @importFrom utils modifyList
#' @importFrom checkmate assert_class assert_string assert_character assert_list
#' @importFrom cli cli_abort cli_warn cli_alert_success
#' @importFrom purrr map_chr

# ============================================================
# PART 1: CORE UTILITIES
# ============================================================

#' Recursively Merge Two Objects (Last-Win Strategy)
#'
#' Merges two objects with the second taking precedence in case of conflicts.
#' Handles NULL values and recursive list merging.
#'
#' @param x First object (list or NULL)
#' @param y Second object (list or NULL). Takes precedence in merge.
#'
#' @return Merged object where conflicts favor `y` values
#'
#' @details
#' - If either object is NULL, returns the non-NULL one
#' - If both are lists, uses `modifyList()` to recursively merge
#' - Otherwise, `y` completely replaces `x` (last wins)
#'
#' @keywords internal
.merge_recursive <- function(x, y) {
  if (is.null(x)) return(y)
  if (is.null(y)) return(x)
  if (is.list(x) && is.list(y)) {
    return(modifyList(x, y, keep.null = TRUE))
  }
  y  # Last wins
}

#' Auto-Generate Unique Identifier
#'
#' Generates a unique ID with a given prefix by appending an incrementing number
#' until a non-existent ID is found.
#'
#' @param prefix Character. Prefix for the ID (e.g., "style_")
#' @param existing_list List. List of existing objects (uses names as existing IDs).
#'   NULL is treated as an empty list.
#'
#' @return Character. Unique identifier in format "<prefix><number>"
#'
#' @keywords internal
.auto_id <- function(prefix, existing_list) {
  # Handle NULL as empty list
  if (is.null(existing_list)) {
    existing_list <- list()
  }
  
  if (!is.list(existing_list)) {
    cli_abort("Internal error: existing_list must be a list or NULL in {.fn .auto_id}")
  }
  
  n <- length(existing_list) + 1L
  max_attempts <- 10000
  
  for (attempt in seq_len(max_attempts)) {
    id <- paste0(prefix, n)
    if (!id %in% names(existing_list)) return(id)
    n <- n + 1L
  }
  
  cli_abort("Failed to generate unique ID after {max_attempts} attempts with prefix {.str {prefix}}")
}

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
    assign("cache", list(
      font = c("font_name", "font_size", "bold", "italic", "underline", "color", "highlight"),
      paragraph = c("alignment", "spacing", "indents", "word_style"),
      spacing = c("before", "after", "line_spacing"),
      indents = c("left", "right", "first_line"),
      table_style = c("background_color", "row_height", "vertical_alignment", 
                      "text_orientation", "borders"),
      borders = c("top", "bottom", "left", "right"),
      border = c("color", "width", "line_style"),
      page = c("size", "orientation", "margins"),
      margins = c("top", "bottom", "left", "right", "header", "footer"),
      documentStyle = c("docTemplate", "page"),
      col_format = c("type", "format", "missings", "colWidth", "valueStyleRef"),
      column = c("colOrder", "label", "isID", "isVisible", "isGrouping", "isPaging",
                 "labelStyleRef", ".isColBreak", "dedupe", "blankAfter", "format"),
      stub_column = c("label", "cols", "labelStyleRef", "stubOrder"),
      document = c("docType", "docPrefix", "glueNumType", "docOrder", "isContinues",
                   "contentWidth", "bodyTitles", "bodyFootnotes", "hasData", 
                   "bodySubtitles", "outFileName"),
      text_group = c("text", "styleRef", "order")
    ), envir = .schema_cache_env)
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
#' @param color Character. Text color as hex code (e.g., "#000000")
#' @param highlight Character. Background highlight color as hex code
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
    .validate_enum(font_name, 
                   c("Arial", "Courier New", "Times New Roman", "Calibri"),
                   "font_name", ".font_spec")
  }
  
  # Validate font_size pattern (e.g., "12pt", "11.5pt")
  if (!is.null(font_size)) {
    .validate_pattern(font_size, "^[0-9]+(\\.[0-9]+)?pt$", 
                      "font_size", ".font_spec", "Must be like '12pt'")
  }
  
  # Validate hex color codes
  if (!is.null(color)) {
    .validate_pattern(color, "^#[0-9A-Fa-f]{6}$", 
                      "color", ".font_spec", "Must be hex like '#000000'")
  }
  
  if (!is.null(highlight)) {
    .validate_pattern(highlight, "^#[0-9A-Fa-f]{6}$", 
                      "highlight", ".font_spec", "Must be hex like '#FFFF00'")
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
    .validate_pattern(before, "^[0-9]+(\\.[0-9]+)?(pt|cm|in|mm)$", 
                      "before", ".spacing_spec", "Must be like '12pt', '10mm'")
  }
  
  if (!is.null(after)) {
    .validate_pattern(after, "^[0-9]+(\\.[0-9]+)?(pt|cm|in|mm)$", 
                      "after", ".spacing_spec", "Must be like '6pt', '10mm'")
  }
  
  # Validate line_spacing as numeric >= 1
  if (!is.null(line_spacing)) {
    if (!is.numeric(line_spacing) || length(line_spacing) != 1) {
      cli_abort("{.arg line_spacing} must be a single numeric value in {.fn .spacing_spec}")
    }
    if (line_spacing < 1) {
      cli_abort(c(
        "{.arg line_spacing} must be >= 1 in {.fn .spacing_spec}:",
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
  
  pattern <- "^-?[0-9]+(\\.[0-9]+)?(in|cm|mm|pt)$"
  if (!is.null(left)) {
    .validate_pattern(left, pattern, "left", "indents_spec",
                      "Must be like '10mm', '0.5in', '2.54cm', or '36pt'")
  }
  if (!is.null(right)) {
    .validate_pattern(right, pattern, "right", "indents_spec",
                      "Must be like '10mm', '0.5in', '2.54cm', or '36pt'")
  }
  if (!is.null(first_line)) {
    .validate_pattern(first_line, pattern, "first_line", "indents_spec",
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
    .validate_enum(alignment, 
                   c("left", "right", "center", "justify", "distributed"),
                   "alignment", "paragraph_spec")
    params$alignment <- alignment
  }
  
  if (!is.null(word_style)) {
    .validate_enum(word_style,
                   c("Normal", "Heading 1", "Heading 2", "Title", "Subtitle", 
                     "No Spacing", "Strong", "Quote", "Intense Quote"),
                   "word_style", "paragraph_spec")
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
#' @param color Border color as hex
#' @param width Border width
#' @param line_style Line style
#' @return Border specification list
#' @keywords internal
.border_spec <- function(color = NULL, width = NULL, line_style = NULL) {
  params <- as.list(environment())
  params <- params[!sapply(params, is.null)]
  
  if (!is.null(color)) {
    .validate_pattern(color, "^#[0-9A-Fa-f]{6}$", "color", "border_spec")
  }
  
  if (!is.null(width)) {
    .validate_pattern(width, "^[0-9]+(\\.[0-9]+)?pt$", "width", "border_spec")
  }
  
  if (!is.null(line_style)) {
    .validate_enum(line_style,
                   c("single", "double", "dashed", "dotted", "thick", "none"),
                   "line_style", "border_spec")
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
    .validate_pattern(background_color, "^#[0-9A-Fa-f]{6}$", 
                      "background_color", "table_style_spec")
    params$background_color <- background_color
  }
  
  if (!is.null(row_height)) {
    .validate_pattern(row_height, "^([0-9]+(\\.[0-9]+)?(pt|in|cm|mm))|(auto)$", 
                      "row_height", "table_style_spec",
                      "Must be like '12pt', '0.5in', '1.27cm', '12.7mm', or 'auto'")
    params$row_height <- row_height
  }
  
  if (!is.null(vertical_alignment)) {
    .validate_enum(vertical_alignment, c("top", "center", "bottom"),
                   "vertical_alignment", "table_style_spec")
    params$vertical_alignment <- vertical_alignment
  }
  
  if (!is.null(text_orientation)) {
    .validate_enum(text_orientation, 
                   c("horizontal", "vertical_90", "vertical_270"),
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
  
  pattern <- "^[0-9]+(\\.[0-9]+)?(in|cm|mm|pt)$"
  for (margin in names(params)) {
    .validate_pattern(params[[margin]], pattern, margin, "margins_spec",
                      "Must be like '1in', '2.54cm', '25.4mm', or '72pt'")
  }
  
  params
}

#' Internal page specification builder
#' 
#' @param size Page size
#' @param orientation Page orientation
#' @param margins Margins specification
#' @return Page specification list
#' @keywords internal
.page_spec <- function(size = "A4", orientation = "landscape", margins) {
  .validate_enum(size, c("A4", "A3", "Letter", "Legal", "Executive"), 
                 "size", "page_spec")
  .validate_enum(orientation, c("portrait", "landscape"), 
                 "orientation", "page_spec")
  
  # Validate margins keys if a raw list is passed
  if (is.list(margins)) {
    .validate_params(margins, "margins", "s_page")
  }
  
  list(size = size, orientation = orientation, margins = margins)
}

#' Internal column format specification builder
#' 
#' @param type Data type
#' @param format Format string
#' @param missings Missing value handling
#' @param colWidth Column width
#' @param valueStyleRef Style reference
#' @return Column format specification list
#' @keywords internal
.col_format_spec <- function(type, format = NULL, missings = NULL, 
                             colWidth = NULL, valueStyleRef = NULL) {
  .validate_enum(type, c("string", "numeric"), "type", "col_format_spec")
  
  params <- list(type = type)
  
  if (!is.null(format)) params$format <- format
  if (!is.null(missings)) params$missings <- missings
  
  if (!is.null(colWidth)) {
    .validate_pattern(colWidth, "^\\d+(\\.\\d+)?(%|in|cm)$", 
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
#' @param color Text color as hex, e.g. "#000000"
#' @param highlight Background highlight color as hex, e.g. "#FFFF00"
#' 
#' @return A font specification object (for internal use)
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- tfl_spec() |>
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
#' spec <- tfl_spec() |>
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
#' spec <- tfl_spec() |>
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
#' spec <- tfl_spec() |>
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
#' @param color Border color as hex, e.g. "#000000"
#' @param width Border width, e.g. "1pt"
#' @param line_style Line style: "single", "double", "dashed", "dotted", "thick", "none"
#' 
#' @return A border specification object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- tfl_spec() |>
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
#' spec <- tfl_spec() |>
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
  for (side in c("top", "bottom", "left", "right")) {
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
#' @param background_color Cell background color as hex
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
#' spec <- tfl_spec() |>
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
    for (side in c("top", "bottom", "left", "right")) {
      if (!is.null(spec$borders[[side]])) {
        .validate_params(spec$borders[[side]], "border", paste0("s_table_style$borders$", side))
      }
    }
  }
  
  structure(spec, class = c("tfl_table_style", "tfl_style_modifier"))
}

#' Define page margins
#' 
#' This function can only be used inside \code{\link{s_page}}.
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
#' spec <- tfl_spec() |>
#'   add_style("page_style",
#'     s_page(
#'       size = "A4",
#'       orientation = "landscape",
#'       margins = s_margins(
#'         top = "25mm", bottom = "25mm",
#'         left = "20mm", right = "20mm",
#'         header = "12mm", footer = "12mm"
#'       )
#'     )
#'   )
#' }
s_margins <- function(top, bottom, left, right, header, footer) {
  .assert_context(c("s_page"), "s_margins")
  
  spec <- .margins_spec(
    top = top, bottom = bottom, 
    left = left, right = right, 
    header = header, footer = footer
  )
  .validate_params(spec, "margins", "s_margins")
  structure(spec, class = c("tfl_margins", "tfl_nested_modifier"))
}

#' Define page settings
#' 
#' This function can only be used inside \code{\link{set_document_style}}.
#' 
#' @param size Page size: "A4", "A3", "Letter", "Legal", "Executive"
#' @param orientation Page orientation: "portrait" or "landscape"
#' @param margins Margins object created with \code{\link{s_margins}} or a list with keys: top, bottom, left, right, header, footer
#' 
#' @return A page specification object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- tfl_spec() |>
#'   set_document_style(
#'     docTemplate = "KeyStat_default",
#'     page = s_page(
#'       size = "A4",
#'       orientation = "landscape",
#'       margins = s_margins(
#'         top = "25mm", bottom = "25mm",
#'         left = "20mm", right = "20mm",
#'         header = "12mm", footer = "12mm"
#'       )
#'     )
#'   )
#' }
s_page <- function(size = "A4", orientation = "landscape", margins) {
  .assert_context(c("set_document_style"), "s_page")
  
  # Set context for nested functions
  .set_context(parent.frame(), "s_page")
  on.exit(.clear_context(parent.frame()))
  
  # Extract nested specs
  if (inherits(margins, "tfl_margins")) {
    margins <- unclass(margins)
  } else if (is.list(margins)) {
    .validate_params(margins, "margins", "s_page")
  }
  
  spec <- .page_spec(size = size, orientation = orientation, margins = margins)
  .validate_params(spec, "page", "s_page")
  structure(spec, class = c("tfl_page", "tfl_document_modifier"))
}

#' Define column format
#' 
#' This function can only be used inside \code{\link{define_cols}}.
#' 
#' @param type Data type: "string" or "numeric"
#' @param format Format string for numeric data (sprintf style), default "%d"
#' @param missings How to display missing values in numeric columns
#' @param colWidth Column width, e.g. "2in", "5cm", "20%"
#' @param valueStyleRef Style reference for cell values
#' 
#' @return A column format specification object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- tfl_init(data) |>
#'   define_cols("age",
#'     label = "Age (years)",
#'     c_format(type = "numeric", format = "%.1f", colWidth = "10%")
#'   )
#' }
c_format <- function(type, format = NULL, missings = NULL, 
                     colWidth = NULL, valueStyleRef = NULL) {
  .assert_context(c("define_cols"), "c_format")
  
  spec <- .col_format_spec(
    type = type,
    format = format,
    missings = missings,
    colWidth = colWidth,
    valueStyleRef = valueStyleRef
  )
  
  .validate_params(spec, "col_format", "c_format")
  
  structure(spec, class = c("tfl_col_format", "tfl_col_modifier"))
}

# ============================================================
# PART 5: EXPORTED CONTEXT FUNCTIONS
# ============================================================


#' Add or update a style definition
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
#' @param spec TFL spec object
#' @param id Style identifier (auto-generated if NULL)
#' @param ... Style modifiers created with s_* functions
#' 
#' @return Updated spec object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- tfl_spec() |>
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
add_style <- function(spec, id = NULL, ...) {
  assert_class(spec, "TFL_spec")
  
  # Auto-generate ID if needed
  if (is.null(id)) {
    id <- .auto_id("style_", spec$attribs$styles)
  }
  
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
    if (!inherits(mod, "tfl_style_modifier")) {
      cli_abort(c(
        "Invalid modifier in {.fn add_style}",
        x = "All arguments must be style modifiers",
        i = "Use: {.fn s_font}, {.fn s_paragraph}, or {.fn s_table_style}"
      ))
    }
    
    # Determine target path
    modifier_class <- class(mod)[1]
    path <- switch(modifier_class,
                   tfl_font = "font",
                   tfl_paragraph = "paragraph",
                   tfl_table_style = "table_style",
                   NULL)
    
    if (is.null(path)) {
      cli_abort("Unknown modifier class: {modifier_class}")
    }
    
    # Payload to merge
    payload <- unclass(mod)
    
    # Validate payload against schema cache before merging
    .validate_params(payload, path, "add_style")
    # Validate nested shapes as needed
    if (path == "paragraph") {
      if (!is.null(payload$spacing)) .validate_params(payload$spacing, "spacing", "add_style$paragraph.spacing")
      if (!is.null(payload$indents)) .validate_params(payload$indents, "indents", "add_style$paragraph.indents")
    }
    if (path == "table_style" && !is.null(payload$borders)) {
      .validate_params(payload$borders, "borders", "add_style$table_style.borders")
      for (side in c("top", "bottom", "left", "right")) {
        if (!is.null(payload$borders[[side]])) {
          .validate_params(payload$borders[[side]], "border", paste0("add_style$table_style.borders$", side))
        }
      }
    }
    
    # Merge with last-win
    current <- spec$attribs$styles[[id]][[path]]
    spec$attribs$styles[[id]][[path]] <- .merge_recursive(current, payload)
  }
  
  spec
}

#' Define or modify column properties
#' 
#' Modify properties of existing columns. Can modify single column or batch update
#' multiple columns. Multiple calls merge with last-win strategy.
#' 
#' Available modifiers inside this function:
#' \itemize{
#'   \item \code{\link{c_format}} - Column format specification
#' }
#' 
#' @param spec TFL spec object (must be initialized with \code{\link{tfl_init}})
#' @param cols Character vector of column names to modify
#' @param colOrder Position of column (length 1 or length of cols)
#' @param label Column label (length 1 or length of cols)
#' @param isID Whether column is identifier (length 1 or length of cols)
#' @param isVisible Whether column is visible (length 1 or length of cols)
#' @param isGrouping Whether column defines groups (length 1 or length of cols)
#' @param isPaging Whether column defines pages (length 1 or length of cols)
#' @param labelStyleRef Label style reference (length 1 or length of cols)
#' @param .isColBreak Whether column triggers page break (length 1 or length of cols)
#' @param dedupe Whether to deduplicate values (length 1 or length of cols)
#' @param blankAfter Whether to add blank after value change (length 1 or length of cols)
#' @param ... Column format modifier created with \code{\link{c_format}}
#' 
#' @return Updated spec object
#' @export
#' 
#' @examples
#' \dontrun{
#' data <- data.frame(id = 1:10, age = rnorm(10, 45, 10), group = rep(c("A", "B"), 5))
#' 
#' # Single column
#' spec <- tfl_init(data) |>
#'   define_cols("age",
#'     label = "Age (years)",
#'     c_format(type = "numeric", format = "%.1f", colWidth = "10%")
#'   )
#' 
#' # Batch update with single value
#' spec <- tfl_init(data) |>
#'   define_cols(c("id", "age", "group"),
#'     isVisible = TRUE  # Applied to all three
#'   )
#' 
#' # Batch update with mapped values
#' spec <- tfl_init(data) |>
#'   define_cols(c("id", "age"),
#'     label = c("Subject ID", "Age (years)"),  # One-to-one mapping
#'     isID = c(TRUE, FALSE)
#'   )
#' 
#' # Multiple calls merge
#' spec <- tfl_init(data) |>
#'   define_cols("age",
#'     label = "Age",
#'     c_format(type = "numeric", format = "%.0f")
#'   ) |>
#'   define_cols("age",
#'     label = "Age (years)",  # Overrides previous label
#'     c_format(colWidth = "15%")  # Merges with format, keeping type and format
#'   )
#' }
define_cols <- function(spec, cols, ..., 
                        label = NULL, isID = NULL, 
                        isVisible = NULL, isGrouping = NULL, isPaging = NULL,
                        labelStyleRef = NULL, .isColBreak = NULL, dedupe = NULL,
                        blankAfter = NULL) {
  assert_class(spec, "TFL_spec")
  cols <- enquos(cols)
  cols <- .get_data_column_names(spec$.metadata$data_env$`__data__`, !!!cols)
  assert_character(cols, min.len = 1)
  
  # Check that all cols exist
  missing_cols <- setdiff(cols, names(spec$columns))
  if (length(missing_cols) > 0) {
    cli_abort(c(
      "Column{?s} not found in {.fn define_cols}:",
      x = paste(missing_cols, collapse = ", "),
      i = "Use {.fn tfl_init} to initialize spec from data first"
    ))
  }
  
  # Set context in the calling environment
  .set_context(parent.frame(), "define_cols")
  on.exit(.clear_context(parent.frame()))
  
  # Collect parameters
  param_names <- c("label", "isID", "isVisible", "isGrouping", 
                   "isPaging", "labelStyleRef", ".isColBreak", "dedupe", "blankAfter")
  params_list <- list(
     label = label, isID = isID, isVisible = isVisible,
    isGrouping = isGrouping, isPaging = isPaging, labelStyleRef = labelStyleRef,
    .isColBreak = .isColBreak, dedupe = dedupe, blankAfter = blankAfter
  )
  
  # Process format modifier from ...
  modifiers <- list(...)
  format_spec <- NULL
  
  if (length(modifiers) > 0) {
    for (mod in modifiers) {
      if (inherits(mod, "tfl_col_format")) {
        if (!is.null(format_spec)) {
          cli_abort("{.fn define_cols} accepts only one {.fn c_format} call")
        }
        format_spec <- unclass(mod)
        .validate_params(format_spec, "col_format", "define_cols$c_format")
      } else {
        cli_abort(c(
          "Invalid modifier in {.fn define_cols}",
          i = "Use {.fn c_format} to define column format"
        ))
      }
    }
  }
  
  # Validate parameter lengths
  n_cols <- length(cols)
  for (pname in param_names) {
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
  
  # Apply to each column
  for (i in seq_along(cols)) {
    col_id <- cols[i]
    
    # Build params for this column
    col_params <- list()
    for (pname in param_names) {
      pval <- params_list[[pname]]
      if (!is.null(pval)) {
        col_params[[pname]] <- if (length(pval) == 1) pval else pval[i]
      }
    }
    
    # Add format if provided
    if (!is.null(format_spec)) {
      # Merge with existing format
      existing_format <- spec$columns[[col_id]]$format
      col_params$format <- .merge_recursive(existing_format, format_spec)
    }
    
    # Validate known keys for column
    .validate_params(col_params, "column", "define_cols")
    
    # Merge with last-win
    spec$columns[[col_id]] <- .merge_recursive(spec$columns[[col_id]], col_params)
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
#' @param styleRef Style reference for title
#' @param order Order of title group (auto-assigned if NULL)
#' 
#' @return Updated spec object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- tfl_spec() |>
#'   add_title(c("Study ABC-123", "Demographics Table")) |>
#'   add_title("Full Analysis Set", styleRef = "subtitle_style")
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
#' @param styleRef Style reference for subtitle
#' @param order Order of subtitle group (auto-assigned if NULL)
#' 
#' @return Updated spec object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- tfl_spec() |>
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
#' @param styleRef Style reference for footnote
#' @param order Order of footnote group (auto-assigned if NULL)
#' 
#' @return Updated spec object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- tfl_spec() |>
#'   add_footnote("Data source: Clinical database lock 2025-12-01") |>
#'   add_footnote("Missing values displayed as 'N/A'")
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
#' Add body text (e.g., when no data to display). Multiple calls add multiple text groups.
#' Calling with the same ID merges with last-win strategy.
#' 
#' @param spec TFL spec object
#' @param text Character vector of body text lines
#' @param id Body text identifier (auto-generated if NULL)
#' @param styleRef Style reference for body text
#' @param order Order of body text group (auto-assigned if NULL)
#' 
#' @return Updated spec object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- tfl_spec() |>
#'   set_document(docType = "Table", hasData = FALSE) |>
#'   add_body_text("No data available for the specified criteria")
#' }
add_body_text <- function(spec, text, id = NULL, styleRef = NULL, order = NULL) {
  assert_class(spec, "TFL_spec")
  
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

#' Add a header row
#' 
#' Add a header row to the specification. Each call adds a new header row.
#' Per schema, headers are arrays of arrays (each call = one row).
#' 
#' @param spec TFL spec object
#' @param ... Up to 3 character strings (left, center, right)
#' 
#' @return Updated spec object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- tfl_spec() |>
#'   add_header("Study ABC-123", "CONFIDENTIAL", "Page {PAGE}") |>
#'   add_header("Protocol v2.0", "", "Date: {DATE}")
#' }
add_header <- function(spec, ...) {
  assert_class(spec, "TFL_spec")
  
  header_parts <- as.character(c(...))
  
  if (length(header_parts) > 3) {
    cli_abort("{.fn add_header} accepts maximum 3 parts (left, center, right)")
  }
  
  # Add as new row
  spec$headers <- c(spec$headers, list(header_parts))
  
  spec
}

#' Add a footer row
#' 
#' Add a footer row to the specification. Each call adds a new footer row.
#' Per schema, footers are arrays of arrays (each call = one row).
#' 
#' @param spec TFL spec object
#' @param ... Up to 3 character strings (left, center, right)
#' 
#' @return Updated spec object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- tfl_spec() |>
#'   add_footer("Company Name", "", "Page {PAGE} of {NUMPAGES}") |>
#'   add_footer("", "Confidential", "")
#' }
add_footer <- function(spec, ...) {
  assert_class(spec, "TFL_spec")
  
  footer_parts <- as.character(c(...))
  
  if (length(footer_parts) > 3) {
    cli_abort("{.fn add_footer} accepts maximum 3 parts (left, center, right)")
  }
  
  # Add as new row
  spec$footers <- c(spec$footers, list(footer_parts))
  
  spec
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
#' @param labelStyleRef Style reference for stub label
#' 
#' @return Updated spec object
#' @export
#' 
#' @examples
#' \dontrun{
#' data <- data.frame(id = 1:10, age = rnorm(10, 45, 10), sex = sample(c("M", "F"), 10, TRUE))
#' spec <- tfl_init(data) |>
#'   add_stub_column(
#'     cols = c("age", "sex"),
#'     label = "Demographics"
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
    cols = cols,
    labelStyleRef = labelStyleRef,
    stubOrder = stubOrder
  )
  params <- params[!sapply(params, is.null)]
  
  .validate_params(params, "stub_column", "add_stub_column")
  
  spec$stubColumns[[id]] <- params
  
  spec
}

#' Add style row definitions
#' 
#' Add styling rules for table rows. Each call appends to the list.
#' 
#' @param spec TFL spec object
#' @param ... Character vectors of styling rules
#' 
#' @return Updated spec object
#' 
#' @examples
#' \dontrun{
#' spec <- tfl_spec() |>
#'   add_style_row("bold", "normal", "bold")
#' }
.add_style_row <- function(spec, ...) {
  assert_class(spec, "TFL_spec")
  
  spec$styleRows <- spec$styleRows %||% character()
  spec$styleRows <- c(spec$styleRows, as.character(c(...)))
  
  spec
}

#' Add data file references
#' 
#' Add references to data files (JSON or image files). Each call appends to the list.
#' 
#' @param spec TFL spec object
#' @param ... Character vectors of file paths
#' 
#' @return Updated spec object
#' 
#' @examples
#' \dontrun{
#' spec <- tfl_spec() |>
#'   add_data_ref("demographics_data.json", "safety_data.json")
#' }
.add_data_ref <- function(spec, ...) {
  assert_class(spec, "TFL_spec")
  
  spec$dataRef <- spec$dataRef %||% character()
  spec$dataRef <- c(spec$dataRef, as.character(c(...)))
  
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
#' @param outFileName Output file name
#' 
#' @return Updated spec object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- tfl_spec() |>
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
                         bodySubtitles = NULL, outFileName = NULL) {
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
    outFileName = outFileName
  )
  params <- params[!sapply(params, is.null)]
  
  # Validate
  .validate_params(params, "document", "set_document")
  
  if (!is.null(contentWidth)) {
    .validate_pattern(contentWidth, "^\\d+(\\.\\d+)?(%|in|cm)$", 
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
#' @param page Page settings object created with \code{\link{s_page}} or a list with keys: size, orientation, margins
#' 
#' @return Updated spec object
#' @export
#' 
#' @examples
#' \dontrun{
#' spec <- tfl_spec() |>
#'   set_document_style(
#'     docTemplate = "KeyStat_default",
#'     page = s_page(
#'       size = "A4",
#'       orientation = "landscape",
#'       margins = s_margins(
#'         top = "25mm", bottom = "25mm",
#'         left = "20mm", right = "20mm",
#'         header = "12mm", footer = "12mm"
#'       )
#'     )
#'   )
#' }
set_document_style <- function(spec, docTemplate = NULL, page = NULL) {
  assert_class(spec, "TFL_spec")
  
  # Set context in the calling environment
  .set_context(parent.frame(), "set_document_style")
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
      .validate_params(page, "page", "set_document_style")
    } else {
      cli_abort(c(
        "{.fn set_document_style} requires {.arg page} created by {.fn s_page} or a list with keys: ",
        paste0("{.arg ", .get_allowed_properties("page"), "}", collapse = ", ")
      ))
    }
    
    # Validate nested shapes
    if (!is.null(page$margins)) {
      .validate_params(page$margins, "margins", "set_document_style$page.margins")
    }
    
    params$page <- page
  }
  
  # Validate params against schema
  .validate_params(params, "documentStyle", "set_document_style")
  
  spec$attribs$documentStyle <- .merge_recursive(spec$attribs$documentStyle, params)
  
  spec
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
#' spec <- tfl_spec() |>
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
      style_ref <- text_groups[[id]]$styleRef
      if (!is.null(style_ref) && !style_ref %in% names(spec$attribs$styles)) {
        issues <<- c(issues, 
                     paste0("Style reference '", style_ref, "' in ", group_name, 
                            " '", id, "' not found in defined styles"))
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
    if (!is.null(col$labelStyleRef) && !col$labelStyleRef %in% names(spec$attribs$styles)) {
      issues <- c(issues, 
                  paste0("Column label style reference '", col$labelStyleRef, 
                         "' for column '", col_id, "' not found in defined styles"))
    }
    
    if (!is.null(col$format$valueStyleRef) && !col$format$valueStyleRef %in% names(spec$attribs$styles)) {
      issues <- c(issues, 
                  paste0("Column value style reference '", col$format$valueStyleRef, 
                         "' for column '", col_id, "' not found in defined styles"))
    }
  }
  
  # Check stub column style references
  for (stub_id in names(spec$stubColumns)) {
    stub <- spec$stubColumns[[stub_id]]
    if (!is.null(stub$labelStyleRef) && !stub$labelStyleRef %in% names(spec$attribs$styles)) {
      issues <- c(issues, 
                  paste0("Stub label style reference '", stub$labelStyleRef, 
                         "' for stub '", stub_id, "' not found in defined styles"))
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


#' Preview the TFL specification structure
#' 
#' Provides a human-readable overview of the specification.
#' 
#' @param spec TFL spec object
#' @param max_levels Maximum levels to show in nested structures
#' @return The spec object (invisibly)
#' @export
#' 
#' @examples
#' \dontrun{
#' data <- data.frame(id = 1:10, age = rnorm(10, 45, 10))
#' spec <- tfl_init(data) |>
#'   set_document(docType = "Table", hasData = TRUE) |>
#'   add_title("Study Title") |>
#'   add_header("Study", "Confidential", "Page {PAGE}")
#'   
#' preview_spec(spec)
#' }
preview_spec <- function(spec, max_levels = 3) {
  if (!inherits(spec, "TFL_spec")) {
    cli_abort("Object must be of class 'TFL_spec'")
  }
  
  cat(cli::rule("TFL Specification Preview", line = 2), "\n")
  cat(cli::col_blue("Document Type: "), spec$document$docType %||% "<not set>", "\n")
  cat(cli::col_blue("Has Data: "), ifelse(is.null(spec$document$hasData), "<not set>", 
                                          ifelse(spec$document$hasData, "Yes", "No")), "\n")
  
  # Page settings summary
  if (!is.null(spec$attribs$documentStyle$page)) {
    pg <- spec$attribs$documentStyle$page
    cat(cli::col_blue("Page settings: "), 
        "size=", pg$size %||% "<default>", 
        ", orientation=", pg$orientation %||% "<default>", "\n", sep = "")
  }
  
  # Titles
  if (length(spec$titles) > 0) {
    cat(cli::col_blue("Titles:\n"))
    for (i in seq_along(spec$titles)) {
      title <- spec$titles[[i]]
      cat("  [", title$order, "] ", paste(title$text, collapse = " "), 
          if (!is.null(title$styleRef)) paste0(" [style: ", title$styleRef, "]") else "", "\n")
    }
  }
  
  # Columns
  if (length(spec$columns) > 0) {
    cat(cli::col_blue("Columns: "), length(spec$columns), "\n")
    n_show <- min(5, length(spec$columns))
    cols <- names(spec$columns)[1:n_show]
    cat("  ", paste(cols, collapse = ", "), 
        if (length(spec$columns) > 5) " ..." else "", "\n")
  }
  
  # Styles overview
  if (length(spec$attribs$styles) > 0) {
    cat(cli::col_blue("Styles defined: "), length(spec$attribs$styles), "\n")
    n_show <- min(5, length(spec$attribs$styles))
    for (sid in names(spec$attribs$styles)[1:n_show]) {
      st <- spec$attribs$styles[[sid]]
      keys <- names(st)
      cat("  - ", sid, " (", paste(keys, collapse = ", "), ")\n", sep = "")
    }
  }
  
  # Stub Columns
  if (length(spec$stubColumns) > 0) {
    cat(cli::col_blue("Stub Columns: "), length(spec$stubColumns), "\n")
    for (stub_id in names(spec$stubColumns)) {
      stub <- spec$stubColumns[[stub_id]]
      cat("  [", stub$stubOrder, "] ", stub$label, 
          " (", length(stub$cols), " columns)", "\n")
    }
  }
  
  # Headers/Footers samples
  if (length(spec$headers) > 0) {
    cat(cli::col_blue("Headers: "), length(spec$headers), " row(s)\n", sep = "")
    sample_h <- spec$headers[[1]]
    cat("  Sample: ", paste(sample_h, collapse = " | "), "\n", sep = "")
  }
  if (length(spec$footers) > 0) {
    cat(cli::col_blue("Footers: "), length(spec$footers), " row(s)\n", sep = "")
    sample_f <- spec$footers[[1]]
    cat("  Sample: ", paste(sample_f, collapse = " | "), "\n", sep = "")
  }
  
  invisible(spec)
}

#