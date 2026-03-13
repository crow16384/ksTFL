source(file.path(getwd(), "inst", "examples", "showcase", "init_showcase.R"))

set.seed(20260304)

# -----------------------------------------------------------------------------
# Premium Example 05: CSR-style multi-section bundle
# Sections: narrative, efficacy table, safety table, subject listing, figure
# -----------------------------------------------------------------------------

# Narrative section
spec_txt <- create_text() %>%
  add_title(c("Clinical Study Report", "Integrated Efficacy and Safety Summary"), toclevel = 1) %>%
  add_subtitle("Protocol KS-001 | Full Analysis Set", toclevel = 2) %>%
  add_body_text(paste0(
    "Primary endpoint (change in score at Week 24) favored active treatment: ",
    "<b>-2.4 points</b> versus placebo (95% CI: -3.4, -1.4; <i>p</i> = <b>0.0003</b>)."
  )) %>%
  add_body_text(paste0(
    "Treatment effect was directionally consistent across key strata (age, sex, baseline severity). ",
    "No major imbalance in serious adverse events was observed."
  )) %>%
  add_footnote(c(
    "Illustrative dataset for ksTFL showcase only.",
    "Abbreviations: CI, confidence interval; SAE, serious adverse event."
  ))

# Efficacy table
eff <- tibble::tibble(
  Endpoint = c("Primary endpoint", "Key secondary endpoint", "Responder analysis", "Exploratory endpoint"),
  Placebo = c("-0.4 (0.2)", "-0.2 (0.2)", "28.1%", "1.2 (0.6)"),
  Active = c("-2.8 (0.2)", "-1.1 (0.2)", "44.7%", "2.5 (0.6)"),
  Effect = c("-2.4", "-0.9", "+16.6%", "+1.3"),
  PVAL = c("0.0003", "0.012", "0.004", "0.031")
)

spec_eff <- create_table(eff) %>%
  add_title(c("Table P5.1", "Efficacy Endpoints at Week 24"), toclevel = 1) %>%
  add_subtitle("Model-adjusted estimates") %>%
  define_cols(Endpoint, label = "Endpoint", isID = TRUE, colWidth = "36%") %>%
  define_cols(c(Placebo, Active), label = c("Placebo", "Active"), valueStyleRef = "text_center", colWidth = "16%") %>%
  define_cols(Effect, label = "Treatment Effect", valueStyleRef = "text_center", colWidth = "16%") %>%
  define_cols(PVAL, label = "p-value", valueStyleRef = "text_center", colWidth = "16%") %>%
  compute_cols(
    as.numeric(PVAL) <= 0.01,
    c_style(c(Endpoint, PVAL), styleRef = f_combine("font_bold", "fc_blue"))
  ) %>%
  add_footnote("Nominal p-values from pre-specified model.")

# Safety table with section headers and merge/glue actions
saf <- tibble::tibble(
  SOC = c("Infections", "Infections", "Infections", "GI", "GI", "GI", "Cardiac", "Cardiac"),
  TERM = c("Any infection", "Upper respiratory tract infection", "Bronchitis",
           "Any GI event", "Nausea", "Diarrhea",
           "Any cardiac event", "Palpitations"),
  Active = c("52 (16.3%)", "22 (6.9%)", "11 (3.4%)", "48 (15.0%)", "18 (5.6%)", "13 (4.1%)", "9 (2.8%)", "4 (1.3%)"),
  Placebo = c("47 (14.8%)", "20 (6.3%)", "9 (2.8%)", "39 (12.3%)", "12 (3.8%)", "10 (3.2%)", "8 (2.5%)", "3 (0.9%)"),
  RD = c("+1.5%", "+0.6%", "+0.6%", "+2.7%", "+1.8%", "+0.9%", "+0.3%", "+0.4%")
)

