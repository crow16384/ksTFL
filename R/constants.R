##' Package constants and validation patterns for ksTFL
##'
##' This file contains package-wide constant objects used across ksTFL.
##' It includes default spec templates, enumerations, validation regexes,
##' schema property lists, and JSON schema helper constants. These constants
##' are referenced by spec constructors, validation routines and serializer
##' helpers to centralize magic strings and ensure consistent behavior.
##'
##' These objects are internal to the package and are not exported to CRAN
##' users. They are documented here to assist developers working on
##' specification creation, schema resolution, and formatting helpers.
##'
##' @keywords internal
##' @name ksTFL-constants
NULL

#=============================================================================
# ksTFL/R/constants.R 
# Package-wide constants for ksTFL
#=============================================================================


## Initial empty spec structure
.const_empty_spec <- list(
  document    = list(),
  attribs     = list(),
  headers     = list(),
  footers     = list(),
  dataRef     = list(),
  stubColumns = list(),
  columns     = list(),
  styleRows   = list(),
  titles      = list(),
  subtitles   = list(),
  footnotes   = list(),
  bodyText    = list(),
  .metadata   = list()
)

# ============================================================
# ENUM VALUES - Allowed values for various properties
# ============================================================

#' Allowed font names
.const_font_names <- c("Arial", "Courier New", "Times New Roman", "Calibri")

#' Allowed text alignment values
.const_alignment_values <- c("left", "right", "center", "justify", "distributed")

#' Allowed Word style names
.const_word_styles <- c(
  "Normal",
  "Heading 1",
  "Heading 2",
  "Title",
  "Subtitle",
  "No Spacing",
  "Strong",
  "Quote",
  "Intense Quote"
)

#' Allowed border line styles
.const_line_styles <- c("single", "double", "dashed", "dotted", "thick", "none")

#' Allowed vertical alignment values
.const_vertical_alignment <- c("top", "center", "bottom")

#' Allowed text orientation values
.const_text_orientation <- c("horizontal", "vertical_90", "vertical_270")

#' Allowed page sizes
.const_page_sizes <- c("A4", "A3", "Letter", "Legal", "Executive")

#' Allowed page orientations
.const_page_orientations <- c("portrait", "landscape")

#' Allowed column data types
.const_column_types <- c("string", "numeric")

#' Allowed document types
.const_doc_types <- c("Table", "Figure", "Text")

#' Border sides (used for iterating over borders)
.const_border_sides <- c("top", "bottom", "left", "right")


#' Color name to hex code mapping
#'
#' Maps standard color names to their hexadecimal RGB equivalents.
#' Includes grayscale colors: grey10-grey90 represent 10%-90% gray intensity
.const_color_hex_map <- list(
  black     = "#000000",
  white     = "#FFFFFF",
  red       = "#FF0000",
  green     = "#008000",
  blue      = "#0000FF",
  yellow    = "#FFFF00",
  orange    = "#FFA500",
  purple    = "#800080",
  pink      = "#FFC0CB",
  brown     = "#A52A2A",
  gray      = "#808080",
  grey      = "#808080",
  cyan      = "#00FFFF",
  magenta   = "#FF00FF",
  navy      = "#000080",
  teal      = "#008080",
  lime      = "#00FF00",
  maroon    = "#800000",
  olive     = "#808000",
  silver    = "#C0C0C0",
  gold      = "#FFD700",
  coral     = "#FF7F50",
  salmon    = "#FA8072",
  turquoise = "#40E0D0",
  violet    = "#EE82EE",
  indigo    = "#4B0082",
  khaki     = "#F0E68C",
  lavender  = "#E6E6FA",
  plum      = "#DDA0DD",
  tan       = "#D2B48C",
  grey10    = "#191919",
  grey20    = "#333333",
  grey30    = "#4D4D4D",
  grey40    = "#666666",
  grey60    = "#999999",
  grey70    = "#B3B3B3",
  grey80    = "#CCCCCC",
  grey90    = "#E6E6E6",
  gray10    = "#191919",
  gray20    = "#333333",
  gray30    = "#4D4D4D",
  gray40    = "#666666",
  gray60    = "#999999",
  gray70    = "#B3B3B3",
  gray80    = "#CCCCCC",
  gray90    = "#E6E6E6"
)

# ============================================================
# VALIDATION PATTERNS - Regex patterns for validation
# ============================================================

