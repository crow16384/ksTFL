#' Print method for TFL specification objects
#'
#' Provides a comprehensive, human-readable overview of a TFL specification object
#' with formatted tables, colors, and legends. Shows document metadata, columns with
#' types and formats, titles, headers, footers, and sample data.
#'
#' @param x A `TFL_spec` object (required). The specification to print.
#' @param layout Display mode as a character string:
#'   \itemize{
#'     \item `"compact"`: Brief overview (default)
#'     \item `"full"`: Detailed view with all sections
#'   }
#' @param width Integer. Terminal width for text wrapping (default: from `getOption("width", 80L)`).
#'   Used to calculate column widths and text truncation.
#' @param colors Logical. If `TRUE` (default), uses ANSI color codes for visual distinction
#'   (section headers in cyan/yellow/green, column names in blue). If `FALSE`, plain text.
#' @param ... Additional arguments passed to print methods (ignored).
#'
#' @return The spec object (invisibly). This allows print to be called on a spec object
#'   for side effects while preserving the spec in piped workflows.
#'
#' @details
#' The full layout displays:
#' \itemize{
#'   \item Document type and data availability
#'   \item Summary counts (columns, titles, headers, footers, etc.)
#'   \item Page settings (size, orientation)
#'   \item Headers and footers content
#'   \item Titles, subtitles, and footnotes
#'   \item Column metadata table (Name, Label, Type, Format, Missings, Width, Flags, Styles)
#'   \item Flag legend explaining special column properties
#'   \item Body text content
#'   \item Sample data (first 3 rows)
#' }
#'
#' \strong{Flags Legend:}
#' \itemize{
#'   \item `*` = ID column (primary identifier)
#'   \item `x` = Hidden column (not visible in output)
#'   \item `#` = Grouping column (used for grouping rows)
#'   \item `>` = Page break (trigger page break)
#'   \item `v` = Column break (trigger column break)
#'   \item `d` = Deduplicate (remove duplicate values)
#'   \item `_` = Blank after (insert blank row after value change)
#' }
#'
#' @keywords internal
#' @name print.TFL_spec
#' @aliases print.TFL_spec
#'
#' @examples
#' \dontrun{
#' data <- data.frame(id = 1:10, age = rnorm(10, 45, 10), group = rep(c("A", "B"), 5))
#' spec <- create_table(data) |>
#'   add_title("Motor Trend Study") |>
#'   add_subtitle("Vehicle Performance Analysis") |>
#'   add_header(c("ABC Research", "Confidential", "2024")) |>
#'   add_footnote("Source: mtcars dataset")
#'
#' # Print with full details (calls print.TFL_spec)
#' print(spec)
#'
#' # Compact view
#' print(spec, layout = "compact")
#'
#' # Without colors
#' print(spec, colors = FALSE)
#' }
print.TFL_spec <- function(x, layout = c("full", "compact"), width = getOption("width", 80L), colors = TRUE, ...) {
  layout <- match.arg(layout)

  # Constants for display
  .const_compact_max_cols <- 12L
  .const_max_name_width <- 30L
  .const_max_label_width <- 50L
  .const_max_format_width <- 20L
  .const_max_width_width <- 12L

  # Color helpers
  col_blue <- function(x) if (isTRUE(colors)) cli::col_blue(x) else x
  col_yellow <- function(x) if (isTRUE(colors)) cli::col_yellow(x) else x
  col_magenta <- function(x) if (isTRUE(colors)) cli::col_magenta(x) else x
  col_green <- function(x) if (isTRUE(colors)) cli::col_green(x) else x
  col_cyan <- function(x) if (isTRUE(colors)) cli::col_cyan(x) else x
  col_red <- function(x) if (isTRUE(colors)) cli::col_red(x) else x

  # Truncate text with ellipsis
  ellipsize <- function(x, max_len) {
    s <- as.character(x)
    if (is.na(s) || s == "") return("")
    # Replace control characters that could break table formatting
    s <- gsub("[\n\r\t]", " ", s, fixed = FALSE)
    # Collapse multiple spaces to single space
    s <- gsub(" +", " ", s)
    if (nchar(s) > max_len) paste0(substr(s, 1, max_len - 1), "\u2026") else s
  }

  # Helper for colored section separators
  .colored_rule <- function(title, color_fn = col_cyan) {
    rule_text <- paste0("\u2500\u2500\u2500 ", title, " ", paste(rep("\u2500", max(1, 70 - nchar(title))), collapse = ""))
    cli::cli_text(color_fn(rule_text))
  }

  # Extract column metadata from spec
  .extract_column_info <- function(cn, cs) {
    lab <- cs$label %||% cs$colLabel %||% ""
    # Handle NULL/NA safely
    if (is.null(lab) || (length(lab) == 1 && is.na(lab))) lab <- ""
    # Replace newlines and other control characters with spaces to prevent table misalignment
    lab <- gsub("[\n\r\t]", " ", lab, fixed = FALSE)
    fmt_val <- cs$format %||% cs$c_format %||% NULL
    ftype <- ""
    ffmt <- ""
    colw <- ""
    miss <- ""
    if (is.list(fmt_val)) {
      ftype <- fmt_val$type %||% ""
      ffmt <- fmt_val$format %||% ""
      if (!is.null(fmt_val$colWidth)) colw <- as.character(fmt_val$colWidth)
    } else if (is.character(fmt_val) && length(fmt_val) == 1) {
      ffmt <- fmt_val
    }

    # Direct fields from define_cols
    if (!is.null(cs$colWidth)) colw <- as.character(cs$colWidth)
    if (!is.null(cs$missings)) miss <- as.character(cs$missings)

    # Collect flags
    flags <- c()
    if (!is.null(cs$isID) && isTRUE(cs$isID)) flags <- c(flags, "ID")
    if (!is.null(cs$isVisible) && isFALSE(cs$isVisible)) flags <- c(flags, "hidden")
    if (!is.null(cs$isGrouping) && isTRUE(cs$isGrouping)) flags <- c(flags, "group")
    if (!is.null(cs$isPaging) && isTRUE(cs$isPaging)) flags <- c(flags, "page_break")
    if (!is.null(cs$isColBreak) && isTRUE(cs$isColBreak)) flags <- c(flags, "col_break")
    if (!is.null(cs$dedupe) && isTRUE(cs$dedupe)) flags <- c(flags, "dedupe")
    if (!is.null(cs$blankAfter) && isTRUE(cs$blankAfter)) flags <- c(flags, "blank_after")

    # Collect styles from all style references, separated by type
    label_styles <- character(0)
    value_styles <- character(0)
    other_styles <- character(0)
    
    # Label styles
    if (!is.null(cs$labelStyleRef)) {
      if (is.list(cs$labelStyleRef)) {
        label_styles <- c(label_styles, unlist(cs$labelStyleRef))
      } else if (is.character(cs$labelStyleRef)) {
        label_styles <- c(label_styles, as.character(cs$labelStyleRef))
      }
    }
    
    # Value styles (from format object or direct)
    if (!is.null(cs$valueStyleRef)) {
      if (is.list(cs$valueStyleRef)) {
        value_styles <- c(value_styles, unlist(cs$valueStyleRef))
      } else if (is.character(cs$valueStyleRef)) {
        value_styles <- c(value_styles, as.character(cs$valueStyleRef))
      }
    } else if (!is.null(cs$format$valueStyleRef)) {
      if (is.list(cs$format$valueStyleRef)) {
        value_styles <- c(value_styles, unlist(cs$format$valueStyleRef))
      } else if (is.character(cs$format$valueStyleRef)) {
        value_styles <- c(value_styles, as.character(cs$format$valueStyleRef))
      }
    }
    
    # Other styles (from styleRef)
    if (!is.null(cs$styleRef)) {
      if (is.list(cs$styleRef)) {
        other_styles <- c(other_styles, unlist(cs$styleRef))
      } else if (is.character(cs$styleRef)) {
        other_styles <- c(other_styles, as.character(cs$styleRef))
      }
    }

    # Remove duplicates and empty values
    label_styles <- unique(label_styles[!is.na(label_styles) & nzchar(label_styles)])
    value_styles <- unique(value_styles[!is.na(value_styles) & nzchar(value_styles)])
    other_styles <- unique(other_styles[!is.na(other_styles) & nzchar(other_styles)])

    list(
      name = cn,
      label = ellipsize(lab, .const_max_label_width),
      type = ftype,
      format = ellipsize(ffmt, .const_max_format_width),
      width = colw,
      missings = ellipsize(miss, .const_max_format_width),
      flags = flags,
      label_styles = label_styles,
      value_styles = value_styles,
      other_styles = other_styles
    )
  }

  # Format flags and styles with icons
  .format_flags <- function(flags) {
    if (length(flags) == 0) return("")
    flag_symbols <- list(
      "ID" = "*",
      "hidden" = "x",
      "group" = "#",
      "page_break" = ">",
      "col_break" = "v",
      "dedupe" = "d",
      "blank_after" = "_"
    )
    result <- sapply(flags, function(f) flag_symbols[[f]] %||% f)
    paste(result, collapse = " ")
  }

  # Summary header
  .colored_rule("TFL Specification Preview", col_cyan)
  cli::cli_text("{.strong \U0001F4DD TFL Specification Preview}")
  doc_type <- if (!is.null(x$document$docType)) x$document$docType else "<not set>"
  has_data <- if (is.null(x$document$hasData)) "<not set>" else if (isTRUE(x$document$hasData)) "\U00002705 Yes" else "\U0000274C No"
  n_cols <- length(x$columns %||% list())
  n_titles <- length(x$titles %||% list())
  n_sub <- length(x$subtitles %||% list())
  n_fn <- length(x$footnotes %||% list())
  n_hdr <- length(x$headers %||% list())
  n_ftr <- length(x$footers %||% list())
  n_body <- length(x$bodyText %||% list())
  n_styles <- length(x$attribs$styles %||% list())
  cli::cli_text("{.strong \U0001F5B9 Document Type:} {col_blue(doc_type)}   {.strong \U0001F4BE Has Data:} {col_green(has_data)}")
  cli::cli_text("{.strong \U0001F4C3 Content:} Columns: {col_red(n_cols)} | Titles: {col_red(n_titles)} | Subtitles: {col_red(n_sub)} | Footnotes: {col_red(n_fn)}")
  cli::cli_text("{.strong \U0001F4D1 Sections:} Headers: {col_red(n_hdr)} | Footers: {col_red(n_ftr)} | Body Text: {col_red(n_body)} | Styles: {col_red(n_styles)}")

  # Compact layout: brief overview
  if (identical(layout, "compact")) {
    return(invisible(x))
  }

  # Full layout: detailed sections
  # Document Properties
  .colored_rule("Document Properties", col_blue)
  doc_props <- x$document
  cli::cli_text("{.strong Type:} {doc_props$docType %||% '<not set>'}")
  cli::cli_text("{.strong Has Data:} {if (is.null(doc_props$hasData)) '<not set>' else if (doc_props$hasData) 'Yes' else 'No'}")
  if (!is.null(doc_props$docPrefix)) cli::cli_text("{.strong Prefix:} {doc_props$docPrefix}")
  if (!is.null(doc_props$glueNumType)) cli::cli_text("{.strong Glue Num Type:} {if (doc_props$glueNumType) 'Yes' else 'No'}")
  if (!is.null(doc_props$docOrder)) cli::cli_text("{.strong Order:} {doc_props$docOrder}")
  if (!is.null(doc_props$isContinues)) cli::cli_text("{.strong Continues:} {if (doc_props$isContinues) 'Yes' else 'No'}")
  if (!is.null(doc_props$contentWidth)) cli::cli_text("{.strong Content Width:} {doc_props$contentWidth}")
  if (!is.null(doc_props$bodyTitles)) cli::cli_text("{.strong Body Titles:} {if (doc_props$bodyTitles) 'Yes' else 'No'}")
  if (!is.null(doc_props$bodySubtitles)) cli::cli_text("{.strong Body Subtitles:} {if (doc_props$bodySubtitles) 'Yes' else 'No'}")
  if (!is.null(doc_props$bodyFootnotes)) cli::cli_text("{.strong Body Footnotes:} {if (doc_props$bodyFootnotes) 'Yes' else 'No'}")

  # Document Style Template
  if (!is.null(x$attribs$documentStyle$docTemplate)) {
    .colored_rule("Document Style Template", col_magenta)
    cli::cli_text("{.strong Template:} {x$attribs$documentStyle$docTemplate}")
  }

  # Row Styles
  if (!is.null(x$styleRows) && length(x$styleRows) > 0) {
    .colored_rule("Row Styles", col_yellow)
    for (i in seq_along(x$styleRows)) {
      row_style <- x$styleRows[i]
      if (row_style != "{}") {
        # Parse JSON to display nicely
        try({
          parsed <- jsonlite::fromJSON(row_style)
          actions <- names(parsed)
          cli::cli_text("{.strong Row {i}:}")
          for (action in actions) {
            val <- parsed[[action]]
            if (is.list(val)) {
              val_str <- paste(names(val), sapply(val, function(v) if (is.list(v)) paste(unlist(v), collapse = ", ") else v), sep = "=", collapse = "; ")
            } else {
              val_str <- as.character(val)
            }
            cli::cli_text("  {action}: {val_str}")
          }
        }, silent = TRUE)
      }
    }
  }

  # Headers (all rows)
  if (length(x$headers %||% list()) > 0) {
    .colored_rule("Headers", col_yellow)
    for (i in seq_along(x$headers)) {
      row <- x$headers[[i]]
      cells <- vapply(row, function(x) ellipsize(x %||% "", floor(width / max(1, length(row)))), character(1))
      cli::cli_text("{.strong Row {i}:} {paste(col_yellow(cells), collapse = ' | ')}")
    }
  }

  # Titles / Subtitles / Footnotes / Body text as bullet lists
  render_text_list <- function(lst, title) {
    if (is.null(lst) || length(lst) == 0) return()
    .colored_rule(title, col_green)
    orders <- vapply(lst, function(x) if (!is.null(x$order)) as.integer(x$order) else NA_integer_, integer(1))
    ord_idx <- order(is.na(orders), orders)
    cli::cli_ul()
    for (x in lst[ord_idx]) {
      txt <- ellipsize(paste(x$text, collapse = " "), width)
      style_vec <- if (is.null(x$styleRef)) character(0) else if (is.list(x$styleRef)) unlist(x$styleRef) else as.character(x$styleRef)
      style_vec <- style_vec[!is.na(style_vec) & nzchar(style_vec)]
      style_ref <- if (length(style_vec) > 0) paste0(" [style: ", col_green(paste(style_vec, collapse = ",")), "]") else ""
      cli::cli_li(paste0(txt, style_ref))
    }
    cli::cli_end()
  }

  render_text_list(x$titles, "Titles")
  render_text_list(x$subtitles, "Subtitles")

  # Stub columns (spanning headers) - displayed before columns table
  if (length(x$stubColumns %||% list()) > 0) {
    .colored_rule("Spanning Headers (Stubs)", col_magenta)
    
    stub_list <- x$stubColumns
    # Sort by stubOrder for display
    stub_orders <- vapply(stub_list, function(s) s$stubOrder %||% 0, numeric(1))
    stub_idx <- order(stub_orders)
    
    for (i in stub_idx) {
      stub <- stub_list[[i]]
      stub_order <- stub$stubOrder %||% "N/A"
      cols_spanned <- paste(stub$cols, collapse = ", ")
      style_ref <- if (!is.null(stub$labelStyleRef)) {
        style_vec <- if (is.list(stub$labelStyleRef)) unlist(stub$labelStyleRef) else as.character(stub$labelStyleRef)
        style_vec <- style_vec[!is.na(style_vec) & nzchar(style_vec)]
        if (length(style_vec) > 0) paste0(" [style: ", col_magenta(paste(style_vec, collapse = ", ")), "]") else ""
      } else ""
      
      label_display <- ellipsize(stub$label %||% "", .const_max_label_width)
      cli::cli_text("{.strong Level {stub_order}:} {label_display}, {.em Spans:} {cols_spanned}{style_ref}")
    }
  }

  # Columns: Complete table with flags and styles
  if (n_cols > 0) {
    .colored_rule("Columns", col_cyan)

    cols <- names(x$columns)
    col_infos <- lapply(seq_along(cols), function(i) {
      .extract_column_info(cols[[i]], x$columns[[cols[[i]]]])
    })

    # Add formatted flags and styles to each column info
    col_infos <- lapply(col_infos, function(info) {
      info$flags_str <- .format_flags(info$flags)
      
      # Format styles with L: and V: prefixes
      styles_parts <- character(0)
      if (length(info$label_styles) > 0) {
        styles_parts <- c(styles_parts, paste0("L: ", paste(info$label_styles, collapse = ", ")))
      }
      if (length(info$value_styles) > 0) {
        styles_parts <- c(styles_parts, paste0("V: ", paste(info$value_styles, collapse = ", ")))
      }
      if (length(info$other_styles) > 0) {
        styles_parts <- c(styles_parts, paste(info$other_styles, collapse = ", "))
      }
      info$styles_str <- paste(styles_parts, collapse = "; ")
      
      info
    })

    # Calculate column widths for alignment (using display width for Unicode)
    max_name <- max(c(4L, max(nchar(vapply(col_infos, `[[`, "name", FUN.VALUE = ""), type = "width"))))
    max_label <- min(.const_max_label_width, max(c(5L, max(nchar(vapply(col_infos, `[[`, "label", FUN.VALUE = ""), type = "width")))))
    max_type <- max(c(4L, max(nchar(vapply(col_infos, `[[`, "type", FUN.VALUE = ""), type = "width"))))
    max_format <- min(.const_max_format_width, max(c(6L, max(nchar(vapply(col_infos, `[[`, "format", FUN.VALUE = ""), type = "width")))))
    max_missings <- min(.const_max_format_width, max(c(7L, max(nchar(vapply(col_infos, `[[`, "missings", FUN.VALUE = ""), type = "width")))))
    max_width <- max(c(5L, max(nchar(vapply(col_infos, `[[`, "width", FUN.VALUE = ""), type = "width"))))
    # Add extra padding for flags column to account for Unicode width issues
    max_flags <- max(c(5L, max(nchar(vapply(col_infos, `[[`, "flags_str", FUN.VALUE = ""), type = "width"))))
    max_styles <- min(32L, max(c(6L, max(nchar(vapply(col_infos, `[[`, "styles_str", FUN.VALUE = ""), type = "width")))))

    # Build header
    header_line <- paste0(
      format("Name", width = max_name, justify = "left"), " | ",
      format("Label", width = max_label, justify = "left"), " | ",
      format("Type", width = max_type, justify = "left"), " | ",
      format("Format", width = max_format, justify = "left"), " | ",
      format("Missings", width = max_missings, justify = "left"), " | ",
      format("Width", width = max_width, justify = "left"), " | ",
      format("Flags", width = max_flags, justify = "left"), " | ",
      format("Styles", width = max_styles, justify = "left")
    )
    separator_line <- paste(rep("\u2500", nchar(header_line, type = "width")), collapse = "")

    # Display table
    cli::cli_verbatim(col_blue(header_line))
    cli::cli_verbatim(separator_line)

    # Display rows with proper width-aware padding
    for (info in col_infos) {
      # Calculate padding for each field based on display width
      pad_name <- max(0, max_name - nchar(info$name, type = "width"))
      pad_label <- max(0, max_label - nchar(info$label, type = "width"))
      pad_type <- max(0, max_type - nchar(info$type, type = "width"))
      pad_format <- max(0, max_format - nchar(info$format, type = "width"))
      pad_missings <- max(0, max_missings - nchar(info$missings, type = "width"))
      pad_width <- max(0, max_width - nchar(info$width, type = "width"))
      pad_flags <- max(0, max_flags - nchar(info$flags_str, type = "width"))
      pad_styles <- max(0, max_styles - nchar(info$styles_str, type = "width"))

      row_line <- paste0(
        info$name, strrep(" ", pad_name), " | ",
        info$label, strrep(" ", pad_label), " | ",
        info$type, strrep(" ", pad_type), " | ",
        info$format, strrep(" ", pad_format), " | ",
        info$missings, strrep(" ", pad_missings), " | ",
        info$width, strrep(" ", pad_width), " | ",
        info$flags_str, strrep(" ", pad_flags), " | ",
        info$styles_str, strrep(" ", pad_styles)
      )
      cli::cli_verbatim(row_line)
    }

    # Add legend for flags
    has_flags <- any(vapply(col_infos, function(x) nchar(x$flags_str) > 0, logical(1)))
    if (has_flags) {
      cli::cli_text("")
      cli::cli_text("{.strong Flag Legend:}")
      cli::cli_ul(c(
        "* = ID column (primary identifier)",
        "x = Hidden column (not visible in output)",
        "# = Grouping column (used for grouping rows)",
        "> = Page break (trigger page break)",
        "v = Column break (trigger column break)",
        "d = Deduplicate (remove duplicate values)",
        "_ = Blank after (insert blank row after value change)"
      ))
    }
  }

  render_text_list(x$footnotes, "Footnotes")

  # Footers (all rows)
  if (length(x$footers %||% list()) > 0) {
    .colored_rule("Footers", col_cyan)
    for (i in seq_along(x$footers)) {
      row <- x$footers[[i]]
      cells <- vapply(row, function(x) ellipsize(x %||% "", floor(width / max(1, length(row)))), character(1))
      cli::cli_text("{.strong Row {i}:} {paste(col_cyan(cells), collapse = ' | ')}")
    }
  }

  render_text_list(x$bodyText, "Body text")

  # Sample data
  try({
    data_env <- x$.metadata$data_env
    if (!is.null(data_env) && exists("__data__", envir = data_env)) {
      df <- get("__data__", envir = data_env)
      if (is.data.frame(df) && nrow(df) > 0) {
        .colored_rule("Sample data (first 3 rows)", col_green)
        srows <- utils::head(df, 3)
        # capture printed output so it fits inside the CLI rules
        s_out <- paste(capture.output(print(srows)), collapse = "\n")
        cli::cat_line(s_out)
      }
    }
  }, silent = TRUE)


   # Optional interactive viewer
  if (isTRUE(getOption("TFL.viewer", FALSE))) {
    try(
      .render_TFL_spec_viewer(x),
      silent = TRUE
    )
  }

  invisible(x)
}