spec_saf <- create_table(saf) %>%
  add_title(c("Table P5.2", "Adverse Events by SOC and Preferred Term"), toclevel = 1) %>%
  define_cols(SOC, isVisible = FALSE) %>%
  define_cols(TERM, label = "System Organ Class / Preferred Term", labelStyleRef = "text_left", valueStyleRef = "indent_1", isID = TRUE, colWidth = "44%") %>%
  define_cols(c(Active, Placebo), label = c("Active n (%)", "Placebo n (%)"), valueStyleRef = "text_center", colWidth = "16%") %>%
  define_cols(RD, label = "Risk Difference", valueStyleRef = "text_center", colWidth = "14%") %>%
  compute_cols(
    firstOf(SOC),
    c_addrow("above", value_from = SOC, styleRef = f_combine("font_bold", "bt_th"))
  ) %>%
  compute_cols(
    TERM == "Any infection" | TERM == "Any GI event" | TERM == "Any cardiac event",
    c_style(c(TERM, Active, Placebo, RD), styleRef = "font_bold")
  ) %>%
  add_footnote("RD = Active minus Placebo incidence.")

# Subject listing with grouping/paging
list_df <- tibble::tibble(
  SITE = rep(sprintf("SITE-%02d", 1:4), each = 15),
  SUBJID = sprintf("KS-%04d", 1:60),
  ARM = sample(c("Placebo", "Active"), 60, replace = TRUE),
  AGE = sample(18:84, 60, replace = TRUE),
  SEX = sample(c("M", "F"), 60, replace = TRUE),
  STATUS = sample(c("Completed", "Discontinued - AE", "Discontinued - Withdrawal"), 60, replace = TRUE, prob = c(0.72, 0.18, 0.10))
) %>% arrange(SITE, SUBJID)

spec_lst <- create_table(list_df) %>%
  add_title(c("Listing P5.1", "Subject Disposition Listing"), toclevel = 1) %>%
  define_cols(SITE, label = "Site", isID = TRUE, isGrouping = TRUE, dedupe = TRUE) %>%
  define_cols(SUBJID, label = "Subject", isID = TRUE, isPaging = TRUE, dedupe = TRUE) %>%
  define_cols(ARM, label = "Treatment", valueStyleRef = "text_center") %>%
  define_cols(AGE, label = "Age", type = "numeric", format = "%.0f", valueStyleRef = "text_center") %>%
  define_cols(SEX, label = "Sex", valueStyleRef = "text_center") %>%
  define_cols(STATUS, label = "Status", labelStyleRef = "text_left") %>%
  compute_cols(
    STATUS != "Completed",
    c_style(c(SUBJID, STATUS), styleRef = f_combine("font_bold", "fc_red"))
  )

# Optional figure section (if ggplot2 installed)
if (requireNamespace("ggplot2", quietly = TRUE)) {
  plot_df <- tibble::tibble(
    Week = rep(c(0, 4, 8, 12, 24), 2),
    Arm = rep(c("Placebo", "Active"), each = 5),
    MeanChange = c(0, -0.2, -0.3, -0.4, -0.4,
                   0, -0.9, -1.5, -2.0, -2.4)
  )

  p <- ggplot2::ggplot(plot_df, ggplot2::aes(Week, MeanChange, colour = Arm, shape = Arm)) +
    ggplot2::geom_line(linewidth = 1.0) +
    ggplot2::geom_point(size = 3) +
    ggplot2::scale_x_continuous(breaks = c(0, 4, 8, 12, 24)) +
    ggplot2::labs(x = "Week", y = "Mean Change from Baseline") +
    ggplot2::theme_bw(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")

  spec_fig <- create_figure(p, dpi = 300) %>%
    add_title(c("Figure P5.1", "Trajectory of Mean Change by Treatment"), toclevel = 1) %>%
    add_subtitle("Model-adjusted means")

  report <- create_report(spec_txt, spec_eff, spec_fig, spec_saf, spec_lst)
} else {
  spec_nofig <- create_text() %>%
    add_title("Figure P5.1 placeholder", toclevel = 1) %>%
    add_body_text("Install ggplot2 to render the trajectory figure section.")

  report <- create_report(spec_txt, spec_eff, spec_nofig, spec_saf, spec_lst)
}

write_doc(report, "premium_05_csr_bundle", toc = TRUE, metaPath = meta_dir)
