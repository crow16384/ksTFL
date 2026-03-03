local_or_default <- function(x, default = NULL) {
  if (is.null(x) || !nzchar(x)) default else x
}

# Schema compliance: output null instead of "" for optional enum/string fields
null_if_empty <- function(x) {
  if (is.null(x) || !nzchar(as.character(x))) NULL else x
}

load_template_file <- function(path) {
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}

bundled_templates_dir <- function() {
  # When running from installed package or source tree, this relative path
  # points from inst/shiny/styles_editor/ to inst/templates/
  normalizePath(file.path("..", "..", "templates"), mustWork = TRUE)
}

bundled_template_paths <- function() {
  dir <- bundled_templates_dir()
  files <- list.files(dir, pattern = "\\.json$", full.names = TRUE)
  names(files) <- tools::file_path_sans_ext(basename(files))
  files
}

initial_template <- function() {
  paths <- bundled_template_paths()
  if (length(paths) == 0L) {
    stop("No bundled templates found in inst/templates/.")
  }
  load_template_file(paths[[1L]])
}

text_style_ui <- function(id_prefix, label) {
  ns <- function(x) paste0(id_prefix, "_", x)
  shiny::tagList(
    shiny::h4(label),
    shiny::fluidRow(
      shiny::column(
        6,
        shiny::textInput(ns("font_name"), "Font family"),
        shiny::textInput(ns("font_size"), "Font size (e.g. 9pt)"),
        shiny::checkboxInput(ns("bold"), "Bold", value = FALSE),
        shiny::checkboxInput(ns("italic"), "Italic", value = FALSE),
        shiny::checkboxInput(ns("underline"), "Underline", value = FALSE),
        colourpicker::colourInput(
          ns("color"),
          "Text color",
          value = "#000000",
          allowTransparent = TRUE,
          showColour = "background"
        )
      ),
      shiny::column(
        6,
        shiny::selectInput(
          ns("alignment"),
          "Paragraph alignment",
          choices = c("left", "right", "center", "justify", "distributed"),
          selected = "left"
        ),
        shiny::textInput(ns("spacing_before"), "Spacing before (e.g. 0pt)"),
        shiny::textInput(ns("spacing_after"), "Spacing after (e.g. 0pt)"),
        shiny::numericInput(ns("line_spacing"), "Line spacing multiplier", value = 1.0, min = 0.5, max = 3, step = 0.1),
        shiny::textInput(ns("indent_left"), "Left indent"),
        shiny::textInput(ns("indent_right"), "Right indent"),
        shiny::textInput(ns("indent_first"), "First-line indent")
      )
    ),
    shiny::hr()
  )
}

text_style_from_inputs <- function(input, id_prefix, template_style = NULL) {
  get_val <- function(name, fallback = NULL) {
    id <- paste0(id_prefix, "_", name)
    if (!is.null(input[[id]])) {
      input[[id]]
    } else if (!is.null(template_style)) {
      # Navigate existing style structure when present
      switch(
        name,
        font_name    = local_or_default(template_style$font$font_name, fallback),
        font_size    = local_or_default(template_style$font$font_size, fallback),
        bold         = local_or_default(template_style$font$bold, fallback),
        italic       = local_or_default(template_style$font$italic, fallback),
        underline    = local_or_default(template_style$font$underline, fallback),
        color        = local_or_default(template_style$font$color, fallback),
        alignment    = local_or_default(template_style$paragraph$alignment, fallback),
        spacing_before = local_or_default(template_style$paragraph$spacing$before, fallback),
        spacing_after  = local_or_default(template_style$paragraph$spacing$after, fallback),
        line_spacing   = local_or_default(template_style$paragraph$spacing$line_spacing, fallback),
        indent_left    = local_or_default(template_style$paragraph$indents$left, fallback),
        indent_right   = local_or_default(template_style$paragraph$indents$right, fallback),
        indent_first   = local_or_default(template_style$paragraph$indents$first_line, fallback),
        fallback
      )
    } else {
      fallback
    }
  }

  list(
    font = list(
      font_name = get_val("font_name"),
      font_size = get_val("font_size"),
      bold      = isTRUE(get_val("bold", FALSE)),
      italic    = isTRUE(get_val("italic", FALSE)),
      underline = isTRUE(get_val("underline", FALSE)),
      color     = {
        raw <- get_val("color")
        if (is.null(raw)) NULL else sub("^#", "", raw)
      }
    ),
    paragraph = list(
      alignment = get_val("alignment", "left"),
      spacing = list(
        before       = get_val("spacing_before", "0pt"),
        after        = get_val("spacing_after", "0pt"),
        line_spacing = as.numeric(local_or_default(get_val("line_spacing", 1.0), 1.0))
      ),
      indents = list(
        left       = get_val("indent_left", "0pt"),
        right      = get_val("indent_right", "0pt"),
        first_line = get_val("indent_first", "0pt")
      )
    )
  )
}