.scalar_text <- function(x) {
  if (is.null(x)) return("")
  paste(as.character(x), collapse = " ")
}

.render_text_object <- function(obj) {
  if (is.null(obj) || length(obj) == 0) return(NULL)

  h <- htmltools::tags

  # order by $order
  items <- unname(obj)
  ord <- vapply(items, function(x) x$order %||% 0L, integer(1))
  items <- items[order(ord)]

  h$div(
    lapply(items, function(it) {
      txt <- it$text
      if (length(txt) > 1) {
        txt_display <- paste(txt, collapse = " | ")
      } else {
        txt_display <- .scalar_text(txt)
      }
      styles <- it$styleRef
      if (!is.null(styles) && length(styles) > 0) {
        styles_display <- paste(styles, collapse = ", ")
      } else {
        styles_display <- ""
      }

      h$div(class = "text-item",
        h$div(class = "text-content", txt_display),
        if (nzchar(styles_display)) h$div(class = "text-styles", "Styles: ", h$code(styles_display))
      )
    })
  )
}

.render_rows <- function(rows) {
  if (is.null(rows) || length(rows) == 0) return(NULL)

  h <- htmltools::tags

  h$div(
    lapply(seq_along(rows), function(i) {
      row <- rows[[i]]
      if (length(row) == 3) {
        # Left | Center | Right
        h$div(class = "header-row",
          h$div(class = "header-cell", row[1]),
          h$div(class = "header-cell", row[2]),
          h$div(class = "header-cell", row[3])
        )
      } else if (length(row) == 2) {
        # Left | Right
        h$div(class = "header-row",
          h$div(class = "header-cell", row[1]),
          h$div(class = "header-cell", ""),
          h$div(class = "header-cell", row[2])
        )
      } else if (length(row) == 1) {
        # Left only
        h$div(class = "header-row",
          h$div(class = "header-cell", row[1]),
          h$div(class = "header-cell", ""),
          h$div(class = "header-cell", "")
        )
      } else {
        # Fallback
        h$div(class = "text-item", paste(row, collapse = " | "))
      }
    })
  )
}