#' Pattern for font size (points only)
.const_pattern_font_size <- "^[0-9]+(\\.[0-9]+)?pt$"

#' Pattern for hex color codes
.const_pattern_hex_color <- "^#[0-9A-Fa-f]{6}$"

#' Pattern for color values (hex codes or predefined color names)
#' This pattern matches either hex codes or color names from .const_color_names
.const_pattern_color <- "^(#[0-9A-Fa-f]{6}|[a-zA-Z]+)$"

#' Pattern for spacing values (allows pt, cm, in, mm)
.const_pattern_spacing <- "^[0-9]+(\\.[0-9]+)?(pt|cm|in|mm)$"

#' Pattern for indentation values (allows negative, pt, cm, in, mm)
.const_pattern_indents <- "^-?[0-9]+(\\.[0-9]+)?(in|cm|mm|pt)$"

#' Pattern for margin values (allows pt, cm, in, mm)
.const_pattern_margins <- "^[0-9]+(\\.[0-9]+)?(in|cm|mm|pt)$"

#' Pattern for border width (points only)
.const_pattern_border_width <- "^[0-9]+(\\.[0-9]+)?pt$"

#' Pattern for row height (allows pt, cm, in, mm, or auto)
.const_pattern_row_height <- "^([0-9]+(\\.[0-9]+)?(pt|in|cm|mm)|(auto)$"

#' Pattern for column width (allows %, in, cm)
.const_pattern_col_width <- "^\\d+(\\.\\d+)?(%|in|cm)$"

#' Pattern for content width (allows %, in, cm)
.const_pattern_content_width <- "^\\d+(\\.\\d+)?(%|in|cm)$"

# ============================================================
# SCHEMA PROPERTY LISTS - Allowed properties for each schema type
# ============================================================

#' Schema property definitions
#'
#' Maps schema type names to their allowed property names.
#' Used for validation in .validate_params()
.const_schema_properties <- list(
  font = c("font_name", "font_size", "bold", "italic", "underline", "color", "highlight"),
  paragraph = c("alignment", "spacing", "indents", "word_style"),
  spacing = c("before", "after", "line_spacing"),
  indents = c("left", "right", "first_line"),
  table_style = c("background_color", "row_height", "vertical_alignment", "text_orientation", "borders"),
  borders = c("top", "bottom", "left", "right"),
  border = c("color", "width", "line_style"),
  page = c("size", "orientation", "margins"),
  margins = c("top", "bottom", "left", "right", "header", "footer"),
  documentStyle = c("docTemplate", "page"),
  col_format = c("type", "format", "missings", "colWidth", "valueStyleRef"),
  column = c("colOrder", "label", "isID", "isVisible", "isGrouping", "isPaging", "labelStyleRef", "isColBreak", "dedupe", "blankAfter", "format"),
  stub_column = c("label", "cols", "labelStyleRef", "stubOrder"),
  document = c("docType", "docPrefix", "glueNumType", "docOrder", "isContinues", "contentWidth", "bodyTitles", "bodyFootnotes", "hasData", "bodySubtitles"),
  text_group = c("text", "styleRef", "order")
)

# ============================================================
# MODIFIER CLASS MAPPINGS - Maps modifier classes to schema paths
# ============================================================

#' Modifier class to schema path mapping
#' 
#' Maps style modifier class names to their corresponding schema property paths.
.const_modifier_paths <- list(
  tfl_font = "font",
  tfl_paragraph = "paragraph",
  tfl_table_style = "table_style"
)

# ============================================================
# DEFAULT VALUES
# ============================================================

#' Default page size
.const_default_page_size <- "A4"

#' Default page orientation
.const_default_page_orientation <- "landscape"

#' Default document template name
.const_default_doc_template <- "KeyStat_default"

#' Default column format string for numeric types
.const_default_numeric_format <- "%d"

#' default missing value representation
.const_default_missing_value <- "NA"

#' Default line spacing minimum
.const_min_line_spacing <- 1

#' Maximum number of header/footer parts
.const_max_header_footer_parts <- 3L

#' Default body text message (when no data available)
.const_default_bodytext <- "No data to report"

#' Body text default ID prefix (for global defaults)
.const_bodytext_default_id_prefix <- "__default"

#' Order value for default body text (appears last)
.const_default_bodytext_order <- 999L

