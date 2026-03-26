## Package constants and validation patterns for ksTFL
##
## This file contains package-wide constant objects used across ksTFL.
## It includes default spec templates, enumerations, validation regexes,
## schema property lists, and JSON schema helper constants. These constants
## are referenced by spec constructors, validation routines and serializer
## helpers to centralize magic strings and ensure consistent behavior.
##
## These objects are internal to the package and are not exported to CRAN
## users. They are documented here to assist developers working on
## specification creation, schema resolution, and formatting helpers.
##
## @keywords internal
## @name ksTFL-constants
NULL

#=============================================================================
# ksTFL/R/constants.R 
# Package-wide constants for ksTFL
#=============================================================================


## Initial empty spec structure
.const_empty_spec <- list(
  document    = list(),
  figure      = list(),
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
#' @noRd 
.const_font_names <- c(
  "Arial",
  "Courier New",
  "Times New Roman",
  "Georgia",
  "Verdana",
  "Trebuchet MS",
  "Liberation Sans"
)

#' Allowed text alignment values
#' @noRd
.const_alignment_values <- c("left", "right", "center", "justify", "distributed")

#' Allowed Word style names
#' @noRd
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
#' @noRd
.const_line_styles <- c("single", "double", "dashed", "dotted", "thick", "none")

#' Allowed vertical alignment values
#' @noRd
.const_vertical_alignment <- c("top", "center", "bottom")

#' Allowed text orientation values
#' @noRd
.const_text_orientation <- c("horizontal", "vertical_90", "vertical_270")

#' Allowed page sizes
#' @noRd
.const_page_sizes <- c("A4", "A3", "Letter", "Legal", "Executive")

#' Allowed page orientations
#' @noRd
.const_page_orientations <- c("portrait", "landscape")

#' Allowed column data types
#' @noRd
.const_column_types <- c("string", "numeric")

#' Allowed document types
#' @noRd
.const_doc_types <- c("Table", "Figure", "Text")

#' Allowed figure scale modes
#' @noRd
.const_figure_scale_modes <- c("fixed", "fitWidth", "fitPage")

#' Allowed figure device values
#' @noRd
.const_figure_devices <- c("png", "jpeg", "jpg", "svg")

#' Border sides (used for iterating over borders)
#' @noRd
.const_border_sides <- c("top", "bottom", "left", "right")


#' Color name to hex code mapping
#'
#' Maps standard color names to their hexadecimal RGB equivalents.
#' Includes grayscale colors: grey10-grey90 represent 10%-90% gray intensity
#' @noRd
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
#' @noRd
.const_pattern_font_size <- "^[0-9]+(\\.[0-9]+)?pt$"

#' Pattern for hex color codes
#' @noRd
.const_pattern_hex_color <- "^#[0-9A-Fa-f]{6}$"

#' Pattern for color values (hex codes or predefined color names)
#' This pattern matches either hex codes or color names from .const_color_names
#' @noRd
.const_pattern_color <- "^(#[0-9A-Fa-f]{6}|[a-zA-Z]+)$"

#' Pattern for spacing values (allows pt, cm, in, mm)
#' @noRd
.const_pattern_spacing <- "^[0-9]+(\\.[0-9]+)?(pt|cm|in|mm)$"

#' Pattern for indentation values (allows negative, pt, cm, in, mm)
#' @noRd
.const_pattern_indents <- "^-?[0-9]+(\\.[0-9]+)?(in|cm|mm|pt)$"

#' Pattern for margin values (allows pt, cm, in, mm)
#' @noRd
.const_pattern_margins <- "^[0-9]+(\\.[0-9]+)?(in|cm|mm|pt)$"

#' Pattern for border width (points only)
#' @noRd
.const_pattern_border_width <- "^[0-9]+(\\.[0-9]+)?pt$"

#' Pattern for row height (allows pt, cm, in, mm, or auto)
#' @noRd
.const_pattern_row_height <- "^([0-9]+(\\.[0-9]+)?(pt|in|cm|mm)|auto)$"

#' Pattern for table empty-line height (allows pt, cm, in, mm)
#' @noRd
.const_pattern_table_empty_line <- "^[0-9]+(\\.[0-9]+)?(pt|in|cm|mm)$"

#' Pattern for column width (allows %, in, cm)
#' @noRd
.const_pattern_col_width <- "^\\d+(\\.\\d+)?(%|in|cm)$"

#' Pattern for content width (allows %, in, cm)
#' @noRd
.const_pattern_content_width <- "^\\d+(\\.\\d+)?(%|in|cm)$"

#' Pattern for figure width/height (allows %, in, cm, mm, pt)
#' @noRd
.const_pattern_figure_size <- "^\\d+(\\.\\d+)?(%|in|cm|mm|pt)$"

# ============================================================
# SCHEMA PROPERTY LISTS - Allowed properties for each schema type
# ============================================================

#' Schema property definitions
#'
#' Maps schema type names to their allowed property names.
#' Used for validation in .validate_params()
#' @noRd
.const_schema_properties <- list(
  font = c("font_name", "font_size", "bold", "italic", "underline", "color", "highlight"),
  paragraph = c("alignment", "spacing", "indents", "word_style"),
  spacing = c("before", "after", "line_spacing"),
  indents = c("left", "right", "first_line"),
  table_style = c("background_color", "row_height", "vertical_alignment", "text_orientation", "borders", "topEmptyLine", "bottomEmptyLine"),
  borders = c("top", "bottom", "left", "right"),
  border = c("color", "width", "line_style"),
  page = c("size", "orientation", "margins"),
  margins = c("top", "bottom", "left", "right", "header", "footer"),
  documentStyle = c("docTemplate", "page"),
  col_format = c("type", "format", "missings", "colWidth", "valueStyleRef"),
  column = c("colOrder", "label", "isID", "isVisible", "isGrouping", "isPaging", "labelStyleRef", "isColBreak", "dedupe", "blankAfter", "format"),
  stub_column = c("label", "cols", "labelStyleRef", "stubOrder"),
  document = c("docType", "docOrder", "isContinues", "contentWidth", "footnotePlace", "hasData", "topEmptyLine", "bottomEmptyLine"),
  figure = c("width", "height", "figureScaleMode", "device"),
  text_group = c("text", "styleRef", "order", "toclevel")
)

# ============================================================
# MODIFIER CLASS MAPPINGS - Maps modifier classes to schema paths
# ============================================================

#' Modifier class to schema path mapping
#' 
#' Maps style modifier class names to their corresponding schema property paths.
#' @noRd
.const_modifier_paths <- list(
  tfl_font = "font",
  tfl_paragraph = "paragraph",
  tfl_table_style = "table_style"
)

# ============================================================
# DEFAULT VALUES
# ============================================================

#' Default page size
#' @noRd
.const_default_page_size <- "A4"

#' Default page orientation
#' @noRd
.const_default_page_orientation <- "landscape"

#' Default document template name
#' @noRd
.const_default_doc_template <- "CRO Example_default"

#' Default column format string for numeric types
#' @noRd
.const_default_numeric_format <- "%d"

#' default missing value representation
#' @noRd
.const_default_missing_value <- "NA"

#' Default line spacing minimum
#' @noRd
.const_min_line_spacing <- 1

#' Maximum number of header/footer parts
#' @noRd
.const_max_header_footer_parts <- 3L

#' Default body text message (when no data available)
#' @noRd
.const_default_bodytext <- "No data to report"

#' Body text default ID prefix (for global defaults)
#' @noRd
.const_bodytext_default_id_prefix <- "__default"

#' Order value for default body text (appears last)
#' @noRd
.const_default_bodytext_order <- 999L

#' Meta-folder index filename
#' @noRd
.const_index_file <- "_index.json"

#' Known asset file extensions for orphan detection in meta folders
#' @noRd
.const_asset_extensions <- c("png", "jpg", "jpeg", "svg", "pdf", "bmp", "tiff")

#' Schema file names
#' @noRd
.const_spec_schema_file = "spec_schema_v2.json"
#' Style schema file name
#' @noRd
.const_style_schema_file = "styles_schema_v2.json"
#' Row style schema file name
#' @noRd
.const_row_style_schema_file = "row_style_actions_schema_v0.json"


# ============================================================
# JSON SCHEMA CONSTANTS
# ============================================================

#' JSON Schema type keywords
#' @noRd
.const_schema_types <- c("string", "number", "integer", "boolean", "array", "object", "null")

#' JSON Schema keywords
#' @noRd
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
#' @noRd
.const_json_pointer_prefix <- "#/"

#' JSON Pointer escape mappings
#' @noRd
.const_json_pointer_escapes <- list(
  tilde_char = "~",
  tilde_escape = "~0",
  slash_char = "/",
  slash_escape = "~1"
)

#' Schema directories in package
#' @noRd
.const_schemas_dir <- "schemas"


# ============================================================
# PACKAGE OPTIONS MANAGEMENT
# ============================================================

# Page structure default values
# NULL means "no page override" — template provides all defaults.
# Only explicit user calls to set_page_style() / p_page() produce overrides.
.const_options_page <- NULL

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

# =============================================================================
# Built-in style atoms
#
# Design principle: each atom sets exactly one visual property.
# Combine atoms with f_combine() to build composite styles on the fly.
#
# Naming convention
# -----------------
#  b / i / u            font: bold / italic / underline
#                        aliases: font_bold / font_italic / font_underline
#  font_<family>        target font family atoms
#                        font_arial / font_courier_new / font_times_new_roman /
#                        font_georgia / font_verdana / font_trebuchet_ms
#  fs_N                 font size in pt  (fs_7 … fs_11)
#  fc_<colour>          font (text) colour
#  hl_<colour>          cell text highlight / shading
#  al / ar / ac         paragraph alignment: left / right / centre
#                        aliases: text_left / text_right / text_center
#  ind0 … ind4          left-indent levels (0.5 cm steps)
#                        aliases: indent_0 … indent_4
#  rind0 … rind4         right-indent levels (0.5 cm steps)
#                        aliases: rindent_0 … rindent_4
#  tw_95 … tw_50        symmetric left+right indent to match table at 95/90/85/…/50 %
#                        of content width, 5 % steps (A4 landscape, 0.5 in margins)
#  sp_0 / sp_2 / sp_4   paragraph spacing before+after: 0 / 2 / 4 pt
#  kl / kn              pagination: keep_lines / keep_next
#  va_t / va_m / va_b   cell vertical alignment: top / middle / bottom
#                        aliases: va_top / va_center / va_bottom
#  to_h / to_90 / to_270  cell text orientation: horizontal / 90° / 270°
#                        aliases: text_horizontal / text_vertical_90 / text_vertical_270
#  bg_<colour>          cell background colour
#  row_h2 / row_h4 / row_h6  row height atoms (2 / 4 / 6 pt)
#  bt / bb / bl / br    border side 1 pt black: top / bottom / left / right
#  bt_th / bb_th        border side 0.5 pt black: top / bottom (thin)
#  bc_gray / bc_white   border colour override: gray / white (suppress)
#                        alias: bc_grey
#  grp_hdr / grp_hdr_i  group-header composites: bold + space-above
# =============================================================================
.const_options_styles <- structure(
  list(

    # -------------------------------------------------------------------------
    # Font — decoration
    # -------------------------------------------------------------------------
    b              = list(font = list(bold      = TRUE)),
    i              = list(font = list(italic    = TRUE)),
    u              = list(font = list(underline = TRUE)),
    # aliases
    font_bold      = list(font = list(bold      = TRUE)),
    font_italic    = list(font = list(italic    = TRUE)),
    font_underline = list(font = list(underline = TRUE)),

  # -------------------------------------------------------------------------
  # Font — target family
  # Use these atoms to select one of the package target font families without
  # setting any face/style properties such as bold or italic.
  # -------------------------------------------------------------------------
  font_arial            = list(font = list(font_name = "Arial")),
  font_courier_new      = list(font = list(font_name = "Courier New")),
  font_times_new_roman  = list(font = list(font_name = "Times New Roman")),
  font_georgia          = list(font = list(font_name = "Georgia")),
  font_verdana          = list(font = list(font_name = "Verdana")),
  font_trebuchet_ms     = list(font = list(font_name = "Trebuchet MS")),

    # -------------------------------------------------------------------------
    # Font — size  (explicit pt values; use the value closest to your template)
    # -------------------------------------------------------------------------
    fs_7  = list(font = list(font_size = "7pt")),
    fs_8  = list(font = list(font_size = "8pt")),
    fs_9  = list(font = list(font_size = "9pt")),
    fs_10 = list(font = list(font_size = "10pt")),
    fs_11 = list(font = list(font_size = "11pt")),

    # -------------------------------------------------------------------------
    # Font — colour  (text colour)
    # Pure colours for flags/alerts; muted colours for secondary content
    # -------------------------------------------------------------------------
    fc_black  = list(font = list(color = "#000000")),  # reset to black
    fc_red    = list(font = list(color = "#FF0000")),  # alert / out-of-range
    fc_blue   = list(font = list(color = "#0000FF")),  # informational
    fc_green  = list(font = list(color = "#008000")),  # within-range / pass
    fc_gray   = list(font = list(color = "#595959")),  # secondary / reference values
    fc_grey   = list(font = list(color = "#595959")),  # alias for fc_gray
    # Muted / softer palette — less aggressive than pure primaries
    fc_navy   = list(font = list(color = "#1F3864")),  # dark navy — formal headers
    fc_teal   = list(font = list(color = "#2E75B6")),  # medium blue — informational
    fc_olive  = list(font = list(color = "#5C7A29")),  # muted green — pass / normal
    fc_rust   = list(font = list(color = "#C0392B")),  # muted red — caution
    fc_plum   = list(font = list(color = "#7B2D8B")),  # purple — special category
    fc_slate  = list(font = list(color = "#44546A")),  # blue-gray — subdued label

    # -------------------------------------------------------------------------
    # Text highlight  (background shading behind text)
    # Pure colours for strong flags; pastel colours for subtle banding
    # -------------------------------------------------------------------------
    hl_yellow = list(font = list(highlight = "#FFFF00")),  # strong flag / attention
    hl_red    = list(font = list(highlight = "#FF0000")),  # critical / TEAE
    hl_green  = list(font = list(highlight = "#90EE90")),  # within-range
    hl_gray   = list(font = list(highlight = "#EEEEEE")),  # suppressed / N/A
    hl_grey   = list(font = list(highlight = "#EEEEEE")),  # alias for hl_gray
    # Pastel palette — softer attention markers
    hl_peach  = list(font = list(highlight = "#FADADD")),  # soft red — mild alert
    hl_mint   = list(font = list(highlight = "#D5F5E3")),  # soft green — normal range
    hl_sky    = list(font = list(highlight = "#D6EAF8")),  # soft blue — informational
    hl_lemon  = list(font = list(highlight = "#FEFBD8")),  # soft yellow — caution
    hl_lilac  = list(font = list(highlight = "#E8DAEF")),  # soft purple — special

    # -------------------------------------------------------------------------
    # Paragraph — alignment
    # -------------------------------------------------------------------------
    al         = list(paragraph = list(alignment = "left")),
    ar         = list(paragraph = list(alignment = "right")),
    ac         = list(paragraph = list(alignment = "center")),
    # aliases
    text_left   = list(paragraph = list(alignment = "left")),
    text_right  = list(paragraph = list(alignment = "right")),
    text_center = list(paragraph = list(alignment = "center")),

    # -------------------------------------------------------------------------
    # Paragraph — left indentation  (stub / sub-group hierarchy)
    #   ind0 = no indent (reset to left margin)
    #   ind1 = top-level category label  e.g. "Age (years)"
    #   ind2 = first sub-group           e.g. "  < 18"
    #   ind3 = second sub-group          e.g. "    Missing"
    #   ind4 = third sub-group / detail
    # -------------------------------------------------------------------------
    ind0    = list(paragraph = list(indents = list(left = "0cm"))),
    ind1    = list(paragraph = list(indents = list(left = "0.5cm"))),
    ind2    = list(paragraph = list(indents = list(left = "1.0cm"))),
    ind3    = list(paragraph = list(indents = list(left = "1.5cm"))),
    ind4    = list(paragraph = list(indents = list(left = "2.0cm"))),
    # aliases
    indent_0 = list(paragraph = list(indents = list(left = "0cm"))),
    indent_1 = list(paragraph = list(indents = list(left = "0.5cm"))),
    indent_2 = list(paragraph = list(indents = list(left = "1.0cm"))),
    indent_3 = list(paragraph = list(indents = list(left = "1.5cm"))),
    indent_4 = list(paragraph = list(indents = list(left = "2.0cm"))),

    # -------------------------------------------------------------------------
    # Paragraph — right indentation
    #   rind0 = no right indent (reset to right margin)
    #   rind1 = 0.5 cm right indent
    #   rind2 = 1.0 cm right indent
    #   rind3 = 1.5 cm right indent
    #   rind4 = 2.0 cm right indent
    # -------------------------------------------------------------------------
    rind0    = list(paragraph = list(indents = list(right = "0cm"))),
    rind1    = list(paragraph = list(indents = list(right = "0.5cm"))),
    rind2    = list(paragraph = list(indents = list(right = "1.0cm"))),
    rind3    = list(paragraph = list(indents = list(right = "1.5cm"))),
    rind4    = list(paragraph = list(indents = list(right = "2.0cm"))),
    # aliases
    rindent_0 = list(paragraph = list(indents = list(right = "0cm"))),
    rindent_1 = list(paragraph = list(indents = list(right = "0.5cm"))),
    rindent_2 = list(paragraph = list(indents = list(right = "1.0cm"))),
    rindent_3 = list(paragraph = list(indents = list(right = "1.5cm"))),
    rindent_4 = list(paragraph = list(indents = list(right = "2.0cm"))),

    # -------------------------------------------------------------------------
    # Paragraph — table-width shrink atoms  (left + right symmetric indent)
    #
    # Use on footnotes / titles / subtitles / body-text to keep them visually
    # aligned with a narrower table.  Calculated for A4 landscape with 0.5 in
    # left/right page margins (content width ≈ 27.16 cm).
    # Each 5 % step = 0.68 cm per side.
    #
    #   tw_%% : table at %% % of content width
    #           → indent each side = (1 - %% / 100) * 27.16 / 2  cm
    #
    #   tw_95 : 95 % → 0.68 cm each side
    #   tw_90 : 90 % → 1.36 cm each side
    #   tw_85 : 85 % → 2.04 cm each side
    #   tw_80 : 80 % → 2.72 cm each side
    #   tw_75 : 75 % → 3.40 cm each side
    #   tw_70 : 70 % → 4.07 cm each side
    #   tw_65 : 65 % → 4.75 cm each side
    #   tw_60 : 60 % → 5.43 cm each side
    #   tw_55 : 55 % → 6.11 cm each side
    #   tw_50 : 50 % → 6.79 cm each side
    #
    # Example:
    #   spec <- add_footnote(spec, "Source: study database.",
    #                        styleRef = "tw_80")
    #   # combine with other atoms:
    #   spec <- add_title(spec, "Demographics",
    #                     styleRef = f_combine("b", "tw_75"))
    # -------------------------------------------------------------------------
    tw_95 = list(paragraph = list(indents = list(left = "0.68cm", right = "0.68cm"))),
    tw_90 = list(paragraph = list(indents = list(left = "1.36cm", right = "1.36cm"))),
    tw_85 = list(paragraph = list(indents = list(left = "2.04cm", right = "2.04cm"))),
    tw_80 = list(paragraph = list(indents = list(left = "2.72cm", right = "2.72cm"))),
    tw_75 = list(paragraph = list(indents = list(left = "3.40cm", right = "3.40cm"))),
    tw_70 = list(paragraph = list(indents = list(left = "4.07cm", right = "4.07cm"))),
    tw_65 = list(paragraph = list(indents = list(left = "4.75cm", right = "4.75cm"))),
    tw_60 = list(paragraph = list(indents = list(left = "5.43cm", right = "5.43cm"))),
    tw_55 = list(paragraph = list(indents = list(left = "6.11cm", right = "6.11cm"))),
    tw_50 = list(paragraph = list(indents = list(left = "6.79cm", right = "6.79cm"))),

    # -------------------------------------------------------------------------
    # Paragraph — vertical spacing  (before + after, same value each side)
    #   sp_0 : no space  — dense safety listings / large tables
    #   sp_2 : 2 pt      — sub-section breathing room
    #   sp_4 : 4 pt      — summary / efficacy tables
    # -------------------------------------------------------------------------
    sp_0 = list(paragraph = list(spacing = list(before = "0pt", after = "0pt", line_spacing = 1.0))),
    sp_2 = list(paragraph = list(spacing = list(before = "2pt", after = "2pt", line_spacing = 1.0))),
    sp_4 = list(paragraph = list(spacing = list(before = "4pt", after = "4pt", line_spacing = 1.0))),

    # -------------------------------------------------------------------------
    # Paragraph — pagination control
    #   kl : keep all lines of a cell together on the same page
    #   kn : keep this row on the same page as the following row
    #        (prevents group headers from being orphaned at page bottom)
    # -------------------------------------------------------------------------
    kl = list(paragraph = list(keep_lines = TRUE)),
    kn = list(paragraph = list(keep_next  = TRUE)),

    # -------------------------------------------------------------------------
    # Group / category header composites
    # Convenience atoms that combine bold + space-above + no-indent.
    # Equivalent to f_combine("b", "sp_4") with an explicit left-indent reset.
    #   grp_hdr   : bold — marks a new parameter/category block
    #   grp_hdr_i : bold + italic — sub-parameter label within a by-visit table
    # -------------------------------------------------------------------------
    grp_hdr = list(
      font      = list(bold = TRUE),
      paragraph = list(indents = list(left = "0cm"),
                       spacing = list(before = "4pt", after = "0pt"))
    ),
    grp_hdr_i = list(
      font      = list(bold = TRUE, italic = TRUE),
      paragraph = list(indents = list(left = "0cm"),
                       spacing = list(before = "4pt", after = "0pt"))
    ),

    # -------------------------------------------------------------------------
    # Cell — vertical alignment
    # -------------------------------------------------------------------------
    va_t      = list(table_style = list(vertical_alignment = "top")),
    va_m      = list(table_style = list(vertical_alignment = "center")),
    va_b      = list(table_style = list(vertical_alignment = "bottom")),
    # aliases
    va_top    = list(table_style = list(vertical_alignment = "top")),
    va_center = list(table_style = list(vertical_alignment = "center")),
    va_bottom = list(table_style = list(vertical_alignment = "bottom")),

    # -------------------------------------------------------------------------
    # Cell — text orientation
    # Useful for narrow column headers in dense tables (e.g. visit/parameter grids)
    #   to_h   : horizontal (default)
    #   to_90  : rotated 90°  counter-clockwise — text reads bottom-to-top
    #   to_270 : rotated 270° counter-clockwise — text reads top-to-bottom
    # aliases: text_horizontal / text_vertical_90 / text_vertical_270
    # -------------------------------------------------------------------------
    to_h   = list(table_style = list(text_orientation = "horizontal")),
    to_90  = list(table_style = list(text_orientation = "vertical_90")),
    to_270 = list(table_style = list(text_orientation = "vertical_270")),
    # aliases
    text_horizontal   = list(table_style = list(text_orientation = "horizontal")),
    text_vertical_90  = list(table_style = list(text_orientation = "vertical_90")),
    text_vertical_270 = list(table_style = list(text_orientation = "vertical_270")),

    # -------------------------------------------------------------------------
    # Cell — background colour
    # Pure / strong backgrounds for clear section breaks
    # Pastel backgrounds for subtle banding without overpowering the content
    # -------------------------------------------------------------------------
    bg_blue      = list(table_style = list(background_color = "#D9E1F2")),  # soft blue — emphasis rows
    bg_gray      = list(table_style = list(background_color = "#F2F2F2")),  # light gray — alternating / sub-totals
    bg_grey      = list(table_style = list(background_color = "#F2F2F2")),  # alias for bg_gray
    # Pastel palette
    bg_peach     = list(table_style = list(background_color = "#FADADD")),  # soft red — mild alert row
    bg_mint      = list(table_style = list(background_color = "#D5F5E3")),  # soft green — normal range row
    bg_sky       = list(table_style = list(background_color = "#D6EAF8")),  # soft blue — informational row
    bg_lemon     = list(table_style = list(background_color = "#FEFBD8")),  # soft yellow — caution row
    bg_lilac     = list(table_style = list(background_color = "#E8DAEF")),  # soft purple — special category
    bg_navy      = list(table_style = list(background_color = "#1F3864")),  # dark navy — strong header band
    bg_slate     = list(table_style = list(background_color = "#44546A")),  # blue-gray — header band
    bg_steel     = list(table_style = list(background_color = "#BDD7EE")),  # medium blue — column group header

    # -------------------------------------------------------------------------
    # Row height atoms  (use with add_row() to build separator rows)
    #   row_h2 : 2 pt — near-invisible spacer
    #   row_h4 : 4 pt — small gap
    #   row_h6 : 6 pt — visible gap
    # Combine with border atoms, e.g.:
    #   f_combine("row_h2", "bb_th")   → thin ruled separator
    #   f_combine("row_h2", "bc_white") → invisible spacer (all borders suppressed)
    # -------------------------------------------------------------------------
    row_h2 = list(table_style = list(row_height = "2pt")),
    row_h4 = list(table_style = list(row_height = "4pt")),
    row_h6 = list(table_style = list(row_height = "6pt")),

    # -------------------------------------------------------------------------
    # Border — side atoms  (1 pt black, single line)
    # -------------------------------------------------------------------------
    bt = list(table_style = list(borders = list(top    = list(width = "1pt",   line_style = "single", color = "#000000")))),
    bb = list(table_style = list(borders = list(bottom = list(width = "1pt",   line_style = "single", color = "#000000")))),
    bl = list(table_style = list(borders = list(left   = list(width = "1pt",   line_style = "single", color = "#000000")))),
    br = list(table_style = list(borders = list(right  = list(width = "1pt",   line_style = "single", color = "#000000")))),

    # -------------------------------------------------------------------------
    # Border — thin side atoms  (0.5 pt black, single line)
    # Use for sub-section dividers, subtotal separators
    # -------------------------------------------------------------------------
    bt_th = list(table_style = list(borders = list(top    = list(width = "0.5pt", line_style = "single", color = "#000000")))),
    bb_th = list(table_style = list(borders = list(bottom = list(width = "0.5pt", line_style = "single", color = "#000000")))),

    # -------------------------------------------------------------------------
    # Border — colour override atoms
    # Apply AFTER a side atom to change its colour.  The merge is last-win, so
    # the colour override replaces the colour set by the preceding side atom.
    # Examples:
    #   f_combine("bt", "bc_gray")   → gray 1 pt top border
    #   f_combine("row_h2", "bc_white") → invisible separator (all sides suppressed)
    #
    #   bc_gray  : medium gray (#AAAAAA) — softer dividers in banded tables
    #   bc_white : white / no border     — suppress all sides (separator rows)
    # -------------------------------------------------------------------------
    bc_gray  = list(table_style = list(borders = list(
      top    = list(color = "#AAAAAA"),
      bottom = list(color = "#AAAAAA"),
      left   = list(color = "#AAAAAA"),
      right  = list(color = "#AAAAAA")
    ))),
    bc_grey  = list(table_style = list(borders = list(
      top    = list(color = "#AAAAAA"),
      bottom = list(color = "#AAAAAA"),
      left   = list(color = "#AAAAAA"),
      right  = list(color = "#AAAAAA")
    ))),
    bc_white = list(table_style = list(borders = list(
      top    = list(width = "0pt", line_style = "none", color = "#FFFFFF"),
      bottom = list(width = "0pt", line_style = "none", color = "#FFFFFF"),
      left   = list(width = "0pt", line_style = "none", color = "#FFFFFF"),
      right  = list(width = "0pt", line_style = "none", color = "#FFFFFF")
    )))

  ),
  class = "TFL_options"
)

# ============================================================
# PACKAGE-LEVEL CACHE ENVIRONMENTS
# ============================================================

#' Package-level cache for schema resolution
#' 
#' Used by .resolve_refs() in schema_serialize.R to cache resolved
#' schema references across multiple spec serializations, reducing
#' redundant JSON pointer resolution.
#' 
#' @keywords internal
#' @noRd
.schema_cache <- new.env(parent = emptyenv())

#' Package-level cache for style resolution
#' 
#' Used by ._resolve_style_refs() in spec_context.R to memoize
#' repeated style lookups with identical inputs, reducing redundant
#' recursive merges during spec validation.
#' 
#' @keywords internal
#' @noRd
.style_resolution_cache <- new.env(parent = emptyenv())

#' Package-level cache for format specifications
#' 
#' Used by .guess_col_formats() in utility_functions.R to cache
#' format specs by column type, avoiding repeated type detection
#' and format string construction for columns with same characteristics.
#' 
#' @keywords internal
#' @noRd
.format_spec_cache <- new.env(parent = emptyenv())

