source(file.path(getwd(), "inst", "examples", "showcase", "init_showcase.R"))

set.seed(20260304)

pk <- tibble(
  TIME = rep(c(0, 0.5, 1, 2, 4, 8, 12), 3),
  TRT = rep(c("Placebo", "Low Dose", "High Dose"), each = 7),
  CONC = c(0, 14, 25, 20, 11, 6, 3,
           0, 22, 39, 31, 18, 10, 5,
           0, 29, 52, 41, 24, 14, 7)
)

summary_tbl <- pk %>%
  group_by(TRT) %>%
  summarise(
    Cmax = max(CONC),
    Tmax = TIME[which.max(CONC)],
    .groups = "drop"
  )

if (requireNamespace("ggplot2", quietly = TRUE)) {
  p <- ggplot2::ggplot(pk, ggplot2::aes(TIME, CONC, colour = TRT, shape = TRT)) +
    ggplot2::geom_line(linewidth = 0.9) +
    ggplot2::geom_point(size = 2.8) +
    ggplot2::scale_x_continuous(breaks = c(0, 0.5, 1, 2, 4, 8, 12)) +
    ggplot2::labs(x = "Time (h)", y = "Concentration (ng/mL)") +
    ggplot2::theme_bw(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")

  spec_fig <- create_figure(p, dpi = 300) %>%
    add_title(c("Figure S3.1", "Mean PK Concentration–Time Profile"), toclevel = 1) %>%
    add_subtitle("PK Analysis Set") %>%
    set_document(continuousSection = FALSE, figureHeight = '4in')
} else {
  spec_fig <- create_text() %>%
    add_title("Figure S3.1 placeholder", toclevel = 1) %>%
    add_body_text("Install ggplot2 to render this figure section.")
}

spec_tbl <- create_table(summary_tbl) %>%
  define_cols(TRT, label = "Treatment", isID = TRUE, colWidth = "40%") %>%
  define_cols(Cmax, label = "C[max]", type = "numeric", format = "%.1f", valueStyleRef = "text_center") %>%
  define_cols(Tmax, label = "T[max] (h)", type = "numeric", format = "%.1f", valueStyleRef = "text_center") %>%
  add_footnote("C[max] = maximum concentration; T[max] = time of C[max].") %>%
  set_document(continuousSection = TRUE)

create_report(spec_fig, spec_tbl) %>%
  write_doc("03.1_table_under_figure", toc = TRUE, metaPath = meta_dir)
