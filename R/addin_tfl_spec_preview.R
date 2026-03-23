#' RStudio Addins for TFL Specification Preview
#'
#' Two addins that open the HTML TFL Specification Preview in the RStudio
#' Viewer pane.
#'
#' \describe{
#'   \item{`tfl_spec_preview_selection()`}{Evaluates the currently selected
#'     text in the source editor and, if the result is a `TFL_spec` object,
#'     opens the HTML preview.}
#'   \item{`tfl_spec_preview_prompt()`}{Prompts for the name of an object
#'     in `.GlobalEnv` and, if it is a `TFL_spec`, opens the HTML preview.}
#' }
#'
#' Both functions require RStudio (`rstudioapi::isAvailable()`).
#'
#' @name tfl_spec_addins
#' @seealso [view_tfl_spec()]
NULL

#' @rdname tfl_spec_addins
#' @export
tfl_spec_preview_selection <- function() {
  if (!rstudioapi::isAvailable()) {
    message("This addin requires RStudio.")
    return(invisible(NULL))
  }

  ctx <- rstudioapi::getSourceEditorContext()
  sel <- trimws(ctx$selection[[1L]]$text)

  if (!nzchar(sel)) {
    rstudioapi::showDialog(
      "TFL Spec Preview",
      "Please select an expression or variable name that evaluates to a TFL_spec object."
    )
    return(invisible(NULL))
  }

  obj <- tryCatch(
    eval(parse(text = sel), envir = .GlobalEnv),
    error = function(e) e
  )

  if (inherits(obj, "error")) {
    rstudioapi::showDialog(
      "TFL Spec Preview",
      paste0("Could not evaluate the selection:\n", conditionMessage(obj))
    )
    return(invisible(NULL))
  }

  if (!inherits(obj, "TFL_spec")) {
    rstudioapi::showDialog(
      "TFL Spec Preview",
      paste0(
        "The selection evaluates to an object of class '",
        paste(class(obj), collapse = "/"), "', not 'TFL_spec'."
      )
    )
    return(invisible(NULL))
  }

  .render_TFL_spec_viewer(obj)
}

#' @rdname tfl_spec_addins
#' @export
tfl_spec_preview_prompt <- function() {
  if (!rstudioapi::isAvailable()) {
    message("This addin requires RStudio.")
    return(invisible(NULL))
  }

  name <- rstudioapi::showPrompt(
    title   = "TFL Spec Preview",
    message = "Enter the name of a TFL_spec object (in .GlobalEnv):",
    default = ""
  )

  if (is.null(name) || !nzchar(trimws(name))) {
    return(invisible(NULL))
  }
  name <- trimws(name)

  if (!exists(name, envir = .GlobalEnv)) {
    rstudioapi::showDialog(
      "TFL Spec Preview",
      paste0("Object '", name, "' not found in .GlobalEnv.")
    )
    return(invisible(NULL))
  }

  obj <- get(name, envir = .GlobalEnv)

  if (!inherits(obj, "TFL_spec")) {
    rstudioapi::showDialog(
      "TFL Spec Preview",
      paste0(
        "'", name, "' is of class '",
        paste(class(obj), collapse = "/"), "', not 'TFL_spec'."
      )
    )
    return(invisible(NULL))
  }

  .render_TFL_spec_viewer(obj)
}

# =========================================================================
# Style Atoms Catalog
# =========================================================================

.style_atom_category <- function(nm) {
  if (nm %in% c("b", "i", "u", "font_bold", "font_italic", "font_underline"))
    return("Font \u2014 decoration")
  if (nm %in% c(
    "font_arial", "font_courier_new", "font_times_new_roman",
    "font_georgia", "font_verdana", "font_trebuchet_ms"
  ))
    return("Font \u2014 family")
  if (grepl("^fs_", nm))    return("Font \u2014 size")
  if (grepl("^fc_", nm))    return("Font \u2014 colour")
  if (grepl("^hl_", nm))    return("Text highlight")
  if (nm %in% c("al", "ar", "ac", "text_left", "text_right", "text_center"))
    return("Paragraph \u2014 alignment")
  if (grepl("^ind", nm) || grepl("^indent_", nm))
    return("Paragraph \u2014 indentation")
  if (grepl("^tw_", nm))    return("Paragraph \u2014 table-width shrink")
  if (grepl("^sp_", nm))    return("Paragraph \u2014 spacing")
  if (nm %in% c("kl", "kn")) return("Paragraph \u2014 pagination")
  if (grepl("^grp_hdr", nm)) return("Group header composites")
  if (grepl("^va_", nm))    return("Cell \u2014 vertical alignment")
  if (grepl("^to_", nm) || grepl("^text_horizontal$|^text_vertical", nm))
    return("Cell \u2014 text orientation")
  if (grepl("^bg_", nm))    return("Cell \u2014 background")
  if (grepl("^row_h", nm))  return("Row height")
  if (nm %in% c("bt", "bb", "bl", "br"))
    return("Border \u2014 sides (1 pt)")
  if (grepl("^bt_th$|^bb_th$", nm))
    return("Border \u2014 thin (0.5 pt)")
  if (grepl("^bc_", nm))    return("Border \u2014 colour override")
  "Other"
}

