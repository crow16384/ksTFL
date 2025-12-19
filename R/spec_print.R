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
#'   \item Column metadata table with flags and styles
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
    if (nchar(s) > max_len) paste0(substr(s, 1, max_len - 1), "…") else s
  }

  # Helper for colored section separators
  .colored_rule <- function(title, color_fn = col_cyan) {
    rule_text <- paste0("─── ", title, " ", paste(rep("─", max(1, 70 - nchar(title))), collapse = ""))
    cli::cli_text(color_fn(rule_text))
  }

  # Extract column metadata from spec
  .extract_column_info <- function(cn, cs) {
    lab <- cs$label %||% cs$colLabel %||% ""
    fmt_val <- cs$format %||% cs$c_format %||% NULL
    ftype <- ""
    ffmt <- ""
    colw <- ""
    if (is.list(fmt_val)) {
      ftype <- fmt_val$type %||% ""
      ffmt <- fmt_val$format %||% ""
      if (!is.null(fmt_val$colWidth)) colw <- as.character(fmt_val$colWidth)
    } else if (is.character(fmt_val) && length(fmt_val) == 1) {
      ffmt <- fmt_val
    }

    # Collect flags
    flags <- c()
    if (!is.null(cs$isID) && isTRUE(cs$isID)) flags <- c(flags, "ID")
    if (!is.null(cs$isVisible) && isFALSE(cs$isVisible)) flags <- c(flags, "hidden")
    if (!is.null(cs$isGrouping) && isTRUE(cs$isGrouping)) flags <- c(flags, "group")
    if (!is.null(cs$isPaging) && isTRUE(cs$isPaging)) flags <- c(flags, "page_break")
    if (!is.null(cs$isColBreak) && isTRUE(cs$isColBreak)) flags <- c(flags, "col_break")
    if (!is.null(cs$dedupe) && isTRUE(cs$dedupe)) flags <- c(flags, "dedupe")
    if (!is.null(cs$blankAfter) && isTRUE(cs$blankAfter)) flags <- c(flags, "blank_after")

    # Collect styles from all style references
    style_sources <- list(
      cs$valueStyleRef,
      cs$labelStyleRef,
      cs$styleRef
    )

    style_vec <- character(0)
    for (style_src in style_sources) {
      if (!is.null(style_src)) {
        if (is.list(style_src)) {
          style_vec <- c(style_vec, unlist(style_src))
        } else if (is.character(style_src)) {
          style_vec <- c(style_vec, as.character(style_src))
        }
      }
    }

    # Remove duplicates and empty values
    style_vec <- unique(style_vec[!is.na(style_vec) & nzchar(style_vec)])

    list(
      name = cn,
      label = ellipsize(lab, .const_max_label_width),
      type = ftype,
      format = ellipsize(ffmt, .const_max_format_width),
      width = colw,
      flags = flags,
      styles = style_vec
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
  cli::cli_text("{.strong TFL Specification Preview}")
  doc_type <- if (!is.null(x$document$docType)) x$document$docType else "<not set>"
  has_data <- if (is.null(x$document$hasData)) "<not set>" else if (isTRUE(x$document$hasData)) "Yes" else "No"
  n_cols <- length(x$columns %||% list())
  n_titles <- length(x$titles %||% list())
  n_sub <- length(x$subtitles %||% list())
  n_fn <- length(x$footnotes %||% list())
  n_hdr <- length(x$headers %||% list())
  n_ftr <- length(x$footers %||% list())
  n_body <- length(x$bodyText %||% list())
  cli::cli_text("{.strong Document Type:} {doc_type}   {.strong Has Data:} {has_data}")
  cli::cli_text("{.strong Summary:} Columns: {n_cols} | Titles: {n_titles} | Subtitles: {n_sub} | Footnotes: {n_fn} | Headers: {n_hdr} | Footers: {n_ftr} | Body: {n_body}")

  # Compact layout: brief overview
  if (identical(layout, "compact")) {
    return(invisible(x))
  }

  # Full layout: detailed sections
  # Page settings
  if (!is.null(x$attribs$documentStyle$page)) {
    pg <- x$attribs$documentStyle$page
    size <- pg$size %||% "<default>"
    orient <- pg$orientation %||% "<default>"
    cli::cli_text("{.strong Page settings:} size={size}, orientation={orient}")
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
      info$styles_str <- if (length(info$styles) > 0) paste(info$styles, collapse = ", ") else ""
      info
    })

    # Calculate column widths for alignment (using display width for Unicode)
    max_name <- max(c(4L, max(nchar(vapply(col_infos, `[[`, "name", FUN.VALUE = ""), type = "width"))))
    max_label <- min(.const_max_label_width, max(c(5L, max(nchar(vapply(col_infos, `[[`, "label", FUN.VALUE = ""), type = "width")))))
    max_type <- max(c(4L, max(nchar(vapply(col_infos, `[[`, "type", FUN.VALUE = ""), type = "width"))))
    max_format <- min(.const_max_format_width, max(c(6L, max(nchar(vapply(col_infos, `[[`, "format", FUN.VALUE = ""), type = "width")))))
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
      format("Width", width = max_width, justify = "left"), " | ",
      format("Flags", width = max_flags, justify = "left"), " | ",
      format("Styles", width = max_styles, justify = "left")
    )
    separator_line <- paste(rep("─", nchar(header_line, type = "width")), collapse = "")

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
      pad_width <- max(0, max_width - nchar(info$width, type = "width"))
      pad_flags <- max(0, max_flags - nchar(info$flags_str, type = "width"))
      pad_styles <- max(0, max_styles - nchar(info$styles_str, type = "width"))

      row_line <- paste0(
        info$name, strrep(" ", pad_name), " | ",
        info$label, strrep(" ", pad_label), " | ",
        info$type, strrep(" ", pad_type), " | ",
        info$format, strrep(" ", pad_format), " | ",
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

  invisible(x)
}
