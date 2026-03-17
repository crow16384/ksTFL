source(file.path(getwd(), "inst", "examples", "showcase", "init_showcase.R"))

set.seed(20260304)

arms <- c("DrugX", "Placebo", "Total")
sections <- c("Age (years)", "Sex", "Race")

raw <- tibble(
  SECTION = c(
    rep("Age (<s>years</s>)", 6),
    rep("<u>Sex</u>", 3),
    rep("Race", 4)
  ),
  STAT = c(
    "n", "Mean (SD)", "Median", "Q1; Q3", "Min; Max", "p-value (ANOVA)",
    "Female", "Male", "p-value (Fisher)",
    "White", "Asian", "Black", "p-value (Fisher)"
  ),
  DRUGX = c("160", "55.2 (12.4)", "54.0", "47.0; 64.0", "18; 82", "", "88 (55.0%)", "72 (45.0%)", "", "130 (81.2%)", "18 (11.2%)", "12 (7.5%)", ""),
  PLCB = c("158", "56.0 (11.9)", "55.0", "48.0; 63.0", "20; 81", "", "90 (57.0%)", "68 (43.0%)", "", "124 (78.5%)", "22 (13.9%)", "12 (7.6%)", ""),
  TOTAL = c("318", "55.6 (12.1)", "54.0", "47.5; 63.5", "18; 82", "", "178 (56.0%)", "140 (44.0%)", "", "254 (79.9%)", "40 (12.6%)", "24 (7.5%)", ""),
  MODELVAL = c(NA, NA, NA, NA, NA, "0.041", NA, NA, ">0.999", NA, NA, NA, "0.772")
) %>%
  group_by(SECTION) %>%
  mutate(SECTION_ID = cur_group_id()) %>%
  ungroup()

spec <- create_table(raw) %>%
  add_title(c("Table S1", "Demographic and Baseline Characteristics"), toclevel = 1) %>%
  add_title("Full Analysis Set", styleRef = "font_italic") %>%
  add_footnote(c(
    "Values are shown as n (%), mean (SD), median, or quartiles.",
    "P-values shown for section-level inferential tests."
  )) %>%
  define_cols(c(SECTION, SECTION_ID, MODELVAL), isVisible = FALSE) %>%
  define_cols(STAT,
    label = "Parameter<br>  Statistic",
    labelStyleRef = "text_left",
    valueStyleRef = "indent_1"
  ) %>%
  define_cols(c(DRUGX, PLCB, TOTAL),
    label = c("DrugX<br>(N=160)", "Placebo<br>(N=158)", "Total<br>(N=318)"),
    #labelStyleRef = "to_90",
    valueStyleRef = "text_center",
    colWidth = "16%"
  ) %>%
  compute_cols(
    firstOf(SECTION),
    c_addrow("above", value_from = SECTION, styleRef = "font_bold")
  ) %>%
  compute_cols(
    !is.na(MODELVAL),
    c_merge(c(DRUGX, PLCB), styleRef = f_combine("text_center", "bt_th", "i")),
    c_style(STAT, "i"),
    c_glue(DRUGX, "after", glue_col = MODELVAL)
  ) %>%
  compute_cols(
    lastOf(SECTION_ID),
    c_addrow("below", styleRef = "row_h4")
  ) %>%
  compute_cols(
    SECTION_ID == 3 & firstOf(SECTION_ID),
    c_pageBreak()
  ) %>%
  set_document(contentWidth = "75%", docTemplate = "Classic_landscape_aptos")

list_reports()

create_report(spec) %>% write_doc("01_clinical_table", toc = TRUE)