.render_columns <- function(cols) {
  if (is.null(cols) || length(cols) == 0) return(NULL)
  h <- htmltools::tags

  # Check if any columns have flags
  has_flags <- any(vapply(cols, function(cs) {
    !is.null(cs$isID) && isTRUE(cs$isID) ||
    !is.null(cs$isVisible) && isFALSE(cs$isVisible) ||
    !is.null(cs$isGrouping) && isTRUE(cs$isGrouping) ||
    !is.null(cs$isPaging) && isTRUE(cs$isPaging) ||
    !is.null(cs$isColBreak) && isTRUE(cs$isColBreak) ||
    !is.null(cs$dedupe) && isTRUE(cs$dedupe) ||
    !is.null(cs$blankAfter) && isTRUE(cs$blankAfter)
  }, logical(1)))

  rows <- lapply(names(cols), function(nm) {
    cs <- cols[[nm]]

    # Collect styles
    label_styles <- character(0)
    value_styles <- character(0)

    if (!is.null(cs$labelStyleRef)) {
      if (is.list(cs$labelStyleRef)) {
        label_styles <- c(label_styles, unlist(cs$labelStyleRef))
      } else if (is.character(cs$labelStyleRef)) {
        label_styles <- c(label_styles, as.character(cs$labelStyleRef))
      }
    }

    if (!is.null(cs$valueStyleRef)) {
      if (is.list(cs$valueStyleRef)) {
        value_styles <- c(value_styles, unlist(cs$valueStyleRef))
      } else if (is.character(cs$valueStyleRef)) {
        value_styles <- c(value_styles, as.character(cs$valueStyleRef))
      }
    } else if (!is.null(cs$format$valueStyleRef)) {
      if (is.list(cs$format$valueStyleRef)) {
        value_styles <- c(value_styles, unlist(cs$format$valueStyleRef))
      } else if (is.character(cs$format$valueStyleRef)) {
        value_styles <- c(value_styles, as.character(cs$format$valueStyleRef))
      }
    }

    label_styles <- unique(label_styles[!is.na(label_styles) & nzchar(label_styles)])
    value_styles <- unique(value_styles[!is.na(value_styles) & nzchar(value_styles)])

    badges <- list()
    if (isTRUE(cs$isID)) badges <- c(badges, paste0('<span class="badge badge-id">', "*", '</span>'))
    if (isFALSE(cs$isVisible)) badges <- c(badges, paste0('<span class="badge badge-hidden">', "x", '</span>'))
    if (isTRUE(cs$isGrouping)) badges <- c(badges, paste0('<span class="badge badge-group">', "#", '</span>'))
    if (isTRUE(cs$isPaging)) badges <- c(badges, paste0('<span class="badge badge-page">', ">", '</span>'))
    if (isTRUE(cs$isColBreak)) badges <- c(badges, paste0('<span class="badge badge-col">', "v", '</span>'))
    if (isTRUE(cs$dedupe)) badges <- c(badges, paste0('<span class="badge badge-dedupe">', "d", '</span>'))
    if (isTRUE(cs$blankAfter)) badges <- c(badges, paste0('<span class="badge badge-blank">', "_", '</span>'))

    h$tr(
      h$td(nm),
      h$td(.scalar_text(cs$label)),
      h$td(.scalar_text(cs$format$type)),
      h$td(.scalar_text(cs$format$format)),
      h$td(.scalar_text(cs$format$missings)),
      h$td(if (nzchar(.scalar_text(cs$format$colWidth))) .scalar_text(cs$format$colWidth) else "-"),
      h$td(if (length(value_styles) > 0) paste(value_styles, collapse = ", ") else ""),
      h$td(if (length(label_styles) > 0) paste(label_styles, collapse = ", ") else ""),
      h$td( h$div( htmltools::HTML( paste(badges, collapse = "") ) ) )
    )
  })

  list(
    h$table(
      h$thead(
        h$tr(
          h$th("Name"),
          h$th("Label"),
          h$th("Type"),
          h$th("Format"),
          h$th("Missings"),
          h$th("Width"),
          h$th("ValueStyle"),
          h$th("LabelStyle"),
          h$th("Flags")
        )
      ),
      h$tbody(rows)
    ),
    if (has_flags) {
      h$div(class = "flags-legend",
        h$h5("📋 Column Flags Legend"),
        h$div(class = "flags-grid",
          h$div(class = "flag-item", h$span(class = "flag-symbol", "*"), " = ID column"),
          h$div(class = "flag-item", h$span(class = "flag-symbol", "x"), " = Hidden column"),
          h$div(class = "flag-item", h$span(class = "flag-symbol", "#"), " = Grouping column"),
          h$div(class = "flag-item", h$span(class = "flag-symbol", ">"), " = Page break"),
          h$div(class = "flag-item", h$span(class = "flag-symbol", "v"), " = Column break"),
          h$div(class = "flag-item", h$span(class = "flag-symbol", "d"), " = Deduplicate"),
          h$div(class = "flag-item", h$span(class = "flag-symbol", "_"), " = Blank after")
        )
      )
    }
  )
}