border_ui <- function(id_prefix, label) {
  ns <- function(x) paste0(id_prefix, "_", x)
    shiny::tagList(
    shiny::h5(label),
    shiny::fluidRow(
      shiny::column(
        4,
        colourpicker::colourInput(
          ns("color"),
          "Color",
          value = "#000000",
          allowTransparent = TRUE,
          showColour = "background"
        )
      ),
      shiny::column(4, shiny::textInput(ns("width"), "Width (pt)", value = "")),
      shiny::column(
        4,
        shiny::selectInput(
          ns("line_style"),
          "Line style",
          choices = c("single", "double", "dashed", "dotted", "thick", "none", ""),
          selected = "single"
        )
      )
    )
  )
}

border_from_inputs <- function(input, id_prefix, template_border = NULL) {
  get_val <- function(name, fallback = NULL) {
    id <- paste0(id_prefix, "_", name)
    if (!is.null(input[[id]])) {
      input[[id]]
    } else if (!is.null(template_border)) {
      switch(
        name,
        color      = local_or_default(template_border$color, fallback),
        width      = local_or_default(template_border$width, fallback),
        line_style = local_or_default(template_border$line_style, fallback),
        fallback
      )
    } else {
      fallback
    }
  }

  list(
    color = {
      raw <- get_val("color")
      if (is.null(raw) || !nzchar(raw)) {
        NULL
      } else {
        sub("^#", "", raw)
      }
    },
    width      = null_if_empty(get_val("width")),
    line_style = null_if_empty(get_val("line_style"))
  )
}

row_style_ui <- function(id_prefix, label) {
  ns <- function(x) paste0(id_prefix, "_", x)
  shiny::tagList(
    shiny::h4(label),
    shiny::fluidRow(
      shiny::column(6,
        colourpicker::colourInput(
          ns("background_color"),
          "Background color",
          value = "#FFFFFF",
          allowTransparent = TRUE,
          showColour = "background"
        ),
        shiny::textInput(ns("row_height"), "Row height (e.g. auto, 10pt)", value = "auto"),
        shiny::selectInput(
          ns("vertical_alignment"),
          "Vertical alignment",
          choices = c("top", "center", "bottom", ""),
          selected = "center"
        ),
        shiny::selectInput(
          ns("text_orientation"),
          "Text orientation",
          choices = c("horizontal", "vertical_90", "vertical_270", ""),
          selected = "horizontal"
        )
      ),
      shiny::column(6,
        shiny::h5("Cell margins"),
        shiny::textInput(ns("cell_top"), "Top", value = ""),
        shiny::textInput(ns("cell_bottom"), "Bottom", value = ""),
        shiny::textInput(ns("cell_left"), "Left", value = ""),
        shiny::textInput(ns("cell_right"), "Right", value = ""),
        shiny::h5("Borders"),
        border_ui(paste0(id_prefix, "_border_top"), "Top"),
        border_ui(paste0(id_prefix, "_border_bottom"), "Bottom"),
        border_ui(paste0(id_prefix, "_border_left"), "Left"),
        border_ui(paste0(id_prefix, "_border_right"), "Right")
      )
    ),
    shiny::hr()
  )
}

