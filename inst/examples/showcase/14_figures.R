
t.fig <- ggplot(mtcars, aes(x = wt, y = mpg, colour = factor(cyl))) +
  geom_point(size = 3, alpha = 0.8) +
  scale_colour_manual(
    name   = "Cylinders",
    values = c("4" = "#2166AC", "6" = "#F4A582", "8" = "#D6604D")
  ) +
  labs(
    x = "Weight (1000 lbs)",
    y = "Miles per Gallon"
  ) +
  theme_bw(base_size = 11) +
  theme(legend.position = "bottom")

t.fig.spec <- t.fig %>% create_figure() %>% 
  add_title(c("Study Motor Trend", "Figure 1: Fuel Efficiency by Vehicle Weight"), toclevel = 1) %>% 
  add_subtitle("All vehicles, 1974") |>
  add_footnote("Source: 1974 Motor Trend US magazine (n = 32 vehicles).")

t.fig.spec <- t.fig.spec %>% 
  set_document(figureScaleMode = "fitPage",
               docTemplate = "Classic_landscape")

t.fig.report <- create_report(t.fig.spec) 

write_doc(t.fig.report, "showcase_14_minimal_figure_svg", toc = T,
          metaPath = meta_dir, prettify = T)
