library(shiny)
library(sortable)
library(shinyFiles)

make_entry_id <- function() {
  paste0("e", format(Sys.time(), "%H%M%S"), "_", sample.int(1e6, 1))
}

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
ui <- fluidPage(
  tags$head(tags$style(HTML("
    .meta-block { background:#f8f9fa; border:1px solid #dee2e6;
      border-radius:6px; padding:10px; margin-bottom:10px; }
    .avail-item { padding:4px 8px; margin:2px 0; cursor:pointer;
      border-radius:3px; border:1px solid transparent; display:flex;
      justify-content:space-between; align-items:center; }
    .avail-item:hover { background:#e9ecef; border-color:#adb5bd; }
    .sel-item { background:#fff; border:1px solid #ced4da;
      border-radius:4px; padding:8px 12px; margin-bottom:4px;
      cursor:grab; display:flex; justify-content:space-between;
      align-items:center; }
    .sel-item:active { cursor:grabbing; }
    .sel-item .doc-name { font-weight:600; }
    .sel-item .meta-src  { font-size:0.8em; color:#6c757d; }
    .sel-item .rm-btn { cursor:pointer; color:#dc3545; font-weight:bold;
      font-size:1.2em; padding:0 4px; }
    .sel-item .rm-btn:hover { color:#a71d2a; }
    #selected_order .rank-list-item { padding:0; background:transparent;
      border:none; }
    .render-log { background:#1e1e1e; color:#d4d4d4; padding:10px;
      border-radius:4px; font-family:monospace; font-size:0.85em;
      max-height:200px; overflow-y:auto; white-space:pre-wrap; }
    .dir-chooser { display:flex; gap:6px; align-items:center;
      margin-bottom:8px; }
    .dir-chooser .form-group { margin-bottom:0; flex:1; }
  "))),

  titlePanel("ksTFL Combined Replay"),

  # ---- Top: Available Reports ----
  wellPanel(
    h4("Meta Folders"),
    fluidRow(
      column(6,
        div(class = "dir-chooser",
          shinyDirButton("browse_meta", "Browse\u2026", "Select meta folder"),
          textInput("new_meta_dir", label = NULL,
                    placeholder = "Enter meta folder path...")
        )
      ),
      column(2, actionButton("btn_add_meta", "Add",
                              class = "btn-primary btn-sm",
                              style = "margin-top:1px;"))
    ),
    uiOutput("meta_folders_ui")
  ),

  # ---- Bottom: Selected Reports (reorderable) + Output ----
  wellPanel(
    h4("Selected Reports (drag to reorder)"),
    uiOutput("selected_reports_ui"),
    hr(),
    fluidRow(
      column(4,
        div(class = "dir-chooser",
          shinyDirButton("browse_outdir", "Browse\u2026",
                         "Select output folder"),
          textInput("output_dir", label = "Output folder",
                    placeholder = "e.g. output/")
        )
      ),
      column(4, textInput("output_file", "Output filename",
                          value = "combined_replay.docx")),
      column(4, style = "padding-top:25px;",
             downloadButton("btn_render", "Render Combined DOCX",
                            class = "btn-success"))
    ),
    fluidRow(
      column(4, checkboxInput("insert_toc", "Insert Table of Contents",
                              value = FALSE)),
      column(8, conditionalPanel(
        condition = "input.insert_toc",
        textInput("toc_title", "TOC Title",
                  value = "Table of Contents")
      ))
    ),
    hr(),
    h5("Render Log"),
    uiOutput("render_log_ui")
  )
)

# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------
server <- function(input, output, session) {

  # System volumes for directory choosers
  volumes <- c(Home = path.expand("~"), getVolumes()())

  rv <- reactiveValues(
    meta_dirs      = character(0),
    reports_by_dir = list(),
    selected       = list(),
    render_log     = ""
  )

  # ---- Directory chooser: meta folder ----
  shinyDirChoose(input, "browse_meta", roots = volumes, session = session)

  observeEvent(input$browse_meta, {
    chosen <- parseDirPath(volumes, input$browse_meta)
    if (length(chosen) > 0 && nzchar(chosen))
      updateTextInput(session, "new_meta_dir", value = as.character(chosen))
  })

  # ---- Directory chooser: output folder ----
  shinyDirChoose(input, "browse_outdir", roots = volumes, session = session)

  observeEvent(input$browse_outdir, {
    chosen <- parseDirPath(volumes, input$browse_outdir)
    if (length(chosen) > 0 && nzchar(chosen))
      updateTextInput(session, "output_dir", value = as.character(chosen))
  })

  # Pre-populate from launcher option
  observe({
    init_dir <- getOption("ksTFL.replay_app.meta_dir")
    if (!is.null(init_dir) && nzchar(init_dir) && dir.exists(init_dir)) {
      isolate({
        if (!init_dir %in% rv$meta_dirs) {
          rv$meta_dirs <- c(rv$meta_dirs, init_dir)
          rv$reports_by_dir[[init_dir]] <- tryCatch(
            ksTFL::list_reports(init_dir),
            error = function(e) data.frame()
          )
        }
      })
    }
  })

  # ---- Add meta folder ----
  observeEvent(input$btn_add_meta, {
    md <- trimws(input$new_meta_dir)
    if (!nzchar(md)) {
      showNotification("Please enter a path.", type = "warning"); return()
    }
    if (!dir.exists(md)) {
      showNotification(paste("Not found:", md), type = "error"); return()
    }
    if (md %in% rv$meta_dirs) {
      showNotification("Already added.", type = "warning"); return()
    }
    reports <- tryCatch(ksTFL::list_reports(md), error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
      data.frame()
    })
    rv$meta_dirs <- c(rv$meta_dirs, md)
    rv$reports_by_dir[[md]] <- reports
    updateTextInput(session, "new_meta_dir", value = "")
  })

  # ---- Latest reports for a meta dir ----
  latest_reports <- function(md) {
    df <- rv$reports_by_dir[[md]]
    if (is.null(df) || nrow(df) == 0) return(NULL)
    if ("is_latest" %in% names(df)) df <- df[df$is_latest, , drop = FALSE]
    if (nrow(df) == 0) return(NULL)
    df
  }

  # ---- Available reports panel ----
  output$meta_folders_ui <- renderUI({
    if (length(rv$meta_dirs) == 0)
      return(tags$p(class = "text-muted", "No meta folders added yet."))

    lapply(seq_along(rv$meta_dirs), function(i) {
      md <- rv$meta_dirs[i]
      df <- latest_reports(md)

      items <- if (is.null(df)) {
        tags$p(class = "text-muted", "No reports found.")
      } else {
        lapply(seq_len(nrow(df)), function(j) {
          tags$div(class = "avail-item",
            tags$span(df$doc_file[j],
              tags$small(class = "text-muted",
                paste0(" (", df$n_specs[j], " specs)"))),
            actionLink(paste0("add_", i, "_", j), label = NULL,
                       icon = icon("plus"),
                       style = "color:#198754;")
          )
        })
      }

      div(class = "meta-block",
        fluidRow(
          column(8, h5(tags$code(basename(md)),
                       tags$small(class = "text-muted",
                                  paste0(" \u2014 ", dirname(md))))),
          column(4, style = "text-align:right;",
            actionLink(paste0("rm_meta_", i), "Remove",
                       style = "color:#dc3545;font-size:0.85em;"),
            if (!is.null(df))
              actionLink(paste0("addall_", i), " | Add all",
                         style = "color:#0d6efd;font-size:0.85em;")
          )
        ),
        items
      )
    })
  })

  # ---- Dynamic observers for add / remove ----
  observe({
    lapply(seq_along(rv$meta_dirs), function(i) {
      md <- rv$meta_dirs[i]
      df <- latest_reports(md)

      observeEvent(input[[paste0("rm_meta_", i)]], {
        rv$meta_dirs <- rv$meta_dirs[rv$meta_dirs != md]
        rv$reports_by_dir[[md]] <- NULL
        rv$selected <- Filter(function(x) x$meta_dir != md, rv$selected)
      }, ignoreInit = TRUE, once = TRUE)

      if (!is.null(df)) {
        observeEvent(input[[paste0("addall_", i)]], {
          for (j in seq_len(nrow(df))) {
            rv$selected <- c(rv$selected, list(list(
              id = make_entry_id(), doc_file = df$doc_file[j],
              meta_dir = md, spec_file = df$spec_file[j]
            )))
          }
        }, ignoreInit = TRUE, once = TRUE)

        lapply(seq_len(nrow(df)), function(j) {
          observeEvent(input[[paste0("add_", i, "_", j)]], {
            rv$selected <- c(rv$selected, list(list(
              id = make_entry_id(), doc_file = df$doc_file[j],
              meta_dir = md, spec_file = df$spec_file[j]
            )))
          }, ignoreInit = TRUE, once = TRUE)
        })
      }
    })
  })

  # ---- Selected reports with sortable ----
  output$selected_reports_ui <- renderUI({
    sel <- rv$selected
    if (length(sel) == 0)
      return(tags$p(class = "text-muted",
                    "No reports selected. Add from the panel above."))

    items <- lapply(seq_along(sel), function(k) {
      e <- sel[[k]]
      tags$div(class = "sel-item", id = e$id,
        tags$div(
          tags$span(class = "doc-name", paste0(k, ". ", e$doc_file)),
          tags$br(),
          tags$span(class = "meta-src", basename(e$meta_dir))
        ),
        tags$span(class = "rm-btn",
          onclick = paste0("Shiny.setInputValue('rm_sel','", e$id,
                           "',{priority:'event'})"),
          HTML("&times;"))
      )
    })

    rank_list(
      text = NULL, labels = items, input_id = "selected_order",
      options = sortable_options(animation = 150)
    )
  })

  # ---- Reorder ----
  observeEvent(input$selected_order, {
    ids <- input$selected_order
    if (is.null(ids) || length(ids) == 0) return()
    old <- isolate(rv$selected)
    id_map <- setNames(old, vapply(old, `[[`, "", "id"))
    reordered <- list()
    for (oid in ids) {
      if (oid %in% names(id_map))
        reordered <- c(reordered, list(id_map[[oid]]))
    }
    if (length(reordered) > 0) rv$selected <- reordered
  })

  # ---- Remove from selected ----
  observeEvent(input$rm_sel, {
    rv$selected <- Filter(function(x) x$id != input$rm_sel, rv$selected)
  })

  # ---- Render log ----
  output$render_log_ui <- renderUI({
    tags$div(class = "render-log",
             if (nzchar(rv$render_log)) rv$render_log else "Ready.")
  })

  # ---- Render combined DOCX ----
  output$btn_render <- downloadHandler(
    filename = function() {
      fn <- trimws(input$output_file)
      if (!nzchar(fn)) fn <- "combined_replay.docx"
      if (!grepl("\\.docx$", fn, ignore.case = TRUE)) fn <- paste0(fn, ".docx")
      fn
    },
    content = function(file) {
      sel <- isolate(rv$selected)
      if (length(sel) == 0) {
        showNotification("No reports selected.", type = "error"); return()
      }

      spec_jsons <- vapply(sel, `[[`, "", "doc_file")
      meta_dirs  <- vapply(sel, `[[`, "", "meta_dir")
      toc_flag   <- if (input$insert_toc) TRUE else NULL
      toc_title  <- if (input$insert_toc && nzchar(input$toc_title))
                      input$toc_title else NULL

      rv$render_log <- paste0("Rendering ", length(sel), " reports...\n")

      tryCatch({
        tmp_out <- tempfile(fileext = ".docx")
        ksTFL::replay_report(
          spec_json   = spec_jsons,
          meta_dir    = meta_dirs,
          output_path = tmp_out,
          insertTOC   = toc_flag,
          tocTitle    = toc_title
        )
        file.copy(tmp_out, file, overwrite = TRUE)
        # Also save to chosen output directory if specified
        out_dir <- trimws(input$output_dir)
        if (nzchar(out_dir) && dir.exists(out_dir)) {
          fn <- trimws(input$output_file)
          if (!nzchar(fn)) fn <- "combined_replay.docx"
          if (!grepl("\\.docx$", fn, ignore.case = TRUE))
            fn <- paste0(fn, ".docx")
          dest <- file.path(out_dir, fn)
          file.copy(tmp_out, dest, overwrite = TRUE)
          rv$render_log <- paste0(rv$render_log, "Saved to: ", dest, "\n")
        }
        unlink(tmp_out)
        rv$render_log <- paste0(rv$render_log,
          "Success! ", length(sel), " documents combined.\n")
      }, error = function(e) {
        rv$render_log <- paste0(rv$render_log, "ERROR: ", e$message, "\n")
        showNotification(paste("Render failed:", e$message), type = "error")
      })
    }
  )
}

shinyApp(ui, server)