row_style_from_inputs <- function(input, id_prefix, template_row = NULL) {
  get_val <- function(name, fallback = NULL) {
    id <- paste0(id_prefix, "_", name)
    if (!is.null(input[[id]])) {
      input[[id]]
    } else if (!is.null(template_row)) {
      switch(
        name,
        background_color = local_or_default(template_row$background_color, fallback),
        row_height       = local_or_default(template_row$row_height, fallback),
        vertical_alignment = local_or_default(template_row$vertical_alignment, fallback),
        text_orientation = local_or_default(template_row$text_orientation, fallback),
        cell_top    = local_or_default(template_row$cell_margins$top, fallback),
        cell_bottom = local_or_default(template_row$cell_margins$bottom, fallback),
        cell_left   = local_or_default(template_row$cell_margins$left, fallback),
        cell_right  = local_or_default(template_row$cell_margins$right, fallback),
        fallback
      )
    } else {
      fallback
    }
  }

  borders <- template_row$borders %||% list()

  list(
    background_color = {
      raw_bg <- get_val("background_color")
      if (is.null(raw_bg) || !nzchar(raw_bg)) {
        NULL
      } else {
        sub("^#", "", raw_bg)
      }
    },
    row_height         = local_or_default(get_val("row_height"), "auto"),
    vertical_alignment = null_if_empty(get_val("vertical_alignment")) %||% "center",
    text_orientation  = null_if_empty(get_val("text_orientation")) %||% "horizontal",
    cell_margins = list(
      top    = null_if_empty(get_val("cell_top")),
      bottom = null_if_empty(get_val("cell_bottom")),
      left   = null_if_empty(get_val("cell_left")),
      right  = null_if_empty(get_val("cell_right"))
    ),
    borders = list(
      top    = border_from_inputs(input, paste0(id_prefix, "_border_top"),    template_border = borders$top),
      bottom = border_from_inputs(input, paste0(id_prefix, "_border_bottom"), template_border = borders$bottom),
      left   = border_from_inputs(input, paste0(id_prefix, "_border_left"),   template_border = borders$left),
      right  = border_from_inputs(input, paste0(id_prefix, "_border_right"),  template_border = borders$right)
    )
  )
}

`%||%` <- function(x, y) if (is.null(x)) y else x