.flatten_style_value <- function(val, prefix = "") {
  if (!is.list(val)) {
    return(paste0(prefix, " = ",
                  if (is.logical(val)) toupper(val) else paste0("\"", val, "\"")))
  }
  parts <- character(0)
  for (k in names(val)) {
    child_prefix <- if (nzchar(prefix)) paste0(prefix, ".", k) else k
    parts <- c(parts, .flatten_style_value(val[[k]], child_prefix))
  }
  parts
}

.hex_swatch <- function(hex) {
  if (cli::num_ansi_colors() >= 256L) {
    tryCatch(
      cli::make_ansi_style(hex)("\u2588\u2588"),
      error = function(e) ""
    )
  } else {
    ""
  }
}

#' Print all built-in style atoms to the console
#'
#' Iterates over every atom in the internal `.const_options_styles` registry
#' and prints a coloured, grouped summary using \pkg{cli}.
#' `tfl_style_atoms_catalog()` is a convenience alias for `tfl_print_style_atoms()`.
#'
#' @return Invisible `NULL`.
#'
#' @examples
#' \dontrun{
#' # Print the full catalog of built-in style atoms
#' tfl_print_style_atoms()
#'
#' # Same output via the alias
#' tfl_style_atoms_catalog()
#' }
#'
#' @export
tfl_print_style_atoms <- function() {
  atoms <- .const_options_styles
  nms   <- names(atoms)

  categories <- vapply(nms, .style_atom_category, character(1),
                       USE.NAMES = FALSE)
  seen_cats  <- unique(categories)

  alias_set <- c(
    "font_bold", "font_italic", "font_underline",
    "fc_grey",
    "hl_grey",
    "text_left", "text_right", "text_center",
    "indent_0", "indent_1", "indent_2", "indent_3", "indent_4",
    "va_top", "va_center", "va_bottom",
    "text_horizontal", "text_vertical_90", "text_vertical_270",
    "bg_grey",
    "bc_grey"
  )

  name_width <- 24L

  for (cat in seen_cats) {
    cli::cli_rule(cat)
    idx <- which(categories == cat)
    for (j in idx) {
      nm  <- nms[j]
      val <- atoms[[j]]

      flat <- .flatten_style_value(val)
      desc <- paste(flat, collapse = ", ")

      is_alias <- nm %in% alias_set
      alias_tag <- if (is_alias) cli::col_yellow(" (alias)") else ""

      padded <- formatC(nm, width = -name_width, flag = "-")
      label  <- cli::col_blue(cli::style_bold(padded))

      hex <- NULL
      for (section in val) {
        for (prop in c("color", "highlight", "background_color")) {
          if (!is.null(section[[prop]])) { hex <- section[[prop]]; break }
        }
        if (!is.null(hex)) break
      }
      swatch <- if (!is.null(hex)) paste0("  ", .hex_swatch(hex)) else ""

      cli::cli_text("  {label}{alias_tag}  {desc}{swatch}")
    }
  }

  n_total   <- length(nms)
  n_alias   <- sum(nms %in% alias_set)
  n_cats    <- length(seen_cats)
  cli::cli_text("")
  cli::cli_alert_info(
    "{n_total} style atom{?s} in {n_cats} categor{?y/ies} ({n_alias} alias{?es})"
  )

  invisible(NULL)
}

#' @rdname tfl_print_style_atoms
#' @export
tfl_style_atoms_catalog <- function() {
  tfl_print_style_atoms()
}