.render_TFL_spec_viewer <- function(x) {
  if (!rstudioapi::isAvailable()) return(invisible(FALSE))
  if (!requireNamespace("htmltools", quietly = TRUE)) return(invisible(FALSE))

  h <- htmltools::tags

  page <- h$html(
    h$head(
      h$style(htmltools::HTML("
        body { 
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
          font-size: 14px; 
          line-height: 1.5; 
          margin: 0; 
          padding: 20px; 
          background: #f8f9fa; 
          color: #212529; 
        }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { 
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
          color: white; 
          padding: 20px; 
          border-radius: 8px; 
          margin-bottom: 20px; 
          box-shadow: 0 2px 10px rgba(0,0,0,0.1); 
        }
        .header h1 { margin: 0; font-size: 24px; }
        .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 20px; }
        .summary-card { 
          background: white; 
          padding: 15px; 
          border-radius: 6px; 
          box-shadow: 0 1px 3px rgba(0,0,0,0.1); 
          text-align: center; 
        }
        .summary-card h3 { margin: 0 0 5px 0; font-size: 16px; color: #6c757d; }
        .summary-card .value { font-size: 24px; font-weight: bold; color: #495057; }
        summary { 
          font-weight: 600; 
          cursor: pointer; 
          background: #e9ecef; 
          padding: 10px 15px; 
          border-radius: 4px; 
          margin-bottom: 5px; 
          transition: background 0.2s; 
        }
        summary:hover { background: #dee2e6; }
        details { margin-bottom: 15px; }
        .content { background: white; padding: 15px; border-radius: 4px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        table { border-collapse: collapse; width: 100%; margin-top: 10px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); border-radius: 6px; overflow: hidden; }
        th, td { border: 1px solid #dee2e6; padding: 8px 12px; text-align: left; }
        th { background: linear-gradient(90deg, #f8f9fa 0%, #e9ecef 100%); font-weight: 600; color: #495057; }
        tr:nth-child(even) { background: #f8f9fa; }
        tr:hover { background: #f1f3f4; }
        .badge { 
          display: inline-block; 
          padding: 1px 4px; 
          font-size: 10px; 
          font-weight: bold; 
          border-radius: 3px; 
          text-transform: uppercase; 
          margin-right: 2px;
        }
        .badge-id { background: #007bff; color: white; }
        .badge-hidden { background: #6c757d; color: white; }
        .badge-group { background: #28a745; color: white; }
        .badge-page { background: #dc3545; color: white; }
        .badge-col { background: #ffc107; color: black; }
        .badge-dedupe { background: #17a2b8; color: white; }
        .badge-blank { background: #6f42c1; color: white; }
        .styles-display { font-family: monospace; font-size: 12px; background: #f8f9fa; padding: 5px; border-radius: 3px; }
        .prop-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 10px; }
        .prop-item { background: #f8f9fa; padding: 8px; border-radius: 4px; }
        .prop-item strong { color: #495057; }
        .styles-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 15px; }
        .style-card { background: #f8f9fa; padding: 15px; border-radius: 6px; border-left: 4px solid #007bff; }
        .style-card h4 { margin: 0 0 10px 0; color: #007bff; }
        .style-section { margin-bottom: 10px; }
        .style-section strong { color: #495057; }
        .style-section ul { margin: 5px 0; padding-left: 20px; }
        .style-section li { margin-bottom: 3px; }
        .style-value { font-family: monospace; background: #e9ecef; padding: 2px 4px; border-radius: 3px; }
        .text-item { background: #f8f9fa; padding: 10px; border-radius: 4px; margin-bottom: 5px; }
        .text-content { font-weight: 500; }
        .text-styles { font-size: 12px; color: #6c757d; margin-top: 5px; }
        .header-row { display: flex; justify-content: space-between; background: #f8f9fa; padding: 8px; border-radius: 4px; margin-bottom: 5px; }
        .header-cell { flex: 1; text-align: center; font-weight: 500; }
        .header-cell:not(:last-child) { border-right: 1px solid #dee2e6; }
        .flags-legend { background: #fff3cd; border: 1px solid #ffeaa7; border-radius: 4px; padding: 10px; margin-top: 10px; }
        .flags-legend h5 { margin: 0 0 8px 0; color: #856404; }
        .flags-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 5px; }
        .flag-item { font-size: 12px; }
        .flag-symbol { font-weight: bold; color: #856404; }
      "))
    ),
    h$body(
      h$div(class = "container",
        h$div(class = "header",
          h$h1("📋 TFL Specification Preview"),
          h$p("Comprehensive overview of your TFL specification with all metadata and styling information.")
        ),

        # Summary Cards
        h$div(class = "summary-grid",
          h$div(class = "summary-card",
            h$h3("Document Type"), 
            h$div(class = "value", .scalar_text(x$document$docType))
          ),
          h$div(class = "summary-card",
            h$h3("Has Data"), 
            h$div(class = "value", if (isTRUE(x$document$hasData)) "✅ Yes" else "❌ No")
          ),
          h$div(class = "summary-card",
            h$h3("Columns"), 
            h$div(class = "value", length(x$columns %||% list()))
          ),
          h$div(class = "summary-card",
            h$h3("Styles Defined"), 
            h$div(class = "value",
              paste0(length(x$attribs$styles %||% list())),
              if (!is.null(x$attribs$documentStyle$docTemplate)) 
                h$div(style = "font-size: smaller; color: #6c757d;", 
                      paste0("Template: ", x$attribs$documentStyle$docTemplate)) 
              else NULL
            )
          )
        ),

        # Document Properties
        h$details(
          h$summary("📄 Document Properties"),
          h$div(class = "content",
            h$div(class = "prop-grid",
              h$div(class = "prop-item", h$strong("Type: "), .scalar_text(x$document$docType)),
              h$div(class = "prop-item", h$strong("Has Data: "), .scalar_text(x$document$hasData)),
              if (!is.null(x$document$docPrefix)) h$div(class = "prop-item", h$strong("Prefix: "), .scalar_text(x$document$docPrefix)),
              if (!is.null(x$document$glueNumType)) h$div(class = "prop-item", h$strong("Glue Num Type: "), .scalar_text(x$document$glueNumType)),
              if (!is.null(x$document$docOrder)) h$div(class = "prop-item", h$strong("Order: "), .scalar_text(x$document$docOrder)),
              if (!is.null(x$document$isContinues)) h$div(class = "prop-item", h$strong("Continues: "), .scalar_text(x$document$isContinues)),
              if (!is.null(x$document$contentWidth)) h$div(class = "prop-item", h$strong("Content Width: "), .scalar_text(x$document$contentWidth)),
              if (!is.null(x$document$bodyTitles)) h$div(class = "prop-item", h$strong("Body Titles: "), .scalar_text(x$document$bodyTitles)),
              if (!is.null(x$document$bodySubtitles)) h$div(class = "prop-item", h$strong("Body Subtitles: "), .scalar_text(x$document$bodySubtitles)),
              if (!is.null(x$document$bodyFootnotes)) h$div(class = "prop-item", h$strong("Body Footnotes: "), .scalar_text(x$document$bodyFootnotes))
            )
          )
        ),

        # Page Settings
        if (!is.null(x$attribs$documentStyle$page)) {
          h$details(
            h$summary("📄 Page Settings"),
            h$div(class = "content",
              h$div(class = "prop-grid",
                {
                  pg <- x$attribs$documentStyle$page
                  props <- list()
                  if (!is.null(pg$size)) props <- c(props, list(h$div(class = "prop-item", h$strong("Size: "), .scalar_text(pg$size))))
                  if (!is.null(pg$orientation)) props <- c(props, list(h$div(class = "prop-item", h$strong("Orientation: "), .scalar_text(pg$orientation))))
                  if (!is.null(pg$margins)) {
                    mg <- pg$margins
                    if (!is.null(mg$top)) props <- c(props, list(h$div(class = "prop-item", h$strong("Top Margin: "), .scalar_text(mg$top))))
                    if (!is.null(mg$bottom)) props <- c(props, list(h$div(class = "prop-item", h$strong("Bottom Margin: "), .scalar_text(mg$bottom))))
                    if (!is.null(mg$left)) props <- c(props, list(h$div(class = "prop-item", h$strong("Left Margin: "), .scalar_text(mg$left))))
                    if (!is.null(mg$right)) props <- c(props, list(h$div(class = "prop-item", h$strong("Right Margin: "), .scalar_text(mg$right))))
                  }
                  props
                }
              )
            )
          )
        },

        # Defined Styles
        if (!is.null(x$attribs$styles) && length(x$attribs$styles) > 0) {
          h$details(
            h$summary("🎨 Defined Styles"),
            h$div(class = "content",
              h$div(class = "styles-grid",
                lapply(names(x$attribs$styles), function(style_id) {
                  style_def <- x$attribs$styles[[style_id]]
                  h$div(class = "style-card",
                    h$h4(style_id),
                    h$div(class = "style-props",
                      if (!is.null(style_def$font)) {
                        font_props <- style_def$font
                        h$div(class = "style-section",
                          h$strong("Font"),
                          h$ul(lapply(names(font_props), function(prop) {
                            h$li(h$code(prop), ": ", h$span(class = "style-value", .scalar_text(font_props[[prop]])))
                          }))
                        )
                      },
                      if (!is.null(style_def$paragraph)) {
                        para_props <- style_def$paragraph
                        h$div(class = "style-section",
                          h$strong("Paragraph"),
                          h$ul(lapply(names(para_props), function(prop) {
                            val <- para_props[[prop]]
                            val_str <- if (is.list(val)) {
                              paste(sapply(names(val), function(subprop) paste0(subprop, ": ", .scalar_text(val[[subprop]])), USE.NAMES = FALSE), collapse = ", ")
                            } else {
                              .scalar_text(val)
                            }
                            h$li(h$code(prop), ": ", h$span(class = "style-value", val_str))
                          }))
                        )
                      },
                      if (!is.null(style_def$table_style)) {
                        table_props <- style_def$table_style
                        h$div(class = "style-section",
                          h$strong("Table"),
                          h$ul(lapply(names(table_props), function(prop) {
                            val <- table_props[[prop]]
                            val_str <- if (is.list(val)) {
                              paste(sapply(names(val), function(subprop) paste0(subprop, ": ", .scalar_text(val[[subprop]])), USE.NAMES = FALSE), collapse = ", ")
                            } else {
                              .scalar_text(val)
                            }
                            h$li(h$code(prop), ": ", h$span(class = "style-value", val_str))
                          }))
                        )
                      }
                    )
                  )
                })
              )
            )
          )
        },

        # Data References
        if (!is.null(x$dataRef) && length(x$dataRef) > 0) {
          h$details(
            h$summary("💾 Data References"),
            h$div(class = "content",
              h$ul(lapply(seq_along(x$dataRef), function(i) h$li("Ref ", i, ": ", x$dataRef[i])))
            )
          )
        },

        # Row Styles
        if (!is.null(x$styleRows) && length(x$styleRows) > 0) {
          h$details(
            h$summary("📊 Row Styles"),
            h$div(class = "content",
              lapply(seq_along(x$styleRows), function(i) {
                row_style <- x$styleRows[i]
                if (row_style != "{}") {
                  tryCatch({
                    parsed <- jsonlite::fromJSON(row_style)
                    actions <- names(parsed)
                    h$div(
                      h$h4("Row ", i),
                      lapply(actions, function(action) {
                        val <- parsed[[action]]
                        if (is.list(val)) {
                          val_str <- paste(names(val), sapply(val, function(v) if (is.list(v)) paste(unlist(v), collapse = ", ") else v), sep = "=", collapse = "; ")
                        } else {
                          val_str <- as.character(val)
                        }
                        h$p(h$strong(action, ": "), val_str)
                      })
                    )
                  }, error = function(e) h$p("Error parsing row style"))
                }
              })
            )
          )
        },

        # Existing sections
        h$details(h$summary("📋 Headers"), .render_rows(x$headers)),
        h$details(h$summary("📝 Titles"), .render_text_object(x$titles)),
        h$details(h$summary("📝 Subtitles"), .render_text_object(x$subtitles)),
        h$details(h$summary("📊 Columns"), h$div(class = "content", .render_columns(x$columns))),
        h$details(h$summary("📝 Footnotes"), .render_text_object(x$footnotes)),
        h$details(h$summary("📋 Footers"), .render_rows(x$footers)),
        h$details(h$summary("📄 Body Text"), .render_text_object(x$bodyText))
      )
    )
  )

  tmp <- tempfile(fileext = ".html")
  htmltools::save_html(page, tmp)
  rstudioapi::viewer(tmp)

  invisible(TRUE)
}