ui <- shiny::fluidPage(
  shiny::tags$head(
    shiny::tags$link(rel = "stylesheet", href = "styles.css", type = "text/css"),
    shiny::tags$script(shiny::HTML('
      (function() {
        var key = "ksTFL-theme";
        var theme = localStorage.getItem(key) || "light";
        document.documentElement.setAttribute("data-theme", theme);
        Shiny.addCustomMessageHandler("set-theme", function(msg) {
          var t = msg.dark ? "dark" : "light";
          document.documentElement.setAttribute("data-theme", t);
          localStorage.setItem(key, t);
        });
        $(document).on("shiny:connected", function() {
          var theme = localStorage.getItem(key) || "light";
          if (theme === "dark") {
            var cb = document.getElementById("dark_theme");
            if (cb) {
              cb.checked = true;
              Shiny.setInputValue("dark_theme", true);
            }
          }
        });
      })();
    '))
  ),
  shiny::div(
    class = "editor-toolbar",
    shiny::div(
      class = "toolbar-row",
      shiny::div(class = "toolbar-left",
        shiny::span("ksTFL Template Editor", class = "toolbar-app-name"),
        shiny::span(class = "toolbar-sep"),
        shiny::div(class = "toolbar-inline", shiny::checkboxInput("dark_theme", "Dark theme", value = FALSE)),
        shiny::span(class = "toolbar-sep"),
        shiny::div(class = "toolbar-inline",
          shiny::tags$label(class = "toolbar-inline-label", "Template"),
          shiny::selectInput("bundled_template", NULL, choices = names(bundled_template_paths()), width = "160px")
        ),
        shiny::div(class = "toolbar-inline",
          shiny::tags$label(class = "toolbar-inline-label", "Upload"),
          shiny::fileInput("uploaded_template", NULL, accept = ".json", width = "140px", buttonLabel = "Browse…")
        )
      ),
      shiny::div(class = "toolbar-right",
        shiny::actionButton("load_bundled", "Load template", class = "btn-primary"),
        shiny::actionButton("load_uploaded", "Load uploaded", class = "btn-primary"),
        shiny::actionButton("reset_template", "Reset"),
        shiny::downloadButton("download_template", "Download JSON")
      )
    )
  ),
  shiny::div(
    class = "main-content",
      shiny::tabsetPanel(
        id = "main_tabs",
        shiny::tabPanel(
          "Document",
          shiny::h3("Page"),
          shiny::selectInput(
            "doc_page_size",
            "Page size",
            choices = c("A4", "A3", "Letter", "Legal", "Executive"),
            selected = "A4"
          ),
          shiny::selectInput(
            "doc_page_orientation",
            "Orientation",
            choices = c("portrait", "landscape"),
            selected = "landscape"
          ),
          shiny::h4("Margins"),
          shiny::fluidRow(
            shiny::column(4, shiny::textInput("doc_margin_top", "Top", value = "1in")),
            shiny::column(4, shiny::textInput("doc_margin_bottom", "Bottom", value = "1in")),
            shiny::column(4, shiny::textInput("doc_margin_left", "Left", value = "0.5in"))
          ),
          shiny::fluidRow(
            shiny::column(4, shiny::textInput("doc_margin_right", "Right", value = "0.5in")),
            shiny::column(4, shiny::textInput("doc_margin_header", "Header", value = "1cm")),
            shiny::column(4, shiny::textInput("doc_margin_footer", "Footer", value = "1cm"))
          ),
          shiny::checkboxInput("doc_widow_control", "Widow/orphan control", value = TRUE)
        ),
        shiny::tabPanel(
          "Text styles",
          text_style_ui("default",    "Default"),
          text_style_ui("docHeader",  "Document header"),
          text_style_ui("docFooter",  "Document footer"),
          text_style_ui("titles",     "Titles"),
          text_style_ui("subtitles",  "Subtitles"),
          text_style_ui("footnotes",  "Footnotes"),
          text_style_ui("tableHeader","Table header"),
          text_style_ui("tableBody",  "Table body")
        ),
        shiny::tabPanel(
          "Table style",
          shiny::h3("Layout"),
          shiny::checkboxInput("tbl_allow_row_break", "Allow row break across pages", value = FALSE),
          shiny::checkboxInput("tbl_repeat_header", "Repeat header on each page", value = TRUE),
          shiny::checkboxInput("tbl_prevent_header_break", "Prevent header row break", value = TRUE),
          shiny::selectInput(
            "tbl_alignment",
            "Table alignment",
            choices = c("left", "center", "right", ""),
            selected = "center"
          ),
          shiny::hr(),
          shiny::h3("Structural borders"),
          border_ui("struct_header_top", "Header top border"),
          border_ui("struct_header_bottom", "Header bottom border"),
          border_ui("struct_table_bottom", "Table bottom border"),
          shiny::hr(),
          shiny::h3("Structural regions"),
          shiny::h4("All headers"),
          shiny::selectInput(
            "struct_allheaders_vertical",
            "Vertical alignment",
            choices = c("top", "center", "bottom", ""),
            selected = "center"
          ),
          shiny::h4("Table body"),
          shiny::selectInput(
            "struct_tablebody_vertical",
            "Vertical alignment",
            choices = c("top", "center", "bottom", ""),
            selected = "center"
          ),
          shiny::hr(),
          shiny::h3("Cell defaults"),
          shiny::fluidRow(
            shiny::column(3, shiny::textInput("cell_default_top", "Top margin", value = "")),
            shiny::column(3, shiny::textInput("cell_default_bottom", "Bottom margin", value = "")),
            shiny::column(3, shiny::textInput("cell_default_left", "Left margin", value = "")),
            shiny::column(3, shiny::textInput("cell_default_right", "Right margin", value = ""))
          ),
          shiny::selectInput(
            "cell_default_vertical",
            "Default vertical alignment",
            choices = c("top", "center", "bottom", ""),
            selected = "center"
          ),
          shiny::hr(),
          row_style_ui("header_row", "Header row defaults"),
          row_style_ui("body_row",   "Body row defaults")
        ),
        shiny::tabPanel(
          "Raw JSON",
          shiny::verbatimTextOutput("template_json")
        )
      )
  )
)

server <- function(input, output, session) {
  # Current template (as list) used to seed UI and as a reference for unmapped fields
  # Initialize both current and original templates from the same initial value
  initial <- initial_template()
  current_template <- shiny::reactiveVal(initial)
  # Keep track of the original template used to seed the current editing session
  original_template <- shiny::reactiveVal(initial)

  # Sync dark theme with UI and localStorage
  shiny::observeEvent(input$dark_theme, {
    session$sendCustomMessage("set-theme", list(dark = isTRUE(input$dark_theme)))
  }, ignoreNULL = TRUE)

  # Load bundled template
  shiny::observeEvent(input$load_bundled, {
    paths <- bundled_template_paths()
    name <- input$bundled_template %||% names(paths)[[1L]]
    path <- paths[[name]]
    tmpl <- load_template_file(path)
    # When a new bundled template is loaded, reset both current and original
    original_template(tmpl)
    current_template(tmpl)
  })

  # Load uploaded template
  shiny::observeEvent(input$load_uploaded, {
    file <- input$uploaded_template
    if (is.null(file) || !nzchar(file$datapath)) {
      return()
    }
    tmpl <- load_template_file(file$datapath)
    # When a new uploaded template is loaded, reset both current and original
    original_template(tmpl)
    current_template(tmpl)
  })

  # Reset JSON/editor state back to the original template for this session
  shiny::observeEvent(input$reset_template, {
    tmpl <- original_template()
    # Force reactive invalidation even if template object is identical
    current_template(NULL)
    current_template(tmpl)
  })

  # When template changes, push values into inputs
  shiny::observeEvent(current_template(), {
    tmpl <- current_template()

    # Document
    page <- tmpl$document$page
    margins <- page$margins
    shiny::updateSelectInput(session, "doc_page_size", selected = local_or_default(page$size, "A4"))
    shiny::updateSelectInput(session, "doc_page_orientation", selected = local_or_default(page$orientation, "landscape"))
    shiny::updateTextInput(session, "doc_margin_top",    value = local_or_default(margins$top, "1in"))
    shiny::updateTextInput(session, "doc_margin_bottom", value = local_or_default(margins$bottom, "1in"))
    shiny::updateTextInput(session, "doc_margin_left",   value = local_or_default(margins$left, "0.5in"))
    shiny::updateTextInput(session, "doc_margin_right",  value = local_or_default(margins$right, "0.5in"))
    shiny::updateTextInput(session, "doc_margin_header", value = local_or_default(margins$header, "1cm"))
    shiny::updateTextInput(session, "doc_margin_footer", value = local_or_default(margins$footer, "1cm"))
    shiny::updateCheckboxInput(
      session,
      "doc_widow_control",
      value = isTRUE(tmpl$document$paragraphDefaults$widow_control)
    )

    # Helper to seed text style inputs
    seed_text_style <- function(prefix, style) {
      ns <- function(x) paste0(prefix, "_", x)
      if (is.null(style)) return()
      shiny::updateTextInput(session, ns("font_name"), value = local_or_default(style$font$font_name, ""))
      shiny::updateTextInput(session, ns("font_size"), value = local_or_default(style$font$font_size, ""))
      shiny::updateCheckboxInput(session, ns("bold"), value = isTRUE(style$font$bold))
      shiny::updateCheckboxInput(session, ns("italic"), value = isTRUE(style$font$italic))
      shiny::updateCheckboxInput(session, ns("underline"), value = isTRUE(style$font$underline))
      colour_val <- local_or_default(style$font$color, "")
      if (!is.null(colour_val) && nzchar(colour_val)) {
        colourpicker::updateColourInput(
          session,
          ns("color"),
          value = paste0("#", gsub("^#", "", colour_val))
        )
      }
      shiny::updateSelectInput(session, ns("alignment"), selected = local_or_default(style$paragraph$alignment, "left"))
      shiny::updateTextInput(session, ns("spacing_before"), value = local_or_default(style$paragraph$spacing$before, "0pt"))
      shiny::updateTextInput(session, ns("spacing_after"),  value = local_or_default(style$paragraph$spacing$after, "0pt"))
      shiny::updateNumericInput(
        session,
        ns("line_spacing"),
        value = as.numeric(local_or_default(style$paragraph$spacing$line_spacing, 1.0))
      )
      shiny::updateTextInput(session, ns("indent_left"),  value = local_or_default(style$paragraph$indents$left, "0pt"))
      shiny::updateTextInput(session, ns("indent_right"), value = local_or_default(style$paragraph$indents$right, "0pt"))
      shiny::updateTextInput(session, ns("indent_first"), value = local_or_default(style$paragraph$indents$first_line, "0pt"))
    }

    ts <- tmpl$textStyles
    seed_text_style("default",    ts$default)
    seed_text_style("docHeader",  ts$docHeader)
    seed_text_style("docFooter",  ts$docFooter)
    seed_text_style("titles",     ts$titles)
    seed_text_style("subtitles",  ts$subtitles)
    seed_text_style("footnotes",  ts$footnotes)
    seed_text_style("tableHeader",ts$tableHeader)
    seed_text_style("tableBody",  ts$tableBody)

    # Table layout
    layout <- tmpl$tableStyle$layout
    shiny::updateCheckboxInput(session, "tbl_allow_row_break",       value = isTRUE(layout$allow_row_break_across_pages))
    shiny::updateCheckboxInput(session, "tbl_repeat_header",         value = isTRUE(layout$repeat_header_on_each_page))
    shiny::updateCheckboxInput(session, "tbl_prevent_header_break",  value = isTRUE(layout$prevent_header_row_break))
    shiny::updateSelectInput(session, "tbl_alignment", selected = local_or_default(layout$table_alignment, "center"))

    # Structural borders
    struct <- tmpl$tableStyle$structural
    seed_border <- function(prefix, border) {
      ns <- function(x) paste0(prefix, "_", x)
      if (is.null(border)) return()
      colour_val <- local_or_default(border$color, "")
      if (!is.null(colour_val) && nzchar(colour_val)) {
        colourpicker::updateColourInput(
          session,
          ns("color"),
          value = paste0("#", gsub("^#", "", colour_val))
        )
      }
      shiny::updateTextInput(session, ns("width"), value = local_or_default(border$width, ""))
      shiny::updateSelectInput(session, ns("line_style"), selected = local_or_default(border$line_style, "single"))
    }
    seed_border("struct_header_top",    struct$header_top_border)
    seed_border("struct_header_bottom", struct$header_bottom_border)
    seed_border("struct_table_bottom",  struct$table_bottom_border)

    shiny::updateSelectInput(
      session,
      "struct_allheaders_vertical",
      selected = local_or_default(struct$allHeaders$vertical_alignment, "center")
    )
    shiny::updateSelectInput(
      session,
      "struct_tablebody_vertical",
      selected = local_or_default(struct$tableBody$vertical_alignment, "center")
    )

    # Cell defaults
    cell_def <- tmpl$tableStyle$cellDefaults
    cm <- cell_def$cell_margins
    shiny::updateTextInput(session, "cell_default_top",    value = local_or_default(cm$top, ""))
    shiny::updateTextInput(session, "cell_default_bottom", value = local_or_default(cm$bottom, ""))
    shiny::updateTextInput(session, "cell_default_left",   value = local_or_default(cm$left, ""))
    shiny::updateTextInput(session, "cell_default_right",  value = local_or_default(cm$right, ""))
    shiny::updateSelectInput(
      session,
      "cell_default_vertical",
      selected = local_or_default(cell_def$vertical_alignment, "center")
    )

    # Header/body row styles
    seed_row <- function(prefix, row_style) {
      ns <- function(x) paste0(prefix, "_", x)
      if (is.null(row_style)) return()
      bg_val <- local_or_default(row_style$background_color, "")
      if (!is.null(bg_val) && nzchar(bg_val)) {
        colourpicker::updateColourInput(
          session,
          ns("background_color"),
          value = paste0("#", gsub("^#", "", bg_val))
        )
      }
      shiny::updateTextInput(session, ns("row_height"), value = local_or_default(row_style$row_height, "auto"))
      shiny::updateSelectInput(session, ns("vertical_alignment"), selected = local_or_default(row_style$vertical_alignment, "center"))
      shiny::updateSelectInput(session, ns("text_orientation"), selected = local_or_default(row_style$text_orientation, "horizontal"))
      shiny::updateTextInput(session, ns("cell_top"),    value = local_or_default(row_style$cell_margins$top, ""))
      shiny::updateTextInput(session, ns("cell_bottom"), value = local_or_default(row_style$cell_margins$bottom, ""))
      shiny::updateTextInput(session, ns("cell_left"),   value = local_or_default(row_style$cell_margins$left, ""))
      shiny::updateTextInput(session, ns("cell_right"),  value = local_or_default(row_style$cell_margins$right, ""))

      borders <- row_style$borders %||% list()
      seed_border(paste0(prefix, "_border_top"),    borders$top)
      seed_border(paste0(prefix, "_border_bottom"), borders$bottom)
      seed_border(paste0(prefix, "_border_left"),   borders$left)
      seed_border(paste0(prefix, "_border_right"),  borders$right)
    }

    header_row <- tmpl$tableStyle$header$row
    body_row   <- tmpl$tableStyle$body$row
    seed_row("header_row", header_row)
    seed_row("body_row",   body_row)
  }, ignoreNULL = TRUE)

  assembled_template <- shiny::reactive({
    tmpl <- current_template()

    # Document
    document <- list(
      page = list(
        size = input$doc_page_size,
        orientation = input$doc_page_orientation,
        margins = list(
          top    = input$doc_margin_top,
          bottom = input$doc_margin_bottom,
          left   = input$doc_margin_left,
          right  = input$doc_margin_right,
          header = input$doc_margin_header,
          footer = input$doc_margin_footer
        )
      ),
      paragraphDefaults = list(
        widow_control = isTRUE(input$doc_widow_control)
      )
    )

    ts <- tmpl$textStyles %||% list()
    textStyles <- list(
      default     = text_style_from_inputs(input, "default",    ts$default),
      docHeader   = text_style_from_inputs(input, "docHeader",  ts$docHeader),
      docFooter   = text_style_from_inputs(input, "docFooter",  ts$docFooter),
      titles      = text_style_from_inputs(input, "titles",     ts$titles),
      subtitles   = text_style_from_inputs(input, "subtitles",  ts$subtitles),
      footnotes   = text_style_from_inputs(input, "footnotes",  ts$footnotes),
      tableHeader = text_style_from_inputs(input, "tableHeader",ts$tableHeader),
      tableBody   = text_style_from_inputs(input, "tableBody",  ts$tableBody)
    )

    layout <- list(
      allow_row_break_across_pages = isTRUE(input$tbl_allow_row_break),
      repeat_header_on_each_page   = isTRUE(input$tbl_repeat_header),
      prevent_header_row_break     = isTRUE(input$tbl_prevent_header_break),
      table_alignment              = null_if_empty(input$tbl_alignment)
    )

    structural <- list(
      header_top_border    = border_from_inputs(input, "struct_header_top",    tmpl$tableStyle$structural$header_top_border),
      header_bottom_border = border_from_inputs(input, "struct_header_bottom", tmpl$tableStyle$structural$header_bottom_border),
      table_bottom_border  = border_from_inputs(input, "struct_table_bottom",  tmpl$tableStyle$structural$table_bottom_border),
      allHeaders = list(
        vertical_alignment = null_if_empty(input$struct_allheaders_vertical) %||% "center"
      ),
      tableBody = list(
        vertical_alignment = null_if_empty(input$struct_tablebody_vertical) %||% "center"
      )
    )

    cellDefaults <- list(
      cell_margins = list(
        top    = null_if_empty(input$cell_default_top),
        bottom = null_if_empty(input$cell_default_bottom),
        left   = null_if_empty(input$cell_default_left),
        right  = null_if_empty(input$cell_default_right)
      ),
      vertical_alignment = null_if_empty(input$cell_default_vertical) %||% "center"
    )

    header_row <- row_style_from_inputs(input, "header_row", tmpl$tableStyle$header$row)
    body_row   <- row_style_from_inputs(input, "body_row",   tmpl$tableStyle$body$row)

    tableStyle <- list(
      layout     = layout,
      structural = structural,
      cellDefaults = cellDefaults,
      header = list(
        row = header_row
      ),
      body = list(
        row = body_row
      )
    )

    list(
      document   = document,
      textStyles = textStyles,
      tableStyle = tableStyle
    )
  })

  output$template_json <- shiny::renderText({
    jsonlite::toJSON(assembled_template(), auto_unbox = TRUE, pretty = TRUE)
  })

  output$download_template <- shiny::downloadHandler(
    filename = function() {
      name <- input$bundled_template %||% "styles_template"
      paste0(name, "_edited.json")
    },
    content = function(file) {
      json <- jsonlite::toJSON(assembled_template(), auto_unbox = TRUE, pretty = TRUE)
      writeLines(json, file, useBytes = TRUE)
    }
  )
}

shiny::shinyApp(ui = ui, server = server)