#' Schema file names
.const_spec_schema_file = "spec_schema_v1.json"
#' Style schema file name
.const_style_schema_file = "styles_schema_v0.json"
#' Row style schema file name
.const_row_style_schema_file = "row_style_actions_schema_v0.json"


# ============================================================
# JSON SCHEMA CONSTANTS
# ============================================================

#' JSON Schema type keywords
.const_schema_types <- c("string", "number", "integer", "boolean", "array", "object", "null")

#' JSON Schema keywords
.const_schema_keywords <- list(
  ref = "$ref",
  defs = "$defs",
  type = "type",
  properties = "properties",
  items = "items",
  enum = "enum",
  pattern = "pattern",
  const = "const",
  allOf = "allOf",
  oneOf = "oneOf",
  anyOf = "anyOf",
  additionalProperties = "additionalProperties",
  patternProperties = "patternProperties"
)

#' JSON Pointer reference prefix
.const_json_pointer_prefix <- "#/"

#' JSON Pointer escape mappings
.const_json_pointer_escapes <- list(
  tilde_char = "~",
  tilde_escape = "~0",
  slash_char = "/",
  slash_escape = "~1"
)

#' Schema directories in package
.const_schemas_dir <- "schemas"


# ============================================================
# PACKAGE OPTIONS MANAGEMENT
# ============================================================

# Page structure default values
.const_options_page <- structure(
  list(
    size = .const_default_page_size,
    orientation = .const_default_page_orientation
  ),
  class = "TFL_options"
)

.const_options_header_footer <- structure(list(), class = "TFL_options")

.const_options_bodytext <- structure(
  list(
    `__default_001` = list(
      text     = .const_default_bodytext,
      styleRef = character(0),
      order    = .const_default_bodytext_order
    )
  ),
  class = "TFL_options"
)

.const_options_styles <- structure(
  list(
    # Font styles
    font_bold = list(
      font = list(bold = TRUE)
    ),
    font_italic = list(
      font = list(italic = TRUE)
    ),
    font_underline = list(
      font = list(underline = TRUE)
    ),
    font_bold_italic = list(
      font = list(bold = TRUE, italic = TRUE)
    ),
    
    # Color styles (commonly used in clinical programming)
    text_blue = list(
      font = list(color = "#0000FF")
    ),
    text_red = list(
      font = list(color = "#FF0000")
    ),
    text_green = list(
      font = list(color = "#008000")
    ),
    
    # Alignment styles
    text_center = list(
      paragraph = list(alignment = "center")
    ),
    text_right = list(
      paragraph = list(alignment = "right")
    ),
    text_left = list(
      paragraph = list(alignment = "left")
    ),
    numeric_right = list(
      paragraph = list(alignment = "right")
    ),
    
    # Cell highlighting (warnings, out-of-range)
    cell_highlight_yellow = list(
      font = list(highlight = "#FFFF00")
    ),
    cell_highlight_red = list(
      font = list(highlight = "#FF0000")
    ),
    cell_highlight_green = list(
      font = list(highlight = "#90EE90")
    ),
    
    # Border styles
    cell_border_bottom = list(
      table_style = list(
        borders = list(
          bottom = list(width = "1pt", line_style = "single", color = "#000000")
        )
      )
    ),
    cell_border_top = list(
      table_style = list(
        borders = list(
          top = list(width = "1pt", line_style = "single", color = "#000000")
        )
      )
    ),
    cell_border_double_bottom = list(
      table_style = list(
        borders = list(
          bottom = list(width = "2pt", line_style = "double", color = "#000000")
        )
      )
    ),
    
    # Combination styles (common in clinical reports)
    header_bold = list(
      font = list(bold = TRUE, font_size = "12pt")
    ),
    header_bold_blue = list(
      font = list(bold = TRUE, color = "#0000FF")
    ),
    emphasis = list(
      font = list(bold = TRUE, italic = TRUE)
    ),
    footnote_italic_small = list(
      font = list(italic = TRUE, font_size = "9pt")
    ),
    total_bold = list(
      font = list(bold = TRUE),
      table_style = list(borders = list(top = list(width = "1pt", line_style = "single", color = "#000000")))
    ),
    result_numeric_right = list(
      font = list(color = "#000000"),
      paragraph = list(alignment = "right")
    ),
    warning_bold_red = list(
      font = list(bold = TRUE, color = "#FF0000")
    )
  ),
  class = "TFL_options"
)

